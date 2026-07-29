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
local open = io.open
local type = type
local tonumber = tonumber

local DB_FORMAT_VERSION = "4"
local OPTION_KEYS = {"option", "options"}
local TAG_KEYS = {"tag", "tags"}
local FILE_KEYS = {"files", "file"}
local MERGED_SCHEMA_IDS = {"wanxiang_pro", "wanxiang", "wanxiang_english"}
local db_instances, db_refs = {}, {}
local file_signature_cache = {}
local RECORD_SEPARATOR = " \t"

local T9_MAP = {}
do
    local letters = "abcdefghijklmnopqrstuvwxyz"
    local digits = "22233344455566677778889999"
    for i = 1, #letters do T9_MAP[s_sub(letters, i, i)] = s_sub(digits, i, i) end
end

-- 基础依赖
local function safe_require(name)
    local status, lib = pcall(require, name)
    if status then return lib end
    return nil
end

local userdb = safe_require("wanxiang/userdb")
local wanxiang = safe_require("wanxiang/wanxiang")

local function clear_array(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function each_config_value(map, keys, callback)
    for _, key in ipairs(keys) do
        local item = map:get(key)
        if item then
            if item.type == "kList" then
                local list = item:get_list()
                for i = 0, list.size - 1 do
                    local value = list:get_value_at(i)
                    if value then callback(value, false) end
                end
            elseif item.type == "kScalar" then
                local value = item:get_value()
                if value then callback(value, true) end
            end
        end
    end
end

local function trim_space(str)
    if not str then return "" end
    return s_match(str, "^%s*(.-)%s*$")
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

-- 计算字节串摘要，避免把原始文件内容写入元数据。
local function hash_bytes(hash, value)
    for i = 1, #value do
        hash = (hash * 131 + s_byte(value, i)) % 4294967296
    end

    return hash
end

-- 采样单个文件；同一路径在当前 Lua 进程内只读取一次。
local function get_file_signature(path)
    local cached = file_signature_cache[path]
    if cached then return cached end

    local file = open(path, "rb")
    if not file then
        file_signature_cache[path] = "missing"
        return "missing"
    end

    local size = file:seek("end") or 0
    local hash = hash_bytes(2166136261, tostring(size))

    if size > 0 then
        file:seek("set", 0)
        hash = hash_bytes(hash, file:read(64) or "")

        file:seek("set", math.max(0, math.floor(size / 2) - 32))
        hash = hash_bytes(hash, file:read(64) or "")

        file:seek("set", math.max(0, size - 64))
        hash = hash_bytes(hash, file:read(64) or "")
    end

    file:close()
    cached = s_format("%08x:%d", hash, size)
    file_signature_cache[path] = cached
    return cached
end

-- 为合并后的任务生成统一文件特征。
local function generate_files_signature(tasks)
    local parts = {}
    local seen = {}

    for _, task in ipairs(tasks) do
        if not seen[task.path] then
            seen[task.path] = true
            parts[#parts + 1] =
                (task.source or task.path) .. "\31"
                .. get_file_signature(task.path)
        end
    end

    return concat(parts, "\30")
end

-- 解析数据文件路径。
local function resolve_path(relative, user_dir, shared_dir)
    if not relative or relative == "" then return nil end

    local user_path = user_dir .. "/" .. relative
    local file = open(user_path, "r")
    if file then file:close(); return user_path end

    local shared_path = shared_dir .. "/" .. relative
    file = open(shared_path, "r")
    if file then file:close(); return shared_path end
    return user_path
end

-- 从指定配置中提取真正影响写库结果的任务。
local function collect_tasks(config, ns, user_dir, shared_dir)
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

            each_config_value(rule, FILE_KEYS, function(file_value)
                local source = file_value:get_string()
                local path = resolve_path(source, user_dir, shared_dir)

                if path then
                    tasks[#tasks + 1] = {
                        source = source,
                        path = path,
                        prefix = prefix,
                        conversion = t9 and T9_MAP or nil,
                        preedit_delim = t9 and "==" or nil,
                    }
                end
            end)
        end
    end

    return tasks
end

-- 生成单方案建库配置特征。
local function tasks_signature(tasks)
    local parts = {}

    for i, task in ipairs(tasks) do
        parts[i] = concat({
            task.source or "",
            task.prefix or "",
            task.conversion and "t9" or "plain",
            task.preedit_delim or "",
        }, "\31")
    end

    return concat(parts, "\30")
end

-- 从部署后的 default 配置读取实际启用方案。
local function enabled_schema_ids(env, user_dir)
    local enabled = {}
    local current = env.engine.schema.schema_id or ""
    local config =
        Config(user_dir .. "/build/default.yaml")
    local list = config and config:get_list("schema_list")

    if list then
        for i = 0, list.size - 1 do
            local item = list:get_at(i)
            local map = item and item:get_map()
            local value = map and map:get_value("schema")
            local id = value and value:get_string()
            if id then enabled[id] = true end
        end
    end

    if current ~= "" then enabled[current] = true end

    local ids = {}
    for _, id in ipairs(MERGED_SCHEMA_IDS) do
        if enabled[id] then ids[#ids + 1] = id end
    end

    if #ids == 0 and current ~= "" then ids[1] = current end
    return ids
end

-- 合并启用方案的任务；相同文件、前缀和 T9 配置只保留一次。
local function merge_tasks(env, ns, current_tasks, user_dir, shared_dir)
    local current_id = env.engine.schema.schema_id or ""
    local groups = {}
    local signatures = {}
    local enabled_ids =
        enabled_schema_ids(env, user_dir)

    for order, id in ipairs(enabled_ids) do
        local tasks

        if id == current_id then
            tasks = current_tasks
        else
            local schema = Schema(id)
            tasks = schema and collect_tasks(
                schema.config, ns, user_dir, shared_dir
            ) or {}
        end

        groups[#groups + 1] = {
            id = id, order = order, tasks = tasks
        }
        signatures[id] = tasks_signature(tasks)
    end

    table.sort(groups, function(a, b)
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

    return merged, signatures, concat(enabled_ids, "\31")
end

-- 生成一条标准 UserDb raw key。
local function make_raw_key(key, value)
    if not key or key == "" or not value or value == "" then return nil end
    return key .. RECORD_SEPARATOR .. value
end

-- 生成保存候选顺序的 c/d/t 尾部。
local function make_record_tail(position)
    return s_format("c=%d d=0 t=0", position)
end

-- 从 c/d/t 尾部读取候选顺序。
local function parse_position(tail)
    if type(tail) ~= "string" then return 0 end
    return tonumber(s_match(tail, "c=([^%s\t]+)")) or 0
end

-- 重建数据库：每个 value 独立存储，c 保存同一逻辑 key 下的位置。
local function rebuild(tasks, db)
    local positions = {}
    local seen_records = {}

    for _, task in ipairs(tasks) do
        local file = open(task.path, "r")

        if file then
            for line in file:lines() do
                if line ~= "" and not s_match(line, "^%s*#") then
                    local key, values = s_match(line, "^([^\t]+)\t+(.+)")

                    if key and values then
                        local original_key = key
                        if task.conversion then
                            key = s_gsub(key, ".", task.conversion)
                        end

                        local db_key = task.prefix .. key

                        -- 源文件一行可包含多个 Tab 分隔 value。
                        for value in s_gmatch(values, "[^\t]+") do
                            value = s_match(value, "^%s*(.-)%s*$")

                            if value ~= "" then
                                if task.preedit_delim
                                    and task.preedit_delim ~= ""
                                    and not s_find(
                                        value,
                                        task.preedit_delim,
                                        1,
                                        true
                                    )
                                then
                                    value = value
                                        .. task.preedit_delim
                                        .. original_key
                                end

                                local raw_key = make_raw_key(db_key, value)

                                -- 相同逻辑 key + value 只保留第一次出现，
                                -- c 按源文件顺序连续编号。
                                if raw_key and not seen_records[raw_key] then
                                    seen_records[raw_key] = true

                                    local position =
                                        (positions[db_key] or 0) + 1
                                    positions[db_key] = position

                                    if not db:update(
                                        raw_key,
                                        make_record_tail(position)
                                    ) then
                                        file:close()
                                        return false
                                    end
                                end
                            end
                        end
                    end
                end
            end

            file:close()
        end
    end

    return true
end

-- 按逻辑 key 查询全部 value，并按 c 恢复源文件顺序。
local function fetch_values(db, key, delimiter)
    local prefix = key .. RECORD_SEPARATOR
    local accessor = db:query(prefix)
    if not accessor then return nil end

    local records = {}
    local count = 0

    for raw_key, tail in accessor:iter() do
        if s_sub(raw_key, 1, #prefix) ~= prefix then break end

        local value = s_sub(raw_key, #prefix + 1)
        if value ~= "" then
            count = count + 1
            records[count] = {
                value = value,
                position = parse_position(tail),
                index = count,
            }
        end
    end

    accessor = nil
    if count == 0 then return nil end

    t_sort(records, function(a, b)
        if a.position ~= b.position then
            if a.position == 0 then return false end
            if b.position == 0 then return true end
            return a.position < b.position
        end

        return a.index < b.index
    end)

    local values = {}
    for i = 1, count do values[i] = records[i].value end
    return concat(values, delimiter, 1, count)
end

-- 增加共享数据库的组件引用。
local function retain_db(db_name)
    db_refs[db_name] = (db_refs[db_name] or 0) + 1
end

-- 连接数据库，并在文件或格式变化时按一值一记录格式重建。
local function connect_db(
    db_name, tasks, config_sig, scheme_sigs, env_fmm_cache
)
    local files_sig = generate_files_signature(tasks)
    local current_signature = config_sig or ""
    local cached = db_instances[db_name]

    local function database_matches(db)
        if (db:meta_fetch("_format_ver") or "")
                ~= DB_FORMAT_VERSION
            or (db:meta_fetch("_replacer_files") or "")
                ~= files_sig
            or (db:meta_fetch("_replacer_union") or "")
                ~= current_signature
        then
            return false
        end

        for schema_id, signature in pairs(scheme_sigs) do
            if (db:meta_fetch(
                "_replacer_scheme/" .. schema_id
            ) or "") ~= signature
            then
                return false
            end
        end

        return true
    end

    if cached then
        local ok, same = pcall(database_matches, cached)

        if ok and same then
            retain_db(db_name)
            return cached
        end

        -- 初始化交叠期间不能关闭其他组件仍在使用的对象。
        if (db_refs[db_name] or 0) > 0 then
            retain_db(db_name)
            return cached
        end

        pcall(function() cached:close() end)
        db_instances[db_name] = nil
    end

    if not userdb then return nil end

    local db = userdb.LevelDb(db_name)
    if not db then return nil end

    if db:open_read_only() then
        if database_matches(db) then
            db_instances[db_name] = db
            retain_db(db_name)
            return db
        end

        db:close()
    end

    if not db:open() then return nil end

    -- 只清普通数据，保留既有 #@ 元数据。
    local cleared = db:empty(false)

    if cleared == false or not rebuild(tasks, db) then
        db:close()
        return nil
    end

    for key in pairs(env_fmm_cache) do env_fmm_cache[key] = nil end

    if not db:meta_update("_format_ver", DB_FORMAT_VERSION)
        or not db:meta_update("_replacer_files", files_sig)
        or not db:meta_update("_replacer_union", current_signature)
    then
        db:close()
        return nil
    end

    for schema_id, signature in pairs(scheme_sigs) do
        if not db:meta_update(
            "_replacer_scheme/" .. schema_id, signature
        ) then
            db:close()
            return nil
        end
    end

    if log and log.info then
        log.info("super_replacer: 联合配置数据已重载")
    end

    collectgarbage("collect")
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
    if db_instances[db_name] == db then
        db_instances[db_name] = nil
    end

    collectgarbage("collect")
    pcall(function() db:close() end)
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
                val = fetch_values(db, cache_key, "\t") or false
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
                val = fetch_values(db, cache_key, "\t") or false
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
    local shared_dir = rime_api.get_shared_data_dir()

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
            each_config_value(rule, OPTION_KEYS, function(value, is_scalar)
                if is_scalar and value:get_bool() == true then
                    triggers[#triggers + 1] = true
                    return
                end

                local str = value:get_string()
                if str and (not is_scalar or str ~= "true") then triggers[#triggers + 1] = str end
            end)
            if #triggers == 0 then goto continue_rule end

            -- 解析 tags
            local target_tags = nil
            each_config_value(rule, TAG_KEYS, function(value)
                local str = value:get_string()
                if str then
                    target_tags = target_tags or {}
                    target_tags[str] = true
                end
            end)

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
            each_config_value(rule, FILE_KEYS, function(value)
                local source = value:get_string()
                local path =
                    resolve_path(source, user_dir, shared_dir)

                if path then
                    tasks[#tasks + 1] = {
                        source = source,
                        path = path,
                        prefix = prefix,
                        conversion = conversion_map,
                        preedit_delim = preedit_delim
                    }
                end
            end)

            ::continue_rule::
        end
    end

    local merged_tasks, scheme_sigs, config_sig =
        merge_tasks(env, ns, tasks, user_dir, shared_dir)

    env.db = connect_db(
        db_name, merged_tasks, config_sig,
        scheme_sigs, env.fmm_cache
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
        local pos = s_find(p, delim, 1, true)
        if pos then return s_sub(p, 1, pos - 1), s_sub(p, pos + #delim) end
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

        local value = fetch_values(db, key, env.delimiter)
        fetch_cache[key] = value or false
        return value
    end

    local fmm_offsets, fmm_parts = env.fmm_offsets, env.fmm_parts
    local pending_texts = env.shared_pending
    local pending_comments = env.shared_pending_comments
    local shared_comments = env.shared_comments
    local main_results, aux_results = {}, {}

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

    local function emit_processed(cand, results, count_yield)
        for _, pc in ipairs(process_rules(cand, results)) do
            local key = trim_space(pc.text)
            if not global_yielded[key] then
                global_yielded[key] = true
                yield(pc)
                if count_yield then yield_count = yield_count + 1 end
            end
        end
    end

    if #always_cands == 0 and #lazy_cands == 0 then
        for cand in input:iter() do emit_processed(cand, main_results, false) end
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
                emit_processed(item.cand, aux_results, true)
            end
        end

        for _, item in ipairs(lazy_cands) do
            if not item.yielded then
                item.yielded = true
                if not group_fronted[item.group_key] then
                    emit_processed(item.cand, aux_results, true)
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

                            emit_processed(item.cand, aux_results, true)

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