--@amzxyz https://github.com/amzxyz/rime-wanxiang
--wanxiang_lookup: #设置归属于super_lookup.lua
--tags: [ abc ]  # 检索当前tag的候选
--key: "`"       # 输入中反查引导符
--lookup: [ wanxiang_reverse ] #反查滤镜数据库
--data_source: [ aux, db ] # 优先级：写在前面优先。即使只写db，只要开启enable_tone也能从注释获取声调。
--enable_tone: true  #启用声调反查
--enable_direct: true  #启用无引导的直接辅助码反查

local wanxiang = require("wanxiang/wanxiang")

-- 1. 基础工具函数 (UTF8处理 / 字符串 / 声调)
local function alt_lua_punc(s)
    if not s then
        return ""
    end
    return s:gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
end

local tones_map = {
    ["ā"] = "7",
    ["á"] = "8",
    ["ǎ"] = "9",
    ["à"] = "0",
    ["ō"] = "7",
    ["ó"] = "8",
    ["ǒ"] = "9",
    ["ò"] = "0",
    ["ē"] = "7",
    ["é"] = "8",
    ["ě"] = "9",
    ["è"] = "0",
    ["ī"] = "7",
    ["í"] = "8",
    ["ǐ"] = "9",
    ["ì"] = "0",
    ["ū"] = "7",
    ["ú"] = "8",
    ["ǔ"] = "9",
    ["ù"] = "0",
    ["ǖ"] = "7",
    ["ǘ"] = "8",
    ["ǚ"] = "9",
    ["ǜ"] = "0",
}

local function get_utf8_len(s)
    if utf8 and utf8.len then
        return utf8.len(s)
    end
    local _, count = string.gsub(s, "[^\128-\193]", "")
    return count
end

local function get_tone_from_pinyin(pinyin)
    if not pinyin or #pinyin == 0 then
        return nil
    end
    for char, tone in pairs(tones_map) do
        if string.find(pinyin, char, 1, true) then
            return tone
        end
    end
    return "0"
end

local function get_utf8_char_at(text, idx)
    local i = 1
    for _, code in utf8.codes(text) do
        if i == idx then
            return utf8.char(code)
        end
        i = i + 1
    end
    return ""
end

-- 提取一段 UTF8 字符片段
local function get_utf8_string_range(text, start_idx, end_idx)
    local chars = {}
    local i = 1
    for _, code in utf8.codes(text) do
        if i > end_idx then
            break
        end
        if i >= start_idx then
            chars[#chars + 1] = utf8.char(code)
        end
        i = i + 1
    end
    return table.concat(chars)
end

-- 将 UTF8 字符串转为字符数组
local function text_to_chars(text)
    if not text or text == "" then
        return {}
    end
    local chars = {}
    for _, cp in utf8.codes(text) do
        table.insert(chars, utf8.char(cp))
    end
    return chars
end

-- 将字符数组拼回字符串
local function chars_to_text(chars)
    return table.concat(chars)
end

-- 替换一段 UTF8 字符片段
local function replace_text_range(current_text, start_idx, end_idx, new_str)
    local out = {}
    local char_idx = 1
    for _, code_pt in utf8.codes(current_text) do
        if char_idx >= start_idx and char_idx <= end_idx then
            if char_idx == start_idx then
                table.insert(out, new_str)
            end
        else
            table.insert(out, utf8.char(code_pt))
        end
        char_idx = char_idx + 1
    end
    return table.concat(out)
end

local function list_contains(list, target)
    if not list then
        return false
    end
    for _, v in ipairs(list) do
        if v == target then
            return true
        end
    end
    return false
end

-- 2. 核心解析逻辑 (输入拆分 / 辅码提取 / 音节切分)
local function split_lookup_input(input, key, bypass_prefix)
    if not input or input == "" or not key or key == "" then
        return nil
    end

    local scan_from = 1
    if bypass_prefix and bypass_prefix ~= "" and input:sub(1, #bypass_prefix) == bypass_prefix then
        scan_from = #bypass_prefix + 1
    end

    local input_body = input:sub(scan_from)
    if input_body:sub(1, #key) == key and not key:match("^%w+$") then
        return nil
    end

    local s_start = nil
    local s_end = nil
    local from = scan_from

    while true do
        local s, e = input:find(key, from, true)
        if not s then
            break
        end
        s_start = s
        s_end = e
        from = s + 1
    end

    if not s_start then
        return nil
    end

    return input:sub(1, s_start - 1), input:sub(s_end + 1), s_start, s_end
end

-- 解析输入的辅码，仅将 7,8,9,0 视为声调，其余为常规辅码
local function parse_fuma_rules(fuma)
    local tone_filter_seq = {}
    local fuma_chunks = {}
    local clean_fuma = ""

    for i = 1, #fuma do
        local char = fuma:sub(i, i)
        if char == "7" or char == "8" or char == "9" or char == "0" then
            table.insert(tone_filter_seq, char)
        else
            clean_fuma = clean_fuma .. char
        end
    end

    for code, digit in fuma:gmatch("(%a%a?)(%d*)") do
        table.insert(fuma_chunks, string.upper(code) .. digit)
    end

    return clean_fuma, tone_filter_seq, fuma_chunks
end

local function parse_comment_part(part, enable_tone)
    local p1, p2 = part:find(";")
    local pinyin_part = p1 and part:sub(1, p1 - 1) or part
    local codes_part = p1 and part:sub(p2 + 1) or ""
    local codes_list = {}

    if #codes_part > 0 then
        for c in codes_part:gmatch("[^,]+") do
            local trimmed = c:gsub("^%s+", ""):gsub("%s+$", "")
            if #trimmed > 0 then
                codes_list[#codes_list + 1] = trimmed
            end
        end
    end

    if enable_tone then
        local tone = get_tone_from_pinyin(pinyin_part)
        if tone then
            codes_list[#codes_list + 1] = tone
        end
    end

    return codes_list
end

local function parse_comment_codes(comment, pattern, target_len, enable_tone)
    if not comment or comment == "" then
        return nil
    end

    if target_len == 1 then
        return { parse_comment_part(comment, enable_tone) }
    end

    local result = {}
    local count = 0
    for part in comment:gmatch(pattern) do
        count = count + 1
        result[count] = parse_comment_part(part, enable_tone)
    end

    if count ~= target_len then
        return nil
    end

    return result
end

local function get_script_text_parts(ctx, reverse_key)
    local parts = {}
    if not ctx or not ctx.composition or ctx.composition:empty() then
        return parts
    end

    local spans = ctx.composition:spans()
    if not spans then
        return parts
    end

    local count = type(spans.count) == "function" and spans:count() or spans.count
    if count == 0 then
        return parts
    end

    local vertices = type(spans.vertices) == "function" and spans:vertices() or spans.vertices
    if not vertices or #vertices < 2 then
        return parts
    end

    local raw_in = ctx.input or ""
    for i = 1, #vertices - 1 do
        local start_byte = vertices[i] + 1
        local end_byte = vertices[i + 1]
        local raw_syl = raw_in:sub(start_byte, end_byte)

        if raw_syl and raw_syl ~= "" then
            if reverse_key and reverse_key ~= "" then
                local split_pos = raw_syl:find(reverse_key, 1, true)
                if split_pos then
                    raw_syl = raw_syl:sub(1, split_pos - 1)
                end
            end
            raw_syl = raw_syl:gsub("['%s]", "")
            if raw_syl ~= "" then
                table.insert(parts, raw_syl)
            end
        end
    end

    return parts
end

-- 3. 数据库反查与展开算法 (Algebra/Projection)
local function parse_and_separate_rules(schema_id)
    if not schema_id or #schema_id == 0 then
        return nil, nil
    end

    local schema = Schema(schema_id)
    if not schema then
        return nil, nil
    end

    local algebra_list = schema.config and schema.config:get_list("speller/algebra")
    if not algebra_list or algebra_list.size == 0 then
        return nil, nil
    end

    local main_rules = {}
    local xlit_rules = {}

    for i = 0, algebra_list.size - 1 do
        local rule = algebra_list:get_value_at(i).value
        if rule and #rule > 0 then
            if rule:match("^xlit/HSPZN/") then
                table.insert(xlit_rules, rule)
            else
                table.insert(main_rules, rule)
            end
        end
    end

    local final_main = nil
    if #main_rules > 0 then
        final_main = main_rules
    end

    local final_xlit = nil
    if #xlit_rules > 0 then
        final_xlit = xlit_rules
    end

    return final_main, final_xlit
end

local function ensure_lookup_resources(env)
    if not env.has_db or env.db_table then
        return
    end

    env.db_table = {}
    for i = 1, #env.db_names do
        env.db_table[i] = ReverseLookup(env.db_names[i])
    end

    local main_rules, xlit_rules = parse_and_separate_rules(env.db_names[1])
    if main_rules then
        env.main_projection = Projection()
        env.main_projection:load(main_rules)
    end
    if xlit_rules then
        env.xlit_projection = Projection()
        env.xlit_projection:load(xlit_rules)
    end
end

local function add_unique(list, seen, value)
    if value and #value > 0 and not seen[value] then
        seen[value] = true
        list[#list + 1] = value
    end
end

local function extract_odd_positions(s)
    if not s or not s:match("^%l+$") or #s % 2 ~= 0 then
        return nil
    end

    local result = ""
    for i = 1, #s, 2 do
        result = result .. s:sub(i, i)
    end
    return result
end

local function get_v_variant(s)
    if not s or not s:match("^%l+$") or #s % 2 ~= 0 then
        return nil
    end

    local result = ""
    local has_change = false
    for i = 1, #s, 2 do
        local odd = s:sub(i, i)
        local even = s:sub(i + 1, i + 1)
        if (odd == "j" or odd == "q" or odd == "x" or odd == "y") and even == "v" then
            result = result .. odd .. "u"
            has_change = true
        else
            result = result .. odd .. even
        end
    end

    if has_change then
        return result
    end
    return nil
end

local function expand_code_variant(main_projection, xlit_projection, part, need_main, need_xlit)
    local out = need_main and {} or nil
    local seen = need_main and {} or nil
    local out_xlit = need_xlit and {} or nil
    local seen_xlit = need_xlit and {} or nil

    if need_main then
        local _, quote_count = part:gsub("'", "")
        if quote_count == 1 then
            local s1, s2 = part:match("^([^']*)'([^']*)$")
            if s1 and s2 and #s1 > 0 and #s2 > 0 then
                add_unique(out, seen, s1:sub(1, 1) .. s2:sub(1, 1))
            end
        end

        if part:match("^%l+$") then
            add_unique(out, seen, part)
        end

        add_unique(out, seen, extract_odd_positions(part))

        if main_projection and not part:match("^%u+$") then
            local projected = main_projection:apply(part, true)
            if projected and #projected > 0 then
                add_unique(out, seen, projected)
                add_unique(out, seen, get_v_variant(projected))
                add_unique(out, seen, extract_odd_positions(projected))
            end
        end
    end

    if need_xlit and part:match("^%u+$") and xlit_projection then
        local xlit_result = xlit_projection:apply(part, true)
        if xlit_result and #xlit_result > 0 then
            add_unique(out_xlit, seen_xlit, xlit_result)
        end
    end

    return out, out_xlit
end

local function build_reverse_group(main_projection, xlit_projection, db_table, text, need_main, need_xlit)
    local group_main = need_main and {} or nil
    local seen_main = need_main and {} or nil
    local group_xlit = need_xlit and {} or nil
    local seen_xlit = need_xlit and {} or nil

    for _, db in ipairs(db_table) do
        local code = db:lookup(text)
        if code and #code > 0 then
            for part in code:gmatch("%S+") do
                local main_variants, xlit_variants =
                    expand_code_variant(main_projection, xlit_projection, part, need_main, need_xlit)

                if need_main then
                    for _, value in ipairs(main_variants) do
                        add_unique(group_main, seen_main, value)
                    end
                end

                if need_xlit then
                    for _, value in ipairs(xlit_variants) do
                        add_unique(group_xlit, seen_xlit, value)
                    end
                end
            end
        end
    end

    return group_main, group_xlit
end

-- 4. 匹配判定引擎 (精准 / 模糊递归)
local function check_char_fuma_match(env, pinyin, fuma, target_char)
    local probe = pinyin .. fuma
    if env.mem:dict_lookup(probe, true, 200) then
        for e in env.mem:iter_dict() do
            if e.text == target_char then
                return true
            end
        end
    end
    if env.mem:user_lookup(probe, true) then
        for e in env.mem:iter_user() do
            if e.text == target_char then
                return true
            end
        end
    end
    return false
end

local function group_match(group, fuma)
    if not group then
        return false
    end
    for i = 1, #group do
        if string.sub(group[i], 1, #fuma) == fuma then
            return true
        end
    end
    return false
end

local function match_direct_word(codes_seq, idx, target, is_db)
    if not codes_seq[idx] then
        return false
    end
    for _, code in ipairs(codes_seq[idx]) do
        local skip = false
        if is_db and #code > 3 then
            skip = true
        end
        if code:match("^%d+$") then
            skip = true
        end

        if not skip then
            local i = 1
            local j = 1
            while i <= #target and j <= #code do
                if target:byte(i) == code:byte(j) then
                    i = i + 1
                end
                j = j + 1
            end
            if i > #target then
                return true
            end
        end
    end
    return false
end

local function match_fuzzy_recursive(codes_sequence, idx, input_str, input_idx, memo, is_phrase_mode)
    if input_idx > #input_str then
        return true
    end
    if idx > #codes_sequence then
        return false
    end

    local state_key = idx * 1000 + input_idx
    if memo[state_key] ~= nil then
        return memo[state_key]
    end

    local codes = codes_sequence[idx]
    local result = false

    if codes then
        for _, code in ipairs(codes) do
            local skip = false
            if is_phrase_mode and #code > 3 then
                skip = true
            end
            if code:match("^%d+$") then
                skip = true
            end

            if not skip then
                local i_curr = input_idx
                local c_curr = 1
                while i_curr <= #input_str and c_curr <= #code do
                    if input_str:byte(i_curr) == code:byte(c_curr) then
                        i_curr = i_curr + 1
                    end
                    c_curr = c_curr + 1
                end
                if match_fuzzy_recursive(codes_sequence, idx + 1, input_str, i_curr, memo, is_phrase_mode) then
                    result = true
                    break
                end
            end
        end
    else
        if match_fuzzy_recursive(codes_sequence, idx + 1, input_str, input_idx, memo, is_phrase_mode) then
            result = true
        end
    end

    memo[state_key] = result
    return result
end

-- 5. 候选项数据构建核心
local function ensure_db_cache_entry(env, char_str, need_xlit)
    local db_cache = env._db_cache
    local entry = db_cache[char_str]

    if not entry then
        local main_codes, xlit_codes =
            build_reverse_group(env.main_projection, env.xlit_projection, env.db_table, char_str, true, need_xlit)
        entry = {
            main = main_codes or {},
            xlit = need_xlit and (xlit_codes or {}) or nil,
            combined = nil,
        }
        db_cache[char_str] = entry
        env.cache_size = env.cache_size + 1
    elseif need_xlit and entry.xlit == nil then
        local _, xlit_codes =
            build_reverse_group(env.main_projection, env.xlit_projection, env.db_table, char_str, false, true)
        entry.xlit = xlit_codes or {}
    end

    if need_xlit and entry.combined == nil then
        local combined = {}
        local count = 0
        for _, value in ipairs(entry.main) do
            count = count + 1
            combined[count] = value
        end
        for _, value in ipairs(entry.xlit or {}) do
            count = count + 1
            combined[count] = value
        end
        entry.combined = combined
    end

    return entry
end

local function build_candidate_raw_data(cand, cand_len, env)
    local raw_data = {}
    local comment_cache = env._comment_cache
    local cand_text = cand.text

    if env.has_comment then
        local genuine = cand:get_genuine()
        local comment_text = ""
        if genuine and genuine.comment then
            comment_text = genuine.comment
        end

        if comment_text ~= "" then
            local cache_key = cand_text .. "_" .. comment_text
            local parsed_comment = comment_cache[cache_key]
            if parsed_comment == nil then
                parsed_comment = parse_comment_codes(comment_text, env.comment_split_ptrn, cand_len, env.enable_tone)
                    or false
                comment_cache[cache_key] = parsed_comment
                env.cache_size = env.cache_size + 1
            end
            if parsed_comment then
                raw_data.aux = parsed_comment
                raw_data._comment_internal = parsed_comment
            end
        end
    end

    if env.has_db then
        raw_data.db = {}
        local i = 0
        local need_xlit = cand_len == 1

        for _, code_point in utf8.codes(cand_text) do
            i = i + 1
            local char_str = utf8.char(code_point)
            local entry = ensure_db_cache_entry(env, char_str, need_xlit)
            local codes = need_xlit and entry.combined or entry.main

            if codes and #codes > 0 then
                raw_data.db[i] = codes
            else
                raw_data.db[i] = nil
            end
        end
    end

    return raw_data
end

-- 6. 引导模式核心逻辑 (声调翻译 / 词组及单字纠错回溯)
local function get_syl_offset(cand, ctx)
    local syl_offset = 0
    local spans = ctx.composition:spans()
    if not spans then
        return 0
    end

    local vertices = type(spans.vertices) == "function" and spans:vertices() or spans.vertices
    if vertices then
        for i = 1, #vertices - 1 do
            if vertices[i] < cand.start then
                syl_offset = syl_offset + 1
            else
                break
            end
        end
    end

    return syl_offset
end

local function attempt_pure_tone_translation(cand, env, syllables, tone_filter_seq, current_syl_count, syl_offset)
    local tone_len = #tone_filter_seq
    if current_syl_count ~= tone_len or not env.main_translator then
        return nil
    end

    local pure_pinyin_parts = {}
    for k = 1, tone_len do
        local syl = syllables[k + syl_offset]
        if syl then
            if #syl > 2 then
                syl = string.sub(syl, 1, 2)
            end
            table.insert(pure_pinyin_parts, syl .. tone_filter_seq[k])
        end
    end

    if #pure_pinyin_parts == tone_len then
        local query_str = table.concat(pure_pinyin_parts, "")
        local seg_trans = Segment(0, #query_str)
        seg_trans.tags = Set({ "abc" })

        local ok, translation = pcall(function()
            return env.main_translator:query(query_str, seg_trans)
        end)

        if ok and translation then
            for c in translation:iter() do
                local custom_cand = Candidate(cand.type, cand.start, cand._end, c.text, c.comment)
                custom_cand.quality = c.quality
                custom_cand.preedit = cand.preedit
                return custom_cand
            end
        end
    end

    return nil
end

-- [词组纠错] 1. 尝试长词组整体匹配
local function try_match_long_phrase(current_text, cand_len, env, syllables, fuma_chunks, syl_offset)
    local fuma_len = #fuma_chunks
    if fuma_len <= 1 or fuma_len > cand_len or not env.main_translator then
        return nil
    end

    for w_start = cand_len - fuma_len + 1, 1, -1 do
        local w_end = w_start + fuma_len - 1
        local pure_pinyin_parts = {}
        local valid_window = true

        for k = 1, fuma_len do
            local syl = syllables[w_start + k - 1 + syl_offset]
            if not syl then
                valid_window = false
                break
            end
            if #syl > 2 then
                syl = string.sub(syl, 1, 2)
            end
            table.insert(pure_pinyin_parts, syl)
        end

        if valid_window then
            local query_str = table.concat(pure_pinyin_parts, "")
            local seg_trans = Segment(0, #query_str)
            seg_trans.tags = Set({ "abc" })

            local translation = env.main_translator:query(query_str, seg_trans)
            local orig_phrase_text = get_utf8_string_range(current_text, w_start, w_end)

            if translation then
                for c in translation:iter() do
                    local phrase_text = c.text
                    if get_utf8_len(phrase_text) == fuma_len and phrase_text ~= orig_phrase_text then
                        local match_all = true
                        local char_idx = 1

                        for _, code_pt in utf8.codes(phrase_text) do
                            local char = utf8.char(code_pt)
                            if
                                not check_char_fuma_match(env, pure_pinyin_parts[char_idx], fuma_chunks[char_idx], char)
                            then
                                match_all = false
                                break
                            end
                            char_idx = char_idx + 1
                        end

                        if match_all then
                            local new_text = replace_text_range(current_text, w_start, w_end, phrase_text)
                            return new_text, fuma_len, w_start - 1
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- [词组纠错] 2. 尝试2字词双向辅助匹配
local function try_match_two_char_phrase(current_text, search_end_idx, env, syllables, fuma_chunk, syl_offset)
    if search_end_idx < 2 or not env.main_translator then
        return nil
    end

    for w_start = search_end_idx - 1, 1, -1 do
        local w_end = w_start + 1
        local pure_pinyin_parts = {}
        local valid_window = true

        for k = 0, 1 do
            local syl = syllables[w_start + k + syl_offset]
            if not syl then
                valid_window = false
                break
            end
            if #syl > 2 then
                syl = string.sub(syl, 1, 2)
            end
            table.insert(pure_pinyin_parts, syl)
        end

        if valid_window then
            local query_str = pure_pinyin_parts[1] .. pure_pinyin_parts[2]
            local seg_trans = Segment(0, #query_str)
            seg_trans.tags = Set({ "abc" })

            local ok, translation = pcall(function()
                return env.main_translator:query(query_str, seg_trans)
            end)

            if ok and translation then
                local orig_phrase_text = get_utf8_string_range(current_text, w_start, w_end)
                for c in translation:iter() do
                    if get_utf8_len(c.text) == 2 and c.text ~= orig_phrase_text then
                        local char1 = get_utf8_char_at(c.text, 1)
                        local char2 = get_utf8_char_at(c.text, 2)
                        local orig_char1 = get_utf8_char_at(orig_phrase_text, 1)
                        local orig_char2 = get_utf8_char_at(orig_phrase_text, 2)

                        local case_a = false
                        if char2 == orig_char2 then
                            case_a = check_char_fuma_match(env, pure_pinyin_parts[1], fuma_chunk, char1)
                        end

                        local case_b = false
                        if char1 == orig_char1 then
                            case_b = check_char_fuma_match(env, pure_pinyin_parts[2], fuma_chunk, char2)
                        end

                        if case_a or case_b then
                            local new_text = replace_text_range(current_text, w_start, w_end, c.text)
                            return new_text, 1, w_start - 1
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- [词组纠错] 3. 尝试单字逐个回溯替换
local function try_match_single_chars(
    current_text,
    search_end_idx,
    env,
    syllables,
    fuma_chunks,
    syl_offset,
    match_count
)
    local chars = text_to_chars(current_text)
    local current_end = search_end_idx
    local m_count = match_count
    local changed = false

    for c_idx = #fuma_chunks, 1, -1 do
        local chunk_fuma = fuma_chunks[c_idx]
        local best_pos = nil
        local best_char = nil
        local perfect_match_idx = nil
        local max_weight = -10000

        for i = current_end, 1, -1 do
            local orig_char = chars[i]
            local pinyin_code = syllables[i + syl_offset]

            if not pinyin_code or not orig_char then
                goto next_i
            end

            if #pinyin_code > 2 then
                pinyin_code = string.sub(pinyin_code, 1, 2)
            end

            local probe_code = pinyin_code .. chunk_fuma
            local is_orig_valid = false
            local local_best_cand = nil
            local local_max_weight = -10000

            if env.mem:dict_lookup(probe_code, true, 200) then
                for entry in env.mem:iter_dict() do
                    if get_utf8_len(entry.text) == 1 then
                        if entry.text == orig_char then
                            is_orig_valid = true
                            break
                        end
                        if (entry.weight or 0) > local_max_weight then
                            local_max_weight = entry.weight or 0
                            local_best_cand = entry.text
                        end
                    end
                end
            end

            if not is_orig_valid and env.mem:user_lookup(probe_code, true) then
                for entry in env.mem:iter_user() do
                    if get_utf8_len(entry.text) == 1 then
                        if entry.text == orig_char then
                            is_orig_valid = true
                            break
                        end
                        if ((entry.weight or 0) + 500) > local_max_weight then
                            local_max_weight = (entry.weight or 0) + 500
                            local_best_cand = entry.text
                        end
                    end
                end
            end

            if is_orig_valid then
                if not perfect_match_idx then
                    perfect_match_idx = i
                end
                goto next_i
            elseif local_best_cand then
                if local_max_weight > max_weight then
                    max_weight = local_max_weight
                    best_pos = i
                    best_char = local_best_cand
                end
            end
            ::next_i::
        end

        if best_pos then
            m_count = m_count + 1
            if best_char ~= chars[best_pos] then
                chars[best_pos] = best_char
                changed = true
            end
            current_end = best_pos - 1
        elseif perfect_match_idx then
            m_count = m_count + 1
            current_end = perfect_match_idx - 1
        end
    end

    if changed then
        return chars_to_text(chars), m_count
    end
    return current_text, m_count
end

-- 组装引导模式的主词组/单字纠错逻辑
local function attempt_phrase_correction(cand, cand_len, env, syllables, fuma_chunks, syl_offset)
    if #fuma_chunks == 0 then
        return nil
    end

    local current_text = cand.text
    local match_count = 0
    local search_end_idx = cand_len

    local new_text, count, next_end =
        try_match_long_phrase(current_text, cand_len, env, syllables, fuma_chunks, syl_offset)

    if new_text then
        current_text = new_text
        match_count = count
        search_end_idx = next_end
    elseif #fuma_chunks == 1 then
        new_text, count, next_end =
            try_match_two_char_phrase(current_text, search_end_idx, env, syllables, fuma_chunks[1], syl_offset)
        if new_text then
            current_text = new_text
            match_count = count
            search_end_idx = next_end
        end
    end

    if match_count == 0 then
        current_text, match_count =
            try_match_single_chars(current_text, search_end_idx, env, syllables, fuma_chunks, syl_offset, match_count)
    end

    if match_count == #fuma_chunks then
        if current_text ~= cand.text then
            local fixed_cand = Candidate(cand.type, cand.start, cand._end, current_text, cand.comment or "")
            fixed_cand.quality = cand.quality
            fixed_cand.preedit = cand.preedit
            return fixed_cand
        else
            return cand
        end
    end

    return nil
end

-- 判断声调是否匹配通过；数据库声调不足时直接借用注释码，不再创建嵌套声调表。
local function check_explicit_tone_match(codes_seq, tone_filter_seq, comment_internal, source_type)
    if #tone_filter_seq > #codes_seq then
        return false
    end

    for k, tone_input in ipairs(tone_filter_seq) do
        local has_tone = list_contains(codes_seq[k], tone_input)
        if not has_tone and source_type == "db" and comment_internal then
            has_tone = list_contains(comment_internal[k], tone_input)
        end
        if not has_tone then
            return false
        end
    end
    return true
end

-- 获取命中类型：仅用于同长度候选内部排序，不改变原候选长度排序
local function get_lookup_match_info(raw_data, cand_len, clean_fuma, env)

    for index, source_type in ipairs(env.data_sources) do
        local codes_seq = raw_data[source_type]

        if codes_seq then
            local is_db = source_type == "db"

            -- 单字：保持原逻辑
            if cand_len == 1 then
                if group_match(codes_seq[1], clean_fuma) then
                    return {
                        source_index = index,
                        level = 1,
                        source = source_type,
                        type = "single"
                    }
                end

            else
                -- 关键：两码完整命中某一个字，属于 single
                -- 例如 老实说，bd 命中 实
                for i = 1, cand_len do
                    if match_direct_word(codes_seq, i, clean_fuma, is_db) then
                        return {
                            source_index = index,
                            level = 1,
                            source = source_type,
                            type = "single"
                        }
                    end
                end

                -- 两码分别落不同字，属于 cross
                if #clean_fuma >= 2 then
                    for i = 1, cand_len - 1 do
                        if
                            match_direct_word(codes_seq, i, clean_fuma:sub(1,1), is_db)
                            and
                            match_direct_word(codes_seq, i + 1, clean_fuma:sub(2,2), is_db)
                        then
                            return {
                                source_index = index,
                                level = 2,
                                source = source_type,
                                type = "cross"
                            }
                        end
                    end
                end

                -- 保留原有多字模糊匹配能力
                local memo = {}
                if match_fuzzy_recursive(
                    codes_seq,
                    1,
                    clean_fuma,
                    1,
                    memo,
                    is_db
                ) then
                    return {
                        source_index = index,
                        level = 2,
                        source = source_type,
                        type = "cross"
                    }
                end
            end
        end
    end

    return nil
end

-- 综合匹配判断引擎 (引导模式使用)
local function check_explicit_match(raw_data, cand_len, clean_fuma, tone_filter_seq, apply_tone_filter, env)
    for _, source_type in ipairs(env.data_sources) do
        local codes_seq = raw_data[source_type]
        if codes_seq then
            local tone_match_pass = true
            if apply_tone_filter then
                tone_match_pass =
                    check_explicit_tone_match(codes_seq, tone_filter_seq, raw_data._comment_internal, source_type)
            end

            if tone_match_pass then
                if source_type == "aux" or source_type == "db" then
                    if cand_len == 1 then
                        if group_match(codes_seq[1], clean_fuma) then
                            return true
                        end
                    else
                        local memo = {}
                        if match_fuzzy_recursive(codes_seq, 1, clean_fuma, 1, memo, source_type == "db") then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

-- 7. 动态引擎逻辑判定提取 (动态模式使用)
local function check_direct_match(raw_data, cand_len, clean_fuma, data_sources)
    for _, source_type in ipairs(data_sources) do
        local codes_seq = raw_data[source_type]
        if codes_seq then
            if cand_len == 1 then
                if group_match(codes_seq[1], clean_fuma) then
                    return true
                end
            elseif cand_len == 2 then
                local is_db = false
                if source_type == "db" then
                    is_db = true
                end

                local fl = #clean_fuma
                if fl == 1 then
                    if
                        match_direct_word(codes_seq, 1, clean_fuma, is_db)
                        or match_direct_word(codes_seq, 2, clean_fuma, is_db)
                    then
                        return true
                    end
                elseif fl == 2 then
                    local case1 = match_direct_word(codes_seq, 1, clean_fuma, is_db)
                    local case2 = match_direct_word(codes_seq, 2, clean_fuma, is_db)
                    local case3 = false
                    if
                        match_direct_word(codes_seq, 1, clean_fuma:sub(1, 1), is_db)
                        and match_direct_word(codes_seq, 2, clean_fuma:sub(2, 2), is_db)
                    then
                        case3 = true
                    end

                    if case1 or case2 or case3 then
                        return true
                    end
                end
            else
                local memo = {}
                if match_fuzzy_recursive(codes_seq, 1, clean_fuma, 1, memo, source_type == "db") then
                    return true
                end
            end
        end
    end
    return false
end

local function create_direct_candidate(cand, ctx_input, pure_code, fuma)
    local ext_cand = Candidate(cand.type, cand.start, #ctx_input, cand.text, cand.comment)
    ext_cand.quality = cand.quality + 100
    local orig_preedit = cand.preedit

    if orig_preedit and orig_preedit ~= "" then
        ext_cand.preedit = orig_preedit:gsub("%s+$", "") .. " " .. fuma
    else
        ext_cand.preedit = pure_code .. " " .. fuma
    end

    return ext_cand
end

-- 8. 模式分发调度控制器 (主干函数)
-- 同一候选长度内排序，不改变原有长度优先级
local function sort_lookup_bucket(list, match_meta)

    table.sort(list, function(a, b)

        local ma = match_meta[a.id] or {}
        local mb = match_meta[b.id] or {}

        if (ma.source_index or 999) ~= (mb.source_index or 999) then
            return (ma.source_index or 999) < (mb.source_index or 999)
        end

        if (ma.level or 999) ~= (mb.level or 999) then
            return (ma.level or 999) < (mb.level or 999)
        end

        return a.order < b.order
    end)

end

-- A. 引导模式 (Explicit Mode) 控制器
local function handle_explicit_mode(input, env, ctx_input, pure_code, explicitly_fuma, s_end)
    ensure_lookup_resources(env)

    if not env.mem then
        env.mem = Memory(env.engine, env.engine.schema)
    end

    if not env.main_translator and Component and Component.Translator then
        pcall(function()
            env.main_translator = Component.Translator(env.engine, "translator", "script_translator")
        end)
    end

    local ctx = env.engine.context
    local clean_fuma, tone_filter_seq, fuma_chunks = parse_fuma_rules(explicitly_fuma)
    local apply_tone_filter = false
    if env.enable_tone and #tone_filter_seq > 0 then
        apply_tone_filter = true
    end

    local if_single_char_first = ctx:get_option("char_priority")
    local buckets = {}
    local match_meta = {}
    local match_seq = 0
    local long_word_cands = {}
    local max_len = 0
    local has_any_match = false
    local is_first_cand = true

    -- 获取输入音节片段；历史切分只读不改，直接复用原表。
    local syllables
    if pure_code == env.history_input and env.history_parts and #env.history_parts > 0 then
        syllables = env.history_parts
    else
        syllables = get_script_text_parts(ctx, env.reverse_key)
    end

    for cand in input:iter() do
        local cand_len = get_utf8_len(cand.text)

        -- 首个候选修正：纯声调翻译与多字纠错
        if is_first_cand then
            is_first_cand = false
            local syl_offset = get_syl_offset(cand, ctx)

            if apply_tone_filter and clean_fuma == "" then
                local current_syl_count = #syllables - syl_offset
                local tone_cand =
                    attempt_pure_tone_translation(cand, env, syllables, tone_filter_seq, current_syl_count, syl_offset)
                if tone_cand then
                    yield(tone_cand)
                    goto skip
                end
            end

            if
                ((cand.type == "sentence" and cand_len > 1) or (cand.type == "phrase" and cand_len > 3))
                and #syllables >= (cand_len + syl_offset)
            then
                local corr_cand = attempt_phrase_correction(cand, cand_len, env, syllables, fuma_chunks, syl_offset)
                if corr_cand then
                    yield(corr_cand)
                    goto skip
                end
            end
        end

        -- 数据校验与匹配判定
        if cand.type == "sentence" or not cand_len or cand_len == 0 then
            goto skip
        end
        if string.byte(cand.text, 1) and string.byte(cand.text, 1) < 128 then
            goto skip
        end

        local raw_data = build_candidate_raw_data(cand, cand_len, env)

        if
            raw_data and check_explicit_match(raw_data, cand_len, clean_fuma, tone_filter_seq, apply_tone_filter, env)
        then
            has_any_match = true

            local info =
                get_lookup_match_info(
                    raw_data,
                    cand_len,
                    clean_fuma,
                    env
                )

            match_seq = match_seq + 1
            match_meta[match_seq] = info


            if if_single_char_first and cand_len > 1 then
                table.insert(long_word_cands, cand)
            else
                if not buckets[cand_len] then
                    buckets[cand_len] = {}
                end
                table.insert(buckets[cand_len], {
                    cand = cand,
                    id = match_seq,
                    order = match_seq
                })
                if cand_len > max_len then
                    max_len = cand_len
                end
            end
        end

        ::skip::
    end

    -- 只对相同长度候选排序，保持原有长短词优先逻辑
    for _, bucket in pairs(buckets) do
        sort_lookup_bucket(bucket, match_meta)
    end


    -- 输出匹配结果 (依单字优先策略不同排序输出)
    if if_single_char_first then
        if buckets[1] then
            for _, c in ipairs(buckets[1]) do
                yield(c.cand)
            end
        end
        for l = max_len, 2, -1 do
            if buckets[l] then
                for _, c in ipairs(buckets[l]) do
                    yield(c.cand)
                end
            end
        end
    else
        for l = max_len, 1, -1 do
            if buckets[l] then
                for _, c in ipairs(buckets[l]) do
                    yield(c.cand)
                end
            end
        end
    end

    for _, c in ipairs(long_word_cands) do
        yield(c)
    end

    -- 兜底：如果完全没有匹配且包含声调过滤，则生成影候选
    if not has_any_match and apply_tone_filter and #clean_fuma > 0 and env.has_db and env.db_table then
        for _, db_obj in ipairs(env.db_table) do
            local res_str = db_obj:lookup(clean_fuma)
            if res_str and #res_str > 0 then
                for word in res_str:gmatch("%S+") do
                    local cand = Candidate("wanxiang_shadow", s_end, #ctx_input, word, "")
                    cand.quality = 1
                    yield(cand)
                end
            end
        end
    end
end

-- B. 动态直辅模式 (direct Mode) 控制器
local function snapshot_direct_candidate(cand)
    return {
        type = cand.type,
        start = cand.start,
        _end = cand._end,
        text = cand.text,
        comment = cand.comment or "",
        quality = cand.quality,
        preedit = cand.preedit,
    }
end

local function restore_direct_candidate(saved)
    local cand = Candidate(saved.type, saved.start, saved._end, saved.text, saved.comment or "")
    if saved.quality ~= nil then
        cand.quality = saved.quality
    end
    if saved.preedit and saved.preedit ~= "" then
        cand.preedit = saved.preedit
    end
    return cand
end

local function handle_direct_mode(input, env, ctx_input)
    local direct_cache = env.direct_cache
    local base_input = direct_cache and direct_cache.input or ""
    local follows_base = base_input ~= ""
        and #ctx_input > #base_input
        and #ctx_input <= #base_input + 2
        and ctx_input:sub(1, #base_input) == base_input
    local extra_len = follows_base and (#ctx_input - #base_input) or 0

    local first_seen = false
    local mode = nil
    local cache_candidates = nil
    local cache_open = false

    local matched_cands = nil
    local matched_text_count = nil
    local clean_fuma = ""
    local fuma = ""
    local matches_yielded = false

    local function clear_direct_cache()
        env.direct_cache = nil
        direct_cache = nil
    end

    local function build_matches()
        ensure_lookup_resources(env)

        matched_cands = {}
        matched_text_count = {}
        fuma = ctx_input:sub(#base_input + 1):gsub("['%s]", "")
        clean_fuma = fuma:gsub("[7890]", "")

        if #clean_fuma ~= 1 and #clean_fuma ~= 2 then
            return
        end

        for _, saved in ipairs(direct_cache.candidates or {}) do
            local cached_cand = restore_direct_candidate(saved)
            local raw_data = build_candidate_raw_data(cached_cand, 2, env)
            if raw_data and check_direct_match(raw_data, 2, clean_fuma, env.data_sources) then
                local ext_cand = create_direct_candidate(cached_cand, ctx_input, base_input, fuma)
                matched_cands[#matched_cands + 1] = ext_cand
                matched_text_count[saved.text] = (matched_text_count[saved.text] or 0) + 1
            end
        end
    end

    local function should_skip_current(cand)
        if not matched_text_count then
            return false
        end
        local count = matched_text_count[cand.text]
        if count and count > 0 then
            matched_text_count[cand.text] = count - 1
            return true
        end
        return false
    end

    local function yield_matches()
        if matches_yielded or not matched_cands then
            return
        end
        for _, cand in ipairs(matched_cands) do
            yield(cand)
        end
        matches_yielded = true
    end

    for cand in input:iter() do
        local cand_len = get_utf8_len(cand.text)

        if not first_seen then
            first_seen = true

            -- 第一位辅码只有在当前首选由两字变成三字时才启动。
            if follows_base and extra_len == 1 and direct_cache and not direct_cache.active and cand_len == 3 then
                direct_cache.active = true
                mode = "lookup"
                build_matches()

            -- 已经启动后，允许继续输入第二位辅码；保持原双码功能。
            elseif follows_base and extra_len >= 1 and extra_len <= 2 and direct_cache and direct_cache.active then
                mode = "lookup"
                build_matches()

            -- 首选两字且完整吃码：建立下一轮直辅缓存。
            elseif cand_len == 2 and cand._end == #ctx_input then
                mode = "cache"
                cache_candidates = {}
                cache_open = true
                env.direct_cache = {
                    input = ctx_input,
                    candidates = cache_candidates,
                    active = false,
                }
            else
                mode = "passthrough"
                if direct_cache then
                    clear_direct_cache()
                end
            end
        end

        if mode == "cache" then
            if cache_open and cand_len == 2 then
                local first_byte = string.byte(cand.text, 1)
                if cand.type ~= "sentence" and (not first_byte or first_byte >= 128) and cand._end == #ctx_input then
                    cache_candidates[#cache_candidates + 1] = snapshot_direct_candidate(cand)
                end
            else
                cache_open = false
            end
            yield(cand)
        elseif mode == "lookup" and matched_cands and #matched_cands > 0 then
            if #clean_fuma == 1 then
                yield_matches()
                if not should_skip_current(cand) then
                    yield(cand)
                end
            else
                if not matches_yielded and cand_len >= 3 then
                    if not should_skip_current(cand) then
                        yield(cand)
                    end
                else
                    yield_matches()
                    if not should_skip_current(cand) then
                        yield(cand)
                    end
                end
            end
        else
            yield(cand)
        end
    end

    if mode == "cache" then
        if cache_candidates and #cache_candidates > 0 then
            env.direct_cache = {
                input = ctx_input,
                candidates = cache_candidates,
                active = false,
            }
        else
            env.direct_cache = nil
        end
    elseif mode == "lookup" and matched_cands and #matched_cands > 0 and #clean_fuma == 2 and not matches_yielded then
        yield_matches()
    end
end

-- 9. Rime 暴露接口 (Init / Func / Fini)
local f = {}

function f.init(env)
    local config = env.engine.schema.config

    env.enable_tone = config:get_bool("wanxiang_lookup/enable_tone")
    if env.enable_tone == nil then
        env.enable_tone = true
    end

    env.enable_direct = config:get_bool("wanxiang_lookup/enable_direct")
    if env.enable_direct == nil then
        env.enable_direct = false
    end

    local sources_list = config:get_list("wanxiang_lookup/data_source")
    env.data_sources = {}
    local config_has_aux_source = false
    env.has_db = false

    if sources_list and sources_list.size > 0 then
        for i = 0, sources_list.size - 1 do
            local s = sources_list:get_value_at(i).value
            table.insert(env.data_sources, s)
            if s == "aux" then
                config_has_aux_source = true
            end
            if s == "db" then
                env.has_db = true
            end
        end
    else
        env.data_sources = { "aux", "db" }
        config_has_aux_source = true
        env.has_db = true
    end

    env.has_comment = false
    if config_has_aux_source or env.enable_tone then
        env.has_comment = true
    end

    env.db_names = {}
    env.db_table = nil
    env.main_projection = nil
    env.xlit_projection = nil

    if env.has_db then
        local db_list = config:get_list("wanxiang_lookup/lookup")
        if db_list and db_list.size > 0 then
            for i = 0, db_list.size - 1 do
                env.db_names[#env.db_names + 1] = db_list:get_value_at(i).value
            end
        else
            env.has_db = false
        end
    end

    if env.has_comment then
        local delimiter = config:get_string("speller/delimiter") or " '"
        if delimiter == "" then
            delimiter = " "
        end
        env.comment_split_ptrn = "[^" .. alt_lua_punc(delimiter) .. "]+"
    end

    env.reverse_key = config:get_string("wanxiang_lookup/key") or "`"
    env.reverse_key_alt = alt_lua_punc(env.reverse_key)
    env.bypass_prefix = config:get_string("add_user_dict/prefix")

    local tag = config:get_list("wanxiang_lookup/tags")
    if tag and tag.size > 0 then
        env.tag = {}
        for i = 0, tag.size - 1 do
            table.insert(env.tag, tag:get_value_at(i).value)
        end
    else
        env.tag = { "abc" }
    end

    env.notifier = env.engine.context.select_notifier:connect(function(ctx)
        local input = ctx.input
        local code, fuma = split_lookup_input(input, env.reverse_key, env.bypass_prefix)
        if not code or #code == 0 then
            return
        end

        local preedit = ctx:get_preedit()
        local no_search_string = code

        local preedit_text = ""
        if preedit and preedit.text then
            preedit_text = preedit.text
        end

        local edit = select(1, split_lookup_input(preedit_text, env.reverse_key, env.bypass_prefix))
        if edit and edit:match("[%w/]") then
            ctx.input = no_search_string .. env.reverse_key
        else
            ctx.input = no_search_string
            ctx:commit()
        end
    end)

    env._db_cache = {}
    env._comment_cache = {}
    env.cache_size = 0
    env.direct_cache = nil
    -- 双轨缓存系统
    env.history_parts = {}
    env.history_input = ""
    -- 专为引导模式(Explicit)的监听器，用于在敲击反查引导符前，保留完美的拼音切分案底
    env.update_conn = env.engine.context.update_notifier:connect(function(ctx)
        if not ctx:is_composing() then
            env.history_parts = {}
            env.history_input = ""
            env.direct_cache = nil
            return
        end
        local raw_in = ctx.input or ""
        if raw_in == "" then
            return
        end

        if env.reverse_key and raw_in:find(env.reverse_key, 1, true) then
            return
        end

        local parts = get_script_text_parts(ctx, env.reverse_key)
        if parts and #parts > 0 then
            env.history_parts = parts
            env.history_input = raw_in
        end
    end)
end

function f.tags_match(seg, env)
    for _, v in ipairs(env.tag) do
        if seg.tags[v] then
            return true
        end
    end
    return false
end

function f.func(input, env)
    local context = env.engine.context
    local seg = context.composition:back()

    if not seg or not f.tags_match(seg, env) or #env.data_sources == 0 then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    if env.cache_size > 2000 then
        env._db_cache = {}
        env._comment_cache = {}
        env.cache_size = 0
    end

    local ctx_input = context.input
    local pure_code, explicitly_fuma, s_start, s_end = split_lookup_input(ctx_input, env.reverse_key, env.bypass_prefix)

    if s_start then
        if not explicitly_fuma or #explicitly_fuma == 0 then
            -- 只输入反查引导符时原样透传，不创建整候选 raw_data 预热表。
            for cand in input:iter() do
                yield(cand)
            end
            return
        end
        return handle_explicit_mode(input, env, ctx_input, pure_code, explicitly_fuma, s_end)
    else
        if not env.enable_direct or wanxiang.is_pro_scheme(env) then
            env.direct_cache = nil
            for cand in input:iter() do
                yield(cand)
            end
            return
        end
        local direct_cache = env.direct_cache
        local first_cached = direct_cache and direct_cache.candidates and direct_cache.candidates[1]
        if first_cached and first_cached.start ~= seg.start then
            env.direct_cache = nil
            for cand in input:iter() do yield(cand) end
            return
        end
        return handle_direct_mode(input, env, ctx_input)
    end
end

function f.fini(env)
    if env.update_conn then
        env.update_conn:disconnect()
    end
    if env.notifier then
        env.notifier:disconnect()
    end
    if env.mem then
        env.mem:disconnect()
    end

    env.db_names = nil
    env.db_table = nil
    env.main_projection = nil
    env.xlit_projection = nil
    env._db_cache = nil
    env._comment_cache = nil
    env.history_parts = nil
    env.direct_cache = nil

    collectgarbage("collect")
end
return f