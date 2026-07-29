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

local DB_FORMAT_VERSION = "7"
local OPTION_KEYS = {"option", "options"}
local TAG_KEYS = {"tag", "tags"}
local FILE_KEYS = {"files", "file"}
local db_instances = {}
local db_refs = {}

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

-- 清空并复用数组，减少热点路径临时分配。
local function clear_array(t)
    for i = #t, 1, -1 do t[i] = nil end
end

-- 遍历配置节点中允许使用的单值或列表值。
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

-- 去除字符串首尾空白。
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

-- 计算字节串的稳定摘要，避免把原始文本写入元数据。
local function hash_bytes(hash, text)
    for i = 1, #text do
        hash = (hash * 131 + s_byte(text, i)) % 4294967296
    end
    return hash
end

-- 采样文件特征并只返回安全的十六进制摘要。
local function generate_files_signature(tasks)
    local sig_parts = {}

    for _, task in ipairs(tasks) do
        local f = open(task.path, "rb")

        if f then
            local size = f:seek("end") or 0
            local hash = 2166136261

            hash = hash_bytes(hash, task.path or "")
            hash = hash_bytes(hash, task.prefix or "")
            hash = hash_bytes(hash, tostring(size))

            if size > 0 then
                f:seek("set", 0)
                hash = hash_bytes(hash, f:read(64) or "")

                local mid_pos = math.floor(size / 2) - 32
                if mid_pos < 0 then mid_pos = 0 end
                f:seek("set", mid_pos)
                hash = hash_bytes(hash, f:read(64) or "")

                local tail_pos = size - 64
                if tail_pos < 0 then tail_pos = 0 end
                f:seek("set", tail_pos)
                hash = hash_bytes(hash, f:read(64) or "")
            end

            f:close()
            insert(sig_parts, s_format("%08x:%d", hash, size))
        end
    end

    return concat(sig_parts, "|")
end

-- 生成只包含十六进制字符的规则配置摘要。
local function generate_config_signature(rules)
    local hash = 2166136261

    for _, rule in ipairs(rules) do
        hash = hash_bytes(hash, tostring(rule.t9_opt or false))
        hash = hash_bytes(hash, "\0")
        hash = hash_bytes(hash, rule.cand_type or "")
        hash = hash_bytes(hash, "\0")
        hash = hash_bytes(hash, rule.prefix or "")
        hash = hash_bytes(hash, "\0")
        hash = hash_bytes(hash, rule.mode or "")
        hash = hash_bytes(hash, "\0")
    end

    return s_format("%08x", hash)
end

-- 重建数据库：每个 value 独立存储，c 保存同一逻辑 key 下的位置。
local function rebuild(tasks, db)
    local positions = {}
    local seen_records = {}

    for _, task in ipairs(tasks) do
        local txt_path = task.path
        local prefix = task.prefix
        local conversion = task.conversion
        local p_delim = task.preedit_delim

        local f = open(txt_path, "r")
        if f then
            for line in f:lines() do
                if line ~= "" and not s_match(line, "^%s*#") then
                    local k, values = s_match(line, "^([^\t]+)\t+(.+)")
                    if k and values then
                        local orig_k = k
                        if conversion then k = s_gsub(k, ".", conversion) end

                        local db_key = prefix .. k

                        for v in s_gmatch(values, "[^\t]+") do
                            v = s_match(v, "^%s*(.-)%s*$")

                            if v ~= "" then
                                if p_delim and p_delim ~= ""
                                    and not s_find(v, p_delim, 1, true)
                                then
                                    v = v .. p_delim .. orig_k
                                end

                                local raw_key =
                                    userdb.make_record_key(db_key, v)

                                if raw_key and not seen_records[raw_key] then
                                    seen_records[raw_key] = true

                                    local position =
                                        (positions[db_key] or 0) + 1
                                    positions[db_key] = position

                                    local tail = userdb.make_record_tail(
                                        position, 0, 0
                                    )

                                    if not db:update_raw(raw_key, tail) then
                                        f:close()
                                        return false
                                    end
                                end
                            end
                        end
                    end
                end
            end

            f:close()
        end
    end

    return true
end

-- 从记录尾部读取候选在当前逻辑 key 下的位置。
local function parse_position(tail)
    if type(tail) ~= "string" then return 0 end
    return tonumber(s_match(tail, "c=([^%s\t]+)")) or 0
end

-- 按逻辑 key 查询全部 value，并按固定位置恢复源文件顺序。
local function fetch_values(db, key, delimiter)
    local accessor = db:query(key .. userdb.RECORD_KEY_SEPARATOR)
    if not accessor then return nil end

    local records = {}
    local count = 0

    for record_key, value, tail in accessor:iter() do
        if record_key ~= key then break end

        count = count + 1
        records[count] = {
            value = value,
            position = parse_position(tail),
            index = count,
        }
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

-- 增加共享数据库的组件引用计数。
local function retain_db(db_name)
    db_refs[db_name] = (db_refs[db_name] or 0) + 1
end

-- 连接数据库，并在文件或格式变化时按新键值结构重建。
local function connect_db(db_name, tasks, config_sig, env_fmm_cache)
    local current_signature =
        generate_files_signature(tasks) .. "|" .. (config_sig or "")
    local cached = db_instances[db_name]

    if cached then
        local ok, same = pcall(function()
            return (cached:meta_fetch("_format_ver") or "")
                    == DB_FORMAT_VERSION
                and (cached:meta_fetch("_files_sig") or "")
                    == current_signature
        end)

        if ok and same then
            retain_db(db_name)
            return cached
        end

        -- 正在被其他组件使用时不能强行关闭底层数据库。
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
        local same = (db:meta_fetch("_format_ver") or "")
                == DB_FORMAT_VERSION
            and (db:meta_fetch("_files_sig") or "")
                == current_signature

        if same then
            db_instances[db_name] = db
            retain_db(db_name)
            return db
        end

        db:close()
    end

    if not db:open() then return nil end
    if not db:empty(true) then
        db:close()
        return nil
    end

    if not rebuild(tasks, db) then
        db:close()
        return nil
    end

    for key in pairs(env_fmm_cache) do env_fmm_cache[key] = nil end

    db:meta_update("_format_ver", DB_FORMAT_VERSION)
    db:meta_update("_files_sig", current_signature)

    if log and log.info then
        log.info("super_replacer: 键值数据已重载，最新特征已记录")
    end

    db:close()

    if not db:open_read_only() then return nil end

    db_instances[db_name] = db
    retain_db(db_name)
    return db
end

-- 释放组件引用，并在最后一个使用者退出时关闭数据库。
local function release_db(env)
    local db = env.db
    local db_name = env.db_name

    if not db or not db_name then
        env.db = nil
        env.db_name = nil
        return
    end

    env.db = nil
    env.db_name = nil

    local refs = (db_refs[db_name] or 1) - 1
    if refs > 0 then
        db_refs[db_name] = refs
        return
    end

    db_refs[db_name] = nil

    if db_instances[db_name] == db then
        db_instances[db_name] = nil
    end

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
-- 初始化规则、数据文件任务、缓存和只读数据库。
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

    local function resolve_path(relative)
        if not relative then return nil end
        local user_path = user_dir .. "/" .. relative
        local f = open(user_path, "r")
        if f then f:close(); return user_path end
        local shared_path = shared_dir .. "/" .. relative
        f = open(shared_path, "r")
        if f then f:close(); return shared_path end
        return user_path
    end

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
                local path = resolve_path(value:get_string())
                if path then
                    tasks[#tasks + 1] = {
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

    local config_sig = generate_config_signature(env.rules)
    env.db = connect_db(db_name, tasks, config_sig, env.fmm_cache)
    env.db_name = env.db and db_name or nil
end

-- 释放当前组件持有的数据库和缓存引用。
function M.fini(env)
    release_db(env)
    env.fmm_cache = nil
    env.fmm_offsets = nil
    env.fmm_parts = nil
    env.shared_pending = nil
    env.shared_pending_comments = nil
    env.shared_comments = nil
    env.rules = nil
end

--解析连接符工具函数
-- 按连接符拆分候选文本和预编辑文本。
local function parse_item(p, delim)
    if delim and delim ~= "" then
        local pos = s_find(p, delim, 1, true)
        if pos then return s_sub(p, 1, pos - 1), s_sub(p, pos + #delim) end
    end
    return p, nil
end

-- [Core Function] 核心逻辑
-- 根据已启用规则转换、追加、注释或插入候选。
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

    -- 查询并缓存同一逻辑 key 下的全部 value。
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