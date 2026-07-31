-- super_replacer.lua 一个rime 更灵活地滤镜转换器
-- https://github.com/amzxyz/rime-wanxiang
-- @amzxyz

local M = {}

-- 性能优化：本地化常用库函数
local insert = table.insert
local concat = table.concat
local s_match = string.match
local s_gmatch = string.gmatch
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
local MERGED_SCHEMA_IDS = {"wanxiang_pro", "wanxiang", "wanxiang_english", "wanxiang_t9"}
local FILE_KEYS = {"files", "file"}
local db_instances = {}
local db_refs = {}
local file_signature_cache = {}
local RECORD_SEPARATOR = " \t"
local RECORD_TAIL = "c=0 d=0 t=0"

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
    for _, key in ipairs(FILE_KEYS) do
        local item = rule:get(key)
        if item then
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
    end
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

local function tasks_signature(tasks)
    local parts = {}
    for i, task in ipairs(tasks) do
        parts[i] = concat({
            task.source or "",
            task.prefix or "",
            task.conversion and "t9" or "plain",
            task.preedit_delim or ""
        }, "|")
    end
    return digest_parts(parts)
end

local function enabled_schema_ids(env, user_dir)
    local enabled = {}
    local current = env.engine.schema.schema_id or ""

    local config = Config("default")
    local list = config and config:get_list("schema_list")

    if list then
        for i = 0, list.size - 1 do
            local item = list:get_at(i)
            local map = item and item:get_map()
            local value = map and map:get_value("schema")
            local id = value and value:get_string()
            if id then enabled[id] = true end
        end

        if current ~= "" then enabled[current] = true end
    else
        -- default.yaml 暂时不可读时按固定列表探测，不能退化为“仅当前方案”。
        for _, id in ipairs(MERGED_SCHEMA_IDS) do
            local schema = Schema(id)
            if schema then enabled[id] = true end
        end
    end

    local ids = {}
    for _, id in ipairs(MERGED_SCHEMA_IDS) do
        if enabled[id] then ids[#ids + 1] = id end
    end

    if #ids == 0 and current ~= "" then ids[1] = current end
    return ids
end

-- 合并所有启用方案的数据任务，并生成固定的方案级表头特征。
local function merge_build_tasks(env, ns, current_tasks, user_dir)
    local current_id = env.engine.schema.schema_id or ""
    local enabled_ids = enabled_schema_ids(env, user_dir)
    local groups = {}
    local signatures = {}

    for order, id in ipairs(enabled_ids) do
        local tasks = nil
        local schema = Schema(id)
        if schema then
            tasks = collect_build_tasks(schema.config, ns)
        elseif id == current_id then
            tasks = current_tasks
        else
            tasks = {}
        end

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
            local key = tasks_signature({task})
            if not seen[key] then
                seen[key] = true
                merged[#merged + 1] = task
            end
        end
    end

    return merged, signatures, digest_parts(enabled_ids)
end

-- 编码聚合内容，确保 UserDb raw key 中只保留一个真实 Tab。
local function encode_record_value(value)
    value = s_gsub(value, "\\", "\\\\")
    value = s_gsub(value, "\t", "\\t")
    value = s_gsub(value, "\n", "\\n")
    value = s_gsub(value, "\r", "\\r")
    return value
end

-- 解码聚合内容；未知转义保留反斜杠和原字符。
local function decode_record_value(value)
    local parts = {}
    local count = 0
    local i = 1

    while i <= #value do
        local char = s_sub(value, i, i)

        if char == "\\" and i < #value then
            local escaped = s_sub(value, i + 1, i + 1)
            if escaped == "\\" then
                char = "\\"
                i = i + 2
            elseif escaped == "t" then
                char = "\t"
                i = i + 2
            elseif escaped == "n" then
                char = "\n"
                i = i + 2
            elseif escaped == "r" then
                char = "\r"
                i = i + 2
            else
                count = count + 1
                parts[count] = "\\"
                char = escaped
                i = i + 2
            end
        else
            i = i + 1
        end

        count = count + 1
        parts[count] = char
    end

    return concat(parts, "", 1, count)
end

-- 源文件格式：业务 key 与内容之间必须使用真实 Tab；内容候选使用字面量 \\t 分隔。
local function parse_source_line(line)
    local key, value = s_match(line, "^([^\t]+)\t+(.+)$")
    if not key or not value or key == "" or value == "" then return nil, nil end

    -- 第一个字段分隔之后不再允许真实 Tab，避免产生多列源格式。
    if s_find(value, "\t", 1, true) then return nil, nil end
    return key, decode_record_value(value)
end

-- 按业务 key 读取整行聚合记录。
local function fetch_aggregate(db, key)
    local prefix = key .. RECORD_SEPARATOR
    local accessor = db:query(prefix)
    if not accessor then return nil, nil end

    local value = nil
    local raw_key = nil

    for current_key, _ in accessor:iter() do
        if s_sub(current_key, 1, #prefix) ~= prefix then break end

        raw_key = current_key
        value = decode_record_value(s_sub(current_key, #prefix + 1))
        break
    end

    accessor = nil
    return value, raw_key
end

-- 写入整行聚合记录；raw value 固定为 c=0 d=0 t=0。
local function update_aggregate(db, key, value)
    if not key or key == "" or not value or value == "" then return false end
    return db:update(key .. RECORD_SEPARATOR .. encode_record_value(value), RECORD_TAIL)
end

-- 重建数据库：每个业务 key 只能出现一行，重复 key 保留第一次并跳过后续行。
local function rebuild(tasks, db)
    local seen_keys = {}
    local duplicate_count = 0
    local invalid_count = 0

    for _, task in ipairs(tasks) do
        local file, close = wanxiang.load_file_with_fallback(task.path, "r")

        if file then
            for line in file:lines() do
                if line ~= "" and not s_match(line, "^%s*#") then
                    local key, value = parse_source_line(line)

                    if key and value then
                        local original_key = key
                        if task.conversion then key = s_gsub(key, ".", task.conversion) end
                        value = s_match(value, "^%s*(.-)%s*$")

                        if task.preedit_delim
                            and task.preedit_delim ~= ""
                            and not s_find(value, task.preedit_delim, 1, true)
                        then
                            value = value .. task.preedit_delim .. original_key
                        end

                        local db_key = task.prefix .. key
                        if seen_keys[db_key] then
                            duplicate_count = duplicate_count + 1
                        else
                            seen_keys[db_key] = true
                            if not update_aggregate(db, db_key, value) then
                                close()
                                return false
                            end
                        end
                    else
                        invalid_count = invalid_count + 1
                    end
                end
            end

            close()
        end
    end

    if log and log.warning then
        if duplicate_count > 0 then
            log.warning(s_format(
                "super_replacer: 已跳过 %d 行重复业务 key，仅保留第一次出现",
                duplicate_count
            ))
        end

        if invalid_count > 0 then
            log.warning(s_format(
                "super_replacer: 已跳过 %d 行无效数据，格式必须为 key<真实Tab>候选1\\t候选2",
                invalid_count
            ))
        end
    end

    return true
end

-- 增加共享数据库的组件引用。
local function retain_db(db_name)
    db_refs[db_name] = (db_refs[db_name] or 0) + 1
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
    union_sig, scheme_sigs, env_fmm_cache
)
    local cached = db_instances[db_name]
    if cached then
        retain_db(db_name)
        return cached
    end

    local db = userdb.LevelDb(db_name)
    if not db then return nil end

    local files_sig = generate_files_signature(tasks)

    if db:open_read_only() then
        if database_matches(
            db, current_version, delimiter,
            files_sig, union_sig, scheme_sigs
        ) then
            db_instances[db_name] = db
            retain_db(db_name)
            return db
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

    for key in pairs(env_fmm_cache) do
        env_fmm_cache[key] = nil
    end

    if log and log.info then
        log.info("super_replacer: 联合配置数据已重载，固定表头特征已记录")
    end

    db:close()

    if not db:open_read_only() then return nil end

    db_instances[db_name] = db
    retain_db(db_name)
    return db
end
-- 释放当前组件引用，并在最后一个使用者退出时关闭数据库。
local function release_db(env)
    local db = env.db
    local db_name = env.db_name

    env.db = nil
    env.db_name = nil

    if not db or not db_name then return end

    local refs = (db_refs[db_name] or 1) - 1
    if refs > 0 then
        db_refs[db_name] = refs
        return
    end

    db_refs[db_name] = nil
    if db_instances[db_name] == db then db_instances[db_name] = nil end
    db:close()
end

-- FMM 分词转换算法：复用 offsets/result_parts，避免热点路径反复分配临时表
local function segment_convert(text, db, prefix, split_pat, fmm_cache, offsets, result_parts)
    local char_count = get_utf8_offsets(text, offsets)
    clear_array(result_parts)

    local i, result_count = 1, 0
    local MAX_LOOKAHEAD = 6

    while i <= char_count do
        local start_byte = offsets[i]
        local matched = false
        local max_j = i + MAX_LOOKAHEAD
        if max_j > char_count + 1 then max_j = char_count + 1 end

        for j = max_j, i + 2, -1 do
            local sub_text = s_sub(text, start_byte, offsets[j] - 1)
            local cache_key = prefix .. sub_text
            local val = fmm_cache[cache_key]

            if val == nil then
                val = fetch_aggregate(db, cache_key) or false
                fmm_cache[cache_key] = val
            end

            if val then
                result_count = result_count + 1
                result_parts[result_count] = s_match(val, split_pat) or sub_text
                i = j - 1
                matched = true
                break
            end
        end

        if not matched then
            local single_char = s_sub(text, start_byte, offsets[i + 1] - 1)
            local cache_key = prefix .. single_char
            local val = fmm_cache[cache_key]

            if val == nil then
                val = fetch_aggregate(db, cache_key) or false
                fmm_cache[cache_key] = val
            end

            result_count = result_count + 1
            result_parts[result_count] = val and (s_match(val, split_pat) or single_char) or single_char
        end

        i = i + 1
    end

    return concat(result_parts, "", 1, result_count)
end

-- 模块接口
function M.init(env)
    env.fmm_cache = {}
    env.fmm_offsets = {}
    env.fmm_parts = {}
    env.shared_pending = {}
    env.shared_pending_comments = {}
    env.shared_comments = {}
    local ns = env.name_space
    ns = s_gsub(ns, "^%*", "")
    ns = string.match(ns, "([^%.]+)$") or ns
    local config = env.engine.schema.config
  
    local user_dir = rime_api.get_user_data_dir()

    -- 1. 获取根节点 Map 对象
    local cfg_root = config:get_map(ns)

    -- 2. 读取基础配置
    local db_name_val = cfg_root and cfg_root:get_value("db_name")
    local db_name = db_name_val and db_name_val:get_string() or "lua/replacer"

    env.delimiter = "\t"
    env.split_pattern = "([^\t]+)"
    
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
    local tasks = {} 

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
            local conversion_map = nil
            local preedit_delim = nil
            
            if t9_opt then
                conversion_map = T9_MAP
                preedit_delim = "=="
            end

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
                t9_opt = t9_opt,
                cand_type = custom_cand_type
            })

            -- 解析文件路径列表
            local keys_to_check = {"files", "file"}
            for _, key in ipairs(keys_to_check) do
                local file_item = rule:get(key)
                if file_item then
                    if file_item.type == "kList" then
                        local list = file_item:get_list()
                        for j = 0, list.size - 1 do
                            local val = list:get_value_at(j)
                            local str = val and val:get_string()
                            if str and str ~= "" then
                                insert(tasks, { source = str, path = str, prefix = prefix, conversion = conversion_map, preedit_delim = preedit_delim })
                            end
                        end
                    elseif file_item.type == "kScalar" then
                        local val = file_item:get_value()
                        local str = val and val:get_string()
                        if str and str ~= "" then
                            insert(tasks, { source = str, path = str, prefix = prefix, conversion = conversion_map, preedit_delim = preedit_delim })
                        end
                    end
                end
            end

            ::continue_rule::
        end
    end
    
    local merged_tasks, scheme_sigs, union_sig =
        merge_build_tasks(env, ns, tasks, user_dir)

    env.db = connect_db(
        db_name, current_version, env.delimiter,
        merged_tasks, union_sig, scheme_sigs, env.fmm_cache
    )
    if env.db then env.db_name = db_name end
end

function M.fini(env)
    env.fmm_cache = nil
    env.fmm_offsets = nil
    env.fmm_parts = nil
    env.shared_pending = nil
    env.shared_pending_comments = nil
    env.shared_comments = nil
    env.rules = nil

    release_db(env)
end

--解析连接符工具函数
local function parse_item(p, delim)
    if delim and delim ~= "" then
        local pos = string.find(p, delim, 1, true)
        if pos then
            return string.sub(p, 1, pos - 1), string.sub(p, pos + #delim)
        end
    end
    return p, nil
end

-- [Core Function] 核心逻辑
function M.func(input, env)
    local ctx = env.engine.context
    local input_code = ctx.input
    local db = env.db
    local rules = env.rules
    local split_pat = env.split_pattern
    local comment_fmt = env.comment_format
    local is_chain = env.chain

    if not ctx:is_composing() or ctx.input == "" then
        env.fmm_cache = {}
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

    local fetch_cache = {}
    local function fetch_cached(key)
        local cached = fetch_cache[key]
        if cached ~= nil then return cached or nil end

        local value = fetch_aggregate(db, key)
        fetch_cache[key] = value or false
        return value
    end

    local fmm_offsets = env.fmm_offsets or {}
    local fmm_parts = env.fmm_parts or {}
    env.fmm_offsets = fmm_offsets
    env.fmm_parts = fmm_parts

    local pending_texts = env.shared_pending or {}
    local pending_comments = env.shared_pending_comments or {}
    local shared_comments = env.shared_comments or {}
    local main_results = {}
    local aux_results = {}
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
            local val = fetch_cached(t.prefix .. query_text)

            if not val and s_find(query_text, "%u") then
                val = fetch_cached(t.prefix .. s_lower(query_text))
            end

            if not val and t.fmm then
                local seg_result = segment_convert(query_text, db, t.prefix, split_pat, env.fmm_cache, fmm_offsets, fmm_parts)
                if seg_result ~= query_text then val = seg_result end
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

                if mode == "comment" then
                    -- 直接汇入共享数组；最终 concat 结果与原来的分规则 parts 完全一致。
                    for p in s_gmatch(val, split_pat) do
                        if p ~= input_code then shared_comments[#shared_comments + 1] = p end
                    end
                elseif mode == "replace" then
                    if is_chain then
                        local first = true
                        for p in s_gmatch(val, split_pat) do
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
                    else
                        show_main = false
                        for p in s_gmatch(val, split_pat) do
                            pending_count = pending_count + 1
                            pending_texts[pending_count] = p
                            pending_comments[pending_count] = rule_comment
                        end
                    end
                elseif mode == "append" then
                    for p in s_gmatch(val, split_pat) do
                        pending_count = pending_count + 1
                        pending_texts[pending_count] = p
                        pending_comments[pending_count] = rule_comment
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

    local yield_count = 0
    local seen_texts = {}
    local global_yielded = {}
    local always_cands = {}
    local lazy_cands = {}
    local group_fronted = {}

    local query_code = s_gsub(input_code, env.speller_delimiter, "")
    if s_match(ctx.input, "^[a-zA-Z]+$") then
        query_code = s_gsub(ctx.input, env.speller_delimiter, "")
    end

    if query_code ~= "" then
        for _, t in ipairs(active_abbrev_rules) do
            local val = fetch_cached(t.prefix .. query_code)
            if not val and not s_match(query_code, "[A-Z]") then
                val = fetch_cached(t.prefix .. s_upper(query_code))
            end

            if val then
                local count = 0
                local group_key = t.prefix

                for p in s_gmatch(val, split_pat) do
                    local item_text, item_preedit = parse_item(p, t.preedit_delim)
                    if not seen_texts[item_text] then
                        seen_texts[item_text] = true

                        local final_type = t.cand_type or "abbrev"
                        local abbrev_cand = Candidate(
                            final_type,
                            seg and seg.start or 0,
                            seg and seg._end or #ctx.input,
                            item_text,
                            ""
                        )
                        if item_preedit and item_preedit ~= "" then abbrev_cand.preedit = item_preedit end

                        count = count + 1
                        if count <= t.always_qty then
                            abbrev_cand.quality = 999
                            always_cands[#always_cands + 1] = {
                                cand = abbrev_cand,
                                index = t.always_idx + count - 1,
                                group_key = group_key,
                                yielded = false
                            }
                        else
                            abbrev_cand.quality = 98
                            lazy_cands[#lazy_cands + 1] = {
                                cand = abbrev_cand,
                                group_key = group_key,
                                yielded = false
                            }
                        end
                    end
                end
            end
        end
    end

    local function trim_space(str)
        if not str then return "" end
        return s_match(str, "^%s*(.-)%s*$")
    end

    if #always_cands == 0 and #lazy_cands == 0 then
        for cand in input:iter() do
            local processed = process_rules(cand, main_results)
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
        abbrev_lookup[trim_space(item.cand.text)] = { type = "always", ref = item }
    end
    for _, item in ipairs(lazy_cands) do
        abbrev_lookup[trim_space(item.cand.text)] = { type = "lazy", ref = item }
    end

    local abbrevs_dumped = false
    local function dump_all_abbrevs()
        if abbrevs_dumped then return end
        abbrevs_dumped = true

        for _, item in ipairs(always_cands) do
            if not item.yielded then
                item.yielded = true
                local processed = process_rules(item.cand, aux_results)
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
                    local processed = process_rules(item.cand, aux_results)
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
        local processed_cands = process_rules(cand, main_results)

        for _, pc in ipairs(processed_cands) do
            local dedup_key = trim_space(pc.text)

            if not global_yielded[dedup_key] then
                local c_type = cand.type or ""
                local is_user = c_type == "user_phrase" or c_type == "user_table"
                local is_regular = c_type == "phrase" or (c_type == "table" and has_phrase)
                local match_info = abbrev_lookup[dedup_key]
                local is_reserved = match_info ~= nil

                if is_user then
                    if is_reserved then
                        match_info.ref.yielded = true
                        if match_info.type == "always" then
                            group_fronted[match_info.ref.group_key] = true
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

                            local ac_processed = process_rules(item.cand, aux_results)
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