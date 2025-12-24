-- 欢迎使用万象拼音方案
-- @amzxyz
-- https://github.com/amzxyz/rime_wanxiang
-- 用来在声调辅助的时候当你输入 2 个数字的时候自动将声调替换为第二个数字，
-- 也就是说你发现输入错误声调你可以手动轮巡输入而不用回退删除直接输入下一个即可
-- 兼容小键盘输入中不回退

local wanxiang = require("wanxiang")

-- 将目标字符的连续段压缩为“最后一个字符”
local function compress_runs_keep_last(text)
    local changed = false
    local out = text:gsub('([7890])([7890]+)', function(_, tail)
        changed = true
        return tail:sub(-1)
    end)
    return out, changed
end

local function should_ignore(ctx)
    return wanxiang.is_function_mode_active(ctx) or ctx.input == ""
end

-- 小键盘 keycode 判定（0xFFB0 ~ 0xFFB9）
local function is_kp_digit_keycode(kc)
    return kc >= 0xFFB0 and kc <= 0xFFB9
end

---@class Env
---@field tone_state "idle"|"skip"|"compress"
---@field tone_fallback_update_connection Connection|nil

local P = {}

function P.init(env)
    env.tone_state = "idle"

    local ctx = env.engine and env.engine.context
    if not ctx or not ctx.update_notifier then return end

    env.tone_fallback_update_connection = ctx.update_notifier:connect(function(c)
        if should_ignore(c) then
            env.tone_state = "idle"
            return
        end

        -- 只在当前按键对应的一次更新里消费 state
        local state = env.tone_state or "idle"
        env.tone_state = "idle"  -- 立刻消费，避免“下一次才生效”

        -- 小键盘数字：标记为 skip，本次直接不压缩
        if state == "skip" then
            return
        end

        -- 非压缩状态：直接不动
        if state ~= "compress" then
            return
        end

        -- 压缩逻辑
        local input = c.input
        local caret = (c.caret_pos ~= nil) and c.caret_pos or #input
        if caret < 0 then caret = 0 end
        if caret > #input then caret = #input end

        -- 仅处理光标左侧；右侧保持不变
        local left  = (caret > 0) and input:sub(1, caret) or ""
        local right = (caret < #input) and input:sub(caret + 1) or ""

        local left_new, changed = compress_runs_keep_last(left)
        if not changed then return end

        -- 只改左侧，避免干扰右侧；并精确设置 caret_pos
        if caret > 0 then c:pop_input(caret) end
        if #left_new > 0 then c:push_input(left_new) end
        if c.caret_pos ~= nil then c.caret_pos = #left_new end
        -- 右侧 right 不需处理，Rime 会保持不变
    end)
end

function P.fini(env)
    if env.tone_fallback_update_connection then
        env.tone_fallback_update_connection:disconnect()
        env.tone_fallback_update_connection = nil
    end
    env.tone_state = "idle"
end

---@return ProcessResult
function P.func(key, env)
    local ctx = env.engine.context
    if should_ignore(ctx) then
        env.tone_state = "idle"
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    -- 小键盘数字：标记这次按键为 skip，本轮 update_notifier 不压缩
    local kc = key.keycode
    if is_kp_digit_keycode(kc) then
        env.tone_state = "skip"
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    -- 主键盘数字 0–9：标记为 compress
    local r = key:repr() or ""
    if r:match("^[0-9]$") then
        env.tone_state = "compress"

        -- 这里用“预测压缩是否会发生”来决定要不要告诉 Rime “我处理了这个按键”
        local input = ctx.input or ""
        local caret = (ctx.caret_pos ~= nil) and ctx.caret_pos or #input
        if caret < 0 then caret = 0 end
        if caret > #input then caret = #input end

        local left = (caret > 0) and input:sub(1, caret) or ""
        local _, changed = compress_runs_keep_last(left)

        return changed and wanxiang.RIME_PROCESS_RESULTS.kAccepted
                       or wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    -- 其它按键：不触发压缩，也不跳过
    env.tone_state = "idle"
    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end

return P
