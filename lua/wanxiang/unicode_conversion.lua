-- @amzxyz  https://github.com/amzxyz/rime-wanxiang
-- 万象拼音
-- Unicode 双向工具：
-- P（Processor）：通过可配置快捷键将当前选中的单字符候选切换为 Uxxxx 输入，再次触发可返回原始 input。
-- T（Translator）：解析 U 输入并生成字符、码点及各种编码表示。

local wanxiang = require("wanxiang/wanxiang")

local P = {}
local T = {}

local MAX_CODEPOINT = 0x10FFFF
local DEFAULT_HOTKEY = "Control+u"

-- 多码点快捷查询内部协议：
-- Unicode 最大合法码点为 0x10FFFF，因此 0x110000 可安全作为保留标记。
-- 标记后的每个码点固定使用 6 位十六进制，整个输入仍满足 ^U[a-f0-9]+。
local SEQUENCE_MARKER = "110000"
local SEQUENCE_WIDTH = 6

local DIGIT_VALUES = {}
for i = 0, 9 do
    DIGIT_VALUES[string.char(0x30 + i)] = i
end
for i = 0, 5 do
    DIGIT_VALUES[string.char(0x41 + i)] = 10 + i
    DIGIT_VALUES[string.char(0x61 + i)] = 10 + i
end

local function parse_base_integer(text, base)
    local value = 0

    for i = 1, #text do
        local digit = DIGIT_VALUES[text:sub(i, i)]
        if digit == nil or digit >= base then
            return nil
        end

        value = value * base + digit
        if value > MAX_CODEPOINT then
            return value
        end
    end

    return value
end

local function parse_codepoint_input(text)
    text = tostring(text or "")
    if text == "" then
        return nil
    end

    local digits

    digits = text:match("^%+([0-9A-Fa-f]+)$")
    if digits then
        return parse_base_integer(digits, 16), 16, "u_plus"
    end

    digits = text:match("^0[xX]([0-9A-Fa-f]+)$") or
        text:match("^[xX]([0-9A-Fa-f]+)$") or
        text:match("^[hH]([0-9A-Fa-f]+)$")
    if digits then
        return parse_base_integer(digits, 16), 16, "hex"
    end

    digits = text:match("^0[dD]([0-9]+)$") or
        text:match("^[dD]([0-9]+)$")
    if digits then
        return parse_base_integer(digits, 10), 10, "decimal"
    end

    digits = text:match("^0[bB]([01]+)$") or
        text:match("^[bB]([01]+)$")
    if digits then
        return parse_base_integer(digits, 2), 2, "binary"
    end

    digits = text:match("^0[oO]([0-7]+)$") or
        text:match("^[oO]([0-7]+)$")
    if digits then
        return parse_base_integer(digits, 8), 8, "octal"
    end

    if text:match("^[0-9A-Fa-f]+$") then
        return parse_base_integer(text, 16), 16, "bare_hex"
    end

    return nil
end

local function get_prefix_hint(text)
    local lower = tostring(text or ""):lower()

    if lower == "" then
        return "十六进制 Unicode 码点", "〔默认〕"
    elseif lower == "d" or lower == "0d" then
        return "十进制 Unicode 码点", "〔提示〕"
    elseif lower == "x" or lower == "h" or lower == "0x" then
        return "十六进制 Unicode 码点", "〔提示〕"
    elseif lower == "b" or lower == "0b" then
        return "二进制 Unicode 码点", "〔提示〕"
    elseif lower == "o" or lower == "0o" then
        return "八进制 Unicode 码点", "〔提示〕"
    elseif lower == "+" then
        return "Unicode 标准码点", "〔提示〕"
    elseif text == "c" then
        return "词库编码转 Unicode", "〔提示〕"
    end

    return nil
end

local function is_valid_scalar(cp)
    return cp and cp >= 0 and cp <= MAX_CODEPOINT and not (cp >= 0xD800 and cp <= 0xDFFF)
end

local function is_control_codepoint(cp)
    return cp < 0x20 or (cp >= 0x7F and cp <= 0x9F)
end

local function format_u_plus(cp)
    return string.format("U+%04X", cp)
end

local function format_hex(cp)
    return string.format("0x%X", cp)
end

local function format_decimal(cp)
    return tostring(cp)
end

local function format_binary(cp)
    if cp == 0 then
        return "0b0"
    end

    local digits = {}
    while cp > 0 do
        digits[#digits + 1] = tostring(cp % 2)
        cp = math.floor(cp / 2)
    end

    local result = {}
    for i = #digits, 1, -1 do
        result[#result + 1] = digits[i]
    end
    return "0b" .. table.concat(result)
end

local function format_octal(cp)
    if cp == 0 then
        return "0o0"
    end

    local digits = {}
    while cp > 0 do
        digits[#digits + 1] = tostring(cp % 8)
        cp = math.floor(cp / 8)
    end

    local result = {}
    for i = #digits, 1, -1 do
        result[#result + 1] = digits[i]
    end
    return "0o" .. table.concat(result)
end

local function format_unicode_escape(cp)
    if cp <= 0xFFFF then
        return string.format("\\u%04X", cp)
    end

    return string.format("\\U%08X", cp)
end

local function format_braced_escape(cp)
    return string.format("\\u{%X}", cp)
end

local function utf16_surrogates(cp)
    if cp <= 0xFFFF then
        return nil
    end

    local value = cp - 0x10000
    local high = 0xD800 + math.floor(value / 0x400)
    local low = 0xDC00 + (value % 0x400)

    return high, low
end

local function format_utf16(cp)
    local high, low = utf16_surrogates(cp)

    if high then
        return string.format("%04X %04X", high, low)
    end

    return string.format("%04X", cp)
end

local function format_js_escape(cp)
    local high, low = utf16_surrogates(cp)

    if high then
        return string.format("\\u%04X\\u%04X", high, low)
    end

    return string.format("\\u%04X", cp)
end

local function format_html_hex(cp)
    return string.format("&#x%X;", cp)
end

local function format_html_decimal(cp)
    return string.format("&#%d;", cp)
end

local function utf8_bytes(text)
    local bytes = {}
    for i = 1, #text do
        bytes[#bytes + 1] = string.byte(text, i)
    end
    return bytes
end

local function format_utf8_bytes(text)
    local bytes = utf8_bytes(text)
    local result = {}

    for i = 1, #bytes do
        result[i] = string.format("%02X", bytes[i])
    end

    return table.concat(result, " ")
end

local function format_url_encoding(text)
    local bytes = utf8_bytes(text)
    local result = {}

    for i = 1, #bytes do
        result[i] = string.format("%%%02X", bytes[i])
    end

    return table.concat(result)
end

local function codepoints(text)
    local result = {}

    local ok = pcall(function()
        for _, cp in utf8.codes(text) do
            result[#result + 1] = cp
        end
    end)

    if not ok then
        return nil
    end

    return result
end

local function encode_codepoint_sequence(points)
    local parts = { SEQUENCE_MARKER }

    for i = 1, #points do
        local cp = points[i]
        if not is_valid_scalar(cp) then return nil end
        parts[#parts + 1] = string.format("%06x", cp)
    end

    return table.concat(parts)
end

local function decode_codepoint_sequence(payload)
    if payload:sub(1, #SEQUENCE_MARKER) ~= SEQUENCE_MARKER then return nil end

    local encoded = payload:sub(#SEQUENCE_MARKER + 1)
    if encoded == "" or #encoded % SEQUENCE_WIDTH ~= 0 then return nil end

    local points = {}
    for i = 1, #encoded, SEQUENCE_WIDTH do
        local cp = parse_base_integer(encoded:sub(i, i + SEQUENCE_WIDTH - 1), 16)
        if not is_valid_scalar(cp) then return nil end
        points[#points + 1] = cp
    end

    if #points < 2 then return nil end

    local chars = {}
    for i = 1, #points do
        chars[i] = utf8.char(points[i])
    end

    return table.concat(chars), points
end

local function join_codepoints(points, formatter, separator)
    local result = {}

    for i = 1, #points do
        result[i] = formatter(points[i])
    end

    return table.concat(result, separator or " ")
end

local function build_codepoint_candidates(cp, character_comment)
    if not is_valid_scalar(cp) then
        return {}
    end

    local char = utf8.char(cp)
    local candidates = {}

    if not is_control_codepoint(cp) then
        candidates[#candidates + 1] = {
            char,
            character_comment or "〔字符〕",
        }
    end

    candidates[#candidates + 1] = { format_u_plus(cp), "〔码点〕" }
    candidates[#candidates + 1] = { format_hex(cp), "〔十六进制〕" }
    candidates[#candidates + 1] = { format_decimal(cp), "〔十进制〕" }
    candidates[#candidates + 1] = { format_binary(cp), "〔二进制〕" }
    candidates[#candidates + 1] = { format_octal(cp), "〔八进制〕" }
    candidates[#candidates + 1] = { format_unicode_escape(cp), "〔Unicode转义〕" }
    candidates[#candidates + 1] = { format_braced_escape(cp), "〔花括号转义〕" }

    local js_escape = format_js_escape(cp)
    if js_escape ~= format_unicode_escape(cp) then
        candidates[#candidates + 1] = { js_escape, "〔JS转义〕" }
    end

    candidates[#candidates + 1] = { format_utf8_bytes(char), "〔UTF-8〕" }
    candidates[#candidates + 1] = { format_utf16(cp), "〔UTF-16〕" }
    candidates[#candidates + 1] = { format_html_hex(cp), "〔HTML十六〕" }
    candidates[#candidates + 1] = { format_html_decimal(cp), "〔HTML十进〕" }
    candidates[#candidates + 1] = { format_url_encoding(char), "〔URL编码〕" }

    return candidates
end

local function get_ambiguous_decimal_character(payload, primary_cp, source)
    if source ~= "bare_hex" or not payload:match("^[0-9]+$") then
        return nil
    end

    local decimal_cp = parse_base_integer(payload, 10)
    if not is_valid_scalar(decimal_cp) or
        is_control_codepoint(decimal_cp) or
        decimal_cp == primary_cp then
        return nil
    end

    return utf8.char(decimal_cp)
end

local function insert_alternative_character(candidates, text)
    if not text then
        return
    end

    local position = 1
    if candidates[1] and candidates[1][2]:find("字符", 1, true) then
        position = 2
    end

    table.insert(candidates, position, { text, "〔字符·十进〕" })
end

local function build_text_candidates(text)
    local points = codepoints(text)
    if not points or #points == 0 then
        return {}
    end

    local unicode_escape = join_codepoints(points, format_unicode_escape, "")
    local js_escape = join_codepoints(points, format_js_escape, "")

    local candidates = {
        { join_codepoints(points, format_u_plus), "〔码点〕" },
        { join_codepoints(points, format_hex), "〔十六进制〕" },
        { join_codepoints(points, format_decimal), "〔十进制〕" },
        { unicode_escape, "〔Unicode转义〕" },
        { join_codepoints(points, format_braced_escape, ""), "〔花括号转义〕" },
    }

    if js_escape ~= unicode_escape then
        candidates[#candidates + 1] = { js_escape, "〔JS转义〕" }
    end

    candidates[#candidates + 1] = { format_utf8_bytes(text), "〔UTF-8〕" }
    candidates[#candidates + 1] = {
        join_codepoints(points, format_utf16),
        "〔UTF-16〕",
    }
    candidates[#candidates + 1] = {
        join_codepoints(points, format_html_hex, ""),
        "〔HTML十六〕",
    }
    candidates[#candidates + 1] = {
        join_codepoints(points, format_html_decimal, ""),
        "〔HTML十进〕",
    }
    candidates[#candidates + 1] = { format_url_encoding(text), "〔URL编码〕" }

    return candidates
end

local function get_unicode_trigger(env)
    if env.unicode_trigger ~= nil then
        return env.unicode_trigger
    end

    local pattern = env.engine.schema.config:get_string("recognizer/patterns/unicode")
    env.unicode_trigger = pattern and pattern:sub(2, 2) or "U"
    return env.unicode_trigger
end

local function extract_payload(input, seg, env)
    local trigger = get_unicode_trigger(env)

    if trigger ~= "" and input:sub(1, #trigger) == trigger then
        return input:sub(#trigger + 1)
    end

    if seg:has_tag("unicode") then
        return input
    end

    return nil
end

local function collect_dictionary_entries(memory, code)
    if not memory or not memory:dict_lookup(code, true, 50) then
        return {}
    end

    local by_text = {}
    for entry in memory:iter_dict() do
        local weight = tonumber(entry.weight) or 0
        local saved = by_text[entry.text]

        if not saved or weight > saved.weight then
            by_text[entry.text] = {
                text = entry.text,
                weight = weight,
            }
        end
    end

    local entries = {}
    for _, entry in pairs(by_text) do
        entries[#entries + 1] = entry
    end

    table.sort(entries, function(a, b)
        if a.weight == b.weight then
            return a.text < b.text
        end
        return a.weight > b.weight
    end)

    return entries
end

local function yield_dictionary_conversion(code, seg, env)
    local entries = collect_dictionary_entries(env.unicode_memory, code)

    for _, entry in ipairs(entries) do
        local candidates = build_text_candidates(entry.text)

        for _, item in ipairs(candidates) do
            yield(Candidate("unicode", seg.start, seg._end, item[1], "〔" .. entry.text .. "〕" .. item[2]))
        end
    end
end

-- ----------------------
-- P：当前候选字符 -> Uxxxx
-- ----------------------

local function has_unicode_prefix(input, env)
    local trigger = get_unicode_trigger(env)
    return trigger ~= "" and input:sub(1, #trigger) == trigger
end

function P.init(env)
    local config = env.engine.schema.config
    local key = config:get_string("unicode/key")
    if not key or key == "" then key = DEFAULT_HOTKEY end

    env.unicode_key = KeyEvent(key)
    env.unicode_prev_input = nil
    env.unicode_update_connection = env.engine.context.update_notifier:connect(function(context)
        if env.unicode_prev_input ~= nil and not has_unicode_prefix(context.input or "", env) then
            env.unicode_prev_input = nil
        end
    end)
end

function P.fini(env)
    if env.unicode_update_connection then
        env.unicode_update_connection:disconnect()
        env.unicode_update_connection = nil
    end

    env.unicode_key = nil
    env.unicode_prev_input = nil
end

function P.func(key, env)
    if key:release() or not env.unicode_key or not key:eq(env.unicode_key) then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local context = env.engine.context

    -- 必须直接保存完整 context.input；不能从当前 segment / preedit 反推。
    -- recognizer / segmentor 即使消费了反查前缀（如 `yuif 的 `），
    -- context.input 仍是需要恢复的完整原始输入。
    local full_input = context.input or ""

    -- 只有快捷键创建的 U 会话才有返回点；U 内部继续编辑仍保留该返回点。
    if env.unicode_prev_input ~= nil and has_unicode_prefix(full_input, env) then
        local prev_input = env.unicode_prev_input
        env.unicode_prev_input = nil
        context.input = prev_input
        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end

    -- 用户手动输入 U... 时不制造虚假的返回点。
    if has_unicode_prefix(full_input, env) then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    -- 普通候选优先直接取 Context 当前候选。
    local cand = context:get_selected_candidate()

    -- punct / 符号菜单可能只有“高亮索引”而没有 selected candidate，
    -- 因此直接按当前 Segment.selected_index 从 Menu 取候选。
    if not cand then
        local current_seg = context.composition:back()
        local menu = current_seg and current_seg.menu or nil
        if menu and not menu:empty() then
            local index = tonumber(current_seg.selected_index) or 0
            menu:prepare(index + 1)
            cand = menu:get_candidate_at(index)
        end
    end

    local text = cand and cand.text or ""
    if text == "" then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local points = codepoints(text)
    if not points or #points == 0 then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local payload
    if #points == 1 then
        if not is_valid_scalar(points[1]) then
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end
        payload = string.format("%x", points[1])
    else
        payload = encode_codepoint_sequence(points)
        if not payload then
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end
    end

    env.unicode_prev_input = full_input
    context.input = get_unicode_trigger(env) .. payload
    return wanxiang.RIME_PROCESS_RESULTS.kAccepted
end

-- ----------------------
-- T：U 输入 -> Unicode 候选
-- ----------------------

function T.init(env)
    env.unicode_memory = Memory(env.engine, env.engine.schema)
end

function T.fini(env)
    if env.unicode_memory then
        env.unicode_memory:disconnect()
        env.unicode_memory = nil
    end
end

function T.func(input, seg, env)
    local payload = extract_payload(input, seg, env)
    if payload == nil then
        return
    end

    local hint_text, hint_comment = get_prefix_hint(payload)
    if hint_text then
        yield(Candidate("unicode", seg.start, seg._end, hint_text, hint_comment))
        return
    end

    if payload:sub(1, 1) == "c" then
        local code = payload:sub(2)
        if code ~= "" then
            yield_dictionary_conversion(code, seg, env)
        end
        return
    end

    local sequence_text, sequence_points = decode_codepoint_sequence(payload)
    if sequence_text then
        local preedit = join_codepoints(sequence_points, format_u_plus)
        local original = Candidate("unicode", seg.start, seg._end, sequence_text, "〔字符序列〕")
        original.preedit = preedit
        yield(original)

        local candidates = build_text_candidates(sequence_text)
        for _, item in ipairs(candidates) do
            local cand = Candidate("unicode", seg.start, seg._end, item[1], item[2])
            cand.preedit = preedit
            yield(cand)
        end
        return
    end

    local cp, _, source = parse_codepoint_input(payload)
    if cp == nil then
        return
    end

    local decimal_alternative = get_ambiguous_decimal_character(
        payload,
        cp,
        source
    )

    if cp > MAX_CODEPOINT then
        yield(Candidate("unicode", seg.start, seg._end, "数值超限！", "〔错误〕"))

        if decimal_alternative then
            yield(Candidate("unicode", seg.start, seg._end, decimal_alternative, "〔字符·十进〕"))
        end
        return
    end

    if cp >= 0xD800 and cp <= 0xDFFF then
        yield(Candidate("unicode", seg.start, seg._end, "代理区字符无效！", "〔错误〕"))

        if decimal_alternative then
            yield(Candidate("unicode", seg.start, seg._end, decimal_alternative, "〔字符·十进〕"))
        end
        return
    end

    local character_comment = source == "bare_hex" and
        payload:match("^[0-9]+$") and
        "〔字符·十六〕" or
        "〔字符〕"

    local candidates = build_codepoint_candidates(cp, character_comment)
    insert_alternative_character(candidates, decimal_alternative)

    for _, item in ipairs(candidates) do
        yield(Candidate("unicode", seg.start, seg._end, item[1], item[2]))
    end
end

return { P = P, T = T }
