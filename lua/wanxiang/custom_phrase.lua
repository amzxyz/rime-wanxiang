-- 万象拼音 · 自定义短语与简码前置
-- @amzxyz https://github.com/amzxyz/rime-wanxiang
-- 需通过两个方案分别生成词典及对应 prism：自定义短语置顶，简码按位置灵活插入。
-- 实现了任意26、14、17、18、9键都能还原实际的编码，如九键则能避免了数字暴露，共用字母编码词库
-- 保存到 lua/wanxiang/custom_phrase.lua，挂接：lua_filter@*wanxiang.custom_phrase
-- 自定义短语，用来置顶
-- custom_phrase:
--   dictionary: custom_phrase
--   prism: wanxiang_phrase_t9
--   enable_user_dict: false
--   enable_completion: false
--   always_show_comments: true
--   spelling_hints: 50
--
-- 自定义简码，用来游走在候选任意位置（自定义短语优先）
-- abbrev_phrase:
--   dictionary: wanxiang_abbrev
--   prism: wanxiang_abbrev_t9
--   enable_user_dict: false
--   enable_completion: false
--   always_show_comments: true
--   spelling_hints: 50
--   insert_position: 2
--   max_candidates: 1
--
-- switches:
--   - name: abbrev
--     states: [简码关, 简码开]

local M = {}

local function passthrough(input)
    for cand in input:iter() do yield(cand) end
end

local function whole_phrase(cand, input_end)
    if cand.type == "sentence" or cand.start ~= 0 or cand._end ~= input_end
        or cand.text == "" then
        return nil
    end
    local source = cand:get_genuine() or cand
    if source.type == "sentence" then return nil end
    return source
end

local function original_preedit(cand, source)
    local comment = source.comment
    if comment and comment ~= "" then return comment end
    local preedit = cand.preedit
    if preedit and preedit ~= "" then return preedit end
    return source.preedit or ""
end

local function prepare_candidate(cand, source, candidate_type)
    local preedit = original_preedit(cand, source)
    if candidate_type == "custom_phrase" then
        source.type = candidate_type
        source.preedit = preedit
        source.comment = ""
        cand.type = candidate_type
        cand.preedit = preedit
        cand.comment = ""
        return cand
    end
    local result = Candidate(candidate_type, cand.start, cand._end, cand.text, "")
    result.preedit = preedit
    result.quality = cand.quality
    return result
end

function M.init(env)
    local config = env.engine.schema.config
    env.insert_position = math.max(1, config:get_int("abbrev_phrase/insert_position") or 2)
    env.max_candidates = math.max(0, config:get_int("abbrev_phrase/max_candidates") or 3)
    env.custom_translator = Component.Translator(env.engine, "custom_phrase", "script_translator")
    env.abbrev_translator = nil
end

function M.func(input, env)
    local context = env.engine.context
    local code = context.input or ""
    local composition = context.composition
    if code == "" or not composition or composition:empty() then
        passthrough(input)
        return
    end
    local seg = composition:back()
    local input_end = #code
    if not seg or seg.start ~= 0 or seg._end ~= input_end then
        passthrough(input)
        return
    end

    local abbrev_enabled = context:get_option("abbrev") and env.max_candidates > 0
    local reserved = {}
    local emitted = 0

    -- 1. 自定义短语按需逐个置顶，保留该词库内部的查询顺序。
    local custom_translation = env.custom_translator
        and env.custom_translator:query(code, seg)
    if custom_translation then
        for cand in custom_translation:iter() do
            local source = whole_phrase(cand, input_end)
            if source and not reserved[cand.text] then
                reserved[cand.text] = true
                emitted = emitted + 1
                yield(prepare_candidate(cand, source, "custom_phrase"))
            end
        end
    end

    -- 2. 简码只保留配置数量；与自定义短语冲突的名额取消、不补取。
    local selected = {}
    local selected_pending = {}
    if abbrev_enabled then
        if not env.abbrev_translator then
            env.abbrev_translator = Component.Translator(
                env.engine, "abbrev_phrase", "script_translator")
        end
        local translation = env.abbrev_translator
            and env.abbrev_translator:query(code, seg)
        if translation then
            local seen, count = {}, 0
            for cand in translation:iter() do
                local source = whole_phrase(cand, input_end)
                local text = cand.text
                if source and not seen[text] then
                    seen[text] = true
                    count = count + 1
                    if not reserved[text] then
                        local item = prepare_candidate(cand, source, "abbrev")
                        selected[#selected + 1] = item
                        selected_pending[text] = item
                        reserved[text] = true
                    end
                    if count >= env.max_candidates then break end
                end
            end
        end
    end

    if emitted == 0 and #selected == 0 then
        passthrough(input)
        return
    end

    local inserted = #selected == 0
    local function insert_selected()
        inserted = true
        for i = 1, #selected do
            local item = selected[i]
            if selected_pending[item.text] then
                selected_pending[item.text] = nil
                emitted = emitted + 1
                yield(item)
            end
        end
    end

    -- 自定义短语已占满目标位置时，直接跟上简码，无需预读普通候选。
    if not inserted and emitted >= env.insert_position - 1 then
        insert_selected()
    end

    -- 3. 原候选流只遍历一次；达到位置就插入简码，不重新比较质量或排序。
    for cand in input:iter() do
        local text = cand.text
        -- 简码词若本就在插入点之前自然出现，就保留它的自然排序、取消这次前置；
        -- 否则会把本该靠前的候选（尤其用户调频过的高频词）反而拉到后面去。
        local keep_natural = false
        if not inserted and selected_pending[text] then
            keep_natural = cand.start == 0 and cand._end == input_end
                and emitted + 1 <= env.insert_position
        end
        local duplicate = not keep_natural and reserved[text]
            and cand.start == 0 and cand._end == input_end
        if keep_natural then
            selected_pending[text] = nil
        end
        if not duplicate then
            emitted = emitted + 1
            yield(cand)
            if not inserted and emitted >= env.insert_position - 1 then
                insert_selected()
            end
        end
    end
    if not inserted then insert_selected() end
end

function M.fini(env)
    env.custom_translator = nil
    env.abbrev_translator = nil
end

return M