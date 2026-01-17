-- https://github.com/amzxyz/rime_wanxiang
-- 万象家族 lua，小键盘行为控制：
--   - 小键盘数字：根据 kp_number_mode 决定 “参与编码 / 直接上屏”
--   - 主键盘数字：在有候选菜单时，用于选第 n 个候选
--
-- 用法示例（schema.yaml）：
--   engine:
--     processors:
--       - lua_processor@*kp_number_processor
--   # 小键盘模式（可省略，默认 auto）
--   # auto    : 空闲时直接上屏，输入中参与编码
--   # compose : 无论是否在输入中，小键盘都参与编码（不直接上屏）
--   kp_number_mode: auto


local wanxiang = require("wanxiang")

-- 小键盘键码映射
local KP = {
    [0xFFB1] = 1,  -- KP_1
    [0xFFB2] = 2,
    [0xFFB3] = 3,
    [0xFFB4] = 4,
    [0xFFB5] = 5,
    [0xFFB6] = 6,
    [0xFFB7] = 7,
    [0xFFB8] = 8,
    [0xFFB9] = 9,
    [0xFFB0] = 0,  -- KP_0
}
local P = {}

-- [调试工具] 最小化日志打印 (如需调试请取消注释)
-- local function log_info(msg)
--    log.info("kp_number: " .. tostring(msg))
-- end

-- 检查当前输入+数字是否匹配命令模式
local function is_function_code_after_digit(env, context, digit_char)
    if not context or not digit_char or digit_char == "" then return false end
    local code = context.input or ""
    local s = code .. digit_char
    
    local pats = env.function_patterns
    if not pats then return false end

    for _, pat in ipairs(pats) do
        -- Lua pattern 匹配
        if s:match(pat) then return true end
    end
    return false
end

---@param env Env
function P.init(env)
    local engine  = env.engine
    local config  = engine.schema.config
    local context = engine.context
    
    env.page_size = config:get_int("menu/page_size") or 6
    local m = config:get_string("kp_number_mode") or "auto"
    if m ~= "auto" and m ~= "compose" then m = "auto" end
    env.kp_mode = m

    env.context      = context
    env.is_composing = context:is_composing()
    env.has_menu     = context:has_menu()

    -- 从 wanxiang 模块加载并转译正则
    -- 这一步会自动处理 YAML 正则到 Lua 模式的所有转换
    env.function_patterns = wanxiang.load_regex_patterns(config, "recognizer/patterns")

    -- log_info("Loaded " .. #(env.function_patterns or {}) .. " patterns.")
    env.kp_update_connection = context.update_notifier:connect(function(ctx)
        env.context      = ctx
        env.is_composing = ctx:is_composing()
        env.has_menu     = ctx:has_menu()
    end)
end
---@param env Env
function P.fini(env)
    if env.kp_update_connection then
        env.kp_update_connection:disconnect()
        env.kp_update_connection = nil
    end
    env.context           = nil
    env.is_composing      = nil
    env.has_menu          = nil
    env.function_patterns = nil
end

---@param key KeyEvent
---@param env Env
---@return ProcessResult
function P.func(key, env)
    if key:release() then return wanxiang.RIME_PROCESS_RESULTS.kNoop end

    local context = env.context or env.engine.context
    local mode    = env.kp_mode or "auto"
    local page_sz = env.page_size

    -- 1) 小键盘数字处理
    local kp_num = KP[key.keycode]
    if kp_num ~= nil then
        if key:ctrl() or key:alt() or key:super() or key:shift() then
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end
        local ch = tostring(kp_num)

        -- 如果匹配到正则（如网址、反查），则拦截，强制作为编码输入
        if is_function_code_after_digit(env, context, ch) then
            if context.push_input then context:push_input(ch)
            else context.input = (context.input or "") .. ch end
            return wanxiang.RIME_PROCESS_RESULTS.kAccepted
        end

        -- 正常数字逻辑
        if mode == "auto" then
            if env.is_composing then
                if context.push_input then context:push_input(ch)
                else context.input = (context.input or "") .. ch end
            else
                return wanxiang.RIME_PROCESS_RESULTS.kNoop
            end
        else -- compose
            if context.push_input then context:push_input(ch)
            else context.input = (context.input or "") .. ch end
        end
        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end

    -- 2) 主键盘数字处理
    local r = key:repr() or ""
    if r:match("^[0-9]$") then
        if key:ctrl() or key:alt() or key:super() then
             return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end
        
        if is_function_code_after_digit(env, context, r) then
            if context.push_input then context:push_input(r)
            else context.input = (context.input or "") .. r end
            return wanxiang.RIME_PROCESS_RESULTS.kAccepted
        end

        if env.has_menu then
            local d = tonumber(r)
            if d == 0 then d = 10 end 
            if d and d >= 1 and d <= page_sz then
                local composition = context.composition
                if composition and not composition:empty() then
                    local seg  = composition:back()
                    local menu = seg and seg.menu
                    if menu and not menu:empty() then
                        local sel_index = seg.selected_index or 0
                        local page_start = math.floor(sel_index / page_sz) * page_sz
                        local index = page_start + (d - 1)
                        if index < menu:candidate_count() then
                            if context:select(index) then
                                return wanxiang.RIME_PROCESS_RESULTS.kAccepted
                            end
                        end
                    end
                end
            end
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end
    end

    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end

return P