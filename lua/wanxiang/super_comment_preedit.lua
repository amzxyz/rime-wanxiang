--@amzxyz https://github.com/amzxyz/rime-wanxiang


local wanxiang = require('wanxiang/wanxiang')

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

-- ----------------------
-- # 错音错字提示模块
-- ----------------------
local CR = {}
local corrections_cache = nil -- 用于缓存已加载的词典
local cached_dict_path = nil  -- 记录当前缓存的词典路径

function CR.init(env)
    -- 动态获取样式，因为配置可能在运行时被修改，所以这个不放进缓存拦截里
    CR.style = env.settings.corrector_type or '{comment}'
    CR.style_left, CR.style_right = CR.style:match("^(.-)comment(.-)$")
    local auto_delimiter = env.settings.auto_delimiter
    local is_pro = wanxiang.is_pro_scheme(env)
    -- 根据方案选择加载路径
    local path = (is_pro and "dicts/cuoyin.pro.dict.yaml") or "dicts/cuoyin.dict.yaml"

    -- 如果缓存已经存在，并且文件路径没变，直接返回，不再读盘
    if corrections_cache and cached_dict_path == path then
        return
    end

    local file, close_file, err = wanxiang.load_file_with_fallback(path)
    if not file then
        log.error(string.format("[super_comment]: 加载失败 %s，错误: %s", path, err))
        return
    end

    corrections_cache = {}
    for line in file:lines() do
        if not line:match("^#") then
            local text, code, weight, comment = line:match("^(.-)\t(.-)\t(.-)\t(.-)$")
            if text and code then
                text = text:match("^%s*(.-)%s*$")
                code = code:match("^%s*(.-)%s*$")
                comment = comment and comment:match("^%s*(.-)%s*$") or ""
                comment = comment:gsub("%s+", auto_delimiter)
                code = code:gsub("%s+", auto_delimiter)
                corrections_cache[code] = { text = text, comment = comment }
            end
        end
    end
    close_file()

    -- 记录本次成功加载的文件路径
    cached_dict_path = path
end

function CR.get_comment(cand)
    local correction = corrections_cache and corrections_cache[cand.comment] or nil
    if not (correction and cand.text == correction.text) then
        return nil
    end
    if CR.style_left then
        return CR.style_left .. correction.comment .. CR.style_right
    end

    return correction.comment
end
-- ----------------------
-- 部件组字返回的注释
-- ----------------------
local function get_charset_label(text)
    if not text or text == "" then return nil end
    local cp = utf8.codepoint(text)
    if not cp then return nil end

    -- 按照 Unicode 区块频率排序
    if cp >= 0x4E00   and cp <= 0x9FFF  then return "基本" end
    if cp >= 0x3400   and cp <= 0x4DBF  then return "扩A" end
    if cp >= 0x20000  and cp <= 0x2A6DF then return "扩B" end
    if cp >= 0x2A700  and cp <= 0x2B73F then return "扩C" end
    if cp >= 0x2B740  and cp <= 0x2B81F then return "扩D" end
    if cp >= 0x2B820  and cp <= 0x2CEAF then return "扩E" end
    if cp >= 0x2CEB0  and cp <= 0x2EBEF then return "扩F" end
    if cp >= 0x2EBF0  and cp <= 0x2EE5F then return "扩I" end
    if cp >= 0x30000  and cp <= 0x3134F then return "扩G" end
    if cp >= 0x31350  and cp <= 0x323AF then return "扩H" end

    -- 兼容区
    if cp >= 0xF900   and cp <= 0xFAFF  then return "兼容" end
    if cp >= 0x2F800  and cp <= 0x2FA1F then return "兼容" end

    return nil
end

local function get_az_comment(cand, env, initial_comment)
    local inner_parts = {}

    -- 音形注释拆解逻辑
    if initial_comment and initial_comment ~= "" then
        local segments = {}
        for segment in string.gmatch(initial_comment, "[^%s]+") do
            segments[#segments + 1] = segment
        end

        if #segments > 0 then
            local semicolon_count = select(2, string.gsub(segments[1], ";", ""))
            local pinyins = {}
            local fuzhu = nil

            for _, segment in ipairs(segments) do
                local pinyin = string.match(segment, "^[^;~]+")
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
-- # 辅助码提示或带调全拼注释模块 (Fuzhu)
-- ----------------------
local function get_fz_comment(cand, env, initial_comment, fuzhu_type)
    if not initial_comment or initial_comment == "" then
        return ""
    end

    local length = utf8.len(cand.text or "") or 0
    if length > env.settings.candidate_length then
        return ""
    end

    local first_segment = initial_comment:match(env.settings.comment_split_pattern) or ""
    local semicolon_count = select(2, first_segment:gsub(";", ""))

    -- 没有辅助码结构时，原始注释和其中的分隔符全部原样保留
    if semicolon_count == 0 then
        return initial_comment
    end

    -- 带调/无调拼音只替换音节内容，自动、手动分隔符及其位置原样保留
    if fuzhu_type == "tone" then
        return (initial_comment:gsub(env.settings.comment_split_pattern, function(segment)
            return segment:match("^(.-);") or ""
        end))
    end

    -- 辅助码模式维持原有使用 "/" 连接的业务逻辑
    local fuzhu_comments = {}
    for segment in initial_comment:gmatch(env.settings.comment_split_pattern) do
        local after = segment:match(";(.+)$")
        if after and after ~= "" then
            fuzhu_comments[#fuzhu_comments + 1] = after
        end
    end

    if #fuzhu_comments == 0 then
        return ""
    end

    return table.concat(fuzhu_comments, "/")
end

-- 对 cand.preedit 应用 tone_preedit/0..9 的映射（数字 -> 上标等）
-- 对 cand.preedit 应用转换：数字转上标，且隐藏双大写辅助码
local function apply_tone_preedit(env, cand)
    if not cand or not cand.preedit or cand.preedit == "" then
        return
    end

    if cand.text:match("^[%a%p%s]+$") then
        return
    end

    local preedit = cand.preedit
    local aux_symbol = env.settings.aux_symbol

    if aux_symbol and aux_symbol ~= "" and preedit:find("[A-Z][A-Z]") then
        local converted = preedit:gsub("^(..?-?)([A-Z][A-Z]+)", function(prefix, upper)
            if prefix:match("[A-Z]") then
                return prefix .. upper
            end
            return prefix .. aux_symbol
        end)

        converted = converted:gsub("([^%s%^])([A-Z][A-Z]+)", function(prev)
            return prev .. aux_symbol
        end)

        cand.preedit = converted
    end

    if not cand.preedit:find("%d") then
        return
    end

    cand.preedit = cand.preedit:gsub("([^%d%s]+)(%d+)", function(body, digits)
        local mapped = digits:gsub("%d", function(d)
            return env.tone_map[d] or d
        end)
        return body .. mapped
    end)
end

-- ----------------------
-- 主函数：根据优先级处理候选词的注释和preedit
-- ----------------------
local ZH = {}
function ZH.init(env)
    local config = env.engine.schema.config
    local delimiter = config:get_string('speller/delimiter') or " '"
    local auto_delimiter = delimiter:sub(1, 1)
    local manual_delimiter = delimiter:sub(2, 2)
    local escaped_delimiters = escape_pattern_class(delimiter)

    env.settings = {
        delimiter = delimiter,
        auto_delimiter = auto_delimiter,
        manual_delimiter = manual_delimiter,
        corrector_enabled = config:get_bool("super_comment/corrector") or true,
        corrector_type = config:get_string("super_comment/corrector_type") or "{comment}",
        candidate_length = tonumber(config:get_string("super_comment/candidate_length")) or 1,
        aux_symbol = config:get_string("force_upper_aux/symbol"),
        tone_isolate = config:get_bool("speller/tone_isolate"),
        comment_split_pattern = "[^" .. escaped_delimiters .. "]+",
    }

    env.tone_map = {}

    for d = 0, 9 do
        local key = tostring(d)
        local value = config:get_string("tone_preedit/" .. key)
        env.tone_map[key] = value and value ~= "" and value or key
    end

    CR.init(env)
end
function ZH.fini(env)
end
function ZH.func(input, env)
    local context = env.engine.context
    local input_str = context.input or ""
    local is_t9_key = input_str:match("^%d") ~= nil
    local skip_tone_preedit = is_t9_key or input_str:match("%d%d") ~= nil
    local is_radical_mode = wanxiang.is_in_radical_mode(env)
    local schema_id = env.engine.schema.schema_id or ""
    local is_wanxiang_pro = (schema_id == "wanxiang_pro")
    local should_skip_candidate_comment = wanxiang.is_function_mode_active(context) or input_str == ""
    local is_tone_comment = env.engine.context:get_option("tone_hint")
    local is_toneless_comment = env.engine.context:get_option("toneless_hint")
    local is_comment_hint = env.engine.context:get_option("fuzhu_hint")
    local fuzhu_type = (is_tone_comment or is_toneless_comment) and "tone" or "fuzhu"
    --preedit相关声明
    local auto_delimiter = env.settings.auto_delimiter
    local manual_delimiter = env.settings.manual_delimiter
    local tone_isolate = env.settings.tone_isolate
    local is_tone_display = context:get_option("tone_display")
    local is_full_pinyin = context:get_option("full_pinyin")

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()
        if genuine_cand.type == "shijian" then
            yield(genuine_cand)
            goto continue
        end
        local preedit = genuine_cand.preedit or ""
        local initial_comment = genuine_cand.comment
        local final_comment = initial_comment

        -- preedit相关处理只跳过 preedit，不影响注释
        if is_radical_mode then
            goto after_preedit
        end
        if not is_tone_display and not is_full_pinyin then
            goto after_preedit
        end
        if (not initial_comment or initial_comment == "") then
            goto after_preedit
        end
        do
            -- 拆分逻辑
            local input_parts = {}
            local current_segment = ""

            for char in preedit:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                if char == auto_delimiter or char == manual_delimiter then
                    if #current_segment > 0 then
                        input_parts[#input_parts + 1] = current_segment
                        current_segment = ""
                    end
                    input_parts[#input_parts + 1] = char
                else
                    current_segment = current_segment .. char
                end
            end

            if #current_segment > 0 then
                input_parts[#input_parts + 1] = current_segment
            end

            -- 拆分拼音段（comment）
            local pinyin_segments = {}
            for segment in initial_comment:gmatch(env.settings.comment_split_pattern) do
                local pinyin = segment:match("^[^;]+")
                if pinyin then
                    pinyin = pinyin:gsub("[%[%]]", "")
                    pinyin_segments[#pinyin_segments + 1] = pinyin
                end
            end

            -- 替换逻辑
            local pinyin_index = 1
            for i, part in ipairs(input_parts) do
                if part ~= auto_delimiter and part ~= manual_delimiter then
                    local py = pinyin_segments[pinyin_index]

                    if py then
                        if is_t9_key then
                            -- 场景 A：九宫格 (T9) 数字输入逻辑
                            local py_first_char = py:match("[%z\1-\127\194-\244][\128-\191]*") or ""
                            local part_offset = utf8.offset(part, 2)
                            local part_tail = part_offset and part:sub(part_offset) or ""
                            part = py_first_char .. part_tail

                            if is_wanxiang_pro then
                                input_parts[i] = py
                                pinyin_index = pinyin_index + 1
                            elseif i == #input_parts and #part == 1 then
                                local prefix = py:sub(1, 2)
                                local first_char = part:sub(1,1):lower()
                                if first_char == "s" or first_char == "c" or first_char == "z" then
                                    input_parts[i] = part
                                else
                                    if prefix == "zh" or prefix == "ch" or prefix == "sh" then
                                        input_parts[i] = prefix
                                    else
                                        input_parts[i] = part
                                    end
                                end
                            else
                                input_parts[i] = py
                                pinyin_index = pinyin_index + 1
                            end

                        else
                            -- 场景 B：常规 26键 字母输入逻辑
                            local _, tone = part:match("([%a]+)([^%a]+)")

                            if is_wanxiang_pro then
                                input_parts[i] = py
                                pinyin_index = pinyin_index + 1
                            elseif i == #input_parts and #part == 1 then
                                local prefix = py:sub(1, 2)
                                local first_char = part:sub(1,1):lower()
                                if first_char == "s" or first_char == "c" or first_char == "z" then
                                    input_parts[i] = part
                                else
                                    if prefix == "zh" or prefix == "ch" or prefix == "sh" then
                                        input_parts[i] = prefix
                                    else
                                        input_parts[i] = part
                                    end
                                end
                            else
                                if tone_isolate then
                                    input_parts[i] = py .. (tone or "")
                                else
                                    input_parts[i] = py
                                end
                                pinyin_index = pinyin_index + 1
                            end
                        end
                    end
                end
            end

            if is_full_pinyin then
                for idx, part in ipairs(input_parts) do
                    input_parts[idx] = remove_pinyin_tone(part)
                end
            end

            genuine_cand.preedit = table.concat(input_parts)
        end
        ::after_preedit::
        if should_skip_candidate_comment then
            yield(genuine_cand)
            goto continue
        end
        if not skip_tone_preedit then
            apply_tone_preedit(env, genuine_cand)
        end
        -- 进入注释处理阶段
        -- ① 辅助码注释或者声调注释
        if initial_comment and (string.find(initial_comment, "~") or cand.type == "shijian") then
            final_comment = initial_comment

        -- 2. 常规的辅助码提示模式
        elseif is_comment_hint then
            local fz_comment = get_fz_comment(cand, env, initial_comment, fuzhu_type)
            if fz_comment then
                final_comment = fz_comment
            end

        -- 3. 常规的带调拼音模式
        elseif is_tone_comment then
            local fz_comment = get_fz_comment(cand, env, initial_comment, fuzhu_type)
            if fz_comment then
                final_comment = fz_comment
            end

        -- 4. 常规的无调拼音模式
        elseif is_toneless_comment then
            local fz_comment = get_fz_comment(cand, env, initial_comment, fuzhu_type)
            if fz_comment then
                final_comment = remove_pinyin_tone(fz_comment)
            end

        -- 5. 超级符号模式，显示对应的Typst代码
        elseif genuine_cand.type == "super_sym" or genuine_cand.type == "super_emoji" then
            final_comment = initial_comment

        -- 6. 其他情况一律清空注释
        else
            final_comment = ""
        end

        -- ② 错音错字提示
        if env.settings.corrector_enabled then
            local cr_comment = CR.get_comment(cand)
            if cr_comment and cr_comment ~= "" then
                final_comment = cr_comment
            end
        end

        -- ③ 反查模式提示
        if is_radical_mode then
            local az_comment = get_az_comment(cand, env, initial_comment)
            if az_comment and az_comment ~= "" then
                final_comment = az_comment
            end
        end

        -- 应用注释
        if final_comment ~= initial_comment then
            genuine_cand.comment = final_comment
        end

        yield(genuine_cand)
        ::continue::
    end
end
return ZH
