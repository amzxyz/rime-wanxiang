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

-- 从 schema 读取 kp_number/patterns 列表
local function load_function_patterns(config)
    local patterns = {}

    local ok_list, list = pcall(function()
        return config:get_list("kp_number/patterns")
    end)
    if ok_list and list and list.size and list.size > 0 then
        for i = 0, list.size - 1 do
            local item = list:get_value_at(i)
            if item then
                local pat = item:get_string()
                if pat and pat ~= "" then
                    table.insert(patterns, pat)
                end
            end
        end
    end

    -- 如果用户没配，给一份保底的默认集合（等价你现在用的那些）
    if #patterns == 0 then
        patterns = {
            "^/[0-9]$", "^/10$", "^/[A-Za-z]+$",
            "^`[A-Za-z]*$",
            "^``[A-Za-z/`']*$",
            "^U[%da-f]+$",
            "^R[0-9]+%.?[0-9]*$",
            "^N0[1-9]?0?[1-9]?$",
            "^N1[02]?0?[1-9]?$",
            "^N0[1-9]?[1-2]?[1-9]?$",
            "^N1[02]?[1-2]?[1-9]?$",
            "^N0[1-9]?3?[01]?$",
            "^N1[02]?3?[01]?$",
            "^N19?[0-9]?[0-9]?[01]?[0-2]?[0-3]?[0-9]?$",
            "^N20?[0-9]?[0-9]?[01]?[0-2]?[0-3]?[0-9]?$",
            "^V.*$",
        }
    end

    return patterns
end

-- 根据“当前编码 + 这次按下的数字字符”判断是否属于命令模式
local function is_function_code_after_digit(env, context, digit_char)
    if not context or not digit_char or digit_char == "" then
        return false
    end
    local code = context.input or ""
    local s = code .. digit_char

    local pats = env.function_patterns
    if not pats or #pats == 0 then
        return false
    end

    for _, pat in ipairs(pats) do
        -- 这里 pat 必须是 Lua pattern 语法
        if s:match(pat) then
            return true
        end
    end
    return false
end

---@param env Env
function P.init(env)
    local engine  = env.engine
    local config  = engine.schema.config
    local context = engine.context

    -- 读数字选词个数
    env.page_size = config:get_int("menu/page_size") or 6

    -- 读小键盘模式：auto / compose，默认 auto
    local m = config:get_string("kp_number/kp_number_mode") or "auto"
    if m ~= "auto" and m ~= "compose" then
        m = "auto"
    end
    env.kp_mode = m

    -- 初始化状态快照
    env.context      = context
    env.is_composing = context:is_composing()
    env.has_menu     = context:has_menu()

    -- 读取命令模式 Lua pattern 集合
    env.function_patterns = load_function_patterns(config)

    -- 用 update_notifier 同步 context / is_composing / has_menu
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
    -- 只处理按下
    if key:release() then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local engine  = env.engine
    local context = env.context or engine.context
    local mode    = env.kp_mode or "auto"
    local page_sz = env.page_size

    local is_composing = env.is_composing
    local has_menu     = env.has_menu

    ------------------------------------------------------------------
    -- 1) 小键盘数字：auto / compose
    --    如果“加上本次数字后”还匹配某个命令模式 pattern：
    --    只作为编码输入，不 commit、不选词。
    ------------------------------------------------------------------
    local kp_num = KP[key.keycode]
    if kp_num ~= nil then
        local ch = tostring(kp_num)  -- "0".."9"

        if is_function_code_after_digit(env, context, ch) then
            if context then
                if context.push_input then
                    context:push_input(ch)
                else
                    context.input = (context.input or "") .. ch
                end
            end
            return wanxiang.RIME_PROCESS_RESULTS.kAccepted
        end

        if mode == "auto" then
            -- 输入中：参与编码；空闲：直接上屏
            if is_composing then
                if context.push_input then
                    context:push_input(ch)
                else
                    context.input = (context.input or "") .. ch
                end
            else
                engine:commit_text(ch)
            end
        else
            -- compose：始终参与编码
            if context.push_input then
                context:push_input(ch)
            else
                context.input = (context.input or "") .. ch
            end
        end

        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end

    ------------------------------------------------------------------
    -- 2) 主键盘数字：
    --    2.1 若“加上本次数字后”匹配命令模式 → 只当编码输入
    --    2.2 否则：
    --         有菜单时：选第 n 个候选
    --         空闲时：直接上屏
    ------------------------------------------------------------------
    local r = key:repr() or ""

    if r:match("^[0-9]$") then
        -- 命令模式：只作为编码输入
        if is_function_code_after_digit(env, context, r) then
            if context then
                if context.push_input then
                    context:push_input(r)
                else
                    context.input = (context.input or "") .. r
                end
            end
            return wanxiang.RIME_PROCESS_RESULTS.kAccepted
        end

        -- 有候选菜单时，用数字选「当前页」的第 n 个候选
        if has_menu then
            local d = tonumber(r)
            -- 如果按下的是 0，视为第 10 个选项
            if d == 0 then d = 10 end 
            -- 检查是否在有效范围内 (例如 page_size 是 10，那么 1-10 都有效)
            if d and d >= 1 and d <= page_sz then
                local composition = context and context.composition
                if composition and not composition:empty() then
                    local seg  = composition:back()
                    local menu = seg and seg.menu
                    if menu and not menu:empty() then
                        local sel_index = seg.selected_index or 0
                        local page_size = page_sz
                        -- 计算当前页起始位置
                        local page_no   = math.floor(sel_index / page_size)
                        local page_start = page_no * page_size
                        
                        -- 计算目标候选的全局下标 (d=10 则取第10个)
                        local index = page_start + (d - 1)

                        -- 防止越界并执行上屏
                        if index < menu:candidate_count() then
                            if context:select(index) then
                                return wanxiang.RIME_PROCESS_RESULTS.kAccepted
                            end
                        end
                    end
                end
            end
            -- 如果数字超出了 page_size (例如设置每页6个，按了7)，
            -- 或者没有选中成功，返回 kNoop，交给 Rime 默认处理
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end
    end
    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end

return P
