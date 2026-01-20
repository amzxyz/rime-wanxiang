--@amzxyz https://github.com/amzxyz/rime_wanxiang
--wanxiang_lookup: #设置归属于super_lookup.lua
  --tags: [ abc ]  # 检索当前tag的候选
  --key: "`"       # 输入中反查引导符
  --lookup: [ wanxiang_reverse ] #反查滤镜数据库
  --data_source: [ aux, db ] # 优先级：写在前面优先。即使只写db，只要开启enable_tone也能从注释获取声调。
  --enable_tone: true  #启用声调反查

-- 工具函数：转义正则特殊字符
local function alt_lua_punc(s)
    return s and s:gsub('([%.%+%-%*%?%[%]%^%$%(%)%%])', '%%%1') or ''
end
-- 声调映射表
local tones_map = {
    ["ā"]="7", ["á"]="8", ["ǎ"]="9", ["à"]="0",
    ["ō"]="7", ["ó"]="8", ["ǒ"]="9", ["ò"]="0",
    ["ē"]="7", ["é"]="8", ["ě"]="9", ["è"]="0",
    ["ī"]="7", ["í"]="8", ["ǐ"]="9", ["ì"]="0",
    ["ū"]="7", ["ú"]="8", ["ǔ"]="9", ["ù"]="0",
    ["ǖ"]="7", ["ǘ"]="8", ["ǚ"]="9", ["ǜ"]="0"
}
-- 高性能 UTF8 长度获取
local function get_utf8_len(s)
    if utf8 and utf8.len then return utf8.len(s) end
    local _, count = string.gsub(s, "[^\128-\193]", "")
    return count
end
-- 提取声调数字 (无声调/轻声 -> 默认归为 0)
local function get_tone_from_pinyin(pinyin)
    if not pinyin or #pinyin == 0 then return nil end
    for char, tone in pairs(tones_map) do
        if string.find(pinyin, char, 1, true) then
            return tone
        end
    end
    return "0"
end

-- 规则加载
local function parse_and_separate_rules(schema_id)
    if not schema_id or #schema_id == 0 then return nil, nil end
    local schema = Schema(schema_id)
    if not schema then return nil, nil end
    local config = schema.config
    if not config then return nil, nil end
    local algebra_list = config:get_list('speller/algebra')
    if not algebra_list or algebra_list.size == 0 then return nil, nil end
    
    local main_rules, xlit_rules = {}, {}
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
    if #main_rules == 0 and #xlit_rules == 0 then return nil, nil end
    return main_rules, xlit_rules
end

local function get_schema_rules(env)
    local config = env.engine.schema.config
    local db_list = config:get_list("wanxiang_lookup/lookup")
    if not db_list or db_list.size == 0 then return {}, {} end
    local schema_id = db_list:get_value_at(0).value
    if not schema_id or #schema_id == 0 then return {}, {} end
    local main_rules, xlit_rules = parse_and_separate_rules(schema_id)
    if not main_rules and not xlit_rules then return {}, {} end
    return main_rules or {}, xlit_rules or {}
end

local function expand_code_variant(main_projection, xlit_projection, part)
    local out, seen = {}, {}
    local function add(s) 
        if s and #s > 0 and not seen[s] then 
            seen[s] = true 
            table.insert(out, s) 
        end 
    end
    local function extract_odd_positions(s)
        if not s or not s:match("^%l+$") or #s % 2 ~= 0 then return nil end
        local res = ""
        for i = 1, #s, 2 do res = res .. s:sub(i, i) end
        return res
    end
    local function get_v_variant(s)
        if not s or not s:match("^%l+$") or #s % 2 ~= 0 then return nil end
        local res = ""
        local has_change = false
        for i = 1, #s, 2 do
            local char_odd = s:sub(i, i)
            local char_even = s:sub(i+1, i+1)
            if (char_odd == 'j' or char_odd == 'q' or char_odd == 'x' or char_odd == 'y') and char_even == 'v' then
                res = res .. char_odd .. 'u'
                has_change = true
            else
                res = res .. char_odd .. char_even
            end
        end
        return has_change and res or nil
    end

    local _, quote_count = part:gsub("'", "")
    if quote_count == 1 then
        local s1, s2 = part:match("^([^']*)'([^']*)$")
        if s1 and s2 and #s1 > 0 and #s2 > 0 then
            add(s1:sub(1,1) .. s2:sub(1,1))
        end
    end
    if part:match("^%l+$") then add(part) end
    local raw_extracted = extract_odd_positions(part)
    if raw_extracted then add(raw_extracted) end

    if main_projection and not part:match('^%u+$') then
        local p = main_projection:apply(part, true)
        if p and #p > 0 then
            add(p) 
            local v_variant = get_v_variant(p)
            if v_variant then add(v_variant) end
            local proj_extracted = extract_odd_positions(p)
            if proj_extracted then add(proj_extracted) end
        end
    end
    if part:match('^%u+$') and xlit_projection then
        local xlit_result = xlit_projection:apply(part, true)
        if xlit_result and #xlit_result > 0 then add(xlit_result) end
    end
    return out
end

local function build_reverse_group(main_projection, xlit_projection, db_table, text)
    local group, seen = {}, {}
    for _, db in ipairs(db_table) do
        local code = db:lookup(text)
        if code and #code > 0 then
            for part in code:gmatch('%S+') do
                local variants = expand_code_variant(main_projection, xlit_projection, part)
                for _, v in ipairs(variants) do 
                    if not seen[v] then 
                        seen[v] = true 
                        group[#group + 1] = v 
                    end 
                end
            end
        end
    end
    return group
end

local function group_match(group, fuma)
    if not group then return false end
    for i = 1, #group do 
        if string.sub(group[i], 1, #fuma) == fuma then return true end 
    end
    return false
end

local function match_fuzzy_recursive(codes_sequence, idx, input_str, input_idx, memo, is_phrase_mode)
    if input_idx > #input_str then return true end
    if idx > #codes_sequence then return false end
    
    local state_key = idx * 1000 + input_idx
    if memo[state_key] ~= nil then return memo[state_key] end

    local codes = codes_sequence[idx]
    local result = false
    
    if codes then
        for _, code in ipairs(codes) do
            local skip = false
            if is_phrase_mode and #code > 3 then skip = true end

            if code:match("^%d+$") then skip = true end
            if not skip then
                local i_curr = input_idx
                local c_curr = 1
                local i_limit = #input_str
                local c_limit = #code
                while i_curr <= i_limit and c_curr <= c_limit do
                    if input_str:byte(i_curr) == code:byte(c_curr) then i_curr = i_curr + 1 end
                    c_curr = c_curr + 1
                end
                if match_fuzzy_recursive(codes_sequence, idx + 1, input_str, i_curr, memo, is_phrase_mode) then
                    result = true
                    break
                end
            end
        end
    else
        if match_fuzzy_recursive(codes_sequence, idx + 1, input_str, input_idx, memo, is_phrase_mode) then result = true end
    end
    memo[state_key] = result
    return result
end

local function list_contains(list, target)
    if not list then return false end
    for _, v in ipairs(list) do
        if v == target then return true end
    end
    return false
end

local function parse_comment_codes(comment, pattern, target_len, enable_tone)
    if not comment or comment == "" then return nil end
    local parts = {}
    
    if target_len == 1 then
        parts = { comment }
    else
        for seg in comment:gmatch(pattern) do table.insert(parts, seg) end
        if #parts ~= target_len then return nil end
    end
    
    local result = {}
    for i, part in ipairs(parts) do
        local p1, p2 = part:find(";")
        local pinyin_part
        local codes_part
        
        if p1 then
            pinyin_part = part:sub(1, p1 - 1)
            codes_part = part:sub(p2 + 1)
        else
            pinyin_part = part
            codes_part = ""
        end
        
        local codes_list = {}
        -- 1. 提取辅码
        if #codes_part > 0 then
            for c in codes_part:gmatch("[^,]+") do 
                local trimmed = c:gsub("^%s+", ""):gsub("%s+$", "")
                if #trimmed > 0 then table.insert(codes_list, trimmed) end
            end
        end
        -- 2. 提取声调 (如果开启)
        if enable_tone then
            local tone = get_tone_from_pinyin(pinyin_part)
            if tone then
                table.insert(codes_list, tone)
            end
        end
        result[i] = codes_list
    end
    return result
end

local f = {}

function f.init(env)
    local config = env.engine.schema.config
    
    -- 1. 开启声调
    env.enable_tone = config:get_bool('wanxiang_lookup/enable_tone')
    if env.enable_tone == nil then env.enable_tone = true end

    -- 2. 读取数据源
    local sources_list = config:get_list('wanxiang_lookup/data_source')
    env.data_sources = {}
    
    local config_has_aux_source = false
    env.has_db = false
    
    if sources_list and sources_list.size > 0 then
        for i = 0, sources_list.size - 1 do
            local s = sources_list:get_value_at(i).value
            table.insert(env.data_sources, s)
            if s == 'aux' then config_has_aux_source = true end
            if s == 'db' then env.has_db = true end
        end
    else
        env.data_sources = { 'aux', 'db' }
        config_has_aux_source = true
        env.has_db = true
    end

    -- 核心逻辑：只要配置了 aux 源，或者开启了 enable_tone (需要借声调)，就必须解析注释
    env.has_comment = config_has_aux_source or env.enable_tone

    env.db_table = nil
    if env.has_db then
        local db_list = config:get_list("wanxiang_lookup/lookup")
        if db_list and db_list.size > 0 then
            env.db_table = {}
            for i = 0, db_list.size - 1 do
                table.insert(env.db_table, ReverseLookup(db_list:get_value_at(i).value))
            end
            local main_rules, xlit_rules = get_schema_rules(env)
            env.main_projection = (type(main_rules) == 'table' and #main_rules > 0) and Projection() or nil
            if env.main_projection then env.main_projection:load(main_rules) end
            env.xlit_projection = (type(xlit_rules) == 'table' and #xlit_rules > 0) and Projection() or nil
            if env.xlit_projection then env.xlit_projection:load(xlit_rules) end
        else
            env.has_db = false
        end
    end

    if env.has_comment then
        local delimiter = config:get_string('speller/delimiter') or " '"
        if delimiter == "" then delimiter = " " end
        env.comment_split_ptrn = "[^" .. alt_lua_punc(delimiter) .. "]+"
    end

    env.search_key_str = config:get_string('wanxiang_lookup/key') or '`'
    env.search_key_alt = alt_lua_punc(env.search_key_str)

    local tag = config:get_list('wanxiang_lookup/tags')
    if tag and tag.size > 0 then
        env.tag = {}
        for i = 0, tag.size - 1 do
            table.insert(env.tag, tag:get_value_at(i).value)
        end
    else
        env.tag = { 'abc' }
    end

    env.notifier = env.engine.context.select_notifier:connect(function(ctx)
        local input = ctx.input
        local code = input:match('^(.-)' .. env.search_key_alt)
        if (not code or #code == 0) then return end
        local preedit = ctx:get_preedit()
        local no_search_string = input:match('^(.-)' .. env.search_key_alt)
        local edit = preedit.text:match('^(.-)' .. env.search_key_alt)
        if edit and edit:match('[%w/]') then
            ctx.input = no_search_string .. env.search_key_str
        else
            ctx.input = no_search_string
            env.commit_code = no_search_string
            ctx:commit()
        end
    end)

    env._global_db_cache = {}
    env._global_comment_cache = {}
    env.cache_size = 0 
end

function f.func(input, env)
    local context = env.engine.context
    local seg = context.composition:back()

    if not seg or not f.tags_match(seg, env) then
        for cand in input:iter() do yield(cand) end
        return
    end
    if #env.data_sources == 0 then
        for cand in input:iter() do yield(cand) end
        return
    end

    local ctx_input = env.engine.context.input
    local s_start, s_end = ctx_input:find(env.search_key_alt, 1, false)
    if not s_start then for cand in input:iter() do yield(cand) end return end
    local fuma = ctx_input:sub(s_end + 1)
    if #fuma == 0 then for cand in input:iter() do yield(cand) end return end

    local tone_filter_seq = {}
    local clean_fuma = ""
    for i = 1, #fuma do
        local char = fuma:sub(i, i)
        if char == "7" or char == "8" or char == "9" or char == "0" then
            table.insert(tone_filter_seq, char)
        else
            clean_fuma = clean_fuma .. char
        end
    end
    local apply_tone_filter = env.enable_tone and (#tone_filter_seq > 0)

    local if_single_char_first = env.engine.context:get_option('char_priority')
    local buckets = {}
    for i = 1, #env.data_sources do buckets[i] = {} end
    local long_word_cands = {}
    local max_len = 0
    local has_any_match = false 

    if env.cache_size > 2000 then
        env._global_db_cache = {}
        env._global_comment_cache = {}
        env.cache_size = 0
    end
    local db_cache = env._global_db_cache
    local comment_cache = env._global_comment_cache

    for cand in input:iter() do
        if cand.type == 'sentence' then goto skip end
        local cand_text = cand.text
        local cand_len = get_utf8_len(cand_text)
        if not cand_len or cand_len == 0 then goto skip end
        local b = string.byte(cand_text, 1)
        if b and b < 128 then goto skip end

        local raw_data = {}
        
        -- 数据加载 A: Aux Data (From Comment)
        if env.has_comment then
            local genuine = cand:get_genuine()
            local comment_text = genuine and genuine.comment or ""
            if comment_text ~= "" then
                local cache_key = cand_text .. "_" .. comment_text
                if not comment_cache[cache_key] then
                    comment_cache[cache_key] = parse_comment_codes(comment_text, env.comment_split_ptrn, cand_len, env.enable_tone) or false
                    env.cache_size = env.cache_size + 1
                end
                if comment_cache[cache_key] then
                    raw_data.aux = comment_cache[cache_key]
                    -- 同时赋给 _comment_internal，用于 data_source: [db] 借用声调
                    raw_data._comment_internal = comment_cache[cache_key]
                end
            end
        end

        -- 数据加载 B: DB Data
        if env.has_db then
            raw_data.db = {}
            local i = 0
            for _, code_point in utf8.codes(cand_text) do
                i = i + 1
                local char_str = utf8.char(code_point)
                if not db_cache[char_str] then
                    db_cache[char_str] = build_reverse_group(env.main_projection, env.xlit_projection, env.db_table, char_str)
                    env.cache_size = env.cache_size + 1 
                end
                raw_data.db[i] = db_cache[char_str] or {}
            end
        end

        -- 提取借用声调 (即使 config 里只写了 db，这里也要尝试从注释里借声调)
        local borrowed_tones = {} 
        if raw_data._comment_internal then
            for k, codes in ipairs(raw_data._comment_internal) do
                borrowed_tones[k] = {}
                for _, c in ipairs(codes) do
                    -- parse_comment_codes 会把声调数字也放入 list，这里提取出来备用
                    if c:match("^%d+$") then borrowed_tones[k][c] = true end
                end
            end
        end

        local matched_idx = nil

        for i, source_type in ipairs(env.data_sources) do
            local codes_seq = raw_data[source_type]
            if codes_seq then
                local tone_match_pass = true
                if apply_tone_filter then
                    for k, tone_input in ipairs(tone_filter_seq) do
                        if k > #codes_seq then break end
                        local has_tone = list_contains(codes_seq[k], tone_input)
                        -- 如果是 db 源且自身没匹配到声调，尝试查阅 borrowed_tones (从注释借来的)
                        if not has_tone and source_type == 'db' then
                            if borrowed_tones[k] and borrowed_tones[k][tone_input] then has_tone = true end
                        end
                        if not has_tone then
                            tone_match_pass = false
                            break
                        end
                    end
                end

                if tone_match_pass then
                    local is_match = false
                    if source_type == 'aux' then
                        if cand_len == 1 then
                            if group_match(codes_seq[1], clean_fuma) then is_match = true end
                        else
                            local memo = {}
                            if match_fuzzy_recursive(codes_seq, 1, clean_fuma, 1, memo, false) then is_match = true end
                        end
                    elseif source_type == 'db' then
                        if cand_len == 1 then
                             if group_match(codes_seq[1], clean_fuma) then is_match = true end
                        else
                             local memo = {}
                             if match_fuzzy_recursive(codes_seq, 1, clean_fuma, 1, memo, true) then is_match = true end
                        end
                    end
                    
                    if is_match then
                        matched_idx = i
                        break 
                    end
                end
            end
        end

        if matched_idx then
            has_any_match = true
            if if_single_char_first and cand_len > 1 then
                table.insert(long_word_cands, cand)
            else
                if not buckets[matched_idx][cand_len] then buckets[matched_idx][cand_len] = {} end
                table.insert(buckets[matched_idx][cand_len], cand)
                if cand_len > max_len then max_len = cand_len end
            end
        end
        ::skip::
    end

    if if_single_char_first then
        for i = 1, #env.data_sources do
            if buckets[i][1] then for _, c in ipairs(buckets[i][1]) do yield(c) end end
        end
        for l = max_len, 2, -1 do
            for i = 1, #env.data_sources do
                if buckets[i][l] then for _, c in ipairs(buckets[i][l]) do yield(c) end end
            end
        end
    else
        for l = max_len, 1, -1 do
            for i = 1, #env.data_sources do
                if buckets[i][l] then for _, c in ipairs(buckets[i][l]) do yield(c) end end
            end
        end
    end
    
    for _, c in ipairs(long_word_cands) do yield(c) end

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

function f.tags_match(seg, env)
    for _, v in ipairs(env.tag) do if seg.tags[v] then return true end end
    return false
end

function f.fini(env)
    if env.notifier then env.notifier:disconnect() end
    env.db_table = nil
    env._global_db_cache = nil
    env._global_comment_cache = nil
    collectgarbage('collect')
end

return f