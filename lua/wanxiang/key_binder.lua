-- 正则按键绑定处理器
-- 在原生 key_binder 基础上增加输入编码正则匹配与混合动作序列。
-- option 动作会在切换后恢复原高亮位置，避免候选刷新后跳回首选。

local wanxiang = require("wanxiang/wanxiang")

local this = {}

---@class KeyBinderEnv: Env
---@field redirecting boolean
---@field bindings Binding[]

---@class Binding
---@field match string|nil
---@field accept KeyEvent|nil
---@field actions SequenceAction[]

---@class SequenceAction
---@field type "keys"|"option"
---@field sequence KeySequence|nil
---@field name string|nil
---@field value boolean|string|nil

---把普通按键片段加入动作列表
---@param actions SequenceAction[]
---@param text string
---@return boolean
local function append_key_action(actions, text)
    if not text or text == "" then
        return true
    end

    local ok, sequence = pcall(function()
        return KeySequence(text)
    end)

    if not ok or not sequence then
        return false
    end

    actions[#actions + 1] = {
        type = "keys",
        sequence = sequence,
    }

    return true
end

---解析 send_sequence 中单个 {...} 块是否为 option 动作
---@param inner string
---@return SequenceAction|nil
local function parse_inline_action(inner)
    local name, value =
        inner:match("^%s*option%s*:%s*([%w_]+)%s*=%s*([%a]+)%s*$")

    if not name then
        return nil
    end

    if value == "true" then
        return {
            type = "option",
            name = name,
            value = true,
        }
    end

    if value == "false" then
        return {
            type = "option",
            name = name,
            value = false,
        }
    end

    if value == "toggle" then
        return {
            type = "option",
            name = name,
            value = "toggle",
        }
    end

    return nil
end

---解析混合 send_sequence。
---普通按键仍交给 KeySequence；
---只有明确的 {option:name=true|false|toggle} 由 Lua 接管。
---@param expr string
---@return SequenceAction[]|nil
local function parse_sequence(expr)
    if not expr or expr == "" then
        return nil
    end

    ---@type SequenceAction[]
    local actions = {}

    local pos = 1
    local len = #expr

    while pos <= len do
        local open_pos = expr:find("{", pos, true)

        if not open_pos then
            if not append_key_action(actions, expr:sub(pos)) then
                return nil
            end
            break
        end

        if open_pos > pos then
            if not append_key_action(actions, expr:sub(pos, open_pos - 1)) then
                return nil
            end
        end

        local close_pos = expr:find("}", open_pos + 1, true)
        if not close_pos then
            return nil
        end

        local whole = expr:sub(open_pos, close_pos)
        local inner = expr:sub(open_pos + 1, close_pos - 1)

        local action = parse_inline_action(inner)

        if action then
            actions[#actions + 1] = action
        else
            if not append_key_action(actions, whole) then
                return nil
            end
        end

        pos = close_pos + 1
    end

    if #actions == 0 then
        return nil
    end

    return actions
end

---解析配置文件中的按键绑定配置
---@param value ConfigMap
---@return Binding|nil
local function parse(value)
    local match = value:get_value("match")
    local accept = value:get_value("accept")
    local send_sequence = value:get_value("send_sequence")

    if not send_sequence then
        return nil
    end

    local actions = parse_sequence(send_sequence:get_string())
    if not actions then
        return nil
    end

    return {
        match = match and match:get_string() or nil,
        accept = accept and KeyEvent(accept:get_string()) or nil,
        actions = actions,
    }
end

---@param env KeyBinderEnv
function this.init(env)
    env.redirecting = false
    ---@type Binding[]
    env.bindings = {}

    local bindings = env.engine.schema.config:get_list("key_binder/bindings")
    if not bindings then
        return
    end

    for i = 1, bindings.size do
        local item = bindings:get_at(i - 1)
        if not item then goto continue end

        local value = item:get_map()
        if not value then goto continue end

        local binding = parse(value)
        if not binding then goto continue end

        env.bindings[#env.bindings + 1] = binding

        ::continue::
    end
end

---切换 option，并恢复切换前的高亮位置。
---@param context Context
---@param name string
---@param value boolean|string
local function set_option_preserve_highlight(context, name, value)
    local highlight_index = nil

    if context.composition and not context.composition:empty() then
        local segment = context.composition:back()
        if segment then
            highlight_index = segment.selected_index
        end
    end

    if value == "toggle" then
        context:set_option(name, not context:get_option(name))
    else
        context:set_option(name, value)
    end

    if highlight_index ~= nil
        and highlight_index >= 0
        and context.refresh_non_confirmed_composition
    then
        context:refresh_non_confirmed_composition()

        if context.highlight and context:has_menu() then
            context:highlight(highlight_index)
        end
    end
end

---执行 send_sequence 中的动作
---@param binding Binding
---@param env KeyBinderEnv
local function execute_actions(binding, env)
    for _, action in ipairs(binding.actions) do
        if action.type == "keys" then
            for _, event in ipairs(action.sequence:toKeyEvent()) do
                env.engine:process_key(event)
            end

        elseif action.type == "option" then
            local context = env.engine.context
            if context then
                set_option_preserve_highlight(
                    context,
                    action.name,
                    action.value
                )
            end
        end
    end
end

---@param key_event KeyEvent
---@param env KeyBinderEnv
---@return ProcessResult
function this.func(key_event, env)
    if env.redirecting then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local context = env.engine.context
    if context == nil
        or context.composition == nil
        or context.composition:back() == nil
    then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local input = context.input
    if not input then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    if not context.composition:back():has_tag("abc") then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    for _, binding in ipairs(env.bindings) do
        local key_ok =
            binding.accept == nil
            or key_event:eq(binding.accept)

        local match_ok =
            binding.match == nil
            or rime_api.regex_match(input, binding.match)

        if key_ok and match_ok then
            env.redirecting = true

            local ok, err = pcall(function()
                execute_actions(binding, env)
            end)

            env.redirecting = false

            if not ok then
                log.error(
                    "key_binder send_sequence error: " .. tostring(err)
                )
                return wanxiang.RIME_PROCESS_RESULTS.kNoop
            end

            return wanxiang.RIME_PROCESS_RESULTS.kAccepted
        end
    end

    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end

return this
