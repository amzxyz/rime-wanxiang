-- super_replacer.lua 一个rime 更灵活地滤镜转换器
-- https://github.com/amzxyz/rime-wanxiang
-- @amzxyz

local M = {}

-- 性能优化：本地化常用库函数
local insert = table.insert
local concat = table.concat
local s_match = string.match
local s_format = string.format
local s_byte = string.byte
local s_sub = string.sub
local s_gsub = string.gsub
local s_find = string.find
local s_lower = string.lower
local s_upper = string.upper
local t_sort = table.sort
local type = type
local tonumber = tonumber
local DB_FORMAT_VERSION = "4"
local MERGED_SCHEMA_IDS = {"wanxiang_pro", "wanxiang", "wanxiang_english", "wanxiang_t9", "wanxiang_t9i"}
-- 模块私有数据库池：同名数据库共享包装器和生命周期。
local DB_POOL = {}
local file_signature_cache = {}
local RECORD_SEPARATOR = " \t"
local VALUE_SEPARATOR = "\\t"
local VALUE_SEPARATOR_LEN = #VALUE_SEPARATOR
local RECORD_TAIL = "c=0 d=0 t=0"
local CANDIDATE_LIMIT = 100
local EXACT_CACHE_PREFIX = "\1"
local FMM_CACHE_PREFIX = "\2"

local T9_MAP = {}
do
    local letters = "abcdefghijklmnopqrstuvwxyz"
    local digits = "22233344455566677778889999"
    for i = 1, #letters do T9_MAP[s_sub(letters, i, i)] = s_sub(digits, i, i) end
end

-- 基础依赖
local userdb = require("wanxiang/userdb")
local wanxiang = require("wanxiang/wanxiang")

local function clear_array(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function clear_table(t)
    for key in pairs(t) do t[key] = nil end
end

-- UTF-8 辅助：复用 offsets 缓冲，避免每次 FMM 都创建新表
local function get_utf8_offsets(text, offsets)
    clear_array(offsets)
    local len = #text
    local i, n = 1, 0
    while i <= len do
        n = n + 1
        offsets[n] = i
        local b = s_byte(text, i)
        if b < 128 then i = i + 1
        elseif b < 224 then i = i + 2
        elseif b < 240 then i = i + 3
        else i = i + 4 end
    end
    offsets[n + 1] = len + 1
    return n
end

-- 计算字节串摘要，表头只保存稳定的 ASCII 特征。
local function hash_bytes(hash, value)
    for i = 1, #value do
        hash = (hash * 131 + s_byte(value, i)) % 4294967296
    end
    return hash
end

local function digest_parts(parts)
    local hash = 2166136261
    local bytes = 0

    for i = 1, #parts do
        local part = parts[i] or ""
        bytes = bytes + #part
        hash = hash_bytes(hash, tostring(#part))
        hash = hash_bytes(hash, ":")
        hash = hash_bytes(hash, part)
        hash = hash_bytes(hash, "|")
    end

    return s_format("%08x:%d:%d", hash, #parts, bytes)
end

-- 保留原来的头、中、尾 64 字节采样方式，仅把结果压成 ASCII 摘要。
local function get_file_signature(path)
    local cached = file_signature_cache[path]
    if cached then return cached end

    local file, close = wanxiang.load_file_with_fallback(path, "rb")
    if not file then
        file_signature_cache[path] = "missing"
        return "missing"
    end

    local size = file:seek("end") or 0
    local parts = {tostring(size)}

    if size > 0 then
        file:seek("set", 0)
        parts[#parts + 1] = file:read(64) or ""

        local tail_pos = size - 64
        if tail_pos < 0 then tail_pos = 0 end
        file:seek("set", tail_pos)
        parts[#parts + 1] = file:read(64) or ""

        file:seek("set", math.floor(size / 2))
        parts[#parts + 1] = file:read(64) or ""
    end

    close()
    cached = digest_parts(parts)
    file_signature_cache[path] = cached
    return cached
end

local function generate_files_signature(tasks)
    local parts = {}
    local seen = {}

    for _, task in ipairs(tasks) do
        if not seen[task.path] then
            seen[task.path] = true
            parts[#parts + 1] = (task.source or task.path) .. "|" .. get_file_signature(task.path)
        end
    end

    return digest_parts(parts)
end

local function each_file_value(rule, callback)
    local function each_item(item)
        if not item then return end

        if item.type == "kList" then
            local list = item:get_list()
            for i = 0, list.size - 1 do
                local value = list:get_value_at(i)
                if value then callback(value) end
            end
        elseif item.type == "kScalar" then
            local value = item:get_value()
            if value then callback(value) end
        end
    end

    each_item(rule:get("files"))
    each_item(rule:get("file"))
end

-- 只提取影响数据库内容的字段，运行时规则仍由当前方案原逻辑解析。
local function collect_build_tasks(config, ns)
    local tasks = {}
    local root = config and config:get_map(ns)
    local rules = root and root:get("rules")
    local list = rules and rules:get_list()
    if not list then return tasks end

    for i = 0, list.size - 1 do
        local item = list:get_at(i)
        local rule = item and item:get_map()
        if rule then
            local value = rule:get_value("prefix")
            local prefix = value and value:get_string() or ""
            value = rule:get_value("t9_optimization")
            local t9 = value and value:get_bool() or false

            each_file_value(rule, function(file_value)
                local source = file_value:get_string()
                if source and source ~= "" then
                    tasks[#tasks + 1] = {
                        source = source,
                        path = source,
                        prefix = prefix,
                        conversion = t9 and T9_MAP or nil,
                        preedit_delim = t9 and "==" or nil
                    }
                end
            end)
        end
    end

    return tasks
end

local function task_signature(task)
    return (task.source or "")
        .. "|" .. (task.prefix or "")
        .. "|" .. (task.conversion and "t9" or "plain")
        .. "|" .. (task.preedit_delim or "")
end

local function tasks_signature(tasks)
    local parts = {}
    for i, task in ipairs(tasks) do
        parts[i] = task_signature(task)
    end
    return digest_parts(parts)
end

-- 为兼容旧版 librime-lua，不使用 Config 接口，直接读取部署后的 build/default.yaml。
local function enabled_schema_ids()
    local enabled = {}
    local file, close = wanxiang.load_file_with_fallback("build/default.yaml", "r")

    for line in file:lines() do
        local id = s_match(line, "^%s*%-%s*schema:%s*[\"']?([%w_%-]+)")
        if id then enabled[id] = true end
    end
    close()

    local ids = {}
    for _, id in ipairs(MERGED_SCHEMA_IDS) do
        if enabled[id] then ids[#ids + 1] = id end
    end
    return ids
end

-- 合并 default.yaml 中已启用方案的数据任务，并生成固定的方案级表头特征。
local function merge_build_tasks(ns)
    local groups = {}
    local signatures = {}
    local schema_ids = enabled_schema_ids()

    for order, id in ipairs(schema_ids) do
        local schema = Schema(id)
        local tasks = collect_build_tasks(schema.config, ns)
        groups[#groups + 1] = {id = id, order = order, tasks = tasks}
        signatures[id] = tasks_signature(tasks)
    end

    t_sort(groups, function(a, b)
        if #a.tasks ~= #b.tasks then return #a.tasks > #b.tasks end
        return a.order < b.order
    end)

    local merged = {}
    local seen = {}
    for _, group in ipairs(groups) do
        for _, task in ipairs(group.tasks) do
            local key = task_signature(task)
            if not seen[key] then
                seen[key] = true
                merged[#merged + 1] = task
            end
        end
    end

    return merged, signatures, digest_parts(schema_ids)
end

local function next_value(value, start)
    local pos = s_find(value, VALUE_SEPARATOR, start, true)
    if pos then
        return s_sub(value, start, pos - 1), pos + VALUE_SEPARATOR_LEN
    end
    if start == 1 then return value, nil end
    return s_sub(value, start), nil
end

local function first_value(value)
    if not value then return nil end
    local pos = s_find(value, VALUE_SEPARATOR, 1, true)
    return pos and s_sub(value, 1, pos - 1) or value
end

local function parse_source_line(line)
    local key, value = s_match(line, "^([^\t]+)\t+(.+)$")
    if not key or not value or key == "" or value == "" then return nil, nil end
    if s_find(value, "\t", 1, true) then return nil, nil end
    return key, value
end

local function fetch_aggregate(db, key)
    local prefix = key .. RECORD_SEPARATOR
    local accessor = db:query(prefix)
    if not accessor then return nil, nil end

    local value = nil
    local raw_key = nil

    for current_key, _ in accessor:iter() do
        if s_find(current_key, prefix, 1, true) ~= 1 then break end

        raw_key = current_key
        value = s_sub(current_key, #prefix + 1)
        break
    end

    accessor = nil
    return value, raw_key
end

local function fetch_exact_cached(db, key, query_cache)
    local cache_key = EXACT_CACHE_PREFIX .. key
    local value = query_cache[cache_key]
    if value ~= nil then return value or nil end

    value = fetch_aggregate(db, key)
    query_cache[cache_key] = value or false
    return value
end

local function update_aggregate(db, key, value)
    if not key or key == "" or not value or value == "" then return false end
    return db:update(key .. RECORD_SEPARATOR .. value, RECORD_TAIL)
end

local function append_preedit(value, delimiter, original_key)
    if not delimiter or delimiter == "" then return value end

    local parts = {}
    local count = 0
    local start = 1

    while start do
        local item
        item, start = next_value(value, start)
        if item ~= "" then
            count = count + 1
            if not s_find(item, delimiter, 1, true) then
                item = item .. delimiter .. original_key
            end
            parts[count] = item
        end
    end

    return concat(parts, VALUE_SEPARATOR, 1, count)
end

local function erase_raw_record(db, raw_key)
    local raw_db = type(db) == "table" and rawget(db, "_db") or db
    return raw_db and raw_db.erase and raw_db:erase(raw_key) or false
end

-- 重建数据库：
-- 1. 普通任务按最终数据库 key 逐行写入，避免把全部词库堆在 Lua 内存中；
-- 2. 重复判定始终包含 prefix，不同模块前缀互不比较；
-- 3. 转换任务仅按“同一 prefix + 原始 key”判重，并按最终 key 聚合碰撞候选；
-- 4. 普通任务与转换任务无论加载先后，最终 key 冲突时都合并候选，不丢数据。
local function rebuild(tasks, db)
    local written_db_keys = {}
    local seen_converted_keys = nil
    local converted_groups = nil
    local converted_order = nil

    for _, task in ipairs(tasks) do
        local prefix = task.prefix or ""
        local conversion = task.conversion
        local seen_source_keys = nil

        if conversion then
            seen_converted_keys = seen_converted_keys or {}
            converted_groups = converted_groups or {}
            converted_order = converted_order or {}
            seen_source_keys = seen_converted_keys[prefix]

            if not seen_source_keys then
                seen_source_keys = {}
                seen_converted_keys[prefix] = seen_source_keys
            end
        end

        local file, close = wanxiang.load_file_with_fallback(task.path, "r")

        if file then
            for line in file:lines() do
                if line ~= "" and not s_match(line, "^%s*#") then
                    local key, value = parse_source_line(line)

                    if key and value then
                        value = s_match(value, "^%s*(.-)%s*$")

                        if conversion then
                            local original_key = key

                            if not seen_source_keys[original_key] then
                                seen_source_keys[original_key] = true
                                key = s_gsub(key, ".", conversion)
                                value = append_preedit(
                                    value,
                                    task.preedit_delim,
                                    original_key
                                )

                                local db_key = prefix .. key
                                local group = converted_groups[db_key]

                                if not group then
                                    group = {}
                                    converted_groups[db_key] = group
                                    converted_order[#converted_order + 1] = db_key
                                end

                                group[#group + 1] = value
                            end
                        else
                            local db_key = prefix .. key

                            -- db_key 已包含 prefix；只有同模块同 key 才视为重复。
                            if not written_db_keys[db_key] then
                                if not update_aggregate(db, db_key, value) then
                                    close()
                                    return false
                                end
                                written_db_keys[db_key] = true
                            end
                        end
                    end
                end
            end

            close()
        end
    end

    if converted_order then
        for _, db_key in ipairs(converted_order) do
            local value = concat(converted_groups[db_key], VALUE_SEPARATOR)

            -- 普通任务可能在转换任务之前或之后读取；统一在这里合并。
            if written_db_keys[db_key] then
                local old_value, old_raw_key = fetch_aggregate(db, db_key)
                if not old_value or not old_raw_key then return false end

                value = old_value .. VALUE_SEPARATOR .. value
                if not erase_raw_record(db, old_raw_key) then return false end
            end

            if not update_aggregate(db, db_key, value) then return false end
            written_db_keys[db_key] = true

            -- 写入后立即释放当前碰撞组，降低重建阶段的尾部占用。
            converted_groups[db_key] = nil
        end
    end

    return true
end

-- 检查数据库表头是否与当前联合数据一致。
local function database_matches(
    db, current_version, delimiter,
    files_sig, union_sig, scheme_sigs
)
    if (db:meta_fetch("_wanxiang_ver") or "") ~= current_version
        or (db:meta_fetch("_delim") or "") ~= delimiter
        or (db:meta_fetch("_files_sig") or "") ~= files_sig
        or (db:meta_fetch("_format_ver") or "") ~= DB_FORMAT_VERSION
        or (db:meta_fetch("_replacer_files") or "") ~= files_sig
        or (db:meta_fetch("_replacer_union") or "") ~= union_sig
    then
        return false
    end

    for schema_id, signature in pairs(scheme_sigs) do
        if (db:meta_fetch("_replacer_scheme/" .. schema_id) or "") ~= signature then
            return false
        end
    end

    return true
end

-- 写入联合数据库表头。
local function update_metadata(
    db, current_version, delimiter,
    files_sig, union_sig, scheme_sigs
)
    if not db:meta_update("_wanxiang_ver", current_version)
        or not db:meta_update("_delim", delimiter)
        or not db:meta_update("_files_sig", files_sig)
        or not db:meta_update("_format_ver", DB_FORMAT_VERSION)
        or not db:meta_update("_replacer_files", files_sig)
        or not db:meta_update("_replacer_union", union_sig)
    then
        return false
    end

    for schema_id, signature in pairs(scheme_sigs) do
        if not db:meta_update("_replacer_scheme/" .. schema_id, signature) then
            return false
        end
    end

    return true
end

-- 连接或重建联合数据库。
local function connect_db(
    db_name, current_version, delimiter, tasks,
    union_sig, scheme_sigs, env_query_cache
)
    local entry = DB_POOL[db_name]
    if entry then
        if entry.db and entry.db:loaded() then
            entry.refs = entry.refs + 1
            return entry.db, false
        end

        DB_POOL[db_name] = nil
    end

    local db = userdb.LevelDb(db_name)
    if not db then return nil end

    local files_sig = generate_files_signature(tasks)

    if db:open_read_only() then
        if database_matches(
            db, current_version, delimiter,
            files_sig, union_sig, scheme_sigs
        ) then
            DB_POOL[db_name] = {db = db, refs = 1}
            return db, false
        end

        db:close()
    end

    if not db:open() then return nil end

    local cleared
    if db.empty then
        cleared = db:empty(false)
    elseif db.clear then
        cleared = db:clear()
    end

    if cleared == false
        or not rebuild(tasks, db)
        or not update_metadata(
            db, current_version, delimiter,
            files_sig, union_sig, scheme_sigs
        )
    then
        db:close()
        return nil
    end

    clear_table(env_query_cache)

    db:close()

    if not db:open_read_only() then return nil end

    DB_POOL[db_name] = {db = db, refs = 1}
    return db, true
end
-- 释放当前组件引用，并在最后一个使用者退出时关闭数据库。
local function release_db(env)
    local db = env.db
    local db_name = env.db_name

    env.db = nil
    env.db_name = nil

    if not db or not db_name then return end

    local entry = DB_POOL[db_name]
    if not entry or entry.db ~= db then return end

    entry.refs = entry.refs - 1
    if entry.refs > 0 then return end

    DB_POOL[db_name] = nil
    collectgarbage()

    if db:loaded() then db:close() end
    entry.db = nil
end

local function fetch_fmm_bucket(db, prefix, stem, query_cache)
    local cache_key = FMM_CACHE_PREFIX .. prefix .. "\0" .. stem
    local bucket = query_cache[cache_key]
    if bucket then return bucket end

    bucket = {}
    local query_prefix = prefix .. stem
    local query_len = #query_prefix
    local prefix_len = #prefix
    local accessor = db:query(query_prefix)

    if accessor then
        for raw_key, _ in accessor:iter() do
            if s_find(raw_key, query_prefix, 1, true) ~= 1 then break end

            local sep_pos = s_find(raw_key, RECORD_SEPARATOR, query_len + 1, true)
            if sep_pos then
                local source = s_sub(raw_key, prefix_len + 1, sep_pos - 1)
                local source_len = utf8.len(source) or 0
                if source_len > 2 then
                    bucket[#bucket + 1] = {
                        source,
                        s_sub(raw_key, sep_pos + #RECORD_SEPARATOR),
                        source_len
                    }
                end
            end
        end

        accessor = nil
    end

    t_sort(bucket, function(a, b) return a[3] > b[3] end)
    query_cache[cache_key] = bucket
    return bucket
end

local function segment_convert(text, db, prefix, query_cache, offsets, result_parts)
    local char_count = get_utf8_offsets(text, offsets)
    clear_array(result_parts)

    local i, result_count = 1, 0

    while i <= char_count do
        local start_byte = offsets[i]
        local source = s_sub(text, start_byte, offsets[i + 1] - 1)
        local output = nil
        local step = 1

        if i + 1 < char_count then
            local stem = s_sub(text, start_byte, offsets[i + 2] - 1)

            for _, entry in ipairs(fetch_fmm_bucket(db, prefix, stem, query_cache)) do
                if s_find(text, entry[1], start_byte, true) == start_byte then
                    source = entry[1]
                    output = first_value(entry[2]) or source
                    step = entry[3]
                    break
                end
            end
        end

        if not output and i < char_count and (char_count > 2 or i > 1) then
            local pair = s_sub(text, start_byte, offsets[i + 2] - 1)
            local value = fetch_exact_cached(
                db, prefix .. pair, query_cache
            )
            if value then
                source = pair
                output = first_value(value) or source
                step = 2
            end
        end

        if not output then
            local value = fetch_exact_cached(
                db, prefix .. source, query_cache
            )
            output = first_value(value) or source
        end

        result_count = result_count + 1
        result_parts[result_count] = output
        i = i + step
    end

    return concat(result_parts, "", 1, result_count)
end

-- 模块接口
function M.init(env)
    if env.db then release_db(env) end

    env.query_cache = {}
    env.fmm_offsets = {}
    env.fmm_parts = {}
    env.shared_pending = {}
    env.shared_pending_comments = {}
    env.shared_comments = {}
    local ns = env.name_space
    ns = s_gsub(ns, "^%*", "")
    ns = string.match(ns, "([^%.]+)$") or ns
    local config = env.engine.schema.config

    -- 1. 获取根节点 Map 对象
    local cfg_root = config:get_map(ns)

    -- 2. 读取基础配置
    local db_name_val = cfg_root and cfg_root:get_value("db_name")
    local db_name = db_name_val and db_name_val:get_string() or "lua/replacer"

    env.delimiter = "\t"
    
    local delimiter = config:get_string("speller/delimiter") or " '"
    env.speller_delimiter = delimiter:sub(2, 2)

    local comment_fmt_val = cfg_root and cfg_root:get_value("comment_format")
    env.comment_format = comment_fmt_val and comment_fmt_val:get_string() or "〔%s〕"
    
    local current_version = "v0.0.2"
    if wanxiang and wanxiang.version then
        current_version = wanxiang.version
    end
    env.input_type = "unknown"
    if wanxiang and wanxiang.get_input_method_type then
        env.input_type = wanxiang.get_input_method_type(env)
    end
    
    local chain_val = cfg_root and cfg_root:get_value("chain")
    env.chain = chain_val and chain_val:get_bool() or false

    env.rules = {}

    -- 3. 读取并遍历 rules 列表
    local rules_item = cfg_root and cfg_root:get("rules")
    local rule_list = rules_item and rules_item:get_list()
  
    if rule_list then
        for i = 0, rule_list.size - 1 do
            local rule_item = rule_list:get_at(i)
            local rule = rule_item and rule_item:get_map()
            if not rule then goto continue_rule end

            local function check_type_list(key)
                local item = rule:get(key)
                if not item then return nil end
                local list = item.type == "kList" and item:get_list()
                if not list then return nil end
                for k = 0, list.size - 1 do
                    local val = list:get_value_at(k)
                    if val and val:get_string() == env.input_type then return true end
                end
                return false
            end

            local is_only = check_type_list("only_types")
            if is_only == false then goto continue_rule end

            local is_excluded = check_type_list("exclude_types")
            if is_excluded == true then goto continue_rule end

            -- 解析 triggers
            local triggers = {}
            local opts_keys = {"option", "options"}
            for _, key in ipairs(opts_keys) do
                local opt_item = rule:get(key)
                if opt_item then
                    if opt_item.type == "kList" then
                        local list = opt_item:get_list()
                        for k = 0, list.size - 1 do
                            local val = list:get_value_at(k)
                            local str = val and val:get_string()
                            if str then insert(triggers, str) end
                        end
                    elseif opt_item.type == "kScalar" then
                        local val = opt_item:get_value()
                        if val:get_bool() == true then
                            insert(triggers, true)
                        else
                            local str = val:get_string()
                            if str and str ~= "true" then insert(triggers, str) end
                        end
                    end
                end
            end

            if #triggers == 0 then goto continue_rule end

            -- 解析 tags
            local target_tags = nil
            local tag_keys = {"tag", "tags"}
            for _, key in ipairs(tag_keys) do
                local tag_item = rule:get(key)
                if tag_item then
                    if not target_tags then target_tags = {} end
                    if tag_item.type == "kList" then
                        local list = tag_item:get_list()
                        for k = 0, list.size - 1 do
                            local val = list:get_value_at(k)
                            local str = val and val:get_string()
                            if str then target_tags[str] = true end
                        end
                    elseif tag_item.type == "kScalar" then
                        local val = tag_item:get_value()
                        local str = val and val:get_string()
                        if str then target_tags[str] = true end
                    end
                end
            end

            -- 解析各项参数
            local prefix_val = rule:get_value("prefix")
            local prefix = prefix_val and prefix_val:get_string() or ""
            
            local mode_val = rule:get_value("mode")
            local mode = mode_val and mode_val:get_string() or "append"
            
            -- T9 优化逻辑
            local t9_val = rule:get_value("t9_optimization")
            local t9_opt = t9_val and t9_val:get_bool() or false
            local preedit_delim = t9_opt and "==" or nil

            local comment_mode_val = rule:get_value("comment_mode")
            local comment_mode = comment_mode_val and comment_mode_val:get_string() or "comment"
            
            local fmm_val = rule:get_value("sentence")
            local fmm = fmm_val and fmm_val:get_bool() or false
            
            local custom_cand_type_val = rule:get_value("cand_type")
            local custom_cand_type = custom_cand_type_val and custom_cand_type_val:get_string()

            local always_qty = 1
            local always_idx = 1
            if mode == "abbrev" then
                local rule_str_val = rule:get_value("abbrev_rule")
                local rule_str = rule_str_val and rule_str_val:get_string() or "1,1"
                local qty_str, idx_str = s_match(rule_str, "^(%d+)%s*,%s*(%d+)$")
                always_qty = tonumber(qty_str) or 1
                always_idx = tonumber(idx_str) or 1
            end

            insert(env.rules, {
                triggers = triggers,
                tags = target_tags,
                prefix = prefix,
                mode  = mode,
                always_qty = always_qty,
                always_idx = always_idx,
                comment_mode = comment_mode,
                fmm = fmm,
                preedit_delim = preedit_delim,
                cand_type = custom_cand_type
            })

            ::continue_rule::
        end
    end
    
    local merged_tasks, scheme_sigs, union_sig = merge_build_tasks(ns)

    local rebuilt
    env.db, rebuilt = connect_db(
        db_name, current_version, env.delimiter,
        merged_tasks, union_sig, scheme_sigs, env.query_cache
    )
    if env.db then env.db_name = db_name end

    if rebuilt then
        merged_tasks, scheme_sigs, union_sig = nil, nil, nil
        collectgarbage("collect")
    end
end

function M.fini(env)
    env.query_cache = nil
    env.fmm_offsets = nil
    env.fmm_parts = nil
    env.shared_pending = nil
    env.shared_pending_comments = nil
    env.shared_comments = nil
    env.rules = nil

    release_db(env)
end

local function parse_item(p, delim)
    if delim and delim ~= "" then
        local pos = string.find(p, delim, 1, true)
        if pos then
            return string.sub(p, 1, pos - 1), string.sub(p, pos + #delim)
        end
    end
    return p, nil
end

function M.func(input, env)
    local ctx = env.engine.context
    local input_code = ctx.input
    local db = env.db
    local rules = env.rules
    local comment_fmt = env.comment_format
    local is_chain = env.chain
    local query_cache = env.query_cache
    if not query_cache then
        query_cache = {}
        env.query_cache = query_cache
    end

    if not ctx:is_composing() or ctx.input == "" then
        clear_table(query_cache)
        for cand in input:iter() do yield(cand) end
        return
    end

    if not rules or #rules == 0 or not db then
        for cand in input:iter() do yield(cand) end
        return
    end

    local seg = ctx.composition:back()
    local current_seg_tags = seg and seg.tags or {}
    if seg then input_code = s_sub(ctx.input, seg.start + 1, seg._end) end

    local active_rules = {}
    local active_abbrev_rules = {}

    local function is_rule_active(t)
        local option_active = false
        for _, trigger in ipairs(t.triggers) do
            if trigger == true then
                option_active = true
                break
            elseif type(trigger) == "string" and ctx:get_option(trigger) then
                option_active = true
                break
            end
        end
        if not option_active then return false end

        if t.tags then
            for req_tag in pairs(t.tags) do
                if current_seg_tags[req_tag] then return true end
            end
            return false
        end

        return true
    end

    for _, t in ipairs(rules) do
        if is_rule_active(t) then
            if t.mode == "abbrev" then
                active_abbrev_rules[#active_abbrev_rules + 1] = t
            else
                active_rules[#active_rules + 1] = t
            end
        end
    end

    local fmm_offsets = env.fmm_offsets or {}
    local fmm_parts = env.fmm_parts or {}
    env.fmm_offsets = fmm_offsets
    env.fmm_parts = fmm_parts

    local pending_texts = env.shared_pending or {}
    local pending_comments = env.shared_pending_comments or {}
    local shared_comments = env.shared_comments or {}
    local main_results = {}
    env.shared_pending = pending_texts
    env.shared_pending_comments = pending_comments
    env.shared_comments = shared_comments

    local function process_rules(cand, results)
        clear_array(results)
        clear_array(pending_texts)
        clear_array(pending_comments)
        clear_array(shared_comments)

        local current_text = cand.text
        local show_main = true
        local current_main_comment = cand.comment
        local matched_cand_type = nil
        local pending_count = 0

        for _, t in ipairs(active_rules) do
            local query_text = is_chain and current_text or cand.text
            local query_key = t.prefix .. query_text
            local val

            val = fetch_exact_cached(db, query_key, query_cache)

            if not val and s_find(query_text, "%u") then
                query_text = s_lower(query_text)
                query_key = t.prefix .. query_text
                val = fetch_exact_cached(db, query_key, query_cache)
            end

            if not val and t.fmm then
                local query_len = utf8.len(query_text) or 0
                if query_len > 1 then
                    local seg_result = segment_convert(
                        query_text, db, t.prefix,
                        query_cache, fmm_offsets, fmm_parts
                    )
                    if seg_result ~= query_text then val = seg_result end
                end
            end

            if val then
                matched_cand_type = t.cand_type or matched_cand_type

                local mode = t.mode
                local rule_comment = ""
                if t.comment_mode == "text" then
                    rule_comment = cand.text
                elseif t.comment_mode == "comment" then
                    rule_comment = cand.comment
                end

                if mode ~= "comment" and rule_comment ~= "" then
                    rule_comment = s_format(comment_fmt, rule_comment)
                end

                local value_pos = 1

                if mode == "comment" then
                    while value_pos do
                        local p
                        p, value_pos = next_value(val, value_pos)
                        if p ~= "" and p ~= input_code then
                            shared_comments[#shared_comments + 1] = p
                        end
                    end
                elseif mode == "replace" and is_chain then
                    local first = true
                    while value_pos do
                        local p
                        p, value_pos = next_value(val, value_pos)
                        if p ~= "" then
                            if first then
                                current_text = p
                                if t.comment_mode == "none" then
                                    current_main_comment = ""
                                elseif t.comment_mode == "text" then
                                    current_main_comment = cand.text
                                end
                                first = false
                            else
                                pending_count = pending_count + 1
                                pending_texts[pending_count] = p
                                pending_comments[pending_count] = rule_comment
                            end
                        end
                    end
                elseif mode == "replace" or mode == "append" then
                    if mode == "replace" then show_main = false end
                    while value_pos do
                        local p
                        p, value_pos = next_value(val, value_pos)
                        if p ~= "" then
                            pending_count = pending_count + 1
                            pending_texts[pending_count] = p
                            pending_comments[pending_count] = rule_comment
                        end
                    end
                end
            end
        end

        if #shared_comments > 0 then
            current_main_comment = s_format(comment_fmt, concat(shared_comments, " "))
        end

        local result_count = 0
        if show_main then
            result_count = 1
            if is_chain and current_text ~= cand.text then
                local final_type = matched_cand_type or cand.type or "kv"
                local nc = Candidate(final_type, cand.start, cand._end, current_text, current_main_comment)
                nc.preedit = cand.preedit
                nc.quality = cand.quality
                results[1] = nc
            else
                cand.comment = current_main_comment
                results[1] = cand
            end
        end

        local final_type = matched_cand_type or "derived"
        for i = 1, pending_count do
            local item_text = pending_texts[i]
            if not (show_main and item_text == current_text) then
                local nc = Candidate(final_type, cand.start, cand._end, item_text, pending_comments[i])
                nc.preedit = cand.preedit
                nc.quality = cand.quality
                result_count = result_count + 1
                results[result_count] = nc
            end
        end

        return results
    end

    local function trim_space(str)
        if not str or str == "" then return "" end

        local first = s_byte(str, 1)
        local last = s_byte(str, #str)
        if first > 32 and last > 32 then return str end
        return s_match(str, "^%s*(.-)%s*$")
    end

    local candidate_count = 0
    local function process_main(cand)
        candidate_count = candidate_count + 1
        if candidate_count <= CANDIDATE_LIMIT then
            return process_rules(cand, main_results)
        end

        clear_array(main_results)
        main_results[1] = cand
        return main_results
    end

    local global_yielded = {}

    -- 没有活跃简码规则时，跳过整套简码查询、排序与候选临时对象。
    if #active_abbrev_rules == 0 then
        for cand in input:iter() do
            local processed = process_main(cand)
            for _, pc in ipairs(processed) do
                local dedup_key = trim_space(pc.text)
                if not global_yielded[dedup_key] then
                    global_yielded[dedup_key] = true
                    yield(pc)
                end
            end
        end
        return
    end

    local yield_count = 0
    local seen_texts = {}
    local always_cands = {}
    local lazy_cands = {}
    local group_fronted = {}
    local aux_results = {}
    local abbrev_start = seg and seg.start or 0
    local abbrev_end = seg and seg._end or #ctx.input

    local function make_abbrev_candidate(item)
        local cand = Candidate(item.cand_type, abbrev_start, abbrev_end, item.text, "")
        cand.quality = item.quality
        if item.preedit then cand.preedit = item.preedit end
        return cand
    end

    local query_source = s_match(ctx.input, "^[a-zA-Z]+$") and ctx.input or input_code
    local query_code = s_gsub(query_source, env.speller_delimiter, "")
    local query_has_upper = s_find(query_code, "[A-Z]") ~= nil
    local upper_query = nil

    if query_code ~= "" then
        for _, t in ipairs(active_abbrev_rules) do
            local val = fetch_exact_cached(db, t.prefix .. query_code, query_cache)

            if not val and not query_has_upper then
                if not upper_query then upper_query = s_upper(query_code) end
                val = fetch_exact_cached(db, t.prefix .. upper_query, query_cache)
            end

            if val then
                local count = 0
                local group_key = t.prefix
                local value_pos = 1

                while value_pos do
                    local p
                    p, value_pos = next_value(val, value_pos)
                    if p ~= "" then
                        local item_text, item_preedit = parse_item(p, t.preedit_delim)
                        if not seen_texts[item_text] then
                            seen_texts[item_text] = true
                            count = count + 1

                            local item = {
                                text = item_text,
                                preedit = item_preedit and item_preedit ~= "" and item_preedit or nil,
                                cand_type = t.cand_type or "abbrev",
                                group_key = group_key
                            }

                            if count <= t.always_qty then
                                item.quality = 999
                                item.index = t.always_idx + count - 1
                                item.is_always = true
                                always_cands[#always_cands + 1] = item
                            else
                                item.quality = 98
                                lazy_cands[#lazy_cands + 1] = item
                            end
                        end
                    end
                end
            end
        end
    end

    if #always_cands == 0 and #lazy_cands == 0 then
        for cand in input:iter() do
            local processed = process_main(cand)
            for _, pc in ipairs(processed) do
                local dedup_key = trim_space(pc.text)
                if not global_yielded[dedup_key] then
                    global_yielded[dedup_key] = true
                    yield(pc)
                end
            end
        end
        return
    end

    t_sort(always_cands, function(a, b) return a.index < b.index end)

    local abbrev_lookup = {}
    for _, item in ipairs(always_cands) do
        abbrev_lookup[trim_space(item.text)] = item
    end
    for _, item in ipairs(lazy_cands) do
        abbrev_lookup[trim_space(item.text)] = item
    end

    local abbrevs_dumped = false
    local function dump_all_abbrevs()
        if abbrevs_dumped then return end
        abbrevs_dumped = true

        for _, item in ipairs(always_cands) do
            if not item.yielded then
                item.yielded = true
                local processed = process_rules(make_abbrev_candidate(item), aux_results)
                for _, pc in ipairs(processed) do
                    local dedup_key = trim_space(pc.text)
                    if not global_yielded[dedup_key] then
                        global_yielded[dedup_key] = true
                        yield(pc)
                        yield_count = yield_count + 1
                    end
                end
            end
        end

        for _, item in ipairs(lazy_cands) do
            if not item.yielded then
                item.yielded = true
                if not group_fronted[item.group_key] then
                    local processed = process_rules(make_abbrev_candidate(item), aux_results)
                    for _, pc in ipairs(processed) do
                        local dedup_key = trim_space(pc.text)
                        if not global_yielded[dedup_key] then
                            global_yielded[dedup_key] = true
                            yield(pc)
                            yield_count = yield_count + 1
                        end
                    end
                end
            end
        end
    end

    local iter_func, state, iter_var = input:iter()
    local lookahead_cache = {}
    local has_phrase = false
    local is_exhausted = false

    while #lookahead_cache < 30 do
        iter_var = iter_func(state, iter_var)
        if not iter_var then
            is_exhausted = true
            break
        end

        lookahead_cache[#lookahead_cache + 1] = iter_var
        if iter_var.type == "phrase" then
            has_phrase = true
            break
        end
    end

    local cache_idx = 1
    local function get_next_cand()
        if cache_idx <= #lookahead_cache then
            local c = lookahead_cache[cache_idx]
            cache_idx = cache_idx + 1
            return c
        end

        if not is_exhausted then
            iter_var = iter_func(state, iter_var)
            if not iter_var then is_exhausted = true end
            return iter_var
        end

        return nil
    end

    local cand = get_next_cand()
    local next_always_ptr = 1

    while cand do
        local c_type = cand.type or ""
        local is_user = c_type == "user_phrase" or c_type == "user_table"
        local is_regular = c_type == "phrase" or (c_type == "table" and has_phrase)
        local processed_cands = process_main(cand)

        for _, pc in ipairs(processed_cands) do
            local dedup_key = trim_space(pc.text)

            if not global_yielded[dedup_key] then
                local match_item = abbrev_lookup[dedup_key]
                local is_reserved = match_item ~= nil

                if is_user then
                    if is_reserved then
                        match_item.yielded = true
                        if match_item.is_always then
                            group_fronted[match_item.group_key] = true
                        end
                    end

                    global_yielded[dedup_key] = true
                    yield(pc)
                    yield_count = yield_count + 1
                elseif is_regular then
                    while next_always_ptr <= #always_cands do
                        local item = always_cands[next_always_ptr]

                        if item.yielded then
                            next_always_ptr = next_always_ptr + 1
                        elseif yield_count + 1 >= item.index then
                            item.yielded = true
                            group_fronted[item.group_key] = true

                            local ac_processed = process_rules(make_abbrev_candidate(item), aux_results)
                            for _, apc in ipairs(ac_processed) do
                                local apc_key = trim_space(apc.text)
                                if not global_yielded[apc_key] then
                                    global_yielded[apc_key] = true
                                    yield(apc)
                                    yield_count = yield_count + 1
                                end
                            end

                            next_always_ptr = next_always_ptr + 1
                        else
                            break
                        end
                    end

                    if not is_reserved then
                        global_yielded[dedup_key] = true
                        yield(pc)
                        yield_count = yield_count + 1
                    end
                else
                    dump_all_abbrevs()

                    if not is_reserved then
                        global_yielded[dedup_key] = true
                        yield(pc)
                        yield_count = yield_count + 1
                    end
                end
            end
        end

        cand = get_next_cand()
    end
    dump_all_abbrevs()
end
return M