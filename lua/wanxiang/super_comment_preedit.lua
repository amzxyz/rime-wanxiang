--@amzxyz https://github.com/amzxyz/rime-wanxiang


local wanxiang = require('wanxiang/wanxiang')

local tone_map = {
    ['ā']='a', ['á']='a', ['ǎ']='a', ['à']='a',
    ['ē']='e', ['é']='e', ['ě']='e', ['è']='e',
    ['ī']='i', ['í']='i', ['ǐ']='i', ['ì']='i',
    ['ō']='o', ['ó']='o', ['ǒ']='o', ['ò']='o', ['ň']='n',
    ['ū']='u', ['ú']='u', ['ǔ']='u', ['ù']='u', ['ǹ']='n',
    ['ǖ']='ü', ['ǘ']='ü', ['ǚ']='ü', ['ǜ']='ü', ['ń']='n',
}

local function remove_pinyin_tone(s)
    local result = {}
    for uchar in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(result, tone_map[uchar] or uchar)
    end
    return table.concat(result)
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
    -- 只认占位符 `comment`，按“刀法”切分
    local tpl = CR.style or "comment"
    local left, right = tpl:match("^(.-)comment(.-)$")

    if left then
        return left .. correction.comment .. right
    else
        return correction.comment
    end
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
            table.insert(segments, segment)
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
                    table.insert(pinyins, pinyin) 
                end
                if not fuzhu and fz and fz ~= "" then fuzhu = fz end
            end

            if #pinyins > 0 then
                local pinyin_str = table.concat(pinyins, ",")
                table.insert(inner_parts, string.format("音%s", pinyin_str))
                
                if fuzhu then
                    table.insert(inner_parts, string.format("辅%s", fuzhu))
                end
            end
        end
    end

    if cand and cand.text then
        local label = get_charset_label(cand.text)
        if label then
            table.insert(inner_parts, label)
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
local function get_fz_comment(cand, env, initial_comment)
    local length = utf8.len(cand.text)
    if length > env.settings.candidate_length then
        return ""
    end
    local auto_delimiter = env.settings.auto_delimiter or " "
    local segments = {}
    for segment in string.gmatch(initial_comment, "[^" .. auto_delimiter .. "]+") do
        table.insert(segments, segment)
    end

    -- 根据 option 动态决定是否强制使用 tone
    local use_tone = env.engine.context:get_option("tone_hint") or env.engine.context:get_option("toneless_hint")
    local fuzhu_type = use_tone and "tone" or "fuzhu"

    local first_segment = segments[1] or ""
    local semicolon_count = select(2, first_segment:gsub(";", ""))
    local fuzhu_comments = {}
    -- 没有分号的情况
    if semicolon_count == 0 then
        return initial_comment:gsub(auto_delimiter, " ")
    else
        -- 有分号：按类型提取
        for _, segment in ipairs(segments) do
            if fuzhu_type == "tone" then
                -- 取第一个分号“前”的内容
                local before = segment:match("^(.-);")
                if before and before ~= "" then
                    table.insert(fuzhu_comments, before)
                end
            else -- "fuzhu"
                -- 取第一个分号“后”的内容（到行尾）
                local after = segment:match(";(.+)$")
                if after and after ~= "" then
                    table.insert(fuzhu_comments, after)
                end
            end
        end
    end

    -- 最终拼接输出，fuzhu用 `,`，tone用 /连接
    if #fuzhu_comments > 0 then
        if fuzhu_type == "tone" then
            return table.concat(fuzhu_comments, " ")
        else
            return table.concat(fuzhu_comments, "/")
        end
    else
        return ""
    end
end

-- 对 cand.preedit 应用 tone_preedit/0..9 的映射（数字 -> 上标等）
-- 对 cand.preedit 应用转换：数字转上标，且隐藏双大写辅助码
local function apply_tone_preedit(env, cand)
    if not cand or not cand.preedit or cand.preedit == "" then
        return
    end

    local engine = env.engine
    local ctx = engine and engine.context
    local input = ctx and ctx.input or ""
    local is_t9_key = input:match("^%d") ~= nil

    -- 如果是九键场景，或者包含连续数字（如电脑小键盘），直接跳过不转换
    if is_t9_key or input:match("%d%d") then return end

    -- 判断首选是否为纯英文（通过匹配是否全由英文字符组成且不含中文）
    if cand.text:match("^[%a%p%s]+$") then
        return
    end

    -- 加载配置
    local cfg = engine and engine.schema and engine.schema.config
    local aux_symbol = cfg and cfg:get_string("force_upper_aux/symbol")
    
    -- 如果没配置 symbol，直接跳过大写转换逻辑
    if not aux_symbol or aux_symbol == "" then
        goto tone_only
    end

    do
        local preedit = cand.preedit
        -- 排除前两位是大写的情况，只转换后续出现的双大写
        -- ([A-Z][A-Z]+) 匹配后续连续的两个及以上的大写字母。
        local converted = preedit:gsub("^(..?-?)([A-Z][A-Z]+)", function(prefix, upper)
            -- 检查前缀是否包含大写字母。如果前缀里有大写，说明可能是英文输入，不转换。
            if prefix:match("[A-Z]") then
                return prefix .. upper
            else
                return prefix .. aux_symbol
            end
        end)

        -- 处理非行首（音节中间或靠后）的双大写
        -- 比如 "nihaoWS" -> "nihao·"
        converted = converted:gsub("([^%s%^])([A-Z][A-Z]+)", function(prev, upper)
            return prev .. aux_symbol
        end)

        cand.preedit = converted
    end
    ::tone_only::
    -- 数字映射逻辑 (上标转换)
    if not env.tone_map then
        env.tone_map = {}
        if cfg then
            for d = 0, 9 do
                local k = tostring(d)
                local v = cfg:get_string("tone_preedit/" .. k)
                env.tone_map[k] = (v and v ~= "") and v or k
            end
        end
    end

    local final_pre = cand.preedit:gsub("([^%d%s]+)(%d+)", function(body, digits)
        local mapped = digits:gsub("%d", function(d)
            return env.tone_map[d] or d
        end)
        return body .. mapped
    end)
    
    cand.preedit = final_pre
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
    env.settings = {
        delimiter = delimiter,
        auto_delimiter = auto_delimiter,
        manual_delimiter = manual_delimiter,
        corrector_enabled = config:get_bool("super_comment/corrector") or true,
        corrector_type = config:get_string("super_comment/corrector_type") or "{comment}",
        candidate_length = tonumber(config:get_string("super_comment/candidate_length")) or 1,
    }

    CR.init(env)
end
function ZH.fini(env)
end
function ZH.func(input, env)
    local config = env.engine.schema.config
    local context = env.engine.context
    local input_str = context.input or ""
    local is_t9_key = input_str:match("^%d") ~= nil
    local is_radical_mode = wanxiang.is_in_radical_mode(env)
    local schema_id = env.engine.schema.schema_id or ""
    local is_wanxiang_pro = (schema_id == "wanxiang_pro")
    local should_skip_candidate_comment = wanxiang.is_function_mode_active(context) or input_str == ""
    local is_tone_comment = env.engine.context:get_option("tone_hint")
    local is_toneless_comment = env.engine.context:get_option("toneless_hint")
    local is_comment_hint = env.engine.context:get_option("fuzhu_hint")
    --preedit相关声明
    local delimiter = env.settings.delimiter
    local auto_delimiter = env.settings.auto_delimiter
    local manual_delimiter = env.settings.manual_delimiter
    local visual_delim = config:get_string("speller/visual_delimiter") or " "
    local tone_isolate = config:get_bool("speller/tone_isolate")
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
                        table.insert(input_parts, current_segment)
                        current_segment = ""
                    end
                    table.insert(input_parts, char)
                else
                    current_segment = current_segment .. char
                end
            end
            if #current_segment > 0 then
                table.insert(input_parts, current_segment)
            end

            -- 拆分拼音段（comment）
            local pinyin_segments = {}
            for segment in string.gmatch(initial_comment, "[^" .. auto_delimiter .. manual_delimiter .. "]+") do
                local pinyin = segment:match("^[^;]+")
                if pinyin then
                    pinyin = pinyin:gsub("[%[%]]", "")  --去掉英文词库编码中的[]
                    table.insert(pinyin_segments, pinyin)
                end
            end

            -- 替换逻辑
            local pinyin_index = 1
            for i, part in ipairs(input_parts) do
                if part == auto_delimiter or part == manual_delimiter then
                    input_parts[i] = visual_delim
                else
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
                            local body, tone = part:match("([%a]+)([^%a]+)") 

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
        apply_tone_preedit(env, genuine_cand)
        -- 进入注释处理阶段
        -- ① 辅助码注释或者声调注释
        if initial_comment and (string.find(initial_comment, "~") or string.find(initial_comment, "\226\152\175") or cand.type == "shijian" or cand.type == "cnen") then
            final_comment = initial_comment
            
        -- 2. 常规的辅助码提示模式
        elseif is_comment_hint then
            local fz_comment = get_fz_comment(cand, env, initial_comment)
            if fz_comment then
                final_comment = fz_comment
            end
            
        -- 3. 常规的带调拼音模式
        elseif is_tone_comment then
            local fz_comment = get_fz_comment(cand, env, initial_comment)
            if fz_comment then
                final_comment = fz_comment
            end
            
        -- 4. 常规的无调拼音模式
        elseif is_toneless_comment then
            local fz_comment = get_fz_comment(cand, env, initial_comment)
            if fz_comment then
                -- 获取到带调拼音后，调用 remove_pinyin_tone 去掉声调
                final_comment = remove_pinyin_tone(fz_comment)
            end
            
        -- 5. 其他情况一律清空注释
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
