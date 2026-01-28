-- lua/super_processor.lua
-- @amzxyz
-- https://github.com/amzxyz/rime_wanxiang
-- 全能按键处理器：整合 KP小键盘、字母选词、符号快打、超强分词、重复限制、退格限制、声调回退、以词定字
-- 
-- 用法: 在 schema.yaml 中 engine/processors 列表添加 - lua_processor@*super_processor

local wanxiang = require("wanxiang")
local M = {}

local K_REJECT, K_ACCEPT, K_NOOP = 0, 1, 2

-- 1. 全局常量定义 (Constants)

-- [KpNumber] 小键盘键码映射
local KP_MAP = {
    [0xFFB1] = 1, [0xFFB2] = 2, [0xFFB3] = 3,
    [0xFFB4] = 4, [0xFFB5] = 5, [0xFFB6] = 6,
    [0xFFB7] = 7, [0xFFB8] = 8, [0xFFB9] = 9,
    [0xFFB0] = 0,
}

-- [LetterSelector] 字母选词键码映射 (qwert...)
local LETTER_SEL_MAP = {
    [0x71] = 1, [0x77] = 2, [0x65] = 3, [0x72] = 4, [0x74] = 5,
    [0x79] = 6, [0x75] = 7, [0x69] = 8, [0x6F] = 9, [0x70] = 10,
}

-- [QuickSymbol] 默认符号映射表
local SYMBOL_DEFAULT = {
    q="：", w="？", e="（", r="）", t="~", y="·", u="『", i="』", o="〖", p="〗",
    a="！", s="……", d="、", f="“", g="”", h="‘", j="’", k="【", l="】",
    z="。", x="？", c="！", v="——", b="%", n="《", m="》"
}

-- [LimitRepeated] 重复限制配置
local MAX_REPEAT = 8
local MAX_SEGMENTS = 40
local INITIALS = "[bpmfdtnlgkhjqxrzcsywiu]"

-- [SuperSegmentation] 分词模式配置
local SEG_PATTERNS = {
    [3] = { all = { {2,1}, {1,2} } },
    [4] = { all = { {2,2}, {1,3}, {3,1} } },
    [5] = { all = { {2,3}, {3,2} } },
    [6] = { all = { {2,2,2}, {3,3} } },
    [7] = { all = { {2,2,3}, {2,3,2}, {3,2,2} } },
    [8] = { all = { {2,2,2,2}, {2,3,3}, {3,2,3}, {3,3,2} } },
    [10] = { all = { {2,2,2,2,2} } },
}

-- 2. 核心辅助函数 (Utilities)

-- 字符串转义
local function escp(ch) return ch:gsub("(%W)","%%%1") end

-- 数组求和
local function sum(a) local s=0; for _,v in ipairs(a) do s=s+v end; return s end

-- 表键生成
local function key_of(a) return table.concat(a, ",") end

-- 列表查找索引
local function find_idx(list, key) for i,t in ipairs(list) do if key_of(t)==key then return i end end end

-- 统计末尾指定字符数量
local function count_trailing(s, ch) local n=0; for i=#s,1,-1 do if s:sub(i,i)==ch then n=n+1 else break end end; return n end

-- 移除末尾指定字符
local function strip_trailing(s, ch) return (s:gsub(escp(ch).."+$","")) end

-- 移除分隔符 (自动和手动)
local function strip_delims(s, md, ad)
    if md and md~="" then s = s:gsub(escp(md),"") end
    if ad and ad~="" then s = s:gsub(escp(ad),"") end
    return s
end

-- 根据分组重构字符串
local function build_by_groups(core, ch_manual, groups)
    if not groups or #groups==0 or sum(groups)~=#core then return core end
    local out, i = {}, 1
    for gi,g in ipairs(groups) do
        out[#out+1] = core:sub(i, i+g-1); i = i + g
        if gi < #groups then out[#out+1] = ch_manual end
    end
    return table.concat(out)
end

-- 从字符串解析分段长度
local function lens_from_string(s, md, ad)
    if not s or s=="" then return nil end
    local segs, buf = {}, {}
    local function flush() if #buf>0 then segs[#segs+1]=table.concat(buf); buf={} end end
    for i=1,#s do
        local c=s:sub(i,i)
        if c==md or c==ad or c==" " then flush()
        else
            local b=string.byte(c)
            if b and ((b>=65 and b<=90) or (b>=97 and b<=122)) then buf[#buf+1]=string.char(b):lower() end
        end
    end
    flush()
    if #segs==0 then return nil end
    local L={}; for _,seg in ipairs(segs) do L[#L+1]=#seg end
    return L
end

-- 获取缓存的分段长度
local function get_cached_lens(env, ctx, md, ad)
    local L = env.seg_last_preedit_lens
    if L and type(L)=="table" and #L>0 then return L end
    local seg = ctx.composition:back()
    local cand = seg and seg:get_selected_candidate() or nil
    return lens_from_string(cand and cand.preedit or nil, md, ad)
end

-- 增强版 UTF-8 长度计算 (Super Segmentation 使用)
local function ulen(s)
    if not s or s == "" then return 0 end
    if utf8 and utf8.len then
        local ok, n = pcall(utf8.len, s)
        if ok and n then return n end
    end
    local n = 0
    if utf8 and utf8.codes then
        for _ in utf8.codes(s) do n = n + 1 end
        return n
    end
    return #s
end

-- 检查数字后是否紧跟功能编码 (KpNumber 使用)
local function is_function_code_after_digit(env, context, digit_char)
    if not context or not digit_char or digit_char == "" then return false end
    local code = context.input or ""
    local s = code .. digit_char
    local pats = env.kp_func_patterns
    if not pats then return false end
    for _, pat in ipairs(pats) do
        if s:match(pat) then return true end
    end
    return false
end

-- 计算尾部重复字符数 (LimitRepeated 使用)
local function tail_rep(s)
    local last, n = s:sub(-1), 1
    for i = #s - 1, 1, -1 do
        if s:sub(i, i) == last then n = n + 1 else break end
    end
    return last, n
end

-- 设置候选框提示 (LimitRepeated 使用)
local function prompt(ctx, msg)
    local comp = ctx.composition
    if comp and not comp:empty() then comp:back().prompt = msg end
end

-- 压缩连续声调 (ToneFallback 使用)
local function compress_runs_keep_last(text)
    local changed = false
    local out = text:gsub('([7890])([7890]+)', function(_, tail)
        changed = true
        return tail:sub(-1)
    end)
    return out, changed
end

-- 3. 初始化与资源管理 (Init & Fini)

function M.init(env)
    local engine = env.engine
    local config = engine.schema.config
    local context = engine.context

    -- [1] 配置加载 (按功能模块分类)

    -- [BackspaceLimit]
    env.bs_prev_len = -1
    env.bs_sequence = false

    -- [KpNumber] 小键盘
    env.kp_page_size = config:get_int("menu/page_size") or 6
    local m = config:get_string("kp_number_mode") or "auto"
    env.kp_mode = (m == "auto" or m == "compose") and m or "auto"
    env.kp_func_patterns = wanxiang.load_regex_patterns(config, "recognizer/patterns")

    -- [LetterSelector] 字母选词状态位
    env.ls_active = false 

    -- [ToneFallback] 声调容错
    env.tone_state = "idle"
    env.lookup_key = config:get_string('wanxiang_lookup/key') or '`'

    -- [QuickSymbol] 符号快打
    env.qs_trigger = "^([a-z])/$"
    if config then
        local ok, s = pcall(function() return config:get_string("quick_symbol_text/trigger") end)
        if ok and type(s)=="string" and #s>0 then env.qs_trigger = s end
    end
    env.qs_mapping = {}
    for k, v in pairs(SYMBOL_DEFAULT) do env.qs_mapping[k] = v end
    local ok_map, map = pcall(function() return config:get_map("quick_symbol_text/symkey") end)
    if ok_map and map then
        local ok_keys, keys = pcall(function() return map:keys() end)
        if ok_keys and keys then
            for _, key in ipairs(keys) do
                local v = config:get_string("quick_symbol_text/symkey/" .. key)
                if v then env.qs_mapping[tostring(key)] = v end
            end
        end
    end
    env.qs_last_commit = "欢迎使用万象拼音！"

    -- [SelectCharacter] 以词定字
    env.sc_first_key = config:get_string('key_binder/select_first_character')
    env.sc_last_key = config:get_string('key_binder/select_last_character')

    -- [SuperSegmentation] 超强分词
    local delim = config:get_string("speller/delimiter") or " '"
    env.seg_auto_delim = delim:sub(1,1)
    env.seg_manual_delim = delim:sub(2,2)
    env.seg_core = nil
    env.seg_start_idx = nil
    env.seg_N = nil
    env.seg_base = nil

    -- [2] 统一 Update Notifier (状态缓存与自动处理)

    env.conn_update = context.update_notifier:connect(function(ctx)
        -- A. [ToneFallback] 执行声调压缩
        local t_state = env.tone_state or "idle"
        env.tone_state = "idle" 
        
        local input = ctx.input or ""
        if t_state == "compress" and input ~= "" then
            local caret = (ctx.caret_pos ~= nil) and ctx.caret_pos or #input
            if caret < 0 then caret = 0 end
            if caret > #input then caret = #input end

            local left  = (caret > 0) and input:sub(1, caret) or ""
            local left_new, changed = compress_runs_keep_last(left)
            
            if changed then
                if caret > 0 then ctx:pop_input(caret) end
                if #left_new > 0 then ctx:push_input(left_new) end
            end
        end

        -- B. [SuperSegmentation] 缓存数据
        local seg = ctx.composition:back()
        local cand = seg and seg:get_selected_candidate() or nil
        local pre = cand and cand.preedit or nil
        env.seg_last_preedit_lens = lens_from_string(pre, env.seg_manual_delim, env.seg_auto_delim)
        env.seg_last_input_caret = input
        env.seg_last_caret_pos = ctx.caret_pos

        -- C. [LetterSelector] 缓存激活状态
        env.ls_active = false
        if not ctx.composition:empty() then
            local s = ctx.composition:back()
            if s and (s:has_tag("number") or s:has_tag("Ndate")) then
                env.ls_active = true
            end
        end

        -- D. [KpNumber] 缓存状态
        env.kp_is_composing = ctx:is_composing()
        env.kp_has_menu = ctx:has_menu()

        -- E. [QuickSymbol] 自动上屏逻辑
        local qkey = string.match(input, env.qs_trigger)
        if qkey then
            local symbol = env.qs_mapping[qkey]
            if symbol and symbol ~= "" then
                if type(symbol)=="string" and symbol:lower()=="repeat" then
                    if env.qs_last_commit ~= "" then
                        engine:commit_text(env.qs_last_commit)
                        ctx:clear()
                    end
                else
                    engine:commit_text(symbol)
                    ctx:clear()
                end
            end
        end
    end)
    -- [3] 统一 Commit Notifier (记录上屏)
    env.conn_commit = context.commit_notifier:connect(function(ctx)
        local t = ctx:get_commit_text()
        if t ~= "" then env.qs_last_commit = t end
    end)
end

function M.fini(env)
    if env.conn_update then env.conn_update:disconnect(); env.conn_update = nil end
    if env.conn_commit then env.conn_commit:disconnect(); env.conn_commit = nil end
    env.memory = nil
end

-- 4. 逻辑分发处理 (Handlers)

-- [QuickSymbol] 拦截触发键，防止进入 Speller
local function handle_quick_symbol_intercept(key, env, ctx)
    local input = ctx.input or ""
    local matched = string.match(input, env.qs_trigger)
    if matched then
        local k = matched
        if env.qs_mapping[k] and env.qs_mapping[k] ~= "" then
            return true -- Accepted
        end
    end
    return false
end

-- [SuperSegmentation] 处理分词符 '
local function handle_segmentation(key, env, ctx)
    if key.keycode ~= string.byte(env.seg_manual_delim) then
        env.seg_core, env.seg_start_idx, env.seg_N, env.seg_base = nil, nil, nil, nil
        return false 
    end
    if ctx.composition:empty() then return false end

    local last_input = env.seg_last_input_caret or ctx.input or ""
    local last_caret = env.seg_last_caret_pos
    if not last_caret or last_caret ~= ulen(last_input) then
        env.seg_core, env.seg_start_idx, env.seg_N, env.seg_base = nil, nil, nil, nil
        return false
    end

    local md = env.seg_manual_delim
    local before = ctx.input or ""
    local after = before .. md
    local tlen = count_trailing(after, md)
    local head = strip_trailing(after, md)
    local core = strip_delims(head, md, env.seg_auto_delim)
    local N = #core
    local conf = SEG_PATTERNS[N]
    -- 大于 10 码动态构建分词：在2、3码之间循环
    if N > 10 then
        local groups_2 = {}
        for i = 1, math.floor(N / 2) do table.insert(groups_2, 2) end
        if N % 2 ~= 0 then table.insert(groups_2, N % 2) end

        local groups_3 = {}
        for i = 1, math.floor(N / 3) do table.insert(groups_3, 3) end
        if N % 3 ~= 0 then table.insert(groups_3, N % 3) end

        conf = { all = { groups_2, groups_3 } }
    end
    if env.seg_core ~= core or env.seg_N ~= N then
        env.seg_core = core
        env.seg_N = N
        env.seg_start_idx = nil
        env.seg_base = nil
    end

    if env.seg_base == nil then env.seg_base = head end

    if conf and env.seg_start_idx == nil then
        local start_idx = 0
        local L = get_cached_lens(env, ctx, md, env.seg_auto_delim)
        if not (L and sum(L)==N) then L = lens_from_string(head, md, env.seg_auto_delim) end
        if L and sum(L)==N then
            local idx = find_idx(conf.all, key_of(L))
            if idx then start_idx = idx end
        end
        env.seg_start_idx = start_idx
    end

    if tlen == 1 then
        ctx.input = after
        return true 
    end

    if not conf then
        ctx.input = after
        return true
    end

    local m = #conf.all
    local k = tlen - 1
    
    local function restore()
        ctx.input = (env.seg_base or head) .. md
        env.seg_core, env.seg_start_idx, env.seg_N, env.seg_base = nil, nil, nil, nil
        env.seg_core = core; env.seg_N = N 
    end

    if env.seg_start_idx and env.seg_start_idx ~= 0 then
        local cycle_len = m 
        local r = k % cycle_len
        if r == 0 then restore(); return true end
        local idx = ((env.seg_start_idx - 1 + r) % m) + 1
        local rebuilt = build_by_groups(core, md, conf.all[idx])
        ctx.input = rebuilt .. md:rep(tlen)
        return true
    else
        local cycle_len = m + 1
        local r = k % cycle_len
        if r == 0 then restore(); return true end
        local idx = ((r - 1) % m) + 1
        local rebuilt = build_by_groups(core, md, conf.all[idx])
        ctx.input = rebuilt .. md:rep(tlen)
        return true
    end
end

-- [Backspace Limit] 退格限制
local function handle_backspace(key, env, ctx)
    local kc = key.keycode
    if not key:release() and ctx.composition:empty() then
        if kc == 0xff0d or kc == 0xff8d or kc == 0x20 then
            ctx:set_property("english_spacing", "true") --记下来按键状态给英文自动加空格用
        end
    end

    if kc ~= 0xFF08 or key:release() then
        env.bs_sequence = false
        env.bs_prev_len = -1
        return false
    end

    local cur_len = ctx.input and #ctx.input or 0
    if env.bs_sequence then
        if not wanxiang.is_mobile_device() then
            if env.bs_prev_len == 1 and cur_len == 0 then
                return true 
            end
        end
        env.bs_prev_len = cur_len
        return false
    end
    env.bs_sequence = true
    env.bs_prev_len = cur_len
    return false
end

-- [Limit Repeated] 重复输入限制
local function handle_limit_repeat(key, env, ctx)
    local kc = key.keycode
    if not (kc >= 0x61 and kc <= 0x7A) then return false end
    
    local cand = ctx:get_selected_candidate()
    local preedit = cand and (cand.preedit or cand:get_genuine().preedit) or ""
    local segs = 1
    for _ in preedit:gmatch("[%'%s]") do segs = segs + 1 end

    local ch = string.char(kc)
    local input = ctx.input or ""
    local nxt = input .. ch
    local last, rep_n = tail_rep(nxt)
    
    if last:match(INITIALS) and rep_n > MAX_REPEAT then
        prompt(ctx, " 〔已超最大重复声母〕")
        return true
    end
    
    if segs >= MAX_SEGMENTS then
        prompt(ctx, " 〔已超最大输入长度〕")
        return true
    end
    return false
end

-- [Letter Selector] 字母选词
local function handle_letter_select(key, env, ctx)
    if not env.ls_active then return false end
    if key:ctrl() or key:alt() or key:super() then return false end
    local idx = LETTER_SEL_MAP[key.keycode]
    if not idx then return false end
    
    if ctx.composition:empty() then return false end
    local seg = ctx.composition:back()
    if not seg or not seg.menu then return false end
    
    local count = seg.menu:prepare(9)
    if idx < 1 or idx > count then return false end
    
    ctx:select(idx - 1)
    return true
end

-- [Select Character] 以词定字逻辑 (New!)
local function handle_select_character(key, env, ctx)
    -- 1. 检查配置是否存在
    if not (env.sc_first_key or env.sc_last_key) then return false end
    
    -- 2. 状态检查：必须在输入中或有候选菜单
    if not (ctx:is_composing() or ctx:has_menu()) then return false end

    -- 3. 键值匹配
    local repr = key:repr()
    local is_first = (repr == env.sc_first_key)
    local is_last = (repr == env.sc_last_key)
    if not (is_first or is_last) then return false end

    -- 4. 获取当前选中的候选词或输入
    local text = ctx.input
    local cand = ctx:get_selected_candidate()
    if cand then text = cand.text end

    -- 5. 执行上屏
    if utf8.len(text) > 1 then
        if is_first then
            -- 上屏第一个字 (sub: 1 到 第二个字偏移量-1)
            env.engine:commit_text(text:sub(1, utf8.offset(text, 2) - 1))
            ctx:clear()
            return true -- Accepted
        elseif is_last then
            -- 上屏最后一个字 (sub: 最后一个字偏移量)
            env.engine:commit_text(text:sub(utf8.offset(text, -1)))
            ctx:clear()
            return true -- Accepted
        end
    end
    return false
end

-- [KpNumber & ToneFallback] 数字键综合逻辑
local function handle_number_logic(key, env, ctx)
    local kc = key.keycode
    local input = ctx.input or ""

    -- A. 小键盘处理 (KpNumber)
    local kp_num = KP_MAP[kc]
    if kp_num ~= nil then
        if key:ctrl() or key:alt() or key:super() or key:shift() then return false end
        
        -- ToneFallback: 小键盘必须跳过压缩
        env.tone_state = "skip"

        local ch = tostring(kp_num)
        
        -- 1. 正则拦截
        if is_function_code_after_digit(env, ctx, ch) then
            if ctx.push_input then ctx:push_input(ch) else ctx.input = input .. ch end
            return true
        end
        -- 2. 模式处理
        if env.kp_mode == "auto" then
            if env.kp_is_composing then
                if ctx.push_input then ctx:push_input(ch) else ctx.input = input .. ch end
            else
                return false -- Noop
            end
        else -- compose mode
            if ctx.push_input then ctx:push_input(ch) else ctx.input = input .. ch end
        end
        return true
    end

    -- B. 主键盘数字
    local r = key:repr() or ""
    if r:match("^[0-9]$") then
        if key:ctrl() or key:alt() or key:super() then return false end
        
        -- ToneFallback: 标记回退意图
        local is_func_mode = false
        if wanxiang.is_function_mode_active then
            is_func_mode = wanxiang.is_function_mode_active(ctx)
        end
        local is_first_cand_has_eng = false
        local cand = ctx:get_selected_candidate()
        if cand then
            if cand.text:match("[a-zA-Z]") then
                is_first_cand_has_eng = true
            end
        end

        -- 如果是反查模式 OR 功能模式，状态设为 idle (不回退)
        if input:find(env.lookup_key, 1, true) or is_func_mode or is_first_cand_has_eng then
            env.tone_state = "idle"
            -- 这里不 return，因为数字键可能还有“正则拦截”或“候选选词”的任务
        else
            env.tone_state = "compress"
            local caret = (ctx.caret_pos ~= nil) and ctx.caret_pos or #input
            if caret > #input then caret = #input end
            local left = (caret > 0) and input:sub(1, caret) or ""
            local _, changed = compress_runs_keep_last(left)
            if changed then return true end
        end

        -- 正则拦截
        if is_function_code_after_digit(env, ctx, r) then
            if ctx.push_input then ctx:push_input(r) else ctx.input = input .. r end
            return true
        end

        -- 候选选词
        if env.kp_has_menu then
            local d = tonumber(r)
            if d == 0 then d = 10 end
            if d and d >= 1 and d <= env.kp_page_size then
                local comp = ctx.composition
                if comp and not comp:empty() then
                    local seg = comp:back()
                    local menu = seg and seg.menu
                    if menu and not menu:empty() then
                        local sel_index = seg.selected_index or 0
                        local page_start = math.floor(sel_index / env.kp_page_size) * env.kp_page_size
                        local index = page_start + (d - 1)
                        if index < menu:candidate_count() then
                            if ctx:select(index) then return true end
                        end
                    end
                end
            end
            return false 
        end
    else
        env.tone_state = "idle"
    end
    return false
end

-- 5. 主入口函数 (Main Logic Flow)
function M.func(key, env)
    local ctx = env.engine.context
    
    -- 1. 优先处理按键释放
    if key:release() then 
        handle_backspace(key, env, ctx)
        return K_NOOP 
    end

    local kc = key.keycode

    -- 2. QuickSymbol 拦截 (a-z + /)
    if handle_quick_symbol_intercept(key, env, ctx) then
        return K_ACCEPT
    end

    -- 3. Backspace 退格防止删除已上屏内容
    if kc == 0xFF08 then
        if handle_backspace(key, env, ctx) then return K_ACCEPT end
    end

    -- 4. Select Character 以词定字 (New!)
    -- 它的优先级很高，因为是针对当前候选的操作
    -- 但必须在 Backspace 之后，防止误操作
    if handle_select_character(key, env, ctx) then
        return K_ACCEPT
    end

    -- 5. 分词符 ' [SuperSegmentation] 处理分词符 '
    if kc == 0x27 then
        if handle_segmentation(key, env, ctx) then return K_ACCEPT end
    end

    -- 6. 字母键 (a-z)[Limit Repeated] 重复输入限制
    if kc >= 0x61 and kc <= 0x7A then
        if handle_limit_repeat(key, env, ctx) then return K_ACCEPT end
    end

    -- 7. (q-o + 特定 Tag)[Letter Selector] 字母选词
    if env.ls_active and (LETTER_SEL_MAP[kc] ~= nil) then
        if handle_letter_select(key, env, ctx) then return K_ACCEPT end
    end

    -- 8. 数字键 (小键盘 + 声调 + 选词)[KpNumber & ToneFallback] 数字键综合逻辑
    if (kc >= 0xFFB0 and kc <= 0xFFB9) or (kc >= 0x30 and kc <= 0x39) then
        if handle_number_logic(key, env, ctx) then return K_ACCEPT end
    else
        -- 非数字键，重置声调状态
        env.tone_state = "idle"
    end

    return K_NOOP
end

return M
