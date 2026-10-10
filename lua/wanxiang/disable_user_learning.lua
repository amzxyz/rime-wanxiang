-- 禁止原生调频，并保留 Ctrl+Del 删除用户词的能力
-- https://github.com/amzxyz/rime-wanxiang
local Filter = {}

local function candidate_key(candidate)
    return candidate._start .. "\31" .. candidate._end .. "\31" .. candidate.text
end

local function on_delete(env, context)
    if (context.input or "") ~= env.cached_input then return end

    local selected = context:get_selected_candidate()
    if not selected then return end

    local key = candidate_key(selected:get_genuine())
    local original = env.original_candidates[key]
    if not original then return end

    env.original_candidates[key] = false

    local memory
    local success, deleted = pcall(function()
        memory = Memory(env.engine, env.engine.schema, "translator")
        return memory:update_candidate(original, -1)
    end)

    if memory then
        pcall(function() memory:disconnect() end)
    end
    memory = nil
    collectgarbage("collect")

    if success and deleted and context:is_composing() then
        env.original_candidates = {}
        context:refresh_non_confirmed_composition()
    end
end

function Filter.init(env)
    env.enabled = env.engine.schema.config:get_bool("translator/enable_auto_phrase") or false
    if not env.enabled then return end

    env.original_candidates = {}
    env.cached_input = nil
    env.delete_connection = env.engine.context.delete_notifier:connect(function(context)
        on_delete(env, context)
    end)
end

function Filter.func(input, env)
    if not env.enabled then
        for candidate in input:iter() do
            yield(candidate)
        end
        return
    end

    env.original_candidates = {}
    env.cached_input = env.engine.context.input or ""

    for original in input:iter() do
        local candidate_type = original.type
        if candidate_type == "phrase"
            or candidate_type == "user_phrase"
            or candidate_type == "sentence" then

            local candidate = Candidate(
                "wanxiang", original._start, original._end,
                original.text, original.comment
            )
            candidate.preedit = original.preedit
            candidate.quality = original.quality

            local key = candidate_key(candidate)
            if env.original_candidates[key] ~= nil then
                env.original_candidates[key] = false
            else
                env.original_candidates[key] = candidate_type == "user_phrase"
                    and original:get_genuine() or false
            end

            yield(candidate)
        else
            yield(original)
        end
    end
end

function Filter.fini(env)
    if env.delete_connection then
        env.delete_connection:disconnect()
        env.delete_connection = nil
    end
    env.original_candidates = nil
end

return Filter
