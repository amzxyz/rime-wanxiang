--@amzxyz https://github.com/amzxyz/rime_wanxiang
--wanxiang_lookup: #设置归属于super_lookup.lua
  --tags: [ abc ]  # 检索当前tag的候选
  --key: "`"       # 输入中反查引导符
  --lookup: [ wanxiang_reverse ] #反查滤镜数据库
  --data_source: [ comment, db ] # 优先级：写在前面优先

-- 工具函数：转义正则特殊字符
local function alt_lua_punc(s)
    return s and s:gsub('([%.%+%-%*%?%[%]%^%$%(%)%%])', '%%%1') or ''
end

-- 高性能 UTF8 长度获取
local function get_utf8_len(s)
    -- 优先使用 Rime 内置的 utf8 库
    if utf8 and utf8.len then return utf8.len(s) end
    local _, count = string.gsub(s, "[^\128-\193]", "")
    return count
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

-- 【DB】构建编码
local function expand_code_variant(main_projection, xlit_projection, part)
    local out, seen = {}, {}
    local function add(s) if s and #s > 0 and not seen[s] then seen[s] = true out[#out + 1] = s end end

    -- 1. 定义“种子”列表，首先放入原始编码 part
    local seeds = { part }

    -- 2. 提取只有一个单引号编码，若成功则将其作为第二个“种子”加入列表
    --    例如：part="ce'shi"，提取出 "cs" 加入 seeds
    local _, quote_count = part:gsub("'", "")
    if quote_count == 1 then
        local s1, s2 = part:match("^([^']*)'([^']*)$")
        if s1 and s2 and #s1 > 0 and #s2 > 0 then
            local derived_code = s1:sub(1,1) .. s2:sub(1,1)
            table.insert(seeds, derived_code)
        end
    end
    -- 3. 遍历所有种子（原始编码 + 缩写编码），统一进行规则投影
    for _, code in ipairs(seeds) do
        -- 应用 main_projection (非大写)
        if main_projection then
            local p = main_projection:apply(code, true)
            if p and #p > 0 then add(p) end
        end
        -- 应用 xlit_projection (大写笔画，不参与前面重复计算)
        if code:match('^%u+$') and xlit_projection then
            local xlit_result = xlit_projection:apply(code, true)
            if xlit_result and #xlit_result > 0 then add(xlit_result) end
        end
    end
    return out
end
-- 【DB】查表
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

-- 单字匹配 (Strict Prefix)
local function group_match(group, fuma)
    if not group then return false end
    for i = 1, #group do 
        if string.sub(group[i], 1, #fuma) == fuma then return true end 
    end
    return false
end

-- 递归匹配引擎 (优化：整数 Key)
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
            -- 词组模式下，过滤掉 >3 的全码
            if is_phrase_mode and #code > 3 then skip = true end

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

-- 注释解析 (严格校验 + Trim)
local function parse_comment_codes(comment, pattern, target_len)
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
        if not p1 then return nil end
        
        local codes_part = part:sub(p2 + 1)
        local codes_list = {}
        for c in codes_part:gmatch("[^,]+") do 
            -- Trim
            local trimmed = c:gsub("^%s+", ""):gsub("%s+$", "")
            if #trimmed > 0 then table.insert(codes_list, trimmed) end
        end
        result[i] = codes_list
    end
    return result
end

local f = {}

function f.init(env)
    local config = env.engine.schema.config
    
    local sources_list = config:get_list('wanxiang_lookup/data_source')
    env.data_sources = {}
    env.has_comment = false
    env.has_db = false
    
    if sources_list and sources_list.size > 0 then
        for i = 0, sources_list.size - 1 do
            local s = sources_list:get_value_at(i).value
            table.insert(env.data_sources, s)
            if s == 'comment' then env.has_comment = true end
            if s == 'db' then env.has_db = true end
        end
    else
        env.data_sources = { 'comment', 'db' }
        env.has_comment = true
        env.has_db = true
    end

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
        -- 确保 " '" 中的所有字符都被加入排除列表 [^% %']+
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
    if #env.data_sources == 0 then
        for cand in input:iter() do yield(cand) end
        return
    end

    local ctx_input = env.engine.context.input
    local s_start, s_end = ctx_input:find(env.search_key_alt, 1, false)
    if not s_start then for cand in input:iter() do yield(cand) end return end
    local fuma = ctx_input:sub(s_end + 1)
    if #fuma == 0 then for cand in input:iter() do yield(cand) end return end

    local if_single_char_first = env.engine.context:get_option('char_priority')
    
    local buckets = {}
    local max_len = 0
    for i = 1, #env.data_sources do buckets[i] = {} end
    
    local long_word_cands = {}

    -- GC
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
        
        -- 1. Comment Data
        if env.has_comment then
            local genuine = cand:get_genuine()
            local comment_text = genuine and genuine.comment or ""
            if comment_text ~= "" then
                local cache_key = cand_text .. "_" .. comment_text
                if not comment_cache[cache_key] then
                    comment_cache[cache_key] = parse_comment_codes(comment_text, env.comment_split_ptrn, cand_len) or false
                    env.cache_size = env.cache_size + 1
                end
                if comment_cache[cache_key] then
                    raw_data.comment = comment_cache[cache_key]
                end
            end
        end

        -- 2. DB Data
        if env.has_db then
            raw_data.db = {}
            local pos = 1
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

        -- 3. Match
        local matched_idx = nil
        for i, source_type in ipairs(env.data_sources) do
            local codes_seq = raw_data[source_type]
            if codes_seq then
                local is_match = false
                if source_type == 'comment' then
                    if cand_len == 1 then
                        if group_match(codes_seq[1], fuma) then is_match = true end
                    else
                        local memo = {}
                        if match_fuzzy_recursive(codes_seq, 1, fuma, 1, memo, false) then is_match = true end
                    end
                elseif source_type == 'db' then
                    if cand_len == 1 then
                         if group_match(codes_seq[1], fuma) then is_match = true end
                    else
                         local memo = {}
                         if match_fuzzy_recursive(codes_seq, 1, fuma, 1, memo, true) then is_match = true end
                    end
                end
                
                if is_match then
                    matched_idx = i
                    break 
                end
            end
        end

        if matched_idx then
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

    -- 输出 (Global Length Priority)
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