--[[

万象英文辅助模块
作者：amzxyz
项目：https://github.com/amzxyz/rime-wanxiang
功能说明：

T（Translator）
调用 wanxiang_english 词典，负责英文候选输出、候选数量限制，
以及单字母当前大小写和相反大小写候选的派生。

F（Filter）
负责英文候选格式化，包括大小写转换、句内空格恢复、连续英文
自动空格、英文造词、输入记忆和历史回溯。

P（Processor）
负责监听 ASCII 模式、符号和回车输入，并维护连续英文自动空格
所需的打断状态。

]]

local byte = string.byte
local find = string.find
local gsub = string.gsub
local lower = string.lower
local upper = string.upper
local sub = string.sub
local match = string.match
local gmatch = string.gmatch
local tonumber = tonumber
local floor = math.floor
local concat = table.concat

local DEFAULT_MAX_CANDIDATES = 0

local function is_single_ascii_letter(input)
    if not input or #input ~= 1 then
        return false
    end

    local code = byte(input, 1)

    return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
end

local function make_single_candidate(text, input, seg, quality)
    local start_pos = seg and seg.start or 0
    local end_pos = seg and seg._end or #input

    local cand = Candidate("completion", start_pos, end_pos, text, "")

    cand.preedit = input
    cand.quality = quality

    return cand
end

local function build_single_candidates(input, seg)
    if not is_single_ascii_letter(input) then
        return nil, nil
    end

    local code = byte(input, 1)
    local input_is_upper = code >= 65 and code <= 90

    local current_case = input
    local opposite_case = input_is_upper and lower(input) or upper(input)

    local current_candidate = make_single_candidate(current_case, input, seg, 1.602)
    local opposite_candidate = make_single_candidate(opposite_case, input, seg, 1.601)

    return current_candidate, opposite_candidate
end

local function update_single_candidate_quality(current_candidate, opposite_candidate, anchor_quality)
    local base_quality = tonumber(anchor_quality) or 1.6

    if current_candidate then
        current_candidate.quality = base_quality + 0.002
    end

    if opposite_candidate then
        opposite_candidate.quality = base_quality + 0.001
    end
end

local function normalized_limit(value)
    local limit = floor(tonumber(value) or 0)

    if limit < 0 then
        return 0
    end

    return limit
end

local T = {}
local function release_eng_translator(env)
    local translator = env.eng_translator
    if not translator then return end

    translator:disconnect()
    env.eng_translator = nil
end

function T.init(env)
    release_eng_translator(env)
    env.max_candidates = DEFAULT_MAX_CANDIDATES

    local config = env.engine and env.engine.schema and env.engine.schema.config

    if config then
        local configured_limit = config:get_int("wanxiang_english/max_candidates")

        if configured_limit ~= nil then
            env.max_candidates = normalized_limit(configured_limit)
        end
    end

    if not Component or type(Component.TableTranslator) ~= "function" then
        return
    end

    env.eng_translator = Component.TableTranslator(env.engine, "wanxiang_english", "table_translator")
end

function T.func(input, seg, env)
    if not env.engine.context:get_option("english") then
        return
    end

    input = input or ""

    if input == "" or not env.eng_translator then
        return
    end

    local total_limit = env.max_candidates
    local limited = total_limit > 0
    local single_letter = is_single_ascii_letter(input)

    local current_candidate = nil
    local opposite_candidate = nil
    local injected_count = 0

    if single_letter then
        current_candidate, opposite_candidate = build_single_candidates(input, seg)

        if current_candidate then
            injected_count = injected_count + 1
        end

        if opposite_candidate then
            injected_count = injected_count + 1
        end

        if limited and total_limit < injected_count then
            total_limit = injected_count
        end
    end

    local native_limit = total_limit

    if limited and single_letter then
        native_limit = total_limit - injected_count
    end

    local translation = env.eng_translator:query(input, seg)

    if not translation then
        if current_candidate then
            yield(current_candidate)
        end

        if opposite_candidate then
            yield(opposite_candidate)
        end

        return
    end

    if single_letter then
        local input_lower = lower(input)
        local next_candidate, iterator_state = translation:iter()
        local first_native = nil
        local native_emitted = 0

        -- 原生配额为 0 时不向内部翻译器索取候选。
        if not limited or native_limit > 0 then
            while true do
                local cand = next_candidate(iterator_state)

                if not cand then
                    break
                end

                local cand_text = cand.text or ""
                local is_single_duplicate = #cand_text == 1 and lower(cand_text) == input_lower

                if not is_single_duplicate then
                    first_native = cand
                    break
                end
            end
        end

        update_single_candidate_quality(current_candidate, opposite_candidate, first_native and first_native.quality)

        if current_candidate then
            yield(current_candidate)
        end

        if opposite_candidate then
            yield(opposite_candidate)
        end

        if first_native then
            yield(first_native)
            native_emitted = 1
        end

        if limited and native_emitted >= native_limit then
            return
        end

        while true do
            local cand = next_candidate(iterator_state)

            if not cand then
                break
            end

            local cand_text = cand.text or ""
            local is_single_duplicate = #cand_text == 1 and lower(cand_text) == input_lower

            if not is_single_duplicate then
                yield(cand)
                native_emitted = native_emitted + 1

                if limited and native_emitted >= native_limit then
                    break
                end
            end
        end

        return
    end

    local emitted = 0

    for cand in translation:iter() do
        yield(cand)
        emitted = emitted + 1

        if limited and emitted >= native_limit then
            break
        end
    end
end

function T.fini(env)
    release_eng_translator(env)
end

local function get_now()
    if rime_api and rime_api.get_time_ms then
        return rime_api.get_time_ms() / 1000
    end
    return os.time()
end

local function pure(s)
    return gsub(s, "[^a-zA-Z]", ""):lower()
end

local function is_ascii_space(code)
    return code == 32 or (code >= 9 and code <= 13)
end

local function trim_spaces(text)
    if not text or text == "" then return "" end

    local first = byte(text, 1)
    local last = byte(text, #text)

    if not is_ascii_space(first) and not is_ascii_space(last) then return text end

    text = gsub(text, "^%s+", "")
    return gsub(text, "%s+$", "")
end

local no_spacing_words = {
    ["http"] = true,
    ["https"] = true,
    ["www"] = true,
    ["ftp"] = true,
    ["ssh"] = true,
    ["mailto"] = true,
    ["file"] = true,
    ["tel"] = true,
}

local allowed_ascii_symbols = {
    [32] = true, -- space
    [33] = true, -- !
    [39] = true, -- '
    [44] = true, -- ,
    [45] = true, -- -
    [43] = true, -- +
    [46] = true, -- .
    [48] = true,
    [49] = true,
    [50] = true,
    [51] = true,
    [52] = true,
    [53] = true,
    [54] = true,
    [55] = true,
    [56] = true,
    [57] = true,
}

-- 必须包含至少一个英文字母，否则纯数字/符号直接返回 false
local function is_ascii_phrase_fast(s)
    if not s or s == "" then
        return false
    end
    local len = #s
    local has_alpha = false
    for i = 1, len do
        local b = byte(s, i)
        local is_upper = (b >= 65 and b <= 90)
        local is_lower = (b >= 97 and b <= 122)
        local is_allowed_sym = allowed_ascii_symbols[b]

        if is_upper or is_lower then
            has_alpha = true
        elseif not is_allowed_sym then
            return false
        end
    end
    return has_alpha
end

local function has_letters(s)
    return find(s, "[a-zA-Z]")
end

local function ascii_lower_byte(code)
    if code >= 65 and code <= 90 then
        return code + 32
    end

    return code
end

local function find_target_in_text(text, start_pos, target_fp)
    local text_len = #text
    local target_len = #target_fp

    if target_len == 0 then
        return nil, nil
    end

    local target_index = 1
    local scan_pos = start_pos
    local match_start = nil

    while scan_pos <= text_len and target_index <= target_len do
        local text_byte = ascii_lower_byte(byte(text, scan_pos))
        local target_byte = byte(target_fp, target_index)

        if text_byte == target_byte then
            if target_index == 1 then
                match_start = scan_pos
            end

            target_index = target_index + 1
        end

        scan_pos = scan_pos + 1
    end

    if target_index > target_len then
        return match_start, scan_pos - 1
    end

    return nil, nil
end

local function restore_sentence_spacing(cand, split_pattern, check_pattern)
    local guide = cand.preedit or ""

    if not find(guide, check_pattern) then
        return cand
    end

    local text = cand.text
    local starts = {}
    local search_pos = 1
    local start_count = 0

    for segment in gmatch(guide, split_pattern) do
        local target = pure(segment)

        if target ~= "" then
            local match_start, match_end = find_target_in_text(text, search_pos, target)

            if not match_start then
                return cand
            end

            start_count = start_count + 1
            starts[start_count] = match_start
            search_pos = match_end + 1
        end
    end

    if start_count == 0 then
        return cand
    end

    local chunks = {}
    local chunk_count = 0

    if starts[1] > 1 then
        chunk_count = chunk_count + 1
        chunks[chunk_count] = sub(text, 1, starts[1] - 1)
    end

    for index = 1, start_count do
        local current_start = starts[index]
        local next_start = starts[index + 1]
        local chunk_end = next_start and (next_start - 1) or #text

        chunk_count = chunk_count + 1
        chunks[chunk_count] = sub(text, current_start, chunk_end)
    end

    local output = {}

    if chunk_count > 0 then
        output[1] = chunks[1]
    end

    for index = 2, chunk_count do
        local previous_chunk = chunks[index - 1]
        local last_char = sub(previous_chunk, -1)

        if last_char == "'" or last_char == "-" then
            output[index] = chunks[index]
        else
            output[index] = " " .. chunks[index]
        end
    end

    local new_text = concat(output)
    new_text = gsub(new_text, "%s%s+", " ")

    if new_text == "" or new_text == text then
        return cand
    end

    local nc = Candidate(cand.type, cand.start, cand._end, new_text, cand.comment)
    nc.preedit = cand.preedit
    nc.quality = cand.quality

    return nc
end

local function is_phrase_initial_prefix(text, input_code)
    if not text or not find(text, " ", 1, true) then return false end
    local code = pure(input_code)
    if #code < 2 then return false end

    local initials = ""
    for word in gmatch(text, "%S+") do
        local first = match(word, "[a-zA-Z]")
        if first then initials = initials .. lower(first) end
    end
    return sub(initials, 1, #code) == code
end

local function apply_segment_formatting(text, input_code, input_has_upper)
    if not input_code or input_code == "" or not input_has_upper then return text end
    local parts = {}
    local p_code = 1
    for word in gmatch(text, "%S+") do
        local out_word = word
        local clean_word = pure(word)
        local w_len = #clean_word
        if w_len > 0 then
            if find(word, "[\128-\255]") then
                local input_remain = #input_code - p_code + 1
                if input_remain > 0 then
                    local check_len = (w_len < input_remain) and w_len or input_remain
                    p_code = p_code + check_len
                end
            else
                local input_remain = #input_code - p_code + 1
                if input_remain > 0 then
                    local check_len = (w_len < input_remain) and w_len or input_remain
                    local segment = sub(input_code, p_code, p_code + check_len - 1)
                    local is_pure_alpha = not find(word, "[^a-zA-Z]")
                    if find(segment, "^%u%u") and is_pure_alpha then
                        out_word = upper(word)
                    elseif find(segment, "^%u") then
                        out_word = gsub(word, "^%a", upper)
                    end
                    p_code = p_code + check_len
                end
            end
        end
        parts[#parts + 1] = out_word
    end

    return concat(parts, " ")
end

local function apply_formatting(cand, code_ctx, preserve_letter_case)
    local text = cand.text
    if not text or text == "" then
        return cand
    end

    local changed = false

    if is_ascii_phrase_fast(text) then
        if code_ctx.input_has_upper and not preserve_letter_case then
            local new_text = apply_segment_formatting(text, code_ctx.raw_input, code_ctx.input_has_upper)

            if new_text ~= text then
                text = new_text
                changed = true
            end
        end

        if code_ctx.spacing_mode and code_ctx.spacing_mode ~= "off" then
            local mode = code_ctx.spacing_mode

            if mode == "smart" then
                if code_ctx.prev_is_eng and not find(text, "^%s") then
                    text = " " .. text
                    changed = true
                end
            elseif mode == "before" then
                if not find(text, "^%s") then
                    text = " " .. text
                    changed = true
                end
            elseif mode == "after" then
                if not find(text, "%s$") then
                    text = text .. " "
                    changed = true
                end
            end
        end
    end

    if not changed then
        return cand
    end

    local nc = Candidate(cand.type, cand.start, cand._end, text, cand.comment)

    nc.preedit = cand.preedit
    nc.quality = cand.quality

    return nc
end

local P = {}

function P.init(env)
    local ctx = env.engine.context
    env.last_ascii_mode = ctx:get_option("ascii_mode") or false
    env.typed_in_ascii = false

    if ctx.option_update_notifier then
        env.option_conn = ctx.option_update_notifier:connect(function(ctx, option_name)
            if option_name == "ascii_mode" then
                local current_ascii = ctx:get_option("ascii_mode")
                if env.last_ascii_mode and not current_ascii then
                    if env.typed_in_ascii then
                        _G.english_spacing_break = true
                    end
                    env.typed_in_ascii = false
                elseif not env.last_ascii_mode and current_ascii then
                    env.typed_in_ascii = false
                end
                env.last_ascii_mode = current_ascii
            end
        end)
    end
end

function P.fini(env)
    if env.option_conn then
        env.option_conn:disconnect()
        env.option_conn = nil
    end
end

function P.func(key, env)
    if key:release() then
        return 2
    end

    local ctx = env.engine.context
    local ascii_mode = ctx:get_option("ascii_mode")
    local kc = key.keycode

    if ctx.composition:empty() then
        local is_letter = (kc >= 0x41 and kc <= 0x5a) or (kc >= 0x61 and kc <= 0x7a)
        local is_digit = (kc >= 0x30 and kc <= 0x39)
        local is_symbol = (kc >= 0x20 and kc <= 0x7e) and not is_letter and not is_digit
        local is_enter = (kc == 0xff0d or kc == 0xff8d)
        if is_symbol or is_enter then
            _G.english_spacing_break = true
        end
    end

    if ascii_mode then
        env.typed_in_ascii = true
    end

    return 2
end

local F = {}

function F.init(env)
    local cfg = env.engine.schema.config
    env.schema_id = env.engine.schema.schema_id
    env.memory = env.schema_id == "wanxiang_english" and {} or nil
    env.english_spacing_mode = "off"
    env.spacing_timeout = 0
    env.lookup_key = "`"
    env.pair_symbol = "\\"
    local delimiter_str = " '"
    if cfg then
        local str = cfg:get_string("wanxiang_english/english_spacing")
        if str then
            env.english_spacing_mode = str
        end
        local timeout = cfg:get_double("wanxiang_english/spacing_timeout")
        if timeout then
            env.spacing_timeout = timeout
        end
        local key = cfg:get_string("wanxiang_lookup/key")
        if key and key ~= "" then
            env.lookup_key = key
        end
        local sym = cfg:get_string("wanxiang_english/trigger")
        if sym and #sym > 0 then
            env.pair_symbol = sub(sym, 1, 1)
        end
        delimiter_str = cfg:get_string("speller/delimiter") or delimiter_str
    end
    env.pair_symbol_double = env.pair_symbol .. env.pair_symbol

    local escaped_delims = gsub(delimiter_str, "([%%%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

    env.split_pattern = "[^" .. escaped_delims .. "]+"

    env.delim_check_pattern = "[" .. escaped_delims .. "]"

    env.prev_commit_is_eng = false
    env.last_commit_time = 0
    env.comp_start_time = nil
    env.block_derivation = false
    if env.engine.context then
        env.update_notifier = env.engine.context.update_notifier:connect(function(ctx)
            local curr_input = ctx.input
            if env.lookup_key and find(curr_input, env.lookup_key, 1, true) then
                env.block_derivation = true
            else
                env.block_derivation = false
            end

            if curr_input == "" then
                env.comp_start_time = nil
                if env.memory then env.memory = {} end
            elseif env.comp_start_time == nil then
                env.comp_start_time = get_now()
            end
        end)
        env.commit_notifier = env.engine.context.commit_notifier:connect(function(ctx)
            local commit_text = ctx:get_commit_text()
            local is_eng = is_ascii_phrase_fast(commit_text)

            if is_eng then
                local clean = lower(trim_spaces(commit_text))

                if no_spacing_words[clean] then
                    is_eng = false
                end
            end

            env.prev_commit_is_eng = is_eng
            if is_eng then
                env.last_commit_time = get_now()
            else
                env.last_commit_time = 0
            end
            _G.english_spacing_break = false
            env.block_derivation = false
        end)
    end
end

function F.fini(env)
    if env.update_notifier then
        env.update_notifier:disconnect()
        env.update_notifier = nil
    end
    if env.commit_notifier then
        env.commit_notifier:disconnect()
        env.commit_notifier = nil
    end
    env.memory = nil
end

function F.func(input, env)
    local ctx = env.engine.context

    if _G.english_spacing_break == true then
        env.prev_commit_is_eng = false
    end

    local curr_input = ctx.input

    if not has_letters(curr_input) then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    local has_valid_candidate = false
    local best_candidate_saved = false
    local code_len = #curr_input
    local input_has_upper = find(curr_input, "%u") ~= nil
    local single_letter_input = code_len == 1 and is_single_ascii_letter(curr_input)
    local input_lower = single_letter_input and lower(curr_input) or nil

    -- [Feature] 强制英文造词
    if code_len > 2 and sub(curr_input, -2) == env.pair_symbol_double then
        local raw_text = sub(curr_input, 1, code_len - 2)
        if is_ascii_phrase_fast(raw_text) then
            if ctx.composition and not ctx.composition:empty() then
                ctx.composition:back().prompt = "〔英文造词〕"
            end
            local cand = Candidate("english", 0, code_len, raw_text, "")
            cand.preedit = raw_text
            yield(cand)
            return
        end
    end

    local break_signal = (_G.english_spacing_break == true)
    local effective_prev_is_eng = env.prev_commit_is_eng

    if break_signal then
        effective_prev_is_eng = false
        env.prev_commit_is_eng = false
    elseif effective_prev_is_eng and env.spacing_timeout > 0 then
        local check_time = env.comp_start_time or get_now()
        if (check_time - env.last_commit_time) > env.spacing_timeout then
            effective_prev_is_eng = false
            env.prev_commit_is_eng = false
        end
    end

    local code_ctx = {
        raw_input = curr_input,
        input_has_upper = input_has_upper,
        spacing_mode = env.english_spacing_mode,
        prev_is_eng = effective_prev_is_eng,
    }

    for cand in input:iter() do
        local good_cand = cand

        if env.schema_id == "wanxiang_english" then
            good_cand = restore_sentence_spacing(cand, env.split_pattern, env.delim_check_pattern)
        end

        local preserve_single_letter_case = single_letter_input
            and is_single_ascii_letter(good_cand.text)
            and lower(good_cand.text) == input_lower

        local preserve_letter_case = preserve_single_letter_case
            or is_phrase_initial_prefix(good_cand.text, curr_input)

        local fmt_cand = apply_formatting(good_cand, code_ctx, preserve_letter_case)

        if env.schema_id == "wanxiang_english" and fmt_cand.comment and find(fmt_cand.comment, "\226\152\175") then
            local original_quality = fmt_cand.quality
            local nc = Candidate(fmt_cand.type, fmt_cand.start, fmt_cand._end, fmt_cand.text, "")

            nc.preedit = fmt_cand.preedit
            nc.quality = original_quality
            fmt_cand = nc
        end

        has_valid_candidate = true

        if env.memory and not best_candidate_saved and fmt_cand.comment ~= "~" and not env.block_derivation then
            env.memory[curr_input] = fmt_cand.text
            best_candidate_saved = true
        end

        yield(fmt_cand)
    end

    -- [Phase 3] 历史回溯构造 & 统一兜底
    if not has_valid_candidate then
        if env.block_derivation then
            return
        end
        if env.schema_id == "wanxiang_english" then
            local anchor_text = nil
            local diff = ""

            for i = #curr_input - 1, 1, -1 do
                local prefix = sub(curr_input, 1, i)
                local saved_text = env.memory[prefix]

                if saved_text then
                    anchor_text = saved_text
                    diff = sub(curr_input, i + 1)
                    break
                end
            end

            if anchor_text and diff ~= "" then
                local has_spacing = find(anchor_text, " ")
                local last_word = match(anchor_text, "(%S+)%s*$") or ""
                local last_len = #last_word
                local spacer = sub(anchor_text, -1) == " " and "" or " "

                local output_text

                if has_spacing or last_len > 3 then
                    output_text = anchor_text .. spacer .. diff
                else
                    output_text = curr_input
                end

                output_text = apply_segment_formatting(output_text, curr_input, input_has_upper)
                local cand = Candidate("fallback", 0, #curr_input, output_text, "~")
                cand.preedit = output_text
                cand.quality = 999
                yield(cand)
            end
        end
    end
end

return {T = T, F = F, P = P}