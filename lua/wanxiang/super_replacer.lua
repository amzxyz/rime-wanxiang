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
local DB_FORMAT_VERSION = "7"
local MERGED_SCHEMA_IDS = {"wanxiang_pro", "wanxiang", "wanxiang_lite", "wanxiang_english", "wanxiang_t9", "wanxiang_t9i"}
local file_signature_map = {}
local build_task_map = {}
local runtime_initialized = {}
local RECORD_SEPARATOR = " \t"
local VALUE_SEPARATOR = "\\t"
local VALUE_SEPARATOR_LEN = #VALUE_SEPARATOR
local RECORD_TAIL = "c=0 d=0 t=0"
local CANDIDATE_LIMIT = 50
local FMM_LONG_STEM_CHARS = 4
local ABBREV_SCRATCH_RETAIN_LIMIT = 128
local OPTION_KEYS = {"option", "options"}
local TAG_KEYS = {"tag", "tags"}

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

local function clear_map(t)
    for key in pairs(t) do t[key] = nil end
end

-- 清空仅供单次 M.func 使用的工作缓冲；保留 table 本身供下轮复用。
local function clear_work_buffers(env)
    if env.result_buffer then clear_array(env.result_buffer) end
    if env.derived_text_buffer then clear_array(env.derived_text_buffer) end
    if env.derived_comment_buffer then clear_array(env.derived_comment_buffer) end
    if env.comment_buffer then clear_array(env.comment_buffer) end
    if env.yielded_texts then clear_map(env.yielded_texts) end
end

local function clear_abbrev_scratch(scratch)
    if not scratch then return end
    clear_map(scratch.seen)
    clear_array(scratch.always)
    clear_array(scratch.lazy)
    clear_map(scratch.group_fronted)
    clear_map(scratch.lookup)
    clear_array(scratch.results)
end

local function finish_abbrev_scratch(env, scratch, discard)
    if not scratch then return end
    if discard then
        env.abbrev_scratch = nil
    else
        clear_abbrev_scratch(scratch)
    end
end

local function trim_space(text)
    if not text or text == "" then return "" end

    local first = s_byte(text, 1)
    local last = s_byte(text, #text)
    if first > 32 and last > 32 then return text end
    return s_match(text, "^%s*(.-)%s*$")
end

local function check_rule_type_list(rule, key, input_type)
    local item = rule:get(key)
    if not item then return nil end
    local list = item.type == "kList" and item:get_list()
    if not list then return nil end

    for i = 0, list.size - 1 do
        local value = list:get_value_at(i)
        if value and value:get_string() == input_type then return true end
    end
    return false
end

local function is_rule_active(rule, context, segment_tags)
    local option_active = false
    for _, trigger in ipairs(rule.triggers) do
        if trigger == true
            or (type(trigger) == "string" and context:get_option(trigger))
        then
            option_active = true
            break
        end
    end
    if not option_active then return false end

    if rule.tags then
        if not segment_tags then return false end
        for required_tag in pairs(rule.tags) do
            if segment_tags[required_tag] then return true end
        end
        return false
    end

    return true
end

local function make_abbrev_candidate(item, start_pos, end_pos)
    local cand = Candidate(item.cand_type, start_pos, end_pos, item.text, "")
    cand.quality = item.quality
    if item.preedit then cand.preedit = item.preedit end
    return cand
end

local function compare_abbrev_index(a, b)
    return a.index < b.index
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
    local cached = file_signature_map[path]
    if cached then return cached end

    local file, close = wanxiang.load_file_with_fallback(path, "rb")
    if not file then
        file_signature_map[path] = "missing"
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
    file_signature_map[path] = cached
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

    if build_task_map[ns] then
        local entry = build_task_map[ns]
        return entry.merged, entry.signatures, entry.union_sig
    end

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

    local union_sig = digest_parts(schema_ids)

    build_task_map[ns] = {
        merged = merged,
        signatures = signatures,
        union_sig = union_sig
    }

    return merged, signatures, union_sig
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


local function fetch_aggregate_db(db, key)
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

local function rebuild(tasks, db)
    local written_db_keys = {}
    local seen_converted_keys = nil
    local converted_groups = nil
    local converted_order = nil
    local prefix_profiles = {}
    local function update_prefix_profile(prefix, key)
        local profile = prefix_profiles[prefix]
        if not profile then
            profile = {
                max_source_bytes = 0,
                min_source_bytes = nil,
                single_char_only = true,
                has_ascii_source = false
            }
            prefix_profiles[prefix] = profile
        end

        local key_bytes = #key
        if key_bytes > profile.max_source_bytes then
            profile.max_source_bytes = key_bytes
        end
        if not profile.min_source_bytes or key_bytes < profile.min_source_bytes then
            profile.min_source_bytes = key_bytes
        end
        if profile.single_char_only and (utf8.len(key) or 0) ~= 1 then
            profile.single_char_only = false
        end

        local first = key_bytes > 0 and s_byte(key, 1) or nil
        if first and first < 128 then profile.has_ascii_source = true end
    end

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
                                update_prefix_profile(prefix, key)
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
                            update_prefix_profile(prefix, key)
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
                local old_value, old_raw_key = fetch_aggregate_db(db, db_key)
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

    return true, prefix_profiles
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
    files_sig, union_sig, scheme_sigs, prefix_profiles
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

    if prefix_profiles then
        for prefix, profile in pairs(prefix_profiles) do
            if not db:meta_update(
                    "_replacer_max_bytes/" .. prefix,
                    tostring(profile.max_source_bytes or 0)
                )
                or not db:meta_update(
                    "_replacer_min_bytes/" .. prefix,
                    tostring(profile.min_source_bytes or 0)
                )
                or not db:meta_update(
                    "_replacer_single_char/" .. prefix,
                    profile.single_char_only and "1" or "0"
                )
                or not db:meta_update(
                    "_replacer_has_ascii/" .. prefix,
                    profile.has_ascii_source and "1" or "0"
                )
            then
                return false
            end
        end
    end

    return true
end

-- 连接或重建联合数据库。
local function connect_db(
    db_name, current_version, delimiter, tasks,
    union_sig, scheme_sigs
)
    local db = userdb.LevelDb(db_name)
    if not db then return nil end

    if not db:loaded() and not db:open() then
        return nil
    end

    -- 重新部署导致 Lua 状态销毁时，该标记自然丢失，再进入完整指纹校验。
    if runtime_initialized[db_name] then
        return db, false
    end

    local files_sig = generate_files_signature(tasks)

    if database_matches(
        db, current_version, delimiter,
        files_sig, union_sig, scheme_sigs
    ) then
        runtime_initialized[db_name] = os.time()
        return db, false
    end

    local cleared
    if db.empty then
        cleared = db:empty(false)
    elseif db.clear then
        cleared = db:clear()
    end

    if cleared == false then return nil end

    local rebuilt_ok, prefix_profiles = rebuild(tasks, db)
    if not rebuilt_ok
        or not update_metadata(
            db, current_version, delimiter,
            files_sig, union_sig, scheme_sigs, prefix_profiles
        )
    then
        return nil
    end

    prefix_profiles = nil
    runtime_initialized[db_name] = os.time()
    return db, true
end

local function release_db(env)
    env.db = nil
    env.db_name = nil
    -- DbAccessor 没有显式析构接口。所有局部访问器先置空，再执行一次
    -- 完整垃圾回收，确保其先于所引用的 LevelDb 释放。
    collectgarbage()
end

local function clear_runtime_cache(env)
    if not env.runtime_cache_active then return end
    env.query_cache = {}
    env.fmm_cache = {}
    env.runtime_cache_active = false
end

-- 运行期缓存只保存 string / false，不保存 Candidate、DbAccessor 或 iterator。
local function fetch_runtime_aggregate(env, db, key)
    env.runtime_cache_active = true

    local cache = env.query_cache
    local cached = cache[key]
    if cached ~= nil then
        return cached or nil
    end

    local value = fetch_aggregate_db(db, key)
    cache[key] = value or false
    return value
end

local function is_ascii_only(text)
    for i = 1, #text do
        if s_byte(text, i) >= 128 then return false end
    end
    return true
end

local function has_multiple_utf8_chars(text)
    local len = #text
    if len <= 1 then return false end

    local b = s_byte(text, 1)
    if not b then return false end

    local first_len
    if b < 128 then first_len = 1
    elseif b < 224 then first_len = 2
    elseif b < 240 then first_len = 3
    else first_len = 4 end

    return len > first_len
end

-- 4 字及以上仍按当前 DB 格式做前缀扫描；完整 FMM 结果在当前 composition 内复用。
local function fetch_fmm_longest(db, prefix, text, start_byte, stem)
    local query_prefix = prefix .. stem
    local query_len = #query_prefix
    local prefix_len = #prefix
    local remaining_bytes = #text - start_byte + 1
    local accessor = db:query(query_prefix)

    if not accessor then return nil, nil end

    local best_source = nil
    local best_value = nil
    local best_bytes = 0

    for raw_key, _ in accessor:iter() do
        if s_find(raw_key, query_prefix, 1, true) ~= 1 then break end

        local sep_pos = s_find(raw_key, RECORD_SEPARATOR, query_len + 1, true)
        if sep_pos then
            local source_bytes = sep_pos - prefix_len - 1

            if source_bytes > best_bytes and source_bytes <= remaining_bytes then
                local source = s_sub(raw_key, prefix_len + 1, sep_pos - 1)
                if s_find(text, source, start_byte, true) == start_byte then
                    best_source = source
                    best_value = s_sub(raw_key, sep_pos + #RECORD_SEPARATOR)
                    best_bytes = source_bytes
                    if best_bytes == remaining_bytes then break end
                end
            end
        end
    end

    accessor = nil
    return best_source, best_value
end

-- 简化 FMM：去掉 LRU、链表和 progress 状态机。
-- 同一 prefix + 文本在一次 composition 内只计算一次完整结果。
local function convert_sentence_fmm(text, db, rule, env, offsets, result_parts)
    env.runtime_cache_active = true

    local prefix = rule.prefix
    local cache_key = prefix .. "\0" .. text
    local cached = env.fmm_cache[cache_key]
    if cached ~= nil then return cached end

    if not rule.has_ascii_source and is_ascii_only(text) then
        env.fmm_cache[cache_key] = text
        return text
    end

    local char_count = get_utf8_offsets(text, offsets)
    clear_array(result_parts)

    local i, result_count = 1, 0

    while i <= char_count do
        local start_byte = offsets[i]
        local source = nil
        local output = nil
        local step = 1

        local first_byte = s_byte(text, start_byte)
        if first_byte and first_byte < 128 and not rule.has_ascii_source then
            source = s_sub(text, start_byte, offsets[i + 1] - 1)
            output = source
        elseif rule.single_char_only then
            source = s_sub(text, start_byte, offsets[i + 1] - 1)
            local value = fetch_runtime_aggregate(env, db, prefix .. source)
            output = first_value(value) or source
        else
            if i + FMM_LONG_STEM_CHARS - 1 <= char_count then
                local stem = s_sub(
                    text, start_byte, offsets[i + FMM_LONG_STEM_CHARS] - 1
                )
                local long_source, long_value = fetch_fmm_longest(
                    db, prefix, text, start_byte, stem
                )

                if long_source then
                    source = long_source
                    output = first_value(long_value) or source
                    step = utf8.len(source) or FMM_LONG_STEM_CHARS
                end
            end

            if not output and i + 2 <= char_count then
                local triple = s_sub(text, start_byte, offsets[i + 3] - 1)
                local value = fetch_runtime_aggregate(env, db, prefix .. triple)
                if value then
                    source = triple
                    output = first_value(value) or source
                    step = 3
                end
            end

            if not output and i + 1 <= char_count then
                local pair = s_sub(text, start_byte, offsets[i + 2] - 1)
                local value = fetch_runtime_aggregate(env, db, prefix .. pair)
                if value then
                    source = pair
                    output = first_value(value) or source
                    step = 2
                end
            end

            if not output then
                source = s_sub(text, start_byte, offsets[i + 1] - 1)
                local value = fetch_runtime_aggregate(env, db, prefix .. source)
                output = first_value(value) or source
            end
        end

        result_count = result_count + 1
        result_parts[result_count] = output
        i = i + step
    end

    local result = concat(result_parts, "", 1, result_count)
    env.fmm_cache[cache_key] = result
    return result
end

-- 模块接口
function M.init(env)
    env.fmm_offsets = nil
    env.fmm_result_parts = nil
    env.query_cache = {}
    env.fmm_cache = {}
    env.runtime_cache_active = false
    env.active_rules = {}
    env.active_abbrev_rules = {}
    env.result_buffer = nil
    env.derived_text_buffer = nil
    env.derived_comment_buffer = nil
    env.comment_buffer = nil
    env.yielded_texts = nil
    env.abbrev_scratch = nil
    local ns = env.name_space
    ns = s_gsub(ns, "^%*", "")
    ns = string.match(ns, "([^%.]+)$") or ns
    local config = env.engine.schema.config
    local cfg_root = config:get_map(ns)

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

    local rules_item = cfg_root and cfg_root:get("rules")
    local rule_list = rules_item and rules_item:get_list()
  
    if rule_list then
        for i = 0, rule_list.size - 1 do
            local rule_item = rule_list:get_at(i)
            local rule = rule_item and rule_item:get_map()
            if not rule then goto continue_rule end

            local is_only = check_rule_type_list(rule, "only_types", env.input_type)
            if is_only == false then goto continue_rule end

            local is_excluded = check_rule_type_list(rule, "exclude_types", env.input_type)
            if is_excluded == true then goto continue_rule end

            -- 解析 triggers
            local triggers = {}
            for _, key in ipairs(OPTION_KEYS) do
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
            for _, key in ipairs(TAG_KEYS) do
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
            
            local sentence_val = rule:get_value("sentence")
            local sentence = sentence_val and sentence_val:get_bool() or false
            
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
                mode = mode,
                always_qty = always_qty,
                always_idx = always_idx,
                comment_mode = comment_mode,
                sentence = sentence,
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
        merged_tasks, union_sig, scheme_sigs
    )
    if env.db then
        env.db_name = db_name

        local profiles = {}
        for _, t in ipairs(env.rules) do
            local profile = profiles[t.prefix]
            if not profile then
                profile = {
                    min_source_bytes = tonumber(
                        env.db:meta_fetch("_replacer_min_bytes/" .. t.prefix)
                    ) or 0,
                    max_source_bytes = tonumber(
                        env.db:meta_fetch("_replacer_max_bytes/" .. t.prefix)
                    ) or 0,
                    single_char_only =
                        (env.db:meta_fetch("_replacer_single_char/" .. t.prefix) or "") == "1",
                    has_ascii_source =
                        (env.db:meta_fetch("_replacer_has_ascii/" .. t.prefix) or "") == "1"
                }
                profiles[t.prefix] = profile
            end

            t.min_source_bytes = profile.min_source_bytes
            t.max_source_bytes = profile.max_source_bytes
            t.single_char_only = profile.single_char_only
            t.has_ascii_source = profile.has_ascii_source
        end
    end

    if rebuilt then
        merged_tasks, scheme_sigs, union_sig = nil, nil, nil
        collectgarbage("collect")
    end

    local context = env.engine and env.engine.context
    if context then
        env.replacer_commit_connection = context.commit_notifier:connect(function()
            clear_runtime_cache(env)
        end)

        env.replacer_update_connection = context.update_notifier:connect(function(updated_context)
            if not updated_context:is_composing() or updated_context.input == "" then
                clear_runtime_cache(env)
            end
        end)
    end
end

function M.fini(env)
    if env.replacer_commit_connection then
        env.replacer_commit_connection:disconnect()
        env.replacer_commit_connection = nil
    end
    if env.replacer_update_connection then
        env.replacer_update_connection:disconnect()
        env.replacer_update_connection = nil
    end

    env.fmm_offsets = nil
    env.fmm_result_parts = nil
    env.query_cache = nil
    env.fmm_cache = nil
    env.runtime_cache_active = nil
    env.active_rules = nil
    env.active_abbrev_rules = nil
    env.result_buffer = nil
    env.derived_text_buffer = nil
    env.derived_comment_buffer = nil
    env.comment_buffer = nil
    env.yielded_texts = nil
    env.abbrev_scratch = nil
    env.rules = nil
    env.delimiter = nil
    env.speller_delimiter = nil
    env.comment_format = nil
    env.input_type = nil
    env.chain = nil

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

    clear_work_buffers(env)

    if not ctx:is_composing() or ctx.input == "" then
        for cand in input:iter() do yield(cand) end
        return
    end

    if not rules or #rules == 0 or not db then
        for cand in input:iter() do yield(cand) end
        return
    end

    local seg = ctx.composition:back()
    local current_seg_tags = seg and seg.tags or nil
    if seg then input_code = s_sub(ctx.input, seg.start + 1, seg._end) end

    local active_rules = env.active_rules or {}
    local active_abbrev_rules = env.active_abbrev_rules or {}
    clear_array(active_rules)
    clear_array(active_abbrev_rules)
    env.active_rules = active_rules
    env.active_abbrev_rules = active_abbrev_rules
    local has_active_sentence_rule = false

    for i = 1, #rules do
        local t = rules[i]
        if is_rule_active(t, ctx, current_seg_tags) then
            if t.mode == "abbrev" then
                active_abbrev_rules[#active_abbrev_rules + 1] = t
            else
                active_rules[#active_rules + 1] = t
                if t.sentence then has_active_sentence_rule = true end
            end
        end
    end

    if #active_rules == 0 and #active_abbrev_rules == 0 then
        for cand in input:iter() do yield(cand) end
        return
    end

    local fmm_offsets = nil
    local fmm_result_parts = nil
    if has_active_sentence_rule then
        fmm_offsets = env.fmm_offsets or {}
        fmm_result_parts = env.fmm_result_parts or {}
        env.fmm_offsets = fmm_offsets
        env.fmm_result_parts = fmm_result_parts
    end

    local derived_texts = env.derived_text_buffer or {}
    local derived_comments = env.derived_comment_buffer or {}
    local comment_parts = env.comment_buffer or {}
    local result_buffer = env.result_buffer or {}
    env.result_buffer = result_buffer
    env.derived_text_buffer = derived_texts
    env.derived_comment_buffer = derived_comments
    env.comment_buffer = comment_parts

    local function process_rules(cand, results)
        clear_array(results)
        clear_array(derived_texts)
        clear_array(derived_comments)
        clear_array(comment_parts)

        local original_text = cand.text
        local original_comment = cand.comment
        local current_text = original_text
        local show_main = true
        local current_main_comment = original_comment
        local matched_cand_type = nil
        local pending_count = 0
        local cand_has_upper = nil
        local cand_lower_text = nil

        for i = 1, #active_rules do
            local rule = active_rules[i]
            local query_text = is_chain and current_text or original_text
            local val
            local is_multi = nil
            local exact_allowed = true

            if rule.single_char_only then
                is_multi = has_multiple_utf8_chars(query_text)
                if is_multi then exact_allowed = false end
            end

            if exact_allowed then
                local query_key = rule.prefix .. query_text
                val = fetch_runtime_aggregate(env, db, query_key)

                if not val then
                    local has_upper
                    if is_chain then
                        has_upper = s_find(query_text, "%u") ~= nil
                    else
                        if cand_has_upper == nil then
                            cand_has_upper = s_find(original_text, "%u") ~= nil
                        end
                        has_upper = cand_has_upper
                    end

                    if has_upper then
                        if is_chain then
                            query_text = s_lower(query_text)
                        else
                            if not cand_lower_text then cand_lower_text = s_lower(original_text) end
                            query_text = cand_lower_text
                        end
                        query_key = rule.prefix .. query_text
                        val = fetch_runtime_aggregate(env, db, query_key)
                    end
                end
            elseif rule.sentence then
                local has_upper
                if is_chain then
                    has_upper = s_find(query_text, "%u") ~= nil
                else
                    if cand_has_upper == nil then
                        cand_has_upper = s_find(original_text, "%u") ~= nil
                    end
                    has_upper = cand_has_upper
                end

                if has_upper then
                    if is_chain then
                        query_text = s_lower(query_text)
                    else
                        if not cand_lower_text then cand_lower_text = s_lower(original_text) end
                        query_text = cand_lower_text
                    end
                end
            end

            if not val and rule.sentence then
                if is_multi == nil then is_multi = has_multiple_utf8_chars(query_text) end
                if is_multi then
                    local seg_result = convert_sentence_fmm(
                        query_text, db, rule, env, fmm_offsets, fmm_result_parts
                    )
                    if seg_result ~= query_text then val = seg_result end
                end
            end

            if val then
                matched_cand_type = rule.cand_type or matched_cand_type

                local mode = rule.mode
                local rule_comment = ""
                if rule.comment_mode == "text" then
                    rule_comment = original_text
                elseif rule.comment_mode == "comment" then
                    rule_comment = original_comment
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
                            comment_parts[#comment_parts + 1] = p
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
                                if rule.comment_mode == "none" then
                                    current_main_comment = ""
                                elseif rule.comment_mode == "text" then
                                    current_main_comment = original_text
                                end
                                first = false
                            else
                                pending_count = pending_count + 1
                                derived_texts[pending_count] = p
                                derived_comments[pending_count] = rule_comment
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
                            derived_texts[pending_count] = p
                            derived_comments[pending_count] = rule_comment
                        end
                    end
                end
            end
        end

        if #comment_parts > 0 then
            current_main_comment = s_format(comment_fmt, concat(comment_parts, " "))
        end

        local result_count = 0
        if show_main then
            result_count = 1
            if is_chain and current_text ~= original_text then
                local final_type = matched_cand_type or cand.type or "kv"
                local new_cand = Candidate(final_type, cand.start, cand._end, current_text, current_main_comment)
                new_cand.preedit = cand.preedit
                new_cand.quality = cand.quality
                results[1] = new_cand
            else
                cand.comment = current_main_comment
                results[1] = cand
            end
        end

        local final_type = matched_cand_type or "derived"
        for i = 1, pending_count do
            local item_text = derived_texts[i]
            if not (show_main and item_text == current_text) then
                local new_cand = Candidate(final_type, cand.start, cand._end, item_text, derived_comments[i])
                new_cand.preedit = cand.preedit
                new_cand.quality = cand.quality
                result_count = result_count + 1
                results[result_count] = new_cand
            end
        end

        return results
    end

    local candidate_count = 0
    local has_regular_rules = #active_rules > 0
    local function process_main(cand)
        candidate_count = candidate_count + 1

        if candidate_count > CANDIDATE_LIMIT then
            return nil
        end

        if has_regular_rules then
            return process_rules(cand, result_buffer)
        end

        clear_array(result_buffer)
        result_buffer[1] = cand
        return result_buffer
    end

    local yielded_texts = env.yielded_texts or {}
    env.yielded_texts = yielded_texts

    -- 没有活跃简码规则时，跳过整套简码查询、排序与候选临时对象。
    if #active_abbrev_rules == 0 then
        local passthrough_tail = false
        for cand in input:iter() do
            if passthrough_tail then
                yield(cand)
            else
                local processed = process_main(cand)
                if not processed then
                    passthrough_tail = true
                    yield(cand)
                else
                    for i = 1, #processed do
                        local processed_cand = processed[i]
                        local dedup_key = trim_space(processed_cand.text)
                        if not yielded_texts[dedup_key] then
                            yielded_texts[dedup_key] = true
                            yield(processed_cand)
                        end
                    end
                end
            end
        end
        clear_work_buffers(env)
        return
    end

    -- 简码路径先只做极少量精确查询；只有真的命中后才创建排序/去重临时表。
    local abbrev_scratch = env.abbrev_scratch
    clear_abbrev_scratch(abbrev_scratch)
    local seen_texts = nil
    local always_cands = nil
    local lazy_cands = nil
    local abbrev_start = seg and seg.start or 0
    local abbrev_end = seg and seg._end or #ctx.input

    local query_source = s_match(ctx.input, "^[a-zA-Z]+$") and ctx.input or input_code
    local query_code = s_gsub(query_source, env.speller_delimiter, "")
    local query_has_upper = s_find(query_code, "[A-Z]") ~= nil
    local upper_query = nil

    if query_code ~= "" then
        local query_len = #query_code
        for i = 1, #active_abbrev_rules do
            local t = active_abbrev_rules[i]
            local min_len = t.min_source_bytes or 0
            local max_len = t.max_source_bytes or 0
            local length_allowed =
                (min_len == 0 or query_len >= min_len)
                and (max_len == 0 or query_len <= max_len)
            local val

            if length_allowed then
                val = fetch_runtime_aggregate(env, db, t.prefix .. query_code)

                if not val and not query_has_upper then
                    if not upper_query then upper_query = s_upper(query_code) end
                    if upper_query ~= query_code then
                        val = fetch_runtime_aggregate(env, db, t.prefix .. upper_query)
                    end
                end
            end

            if val then
                if not seen_texts then
                    if not abbrev_scratch then
                        abbrev_scratch = {
                            seen = {},
                            always = {},
                            lazy = {},
                            group_fronted = {},
                            lookup = {},
                            results = {}
                        }
                        env.abbrev_scratch = abbrev_scratch
                    end

                    seen_texts = abbrev_scratch.seen
                    always_cands = abbrev_scratch.always
                    lazy_cands = abbrev_scratch.lazy
                end

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

    if not always_cands or (#always_cands == 0 and #lazy_cands == 0) then
        local passthrough_tail = false
        for cand in input:iter() do
            if passthrough_tail then
                yield(cand)
            else
                local processed = process_main(cand)
                if not processed then
                    passthrough_tail = true
                    yield(cand)
                else
                    for i = 1, #processed do
                        local processed_cand = processed[i]
                        local dedup_key = trim_space(processed_cand.text)
                        if not yielded_texts[dedup_key] then
                            yielded_texts[dedup_key] = true
                            yield(processed_cand)
                        end
                    end
                end
            end
        end
        clear_abbrev_scratch(abbrev_scratch)
        clear_work_buffers(env)
        return
    end

    local discard_abbrev_scratch =
        (#always_cands + #lazy_cands) > ABBREV_SCRATCH_RETAIN_LIMIT
    local yield_count = 0
    local group_fronted = abbrev_scratch.group_fronted
    local aux_results = abbrev_scratch.results
    local abbrev_lookup = abbrev_scratch.lookup
    clear_map(group_fronted)
    clear_array(aux_results)
    clear_map(abbrev_lookup)

    t_sort(always_cands, compare_abbrev_index)

    for i = 1, #always_cands do
        local item = always_cands[i]
        abbrev_lookup[trim_space(item.text)] = item
    end
    for i = 1, #lazy_cands do
        local item = lazy_cands[i]
        abbrev_lookup[trim_space(item.text)] = item
    end

    local abbrevs_dumped = false
    local function dump_all_abbrevs()
        if abbrevs_dumped then return end
        abbrevs_dumped = true

        for _, item in ipairs(always_cands) do
            if not item.yielded then
                item.yielded = true
                local processed = process_rules(make_abbrev_candidate(item, abbrev_start, abbrev_end), aux_results)
                for i = 1, #processed do
                    local pc = processed[i]
                    local dedup_key = trim_space(pc.text)
                    if not yielded_texts[dedup_key] then
                        yielded_texts[dedup_key] = true
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
                    local processed = process_rules(make_abbrev_candidate(item, abbrev_start, abbrev_end), aux_results)
                    for i = 1, #processed do
                        local pc = processed[i]
                        local dedup_key = trim_space(pc.text)
                        if not yielded_texts[dedup_key] then
                            yielded_texts[dedup_key] = true
                            yield(pc)
                            yield_count = yield_count + 1
                        end
                    end
                end
            end
        end
    end

    local iter_func, state, iter_var = input:iter()
    local lookahead = {}
    local has_phrase = false
    local is_exhausted = false

    while #lookahead < 30 do
        iter_var = iter_func(state, iter_var)
        if not iter_var then
            is_exhausted = true
            break
        end

        lookahead[#lookahead + 1] = iter_var
        if iter_var.type == "phrase" then
            has_phrase = true
            break
        end
    end

    local lookahead_index = 1
    local function get_next_cand()
        if lookahead_index <= #lookahead then
            local c = lookahead[lookahead_index]
            lookahead_index = lookahead_index + 1
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
        local candidate_type = cand.type or ""
        local is_user = candidate_type == "user_phrase" or candidate_type == "user_table"
        local is_regular = candidate_type == "phrase" or (candidate_type == "table" and has_phrase)
        local processed_cands = process_main(cand)

        if not processed_cands then
            dump_all_abbrevs()
            yield(cand)
            cand = get_next_cand()
            while cand do
                yield(cand)
                cand = get_next_cand()
            end
            finish_abbrev_scratch(env, abbrev_scratch, discard_abbrev_scratch)
            clear_work_buffers(env)
            return
        end

        for i = 1, #processed_cands do
            local pc = processed_cands[i]
            local dedup_key = trim_space(pc.text)

            if not yielded_texts[dedup_key] then
                local match_item = abbrev_lookup[dedup_key]
                local is_reserved = match_item ~= nil

                if is_user then
                    if is_reserved then
                        match_item.yielded = true
                        if match_item.is_always then
                            group_fronted[match_item.group_key] = true
                        end
                    end

                    yielded_texts[dedup_key] = true
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

                            local ac_processed = process_rules(make_abbrev_candidate(item, abbrev_start, abbrev_end), aux_results)
                            for i = 1, #ac_processed do
                                local apc = ac_processed[i]
                                local apc_key = trim_space(apc.text)
                                if not yielded_texts[apc_key] then
                                    yielded_texts[apc_key] = true
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
                        yielded_texts[dedup_key] = true
                        yield(pc)
                        yield_count = yield_count + 1
                    end
                else
                    dump_all_abbrevs()

                    if not is_reserved then
                        yielded_texts[dedup_key] = true
                        yield(pc)
                        yield_count = yield_count + 1
                    end
                end
            end
        end

        cand = get_next_cand()
    end
    dump_all_abbrevs()
    finish_abbrev_scratch(env, abbrev_scratch, discard_abbrev_scratch)
    clear_work_buffers(env)
end
return M