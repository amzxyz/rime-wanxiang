-- @amzxyz  https://github.com/amzxyz/rime-wanxiang
-- 按需提交：Ctrl+数字上屏前 N 字并保留剩余输入；[ / ] 以词定字
local wanxiang = require("wanxiang/wanxiang")

local M = {}

-- 数字键映射（主键盘 + 小键盘）
local DIGIT = { [0x31]=1,[0x32]=2,[0x33]=3,[0x34]=4,[0x35]=5,[0x36]=6,[0x37]=7,[0x38]=8,[0x39]=9,[0x30]=10 }
local KP    = { [0xFFB1]=1,[0xFFB2]=2,[0xFFB3]=3,[0xFFB4]=4,[0xFFB5]=5,[0xFFB6]=6,[0xFFB7]=7,[0xFFB8]=8,[0xFFB9]=9,[0xFFB0]=10 }

-- 取候选前 n 个字符
local function utf8_head(s, n)
    if not s or s == "" or n <= 0 then return "" end
    local offset = utf8.offset(s, n + 1)
    return offset and s:sub(1, offset - 1) or s
end

-- 获取已确认文字和当前未确认段的输入起点
local function confirmed_prefix(c)
    local segmentation = c.composition:toSegmentation()
    local segments = segmentation and segmentation:get_segments()
    if not segments or #segments == 0 then return "", 0 end

    local parts = {}
    for i = 1, #segments - 1 do
        local seg = segments[i]
        local cand = seg:get_selected_candidate()

        if cand then
            parts[#parts + 1] = cand.text
        elseif not seg:has_tag("phony") then
            parts[#parts + 1] =
                c.input:sub(seg._start + 1, seg._end)
        end
    end

    return table.concat(parts), segments[#segments]._start
end

-- 事务级状态挂起模块
local function set_pending(env, rest)
    env._cpc_pending_rest = rest or ""
end
local function has_pending(env)
    return type(env._cpc_pending_rest) == "string" and env._cpc_pending_rest ~= nil
end
local function take_pending(env)
    local r = env._cpc_pending_rest
    env._cpc_pending_rest = nil
    return r
end

-- 以词定字：[ 上屏候选首字，] 上屏候选末字；不处理功能命令及组合快捷键
local function handle_select_character(key, env, ctx)
    if not (env.sc_first_key or env.sc_last_key) then return false end
    if key:release() or key:ctrl() or key:alt() or key:super() then return false end
    if wanxiang.is_function_mode and wanxiang.is_function_mode(ctx) then return false end
    if not (ctx:is_composing() or ctx:has_menu()) then return false end

    -- 同时识别符号字符与 Rime 键名（如 bracketleft）
    local repr = key:repr()
    local ch = (key.keycode >= 0x20 and key.keycode <= 0x7E)
        and string.char(key.keycode) or nil
    local is_first = env.sc_first_key and (repr == env.sc_first_key or ch == env.sc_first_key)
    local is_last = env.sc_last_key and (repr == env.sc_last_key or ch == env.sc_last_key)
    if not (is_first or is_last) then return false end

    local cand = ctx:get_selected_candidate()
    local text = cand and cand.text or ctx.input
    if not text or (utf8.len(text) or 0) <= 1 then return false end

    local selected
    if is_first then
        local next_char = utf8.offset(text, 2)
        if not next_char then return false end
        selected = text:sub(1, next_char - 1)
    else
        local last_char = utf8.offset(text, -1)
        if not last_char then return false end
        selected = text:sub(last_char)
    end

    env.engine:commit_text(selected)
    ctx:clear()
    return true
end

function M.init(env)
    local ctx = env.engine.context
    local config = env.engine.schema.config

    -- partial_commit 配置；空字符串可禁用对应以词定字键
    local control_digits = config and config:get_bool("partial_commit/control_digits")
    env.control_digits = control_digits ~= false
    env.sc_first_key = config and config:get_string("partial_commit/first_key") or "["
    env.sc_last_key = config and config:get_string("partial_commit/last_key") or "]"
    if env.sc_first_key == "" then env.sc_first_key = nil end
    if env.sc_last_key == "" then env.sc_last_key = nil end

    -- 监听器：在上屏动作完成后，立刻将截断后的剩余拼音恢复到输入框
    env._cpc_update_conn = ctx.update_notifier:connect(function(c)
        if not has_pending(env) then return end
        local rest = take_pending(env) or ""

        c.input = rest
        if c.clear_non_confirmed_composition then
            c:clear_non_confirmed_composition()
        end
        if c.caret_pos ~= nil then
            c.caret_pos = #rest
        end
    end)

    -- 核心拦截器
    env._cpc_key_handler = function(key)

        if not key:ctrl() or key:release() then
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end

        local n = DIGIT[key.keycode] or KP[key.keycode]
        if not n then return wanxiang.RIME_PROCESS_RESULTS.kNoop end

        local c = env.engine.context
        if not c:is_composing() then
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end

        local cand = c:get_selected_candidate() or c:get_candidate(0)
        if not cand or not cand.text or #cand.text == 0 then
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end

        -- 直接调用底层 spans 获取物理切分坐标
        local spans = c.composition:spans()
        if not spans then return wanxiang.RIME_PROCESS_RESULTS.kNoop end
        local count = type(spans.count) == "function" and spans:count() or spans.count
        if not count or count == 0 then return wanxiang.RIME_PROCESS_RESULTS.kNoop end

        local vertices = type(spans.vertices) == "function" and spans:vertices() or spans.vertices
        if not vertices or #vertices < 2 then return wanxiang.RIME_PROCESS_RESULTS.kNoop end

        -- 已确认段一并提交；切分点只保留当前未确认段的绝对坐标
        local prefix, base = confirmed_prefix(c)
        local stops = {}
        for _, vertex in ipairs(vertices) do
            if vertex >= base then stops[#stops + 1] = vertex end
        end
        if #stops < 2 then return wanxiang.RIME_PROCESS_RESULTS.kNoop end

        -- 防呆保护：取 期望长度(N)、当前段音节数、候选词字符数 三者中的最小值
        local available_syllables = #stops - 1
        local cand_len = utf8.len(cand.text) or 0
        n = math.min(n, available_syllables, cand_len)
        if n <= 0 then return wanxiang.RIME_PROCESS_RESULTS.kNoop end
        -- 获取需要上屏的中文候选字串
        local head = utf8_head(cand.text, n)
        -- 利用当前段 stops 拿到第 n 个音节的绝对字节偏移量
        local cut_byte = stops[n + 1]
        -- 截取剩余的 raw_input
        local rest = c.input:sub(cut_byte + 1)
        -- 如果剩余输入首字符是手动输入的分隔符（比如 ' ），顺手切掉保证清爽
        if rest:sub(1, 1) == "'" or rest:sub(1, 1) == " " then 
            rest = rest:sub(2) 
        end
        -- 已确认段与当前截取内容一起提交
        env.engine:commit_text(prefix .. head)
        -- 挂起剩余拼音，触发 update_notifier 恢复
        set_pending(env, rest)
        c:refresh_non_confirmed_composition()

        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end
end

function M.fini(env)
    if env._cpc_update_conn then
        env._cpc_update_conn:disconnect()
        env._cpc_update_conn = nil
    end
    env._cpc_key_handler = nil
end

function M.func(key, env)
    if key:release() then return wanxiang.RIME_PROCESS_RESULTS.kNoop end

    if handle_select_character(key, env, env.engine.context) then
        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end
    if env.control_digits and env._cpc_key_handler then
        return env._cpc_key_handler(key)
    end
    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end

return M
