-- @amzxyz  https://github.com/amzxyz/rime-wanxiang
-- 万象拼音

local LOWER_DIGITS = { "〇", "一", "二", "三", "四", "五", "六", "七", "八", "九" }
local UPPER_DIGITS = { "零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }

local LOWER_PLACE_UNITS = { "", "十", "百", "千" }
local UPPER_PLACE_UNITS = { "", "拾", "佰", "仟" }

local SIMPLIFIED_GROUP_UNITS = { "", "万", "亿" }
local TRADITIONAL_GROUP_UNITS = { "", "萬", "億" }

local CURRENCY_FRACTION_UNITS = { "角", "分", "厘", "毫" }

local SUPERSCRIPT_DIGITS = {
    ["0"] = "⁰",
    ["1"] = "¹",
    ["2"] = "²",
    ["3"] = "³",
    ["4"] = "⁴",
    ["5"] = "⁵",
    ["6"] = "⁶",
    ["7"] = "⁷",
    ["8"] = "⁸",
    ["9"] = "⁹",
}

local BASE_DIGITS = "0123456789ABCDEF"

local function parse_number_literal(text)
    text = tostring(text or "")

    if text == "-" then
        return { kind = "pending_negative" }
    end

    local left, right = text:match("^(-?%d+):(%d+)$")
    if left and right then
        return {
            kind = "ratio",
            left = left,
            right = right,
        }
    end

    local sign, integer, separator, fraction = text:match("^(-?)(%d*)(%.?)(%d*)$")
    if not sign or (integer == "" and fraction == "") then
        return nil
    end

    return {
        kind = "number",
        negative = sign == "-",
        integer = integer == "" and "0" or integer,
        has_decimal = separator == ".",
        fraction = fraction,
    }
end

local function normalize_integer_digits(integer)
    integer = tostring(integer or ""):gsub("^0+", "")
    return integer == "" and "0" or integer
end

local function convert_four_digit_group(group, digits, place_units)
    group = tostring(group or "")
    local zero = digits[1]
    local result = ""
    local pending_zero = false

    for i = 1, #group do
        local digit = tonumber(group:sub(i, i))
        local place = #group - i + 1

        if digit == 0 then
            if result ~= "" then
                pending_zero = true
            end
        else
            if pending_zero then
                result = result .. zero
                pending_zero = false
            end
            result = result .. digits[digit + 1] .. place_units[place]
        end
    end

    return result
end

local function convert_integer_to_chinese(integer, uppercase, group_units, suffix)
    integer = normalize_integer_digits(integer)
    if #integer > 12 then
        return "数值超限！"
    end

    local digits = uppercase and UPPER_DIGITS or LOWER_DIGITS
    local place_units = uppercase and UPPER_PLACE_UNITS or LOWER_PLACE_UNITS
    group_units = group_units or SIMPLIFIED_GROUP_UNITS
    suffix = suffix or ""

    if integer == "0" then
        return digits[1] .. suffix
    end

    local groups = {}
    for finish = #integer, 1, -4 do
        local start = math.max(1, finish - 3)
        groups[#groups + 1] = integer:sub(start, finish)
    end

    local result = ""
    local pending_zero = false

    for index = #groups, 1, -1 do
        local group = groups[index]
        local group_value = tonumber(group) or 0

        if group_value == 0 then
            if result ~= "" then
                pending_zero = true
            end
        else
            if result ~= "" and (pending_zero or group_value < 1000) then
                result = result .. digits[1]
            end

            result = result ..
                convert_four_digit_group(group, digits, place_units) ..
                group_units[index]

            pending_zero = false
        end
    end

    if not uppercase then
        result = result:gsub("^一十", "十")
    end

    return result .. suffix
end

local function spell_digits(text, uppercase)
    local digits = uppercase and UPPER_DIGITS or LOWER_DIGITS
    local result = ""

    for i = 1, #text do
        local digit = tonumber(text:sub(i, i))
        if not digit then
            return ""
        end
        result = result .. digits[digit + 1]
    end

    return result
end

local function format_currency_fraction(fraction, uppercase)
    local digits = uppercase and UPPER_DIGITS or LOWER_DIGITS
    local fraction_text = tostring(fraction or ""):sub(1, #CURRENCY_FRACTION_UNITS):gsub("0+$", "")
    if fraction_text == "" then
        return "整"
    end

    local result = ""
    local pending_zero = false

    for i = 1, #fraction_text do
        local digit = tonumber(fraction_text:sub(i, i))

        if digit == 0 then
            if result ~= "" then
                pending_zero = true
            end
        else
            if pending_zero then
                result = result .. digits[1]
                pending_zero = false
            elseif result == "" and i > 1 then
                result = result .. digits[1]
            end

            result = result .. digits[digit + 1] .. CURRENCY_FRACTION_UNITS[i]
        end
    end

    return result
end

local function format_grouped_integer(integer)
    integer = normalize_integer_digits(integer)
    local parts = {}

    while #integer > 3 do
        table.insert(parts, 1, integer:sub(-3))
        integer = integer:sub(1, -4)
    end
    table.insert(parts, 1, integer)

    return table.concat(parts, ",")
end

local function format_grouped_number(number)
    local result = format_grouped_integer(number.integer)

    if number.has_decimal then
        result = result .. "." .. number.fraction
    end

    if number.negative then
        result = "-" .. result
    end

    return result
end

local function format_fixed_currency(number)
    if #number.fraction > 2 then
        return nil
    end

    local fraction = number.fraction
    if #fraction == 0 then
        fraction = "00"
    elseif #fraction == 1 then
        fraction = fraction .. "0"
    end

    return "￥" .. format_grouped_integer(number.integer) .. "." .. fraction
end

local function format_accounting_negative(number)
    if not number.negative or #number.fraction > 2 then
        return nil
    end

    local fraction = number.fraction
    if #fraction == 0 then
        fraction = "00"
    elseif #fraction == 1 then
        fraction = fraction .. "0"
    end

    return "(" .. format_grouped_integer(number.integer) .. "." .. fraction .. ")"
end


local function to_superscript(integer)
    local text = tostring(integer)
    local result = ""

    if text:sub(1, 1) == "-" then
        result = "⁻"
        text = text:sub(2)
    end

    for i = 1, #text do
        result = result .. (SUPERSCRIPT_DIGITS[text:sub(i, i)] or "")
    end

    return result
end

local function get_scientific_parts(number)
    local integer = tostring(number.integer or "")
    local fraction = tostring(number.fraction or "")
    local combined = integer .. fraction
    local first_nonzero = combined:find("[1-9]")

    if not first_nonzero then
        return nil
    end

    local exponent = #integer - first_nonzero
    local significant = combined:sub(first_nonzero)

    if not number.has_decimal then
        significant = significant:gsub("0+$", "")
    end

    if significant == "" then
        significant = "0"
    end

    return significant, exponent
end

local function format_scientific_notation(number)
    local significant, exponent = get_scientific_parts(number)
    if not significant then
        return nil
    end

    local coefficient = significant:sub(1, 1)
    if #significant > 1 then
        coefficient = coefficient .. "." .. significant:sub(2)
    end

    if number.negative then
        coefficient = "-" .. coefficient
    end

    return coefficient .. "×10" .. to_superscript(exponent)
end

local function format_e_notation(number)
    local significant, exponent = get_scientific_parts(number)
    if not significant then
        return nil
    end

    local coefficient = significant:sub(1, 1)
    if #significant > 1 then
        coefficient = coefficient .. "." .. significant:sub(2)
    end

    if number.negative then
        coefficient = "-" .. coefficient
    end

    local sign = exponent >= 0 and "+" or "-"
    local exponent_text = tostring(math.abs(exponent))
    if #exponent_text < 2 then
        exponent_text = "0" .. exponent_text
    end

    return coefficient .. "E" .. sign .. exponent_text
end

local function format_engineering_notation(number)
    local significant, exponent = get_scientific_parts(number)
    if not significant then
        return nil
    end

    local engineering_exponent = math.floor(exponent / 3) * 3
    local integer_digits = exponent - engineering_exponent + 1

    if #significant < integer_digits then
        significant = significant .. string.rep("0", integer_digits - #significant)
    end

    local coefficient = significant:sub(1, integer_digits)
    if #significant > integer_digits then
        coefficient = coefficient .. "." .. significant:sub(integer_digits + 1)
    end

    if number.negative then
        coefficient = "-" .. coefficient
    end

    return coefficient .. "×10" .. to_superscript(engineering_exponent)
end

local function decimal_string_to_base(integer, base)
    integer = normalize_integer_digits(integer)
    if integer == "0" then
        return "0"
    end

    local result = ""
    local current = integer

    while current ~= "0" do
        local quotient = {}
        local quotient_started = false
        local remainder = 0

        for i = 1, #current do
            local value = remainder * 10 + tonumber(current:sub(i, i))
            local digit = math.floor(value / base)
            remainder = value % base

            if digit ~= 0 or quotient_started then
                quotient[#quotient + 1] = tostring(digit)
                quotient_started = true
            end
        end

        result = BASE_DIGITS:sub(remainder + 1, remainder + 1) .. result
        current = quotient_started and table.concat(quotient) or "0"
    end

    return result
end

local function build_base_candidates(number)
    if number.has_decimal then
        return {}
    end

    local sign = number.negative and "-" or ""
    local integer = normalize_integer_digits(number.integer)

    return {
        { sign .. "0x" .. decimal_string_to_base(integer, 16), "〔十六进制〕" },
        { sign .. "0b" .. decimal_string_to_base(integer, 2), "〔二进制〕" },
        { sign .. "0o" .. decimal_string_to_base(integer, 8), "〔八进制〕" },
    }
end

local function build_ratio_candidates(number)
    local left_negative = number.left:sub(1, 1) == "-"
    local left_digits = left_negative and number.left:sub(2) or number.left

    local left_chinese = convert_integer_to_chinese(left_digits, false, SIMPLIFIED_GROUP_UNITS, "")
    local right_chinese = convert_integer_to_chinese(number.right, false, SIMPLIFIED_GROUP_UNITS, "")

    if left_negative then
        left_chinese = "负" .. left_chinese
    end

    return {
        { number.left .. ":" .. number.right, "〔比例〕" },
        { number.left .. "∶" .. number.right, "〔比例符号〕" },
        { left_chinese .. "比" .. right_chinese, "〔中文比例〕" },
    }
end

local function build_number_candidates(text)
    local number = parse_number_literal(text)
    if not number then
        return {}
    end

    if number.kind == "pending_negative" then
        return { { "-", "" } }
    end

    if number.kind == "ratio" then
        return build_ratio_candidates(number)
    end

    local sign_prefix = number.negative and "负" or ""

    local lower_integer = convert_integer_to_chinese(
        number.integer, false, SIMPLIFIED_GROUP_UNITS, ""
    )
    local upper_integer = convert_integer_to_chinese(
        number.integer, true, TRADITIONAL_GROUP_UNITS, ""
    )
    local lower_currency_integer = convert_integer_to_chinese(
        number.integer, false, SIMPLIFIED_GROUP_UNITS, "元"
    )
    local upper_currency_integer = convert_integer_to_chinese(
        number.integer, true, SIMPLIFIED_GROUP_UNITS, "元"
    )

    local lower_plain = sign_prefix .. lower_integer
    local upper_plain = sign_prefix .. upper_integer

    if number.has_decimal then
        lower_plain = lower_plain .. "点" .. spell_digits(number.fraction, false)
        upper_plain = upper_plain .. "点" .. spell_digits(number.fraction, true)
    end

    local lower_currency = sign_prefix ..
        lower_currency_integer ..
        format_currency_fraction(number.fraction, false)

    local upper_currency = sign_prefix ..
        upper_currency_integer ..
        format_currency_fraction(number.fraction, true)

    local candidates
    if number.negative then
        candidates = {
            { lower_plain, "〔小写〕" },
            { upper_plain, "〔繁体大写〕" },
        }
    else
        candidates = {
            { lower_plain, "〔小写〕" },
            { upper_currency, "〔大写〕" },
            { upper_plain, "〔繁体大写〕" },
            { lower_currency, "〔小写金额〕" },
        }
    end

    if #number.integer > 1 and number.integer:sub(1, 1) == "0" then
        local digit_spelling = spell_digits(number.integer, false)
        if number.has_decimal then
            digit_spelling = digit_spelling .. "点" .. spell_digits(number.fraction, false)
        end
        if number.negative then
            digit_spelling = "负" .. digit_spelling
        end
        candidates[#candidates + 1] = { digit_spelling, "〔逐位〕" }
    end

    candidates[#candidates + 1] = { format_grouped_number(number), "〔千分计数〕" }

    if number.negative then
        local accounting = format_accounting_negative(number)
        if accounting then
            candidates[#candidates + 1] = { accounting, "〔会计格式〕" }
        end
    else
        local fixed_currency = format_fixed_currency(number)
        if fixed_currency then
            candidates[#candidates + 1] = { fixed_currency, "〔人民币〕" }
        end

    end

    local scientific = format_scientific_notation(number)
    if scientific then
        candidates[#candidates + 1] = { scientific, "〔科学计数〕" }
    end

    local e_notation = format_e_notation(number)
    if e_notation then
        candidates[#candidates + 1] = { e_notation, "〔E计数〕" }
    end

    local engineering = format_engineering_notation(number)
    if engineering and engineering ~= scientific then
        candidates[#candidates + 1] = { engineering, "〔工程计数〕" }
    end

    local base_candidates = build_base_candidates(number)
    for i = 1, #base_candidates do
        candidates[#candidates + 1] = base_candidates[i]
    end

    return candidates
end

local function get_number_trigger(env)
    if env.number_trigger ~= nil then
        return env.number_trigger
    end

    local pattern = env.engine.schema.config:get_string("recognizer/patterns/number")
    env.number_trigger = pattern and pattern:sub(2, 2) or ""
    return env.number_trigger
end

local function number_conversion(input, seg, env)
    local trigger = get_number_trigger(env)
    if trigger == "" or input:sub(1, 1) ~= trigger then
        return
    end

    local candidates = build_number_candidates(input:sub(2))
    if #candidates == 0 then
        return
    end

    local context = env.engine.context
    local segment = context.composition:back()

    if segment then
        segment.tags = segment.tags + Set({ "number" })
    end

    for i = 1, #candidates do
        local item = candidates[i]
        yield(Candidate("number", seg.start, seg._end, item[1], item[2]))
    end
end

return number_conversion
