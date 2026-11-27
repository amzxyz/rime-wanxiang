-- 输入类型快捷切换兼容入口。
-- 通过方案 input_types 列表读取 option/label，不修改 custom.yaml，也不触发重新部署。

local M = {}

local COMMAND_PREFIX = "/"

local function emit(seg, message)
    yield(Candidate("switch", seg.start, seg._end, message, "输入类型"))
end

function M.func(input, seg, env)
    if type(input) ~= "string" or input:sub(1, #COMMAND_PREFIX) ~= COMMAND_PREFIX then
        return
    end

    local option_name = input:sub(#COMMAND_PREFIX + 1)
    if option_name == "" then return end

    local config = env.engine.schema.config
    local options = config:get_list("input_types")
    if not options then return end

    local context = env.engine.context
    for i = 0, options.size - 1 do
        local path = "input_types/@" .. i .. "/"
        local option = config:get_string(path .. "option")
        if option == option_name then
            local label = config:get_string(path .. "label") or option
            if context:get_option(option) then
                emit(seg, "当前已是〔" .. label .. "〕")
            else
                context:set_option(option, true)
                emit(seg, "已切换为〔" .. label .. "〕")
            end
            return
        end
    end
end

return M
