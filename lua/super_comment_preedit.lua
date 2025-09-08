--@amzxyz https://github.com/amzxyz/rime_wanxiang
-- 省略说明注释 …

local wanxiang = require('wanxiang')

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

local patterns = {
    fuzhu = "[^;];(.*)$",
    tone = "([^;]*);",
    moqi = "[^;]*;([^;]*);",
    flypy = "[^;]*;[^;]*;([^;]*);",
    zrm = "[^;]*;[^;]*;[^;]*;([^;]*);",
    tiger = "[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
    wubi = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
    hanxin = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);"
}
-- #########################
-- # 辅助码拆分提示模块
-- PRO 专用
-- #########################
local CF = {}
function CF.init(env)
    if wanxiang.is_pro_scheme(env) then -- pro 版直接初始化
        CF.get_dict(env)
    end
end

function CF.fini(env)
    env.chaifen_dict = nil
    collectgarbage()
end

function CF.get_dict(env)
    if env.chaifen_dict == nil then
        env.chaifen_dict = ReverseLookup("wanxiang_chaifen")
    end
    return env.chaifen_dict
end

function CF.get_comment(cand, env)
    local dict = CF.get_dict(env)
    if not dict then return "" end

    local raw = dict:lookup(cand.text)
    if raw == "" then return "" end
    -- 跳过 tone 类型
    local fuzhu_type = env.settings.fuzhu_type or ""
    if fuzhu_type == "tone" then
        return ""
    end
    -- 辅助码类型 → 圈字映射
    local mark_map = {
        hanxin = "Ⓐ",
        tiger  = "Ⓒ",
        flypy  = "Ⓓ",
        moqi   = "Ⓔ",
        zrm    = "Ⓕ",
        wubi   = "Ⓑ"
    }
    local fuzhu_type = env.settings.fuzhu_type or ""
    local mark = mark_map[fuzhu_type]
    if not mark then return raw end  -- 如果没有匹配的圈字，返回整个 raw

    -- 拆分各字注释段（按空格、或用 %s 拆分多个注释块）
    local segments = {}
    for segment in raw:gmatch("[^%s]+") do
        table.insert(segments, segment)
    end
    -- 遍历查找包含指定圈字的片段
    for _, seg in ipairs(segments) do
        if seg:find(mark, 1, true) then
            -- 去除圈字标志，返回剩余内容
            return seg:gsub(mark, "", 1)
        end
    end
    return raw  -- 如果没有任何片段含圈字，也返回原始内容
end

-- #########################
-- # 错音错字提示模块
-- #########################
local CR = {}
local corrections_cache = nil -- 用于缓存已加载的词典
function CR.init(env)
    CR.style = env.settings.corrector_type or '{comment}'
    --if corrections_cache then return end
    local auto_delimiter = env.settings.auto_delimiter
    local is_pro = wanxiang.is_pro_scheme(env)
    -- 根据方案选择加载路径
    local path = (is_pro and "dicts/corrections.pro.dict.yaml") or "dicts/corrections.dict.yaml"
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
end

function CR.get_comment(cand)
    -- 使用候选词的 comment 作为 code，在缓存中查找对应的修正
    local correction = nil
    if corrections_cache then
        correction = corrections_cache[cand.comment]
    end
    if correction and cand.text == correction.text then
        -- 用新的注释替换默认注释
        local final_comment = CR.style:gsub("{comment}", correction.comment)
        return final_comment
    end
    return nil
end

-- ################################
-- 部件组字返回的注释
-- ################################
---@return string
local function get_az_comment(_, env, initial_comment)
    if not initial_comment or initial_comment == "" then return "〔无〕" end
    local final_comment = nil
    local auto_delimiter = env.settings.auto_delimiter or " "
    -- 拆分初始评论为多个段落
    local segments = {}
    for segment in initial_comment:gmatch("[^%s]+") do
        table.insert(segments, segment)
    end
    local semicolon_count = select(2, segments[1]:gsub(";", "")) -- 使用第一个段来判断分号的数量
    local pinyins = {}
    local fuzhu = nil
    for _, segment in ipairs(segments) do
        local pinyin = segment:match("^[^;]+")
        local fz = nil

        if semicolon_count == 0 then
            -- 无分号，只收集拼音
            fz = nil
        elseif semicolon_count == 1 then
            -- 一个分号，取后段
            fz = segment:match(";(.+)$")
        else
            -- 多个分号，使用模式提取
            local pattern = patterns[env.settings.fuzhu_type]
            if pattern then
                fz = segment:match(pattern)
            end
        end

        if pinyin then table.insert(pinyins, pinyin) end
        if not fuzhu and fz and fz ~= "" then fuzhu = fz end
    end

    -- 构建最终注释
    if #pinyins > 0 then
        local pinyin_str = table.concat(pinyins, ",")
        if fuzhu then
            final_comment = string.format("〔音%s 辅%s〕", pinyin_str, fuzhu)
        else
            final_comment = "〔无〕"
        end
    end
    -- 如果没有匹配到其他条件，确保返回默认格式
    return final_comment
end
-- #########################
-- # 辅助码提示或带调全拼注释模块 (Fuzhu)
-- #########################
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
    local use_tone = env.engine.context:get_option("tone_hint")
    local fuzhu_type = use_tone and "tone" or env.settings.fuzhu_type

    local first_segment = segments[1] or ""
    local semicolon_count = select(2, first_segment:gsub(";", ""))
    local fuzhu_comments = {}
    -- 没有分号的情况
    if semicolon_count == 0 then
        return initial_comment:gsub(auto_delimiter, " ")
    else   -- 有分号的情况根据类型选择
        local pattern = patterns[fuzhu_type]
        if pattern then
            for _, segment in ipairs(segments) do
                local match = segment:match(pattern)
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        else
            return ""
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
-- #########################
-- # 自动无词频造词模块
-- #########################
local AP = {}
local comment_cache = {}

function AP.init(env)
    local config = env.engine.schema.config
    local enable_auto_phrase = config:get_string("add_user_dict/enable_auto_phrase") or false

        -- 依据配置选择是否开始缓存comment
    if enable_auto_phrase:lower() == "true" then 
        env._commit_conn = env.engine.context.commit_notifier:connect(
            function(ctx)
                AP.commit_handler(ctx, env)
            end
        )
    end
end

function AP.fini(env)
    if env._commit_conn then
        env._commit_conn:disconnect()
        env._commit_conn = nil
    end
end

function AP.save_comment_cache(cand)
    local comment = cand.comment
    local comment_text = cand.text

    if comment_text and comment_text ~= "" and comment and comment ~= "" then
        comment_cache[comment_text] = comment
    end
end

function AP.commit_handler(ctx, env)
    if not ctx or not ctx.composition then
        comment_cache = {}
        return
    end

    local segments = ctx.composition:toSegmentation():get_segments()
    local segments_count = #segments
    local commit_text = ctx:get_commit_text()

    -- 检查是否符合最小造词单元要求
    if segments_count <= 1 or utf8.len(commit_text) <= 1 then
        comment_cache = {}
        return
    end

    -- 检查是否符合造词内容要求
    if not AP.is_chinese_only(commit_text) or comment_cache[commit_text] then
        comment_cache = {}
        return
    end

    local preedits_table = {}
    local config = env.engine.schema.config
    local delimiter = config:get_string("speller/delimiter") or " '"
    local escaped_delimiter = utf8.char(utf8.codepoint(delimiter)):gsub("(%W)", "%%%1")

    for i = 1, segments_count do
        local seg = segments[i]
        local cand = seg:get_selected_candidate()

        if cand then
            local cand_text = cand.text
            local preedit = comment_cache[cand_text]

            if preedit and preedit ~= "" then
                for part in preedit:gmatch("[^" .. escaped_delimiter .. "]+") do
                    table.insert(preedits_table, part)
                end
            end
        end
    end

    local memory = Memory(env.engine, env.engine.schema, "add_user_dict")
    local dictEntry = DictEntry()

    dictEntry.text = commit_text
    dictEntry.weight = 1
    dictEntry.custom_code = table.concat(preedits_table, " ") .. " "

    memory:update_userdict(dictEntry, 1, "")

    log.info(string.format("[auto_phrase] 自动造词：[%s]，编码：[%s]", dictEntry.text, dictEntry.custom_code))

    comment_cache = {}
end

-- 判断字符是否为汉字
function AP.is_chinese_only(text)
    local non_chinese_pattern = "[%w%p]"

    if not text or text == "" then
        return false
    end

    if text:match(non_chinese_pattern) then
        return false
    end

    for _, cp in utf8.codes(text) do
        -- 常用汉字区 + 扩展 A/B/C/D/E/F/G
        if
            not ((cp >= 0x4E00 and cp <= 0x9FFF) or -- CJK Unified Ideographs
                (cp >= 0x3400 and cp <= 0x4DBF) or -- CJK Ext-A
                (cp >= 0x20000 and cp <= 0x2EBEF) or -- CJK Ext-B~G（需 5.3+ 支持大码点）
                false)
         then
            return false
        end
    end
    return true
end
-- #########################
-- 主函数：根据优先级处理候选词的注释和preedit
-- #########################
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
        fuzhu_type = config:get_string("super_comment/fuzhu_type") or ""
    }
    CR.init(env)
    AP.init(env)
end
function ZH.fini(env)
    -- 清理
    CF.fini(env)
    AP.fini(env)
end
function ZH.func(input, env)
    local config = env.engine.schema.config
    local context = env.engine.context
    local input_str = context.input
    local is_radical_mode = wanxiang.is_in_radical_mode(env)
    local schema_id = env.engine.schema.schema_id or ""
    local is_wanxiang_pro = (schema_id == "wanxiang_pro")
    local should_skip_candidate_comment = wanxiang.is_function_mode_active(context) or input_str == ""
    local is_tone_comment = env.engine.context:get_option("tone_hint")
    local is_comment_hint = env.engine.context:get_option("fuzhu_hint")
    local is_chaifen_enabled = env.engine.context:get_option("chaifen_switch")
    --preedit相关声明
    local delimiter = env.settings.delimiter
    local auto_delimiter = env.settings.auto_delimiter
    local manual_delimiter = env.settings.manual_delimiter
    local visual_delim = config:get_string("speller/visual_delimiter") or " "
    local tone_isolate = config:get_bool("speller/tone_isolate")
    local is_tone_display = context:get_option("tone_display")
    local is_full_pinyin = context:get_option("full_pinyin")
    local index = 0
    -- auto_phrase 相关声明
    local enable_auto_phrase = config:get_string("add_user_dict/enable_auto_phrase") or false

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()
        local preedit = genuine_cand.preedit or ""
        local initial_comment = genuine_cand.comment
        local final_comment = initial_comment
        index = index + 1

        -- auto_phrase 相关处理,只保存comment
        if enable_auto_phrase then 
            AP.save_comment_cache(cand)
        end

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
            -- 拆分 preedit
            local input_parts = {}
            local current_segment = ""
            for i = 1, #preedit do
                local char = preedit:sub(i, i)
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
                    table.insert(pinyin_segments, pinyin)
                end
            end

            -- 替换逻辑
            local pinyin_index = 1
            for i, part in ipairs(input_parts) do
                if part == auto_delimiter or part == manual_delimiter then
                    input_parts[i] = visual_delim
                else
                    local body, tone = part:match("([%a]+)([^%a]+)") --后面加号很必要
                    local py = pinyin_segments[pinyin_index]

                    if py then
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
        -- 进入注释处理阶段
        -- ① 辅助码注释或者声调注释
        if is_comment_hint then
            local fz_comment = get_fz_comment(cand, env, initial_comment)
            if fz_comment then
                final_comment = fz_comment
            end
        elseif is_tone_comment then
            local fz_comment = get_fz_comment(cand, env, initial_comment)
            if fz_comment then
                final_comment = fz_comment
            end
        else
            final_comment = ""
        end

        -- ② 拆分注释
        if is_chaifen_enabled then
            local cf_comment = CF.get_comment(cand, env)
            if cf_comment and cf_comment ~= "" then  --不为空很重要
                final_comment = cf_comment
            end
        end

        -- ③ 错音错字提示
        if env.settings.corrector_enabled then
            local cr_comment = CR.get_comment(cand)
            if cr_comment and cr_comment ~= "" then
                final_comment = cr_comment
            end
        end

        -- ④ 反查模式提示
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