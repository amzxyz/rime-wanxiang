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

local wanxiang = require("wanxiang/wanxiang")

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
    env.special_types = { table=true, user_table=true, completion=true }
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

    local input_type = wanxiang.get_input_method_type(env)
    local abbrev_enabled =
        context:get_option("abbrev")
        and env.max_candidates > 0
        and input_type ~= "pinyin"
    local reserved = {}
    local custom = {}

    local custom_translation = env.custom_translator and env.custom_translator:query(code, seg)
    if custom_translation then
        for cand in custom_translation:iter() do
            local source = whole_phrase(cand, input_end)
            if source and cand.text and cand.text ~= "" and not reserved[cand.text] then
                reserved[cand.text] = true
                custom[#custom + 1] = prepare_candidate(cand, source, "custom_phrase")
            end
        end
    end

    local selected = {}
    local abbrev_loaded = false
    local function load_abbrev()
        if abbrev_loaded then return end
        abbrev_loaded = true
        if not abbrev_enabled then return end

        if not env.abbrev_translator then
            env.abbrev_translator = Component.Translator(env.engine, "abbrev_phrase", "script_translator")
        end

        local translation = env.abbrev_translator and env.abbrev_translator:query(code, seg)
        if not translation then return end

        local seen = {}
        for cand in translation:iter() do
            local source = whole_phrase(cand, input_end)
            local text = cand.text
            if source and text and text ~= "" and not seen[text] and not reserved[text] then
                seen[text] = true
                selected[#selected + 1] = prepare_candidate(cand, source, "abbrev")
            end
        end
    end

    local special_checked = false
    local special_first = false
    local emitted = 0
    local custom_done = false      -- custom 是否已全量输出过
    local abbrev_done = false      -- abbrev 是否已插入过（含受限/全量两种模式）
    local has_original = false     -- 原始候选流是否非空（仅由 input:iter() 置位）

    local function emit_custom()
        if custom_done then return end
        custom_done = true
        for i = 1, #custom do
            emitted = emitted + 1
            yield(custom[i])
        end
    end

    local function emit_abbrev(full_mode)
        if abbrev_done then return end
        abbrev_done = true
        load_abbrev()
        local n = #selected
        if not full_mode and n > env.max_candidates then
            n = env.max_candidates
        end
        for i = 1, n do
            emitted = emitted + 1
            yield(selected[i])
        end
    end

    for cand in input:iter() do
        has_original = true

        if not special_checked then
            special_checked = true
            special_first = env.special_types and env.special_types[cand.type] == true
            emit_custom()
            if special_first then
                emit_abbrev(true)
                yield(cand)
                goto continue
            end
        end

        if not special_first then
            if not abbrev_done and emitted >= env.insert_position - 1 then
                emit_abbrev(false)
            end
        end

        if cand.text and cand.text ~= "" and reserved[cand.text] then
            goto continue
        end

        emitted = emitted + 1
        yield(cand)
        ::continue::
    end

    emit_custom()
    emit_abbrev(not has_original or special_first)
end

function M.fini(env)
    env.custom_translator = nil
    env.abbrev_translator = nil
end

return M