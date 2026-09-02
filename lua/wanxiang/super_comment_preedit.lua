-- @amzxyz https://github.com/amzxyz/rime-wanxiang
local wanxiang = require('wanxiang/wanxiang')

local SCHEME_CAPABILITIES = {
    wanxiang_pro = {tone = true, aux = true, pro = true, lite = false, t9 = false},
    wanxiang = {tone = true, aux = false, pro = false, lite = false, t9 = false},
    wanxiang_lite = {tone = false, aux = false, pro = false, lite = true, t9 = false},
    wanxiang_t9 = {tone = true, aux = false, pro = false, lite = false, t9 = true},
    wanxiang_t9i = {tone = true, aux = false, pro = false, lite = false, t9 = true},
}

local COMMENT_CLEAR = 0
local COMMENT_TONE = 1
local COMMENT_TONELESS = 2
local COMMENT_AUX = 3
local COMMENT_NATIVE_TONELESS = 4

local tone_map = {
    ['ā']='a', ['á']='a', ['ǎ']='a', ['à']='a',
    ['ē']='e', ['é']='e', ['ě']='e', ['è']='e',
    ['ī']='i', ['í']='i', ['ǐ']='i', ['ì']='i',
    ['ō']='o', ['ó']='o', ['ǒ']='o', ['ò']='o', ['ň']='en',
    ['ū']='u', ['ú']='u', ['ǔ']='u', ['ù']='u', ['ǹ']='en',
    ['ǖ']='ü', ['ǘ']='ü', ['ǚ']='ü', ['ǜ']='ü', ['ń']='en',
}

local function remove_pinyin_tone(s)
    local result = {}
    for uchar in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        result[#result + 1] = tone_map[uchar] or uchar
    end
    return table.concat(result)
end

local function escape_pattern_class(s)
    return (s:gsub("([%%%^%[%]%-])", "%%%1"))
end

local function escape_pattern_literal(s)
    return (s:gsub("([^%w])", "%%%1"))
end

local function normalize_comment_delimiter(comment, delimiter_pattern)
    if not delimiter_pattern or not comment or comment == "" then return comment end
    return (comment:gsub(delimiter_pattern, " "))
end

-- 只判断 UTF-8 字符数是否未超过上限。
local function utf8_within(text, limit)
    if not text or text == "" then return true end
    if not limit or limit < 1 then return false end
    local pos = utf8.offset(text, limit + 1)
    return not pos or pos > #text
end

-- ----------------------
-- # 错音错字提示模块
-- ----------------------
local CR = {}
local correction_dict_cache = {}

function CR.init(env)
    local style = env.settings.corrector_type or "{comment}"
    env.corrector_style_left, env.corrector_style_right = style:match("^(.-)comment(.-)$")

    local auto_delimiter = env.settings.auto_delimiter
    local path
    if env.is_pro then
        path = "dicts/cuoyin.pro.dict.yaml"
    elseif env.is_lite then
        path = "dicts/cuoyin.lite.dict.yaml"
    else
        path = "dicts/cuoyin.dict.yaml"
    end
    local cache_key = path .. "\0" .. auto_delimiter
    local corrections = correction_dict_cache[cache_key]

    if corrections then
        env.corrections = corrections
        return
    end

    local file, close_file, err = wanxiang.load_file_with_fallback(path)
    if not file then
        log.error(string.format("[super_comment]: 加载失败 %s，错误: %s", path, err))
        env.corrections = nil
        return
    end

    corrections = {}
    for line in file:lines() do
        if not line:match("^#") then
            local text, code, weight, comment = line:match("^(.-)\t(.-)\t(.-)\t(.-)$")
            if text and code then
                text = text:match("^%s*(.-)%s*$")
                code = code:match("^%s*(.-)%s*$")
                comment = comment and comment:match("^%s*(.-)%s*$") or ""
                comment = comment:gsub("%s+", " ")
                code = code:gsub("%s+", auto_delimiter)
                corrections[code] = {text = text, comment = comment}
            end
        end
    end
    close_file()

    correction_dict_cache[cache_key] = corrections
    env.corrections = corrections
end

function CR.get_comment(cand, env)
    local corrections = env.corrections
    local correction = corrections and corrections[cand.comment] or nil
    if not (correction and cand.text == correction.text) then
        return nil
    end

    if env.corrector_style_left then
        return env.corrector_style_left .. correction.comment .. env.corrector_style_right
    end

    return correction.comment
end
-- ----------------------
-- 部件组字返回的注释
-- ----------------------
local function get_charset_label(text)
    if not text or text == "" then
        return nil
    end
    local cp = utf8.codepoint(text)
    if not cp then
        return nil
    end

    -- 按照 Unicode 区块频率排序
    if cp >= 0x4E00 and cp <= 0x9FFF then
        return "基本"
    end
    if cp >= 0x3400 and cp <= 0x4DBF then
        return "扩A"
    end
    if cp >= 0x20000 and cp <= 0x2A6DF then
        return "扩B"
    end
    if cp >= 0x2A700 and cp <= 0x2B73F then
        return "扩C"
    end
    if cp >= 0x2B740 and cp <= 0x2B81F then
        return "扩D"
    end
    if cp >= 0x2B820 and cp <= 0x2CEAF then
        return "扩E"
    end
    if cp >= 0x2CEB0 and cp <= 0x2EBEF then
        return "扩F"
    end
    if cp >= 0x2EBF0 and cp <= 0x2EE5F then
        return "扩I"
    end
    if cp >= 0x30000 and cp <= 0x3134F then
        return "扩G"
    end
    if cp >= 0x31350 and cp <= 0x323AF then
        return "扩H"
    end

    -- 兼容区
    if cp >= 0xF900 and cp <= 0xFAFF then
        return "兼容"
    end
    if cp >= 0x2F800 and cp <= 0x2FA1F then
        return "兼容"
    end

    return nil
end

local function get_az_comment(cand, env, initial_comment)
    local inner_parts = {}

    -- 音形注释拆解逻辑
    if initial_comment and initial_comment ~= "" then
        local segments = {}
        for segment in initial_comment:gmatch(env.settings.comment_split_pattern) do
            segments[#segments + 1] = segment
        end

        if #segments > 0 then
            local has_aux = env.has_aux
            local semicolon_count = has_aux
                and select(2, string.gsub(segments[1], ";", "")) or 0
            local pinyins = {}
            local fuzhu = nil

            for _, segment in ipairs(segments) do
                local pinyin = has_aux
                    and string.match(segment, "^[^;~]+")
                    or string.match(segment, "^[^~]+")
                local fz = nil

                if semicolon_count == 1 then
                    fz = string.match(segment, ";(.+)$")
                end

                if pinyin then
                    pinyins[#pinyins + 1] = pinyin
                end
                if not fuzhu and fz and fz ~= "" then fuzhu = fz end
            end

            if #pinyins > 0 then
                local pinyin_str = table.concat(pinyins, ",")
                inner_parts[#inner_parts + 1] = string.format("音%s", pinyin_str)

                if fuzhu then
                    inner_parts[#inner_parts + 1] = string.format("辅%s", fuzhu)
                end
            end
        end
    end

    if cand and cand.text then
        local label = get_charset_label(cand.text)
        if label then
            inner_parts[#inner_parts + 1] = label
        end
    end

    if #inner_parts == 0 then
        return "〔无〕"
    end
    -- 使用间隔号连接
    return "〔" .. table.concat(inner_parts, "・") .. "〕"
end
-- ----------------------
-- 辅助码与 preedit 处理
-- ----------------------
local function strip_aux_comment(initial_comment, split_pattern)
    if not initial_comment or initial_comment == "" then return "" end

    local first_segment = initial_comment:match(split_pattern) or ""
    if not first_segment:find(";", 1, true) then return initial_comment end

    return (initial_comment:gsub(split_pattern, function(segment)
        return segment:match("^(.-);") or ""
    end))
end

local function get_aux_comment(env, initial_comment)
    if not initial_comment or initial_comment == "" then return "" end

    local first_segment = initial_comment:match(env.settings.comment_split_pattern) or ""
    if not first_segment:find(";", 1, true) then return initial_comment end

    local parts = {}
    for segment in initial_comment:gmatch(env.settings.comment_split_pattern) do
        local aux = segment:match(";(.+)$")
        if aux and aux ~= "" then parts[#parts + 1] = aux end
    end

    return #parts > 0 and table.concat(parts, "/") or ""
end

local function apply_aux_preedit(env, cand)
    local preedit = cand.preedit
    local aux_symbol = env.settings.aux_symbol
    if not preedit or preedit == "" or not aux_symbol or aux_symbol == "" then return end
    if not preedit:find("[A-Z][A-Z]") then return end
    if cand.text:match("^[%a%p%s]+$") then return end

    local converted = preedit:gsub("^(..?-?)([A-Z][A-Z]+)", function(prefix, upper)
        if prefix:match("[A-Z]") then return prefix .. upper end
        return prefix .. aux_symbol
    end)

    cand.preedit = converted:gsub("([^%s%^])([A-Z][A-Z]+)", function(prev)
        return prev .. aux_symbol
    end)
end

local function apply_tone_digits(env, cand)
    local preedit = cand.preedit
    if not preedit or preedit == "" or not preedit:find("%d") then return end
    if cand.text:match("^[%a%p%s]+$") then return end

    cand.preedit = preedit:gsub("([^%d%s]+)(%d+)", function(body, digits)
        local mapped = digits:gsub("%d", function(d)
            return env.tone_map[d] or d
        end)
        return body .. mapped
    end)
end

-- 按自动、手动分隔符拆分 preedit，并保留分隔符原位。
local function split_preedit_parts(preedit, auto_delimiter, manual_delimiter)
    local parts = {}
    local current_segment = ""

    for char in preedit:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if char == auto_delimiter or char == manual_delimiter then
            if current_segment ~= "" then
                parts[#parts + 1] = current_segment
                current_segment = ""
            end
            parts[#parts + 1] = char
        else
            current_segment = current_segment .. char
        end
    end

    if current_segment ~= "" then
        parts[#parts + 1] = current_segment
    end

    return parts
end

-- 从候选注释中提取与 preedit 音节一一对应的拼音。
local function extract_pinyin_segments(initial_comment, split_pattern, has_aux)
    local pinyins = {}

    for segment in initial_comment:gmatch(split_pattern) do
        local pinyin = has_aux and segment:match("^[^;]+") or segment
        pinyins[#pinyins + 1] = pinyin:gsub("[%[%]]", "")
    end

    return pinyins
end

-- 取得真实拼音的显示声母；zh/ch/sh 优先使用完整声母。
local function get_display_initial(py)
    if not py or py == "" then return "" end

    local normalized = remove_pinyin_tone(py):lower()
    local prefix = normalized:sub(1, 2)
    if prefix == "zh" or prefix == "ch" or prefix == "sh" then
        return prefix
    end

    return py:match("[%z\1-\127\194-\244][\128-\191]*") or ""
end

-- false：简码保留；true：简码直接转换为完整拼音。
local function render_abbreviation(typed, py, should_convert)
    if should_convert then return py end

    local initial = get_display_initial(py)
    if initial == "zh" or initial == "ch" or initial == "sh" then
        return initial
    end

    return typed
end

local function is_alpha_abbreviation(part, state)
    if part:match("^[%a]$") then return true end

    local lower = part:lower()
    if lower ~= "zh" and lower ~= "ch" and lower ~= "sh" then
        return false
    end
    return not state.input_method_type or state.input_method_type == "pinyin"
end

-- T9 优先处理：单数字是简码，多数字音节直接转换为完整拼音。
local function convert_t9_syllable(part, py, state)
    if state.is_pro or not part:match("^%d$") then return py end

    local typed = get_display_initial(py)
    if typed == "" then return part end
    return render_abbreviation(
        typed, py, state.convert_abbrev_preedit
    )
end

-- 26键处理：简码按配置保留或转全拼，其他音节维持原有转换语义。
local function convert_alpha_syllable(part, py, state)
    if state.is_pro then return py end

    if is_alpha_abbreviation(part, state) then
        return render_abbreviation(
            part, py, state.convert_abbrev_preedit
        )
    end

    local _, tone = part:match("([%a]+)([^%a]+)")
    if state.tone_isolate then return py .. (tone or "") end
    return py
end

-- 单音节转换总入口：T9 优先，再进入26键处理。
local function convert_preedit_syllable(part, py, state)
    if state.is_t9 then
        return convert_t9_syllable(part, py, state)
    end

    return convert_alpha_syllable(part, py, state)
end

-- 完成 preedit 拆分、拼音对齐、逐音节转换和最终去声调。
local function convert_preedit(preedit, initial_comment, state)
    local parts = split_preedit_parts(
        preedit, state.auto_delimiter, state.manual_delimiter
    )
    local pinyins = extract_pinyin_segments(
        initial_comment, state.comment_split_pattern, state.has_aux
    )
    local pinyin_index = 1

    for i, part in ipairs(parts) do
        if part ~= state.auto_delimiter
            and part ~= state.manual_delimiter
        then
            local py = pinyins[pinyin_index]
            if py then
                parts[i] = convert_preedit_syllable(part, py, state)
            end
            pinyin_index = pinyin_index + 1
        end
    end

    local result = table.concat(parts)
    if state.is_full_pinyin and state.has_tone then
        result = remove_pinyin_tone(result)
    end

    return result
end

-- ----------------------
-- 主函数：根据优先级处理候选词的注释和preedit
-- ----------------------
local ZH = {}
function ZH.init(env)
    local config = env.engine.schema.config
    local schema_id = env.engine.schema.schema_id or "wanxiang"
    local caps = SCHEME_CAPABILITIES[schema_id] or SCHEME_CAPABILITIES.wanxiang
    local delimiter = config:get_string('speller/delimiter') or " '"
    local auto_delimiter = delimiter:sub(1, 1)
    local manual_delimiter = delimiter:sub(2, 2)
    local escaped_delimiters = escape_pattern_class(delimiter)
    local convert_abbrev_preedit = config:get_bool("super_comment/convert_abbrev_preedit")
    if convert_abbrev_preedit == nil then convert_abbrev_preedit = false end

    env.has_tone = caps.tone
    env.has_aux = caps.aux
    env.is_pro = caps.pro
    env.is_lite = caps.lite
    env.is_t9 = caps.t9
    env.input_method_type = nil

    if not env.is_t9 and wanxiang.get_input_method_type then
        env.input_method_type = wanxiang.get_input_method_type(env)
    end

    env.settings = {
        auto_delimiter = auto_delimiter,
        manual_delimiter = manual_delimiter,
        comment_delimiter_pattern = auto_delimiter ~= " "
            and escape_pattern_literal(auto_delimiter) or nil,
        corrector_type = config:get_string("super_comment/corrector_type") or "{comment}",
        candidate_length = tonumber(
            config:get_string("super_comment/candidate_length")
        ) or 1,
        convert_abbrev_preedit = convert_abbrev_preedit,
        comment_split_pattern = "[^" .. escaped_delimiters .. "]+",
    }

    if env.has_aux then
        env.settings.aux_symbol = config:get_string("force_upper_aux/symbol")
    end

    if env.has_tone then
        env.settings.tone_isolate = config:get_bool("super_comment/tone_isolate")
    end

    env.tone_map = nil
    if env.has_tone and not env.is_t9 then
        env.tone_map = {}
        for d = 0, 9 do
            local key = tostring(d)
            local value = config:get_string("tone_preedit/" .. key)
            env.tone_map[key] = value and value ~= "" and value or key
        end
    end

    CR.init(env)
end

function ZH.fini(env)
    env.settings = nil
    env.input_method_type = nil
    env.tone_map = nil
    env.corrections = nil
    env.corrector_style_left = nil
    env.corrector_style_right = nil
    env.has_tone = nil
    env.has_aux = nil
    env.is_pro = nil
    env.is_lite = nil
    env.is_t9 = nil
end

function ZH.func(input, env)
    local context = env.engine.context
    local settings = env.settings
    local has_tone = env.has_tone
    local has_aux = env.has_aux
    local is_t9 = env.is_t9
    local is_pro = env.is_pro
    local input_str = context.input or ""
    local is_radical_mode = wanxiang.is_in_radical_mode(env)
    local skip_comment = input_str == "" or wanxiang.is_function_mode(context)

    local preedit_state = nil
    if not is_radical_mode then
        local is_full_pinyin = context:get_option("full_pinyin")
        local is_tone_display = has_tone and context:get_option("tone_display") or false

        if is_full_pinyin or is_tone_display then
            preedit_state = {
                is_t9 = is_t9,
                is_pro = is_pro,
                has_tone = has_tone,
                has_aux = has_aux,
                input_method_type = env.input_method_type,
                is_full_pinyin = is_full_pinyin,
                tone_isolate = settings.tone_isolate,
                convert_abbrev_preedit = settings.convert_abbrev_preedit,
                auto_delimiter = settings.auto_delimiter,
                manual_delimiter = settings.manual_delimiter,
                comment_split_pattern = settings.comment_split_pattern,
            }
        end
    end

    local comment_mode = COMMENT_CLEAR
    if not skip_comment and not is_radical_mode then
        if has_aux and context:get_option("fuzhu_hint") then
            comment_mode = COMMENT_AUX
        elseif has_tone then
            if context:get_option("tone_hint") then
                comment_mode = COMMENT_TONE
            elseif context:get_option("toneless_hint") then
                comment_mode = COMMENT_TONELESS
            end
        elseif context:get_option("toneless_hint") then
            comment_mode = COMMENT_NATIVE_TONELESS
        end
    end

    local candidate_length = settings.candidate_length
    local comment_split_pattern = settings.comment_split_pattern
    local comment_delimiter_pattern = settings.comment_delimiter_pattern

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()
        local cand_type = genuine_cand.type
        if cand_type == "shijian"
            or cand_type == "compose"
            or cand_type == "super_sym"
            or cand_type == "super_emoji"
            or cand_type == "url"
            or cand_type == "version"
        then
            yield(genuine_cand)
            goto continue
        end

        local initial_comment = genuine_cand.comment

        if preedit_state and initial_comment and initial_comment ~= "" then
            genuine_cand.preedit = convert_preedit(
                genuine_cand.preedit or "", initial_comment, preedit_state
            )
        end

        if skip_comment then
            yield(genuine_cand)
            goto continue
        end

        if not is_t9 then
            if has_aux then apply_aux_preedit(env, genuine_cand) end
            if has_tone then apply_tone_digits(env, genuine_cand) end
        end

        if is_radical_mode then
            genuine_cand.comment = normalize_comment_delimiter(
                get_az_comment(cand, env, initial_comment),
                comment_delimiter_pattern
            )
            yield(genuine_cand)
            goto continue
        end

        local final_comment
        if initial_comment and initial_comment:find("~", 1, true) then
            final_comment = initial_comment
        elseif comment_mode ~= COMMENT_CLEAR
            and utf8_within(cand.text, candidate_length)
        then
            if comment_mode == COMMENT_AUX then
                final_comment = get_aux_comment(env, initial_comment)
            elseif comment_mode == COMMENT_TONE then
                if has_aux then
                    final_comment = strip_aux_comment(
                        initial_comment, comment_split_pattern
                    )
                else
                    final_comment = initial_comment or ""
                end
            elseif comment_mode == COMMENT_TONELESS then
                if has_aux then
                    final_comment = remove_pinyin_tone(strip_aux_comment(
                        initial_comment, comment_split_pattern
                    ))
                else
                    final_comment = remove_pinyin_tone(initial_comment or "")
                end
            else
                final_comment = initial_comment or ""
            end
        else
            final_comment = ""
        end

        if initial_comment and initial_comment ~= "" then
            local correction = CR.get_comment(cand, env)
            if correction and correction ~= "" then
                final_comment = correction
            end
        end

        final_comment = normalize_comment_delimiter(
            final_comment, comment_delimiter_pattern
        )

        if final_comment ~= initial_comment then
            genuine_cand.comment = final_comment
        end

        yield(genuine_cand)
        ::continue::
    end
end
return ZH
