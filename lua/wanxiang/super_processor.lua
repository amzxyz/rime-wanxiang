-- lua/super_processor.lua
-- @amzxyz
-- https://github.com/amzxyz/rime-wanxiang
-- 全能按键处理器：整合 KP小键盘、字母选词、符号快打、超强分词、重复限制、退格限制、声调回退、以词定字
-- 
-- 用法: 在 schema.yaml 中 engine/processors 列表添加 - lua_processor@*super_processor

local wanxiang = require("wanxiang/wanxiang")
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

-- [LimitRepeated] 重复限制默认配置 (现已支持配置覆盖)
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
-- 执行符号快打 (双端通用)
local function execute_quick_symbol(env, ctx, text)
    local qkey = string.match(text, env.qs_trigger)
    if qkey then
        local symbol = env.qs_mapping[qkey]
        if symbol and symbol ~= "" then
            if type(symbol) == "string" and symbol:lower() == "repeat" then
                if env.qs_last_commit ~= "" then
                    env.engine:commit_text(env.qs_last_commit)
                end
            else
                env.engine:commit_text(symbol)
            end
            ctx:clear()
            return true
        end
    end
    return false
end
-- 3. 初始化与资源管理 (Init & Fini)

function M.init(env)
    local engine = env.engine
    local config = engine.schema.config
    local context = engine.context

    -- [1] 配置加载 (按功能模块分类)
    
    env.enable_backspace_limit = true
    env.enable_seg_loop = true
    env.enable_tone_fallback = true
    env.enable_limit_repeated = true
    env.enable_predict_space = true
    env.pending_predict_space = false
    env.max_repeat = 8
    env.max_segments = 40
    env.sc_first_key = nil
    env.sc_last_key = nil
    env.is_t9 = false
    if wanxiang.get_input_method_type then
        local im_type = wanxiang.get_input_method_type(env)
        if im_type == "t9" then
            env.is_t9 = true
        end
    end
    if config then
        -- 基础开关加载
        local ok_bs, bs_val = pcall(function() return config:get_bool("super_processor/enable_backspace_limit") end)
        if ok_bs and bs_val ~= nil then env.enable_backspace_limit = bs_val end
        
        local ok_seg, seg_val = pcall(function() return config:get_bool("super_processor/enable_seg_loop") end)
        if ok_seg and seg_val ~= nil then env.enable_seg_loop = seg_val end

        local ok_tf, tf_val = pcall(function() return config:get_bool("super_processor/enable_tone_fallback") end)
        if ok_tf and tf_val ~= nil then env.enable_tone_fallback = tf_val end

        local ok_ps, ps_val = pcall(function() return config:get_bool("super_processor/enable_predict_space") end)
        if ok_ps and ps_val ~= nil then env.enable_predict_space = ps_val end
        -- 长度限制配置加载（支持 false, "", "8,40"）
        local ok_lr_bool, lr_bool = pcall(function() return config:get_bool("super_processor/limit_repeated") end)
        local ok_lr_str, lr_str = pcall(function() return config:get_string("super_processor/limit_repeated") end)

        if ok_lr_bool and lr_bool == false then
            env.enable_limit_repeated = false
        elseif ok_lr_str and type(lr_str) == "string" then
            local str_trim = lr_str:match("^%s*(.-)%s*$")
            if str_trim == "" or str_trim:lower() == "false" then
                env.enable_limit_repeated = false
            else
                local p1, p2 = str_trim:match("^(%d+)%s*,%s*(%d+)$")
                if p1 and p2 then
                    env.max_repeat = tonumber(p1)
                    env.max_segments = tonumber(p2)
                end
            end
        end

        -- 以词定字配置加载（支持 false, "", "[,]", "bracketleft, bracketright"）
        local has_new_config = false
        local ok_sc_bool, sc_bool = pcall(function() return config:get_bool("super_processor/select_character") end)
        local ok_sc_str, sc_str = pcall(function() return config:get_string("super_processor/select_character") end)

        if ok_sc_bool and sc_bool == false then
            env.sc_first_key, env.sc_last_key = nil, nil
            has_new_config = true
        elseif ok_sc_str and type(sc_str) == "string" then
            local str_trim = sc_str:match("^%s*(.-)%s*$")
            if str_trim == "" or str_trim:lower() == "false" then
                env.sc_first_key, env.sc_last_key = nil, nil
            else
                -- 尝试使用逗号分割
                local p1, p2 = str_trim:match("^(.-),(.-)$")
                if p1 and p2 then
                    env.sc_first_key = p1:match("^%s*(.-)%s*$")
                    env.sc_last_key  = p2:match("^%s*(.-)%s*$")
                elseif #str_trim >= 2 then
                    -- 兜底兼容旧的 "[]" 无逗号写法
                    env.sc_first_key = str_trim:sub(1,1)
                    env.sc_last_key  = str_trim:sub(2,2)
                end
            end
            has_new_config = true
        end

        if not has_new_config then
            -- 兜底：只有在新配置完全缺失时，才去读旧配置
            env.sc_first_key = config:get_string('key_binder/select_first_character')
            env.sc_last_key = config:get_string('key_binder/select_last_character')
        end
    end

    -- [BackspaceLimit]
    env.bs_prev_len = -1
    env.bs_sequence = false

    -- [KpNumber] 小键盘
    env.kp_page_size = config:get_int("menu/page_size") or 6
    local m = config:get_string("super_processor/kp_number_mode") or "select"
    env.kp_mode = (m == "auto" or m == "compose" or m == "select") and m or "select"
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
        local input = ctx.input or ""
        if env.pending_predict_space then
            env.pending_predict_space = false
            ctx:set_option("_dummy_predict_update", false)
            ctx:clear()
            env.engine:commit_text(" ")
        end
        -- A. [ToneFallback] 执行声调压缩
        if env.enable_tone_fallback then
            local t_state = env.tone_state or "idle"
            env.tone_state = "idle" 
            
            if t_state == "compress" and input ~= "" then
                local caret = (ctx.caret_pos ~= nil) and ctx.caret_pos or #input
                if caret < 0 then caret = 0 end
                if caret > #input then caret = #input end

                local left  = (caret > 0) and input:sub(1, caret) or ""
                local left_new, changed = compress_runs_keep_last(left)
                
                if changed then
                    if caret > 0 then ctx:pop_input(caret) end
                    if #left_new > 0 then ctx:push_input(left_new) end
                    -- push_input 会自动触发下一次 update_notifier，所以这里可以更新本地 input
                    input = ctx.input or ""
                end
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
        execute_quick_symbol(env, ctx, input)
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
    local kc = key.keycode
    if kc < 0x20 or kc > 0x7E then return false end
    
    local input = ctx.input or ""
    local next_input = input .. string.char(kc)
    
    if execute_quick_symbol(env, ctx, next_input) then
        return true
    end
    return false
end

-- [Predict Space] 联想空格接力起跑点
local function handle_predict_space(key, env, ctx)
    if not env.enable_predict_space then return false end
    if (not ctx:is_composing() or ctx.input == "") and ctx:has_menu() then
        env.pending_predict_space = true
        ctx:set_option("_dummy_predict_update", true)
        return true 
    end
    return false
end
-- [SuperSegmentation] 处理分词符 '
local function handle_segmentation(key, env, ctx)
    if not env.enable_seg_loop then return false end

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
    if not env.enable_backspace_limit then return false end

    local kc = key.keycode
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
    if not env.enable_limit_repeated then return false end

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
    
    if last:match(INITIALS) and rep_n > env.max_repeat then
        prompt(ctx, " 〔已超最大重复声母〕")
        return true
    end
    
    if segs >= env.max_segments then
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
    -- 检查配置是否存在
    if not (env.sc_first_key or env.sc_last_key) then return false end
    -- 判断是否在命令模式，如果是，则关闭以词定字，释放占用的按键/符号
    if wanxiang.is_function_mode_active and wanxiang.is_function_mode_active(ctx) then
        return false
    end
    -- 状态检查：必须在输入中或有候选菜单
    if not (ctx:is_composing() or ctx:has_menu()) then return false end

    -- 键值与字符双重匹配（解决 Rime 返回 "bracketleft" 无法匹配 "[" 的问题）
    local repr = key:repr()
    local ch = ""
    if key.keycode >= 0x20 and key.keycode <= 0x7E then
        ch = string.char(key.keycode)
    end

    local is_first = (env.sc_first_key and (repr == env.sc_first_key or ch == env.sc_first_key))
    local is_last  = (env.sc_last_key and (repr == env.sc_last_key or ch == env.sc_last_key))
    if not (is_first or is_last) then return false end

    -- 获取当前选中的候选词或输入
    local text = ctx.input
    local cand = ctx:get_selected_candidate()
    if cand then text = cand.text end

    -- 执行上屏
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
    local r = key:repr() or ""

    local kp_num = KP_MAP[kc]

    -- A. 小键盘不上屏处理
    if kp_num ~= nil then
        if key:ctrl() or key:alt() or key:super() or key:shift() then return false end
        
        if env.enable_tone_fallback then
            env.tone_state = "skip"
        end
        local ch = tostring(kp_num)
        if is_function_code_after_digit(env, ctx, ch) then
            if ctx.push_input then ctx:push_input(ch) else ctx.input = input .. ch end
            return true
        end

        if env.kp_mode == "select" then
            return false
        end

        if env.kp_mode == "auto" then
            if env.kp_is_composing then
                if ctx.push_input then ctx:push_input(ch) else ctx.input = input .. ch end
            else
                env.engine:commit_text(ch)
            end
        else 
            if ctx.push_input then ctx:push_input(ch) else ctx.input = input .. ch end
        end
        return true
    end

    -- B. 统一数字处理：提取主键盘的数字，或者移动端的小键盘数字
    local digit_str = nil
    if r:match("^[0-9]$") then
        digit_str = r
    end

    if digit_str then
        if key:ctrl() or key:alt() or key:super() then return false end
        
        -- 只要是 T9 九键方案，数字键就是打字编码键，放行给底层
        if env.is_t9 then
            if env.enable_tone_fallback then
                env.tone_state = "idle"
            end
            return false
        end

        if env.enable_tone_fallback then
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

            if input:find(env.lookup_key, 1, true) or is_func_mode or is_first_cand_has_eng then
                env.tone_state = "idle"
            else
                env.tone_state = "compress"
                local caret = (ctx.caret_pos ~= nil) and ctx.caret_pos or #input
                if caret > #input then caret = #input end
                local left = (caret > 0) and input:sub(1, caret) or ""
                local _, changed = compress_runs_keep_last(left)
                if changed then return true end
            end
        end

        if is_function_code_after_digit(env, ctx, digit_str) then
            if ctx.push_input then ctx:push_input(digit_str) else ctx.input = input .. digit_str end
            return true
        end

        -- 选词逻辑 (桌面端主键盘数字 / 移动端所有数字)
        if env.kp_has_menu then
            local d = tonumber(digit_str)
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
                        ctx:select(index)
                        return true
                    end
                end
            end
            return false
        end
    else
        -- 非数字键重置状态，保证声调压缩不越界
        if env.enable_tone_fallback then
            env.tone_state = "idle"
        end
    end
    
    return false
end
-- 5. 主入口函数 (Main Logic Flow)
function M.func(key, env)
    collectgarbage("step", 2)
    local ctx = env.engine.context
    
    -- 1. 优先处理按键释放
    if key:release() then 
        handle_backspace(key, env, ctx)
        return K_NOOP 
    end

    local kc = key.keycode

    -- [Predict Space] 联想空格
    if kc == 0x20 then
        if handle_predict_space(key, env, ctx) then return K_ACCEPT end
    end

    if ctx.composition:empty() then
        if kc == 0xff0d or kc == 0xff8d or kc == 0x20 then
            _G.english_spacing_break = true
        end
        if kc == 0x5c or kc == 0x2f then
            _G.force_sticky_code = true
        end
    end

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
        if env.enable_tone_fallback then
            env.tone_state = "idle"
        end
    end

    return K_NOOP
end
return M