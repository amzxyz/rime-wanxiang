-- @amzxyz  https://github.com/amzxyz/rime-wanxiang
-- Ctrl+1..9,0：上屏首选前 N 字；利用 spans 底层物理标尺精准切分 raw input
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

function M.init(env)
    local ctx = env.engine.context

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
        local count = type(spans.count) == "function" and spans:count() or spans.count
        if not spans or count == 0 then return wanxiang.RIME_PROCESS_RESULTS.kNoop end
        
        local vertices = type(spans.vertices) == "function" and spans:vertices() or spans.vertices
        if not vertices or #vertices < 2 then return wanxiang.RIME_PROCESS_RESULTS.kNoop end

        -- 防呆保护：取 期望长度(N)、实际拼音音节数、候选词字符数 三者中的最小值
        local available_syllables = #vertices - 1
        local cand_len = utf8.len(cand.text) or 0
        n = math.min(n, available_syllables, cand_len)
        if n <= 0 then return wanxiang.RIME_PROCESS_RESULTS.kNoop end
        -- 获取需要上屏的中文候选字串
        local head = utf8_head(cand.text, n)
        -- 【神级一刀切】：利用 vertices 拿到第 n 个音节的精确字节偏移量
        local cut_byte = vertices[n + 1]
        -- 截取剩余的 raw_input
        local rest = c.input:sub(cut_byte + 1)
        -- 如果剩余输入首字符是手动输入的分隔符（比如 ' ），顺手切掉保证清爽
        if rest:sub(1, 1) == "'" or rest:sub(1, 1) == " " then 
            rest = rest:sub(2) 
        end
        -- 提交前 n 个字
        env.engine:commit_text(head)
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
    if not env._cpc_key_handler then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end
    return env._cpc_key_handler(key)
end

return M