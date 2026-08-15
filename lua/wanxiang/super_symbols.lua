-- 万象家族 lua / 超级符号（super_symbols）
-- https://github.com/amzxyz/rime-wanxiang
-- version: v2.3.5
--
-- /sym.<path>                     路径前缀查询
-- /sym?<keyword> / /sym/<keyword> 全局模糊搜索
-- /sym.<path>?<keyword>            当前路径内模糊搜索
-- /sym.<path>/<keyword>            同上
-- /emoji.*                         同理
--
-- 设计：
-- 1. 有真实候选时只输出真实字符，Segment.prompt 仅补充数量与下一步信息。
-- 2. 无真实候选时输出一个状态候选承接当前状态，避免候选框反复出现/消失。
-- 3. 精确查询与模糊查询均支持公共前缀递进补全，但不会自动跨过“.”路径边界。
-- 4. “.”负责路径递进，“?”/“/”可在任意路径位置切换为模糊搜索。
-- 5. 局部模糊只显示相对当前 scope 的候选注释。

local wanxiang = require("wanxiang/wanxiang")

local M = {}

local function starts_with(text, prefix)
    return #text >= #prefix and text:sub(1, #prefix) == prefix
end

local function split_nonempty(text, separator)
    local parts = {}
    local start_pos = 1

    while true do
        local separator_pos = text:find(separator, start_pos, true)
        if not separator_pos then
            local part = text:sub(start_pos)
            if part ~= "" then
                parts[#parts + 1] = part
            end
            return parts
        end

        local part = text:sub(start_pos, separator_pos - 1)
        if part ~= "" then
            parts[#parts + 1] = part
        end
        start_pos = separator_pos + #separator
    end
end

local function new_store(candidate_type)
    return {
        candidate_type = candidate_type,
        entries = {}
    }
end

local function read_store(path, candidate_type)
    local store = new_store(candidate_type)
    local file, close_file = wanxiang.load_file_with_fallback(path, "r")
    if not file then
        log.error("[super_symbols] cannot open data: " .. path)
        return store
    end

    local source_order = 0
    for line in file:lines() do
        if line ~= "" and not line:match("^#") then
            local name, char = line:match("^([^\t]+)\t([^\t]+)$")
            if name and char then
                source_order = source_order + 1
                store.entries[#store.entries + 1] = {
                    name = name,
                    lower_name = name:lower(),
                    char = char,
                    source_order = source_order
                }
            end
        end
    end

    close_file()
    return store
end

local function load_stores(env)
    if env.super_symbols_stores then
        return true
    end
    if env.super_symbols_loading then
        return false
    end

    env.super_symbols_loading = true

    local ok, err = pcall(function()
        local config = env.engine.schema.config
        local symbol_path = config:get_string("super_symbols/data_sym") or "lua/data/codex_sym.txt"
        local emoji_path = config:get_string("super_symbols/data_emoji") or "lua/data/codex_emoji.txt"

        env.super_symbols_stores = {
            sym = read_store(symbol_path, "super_sym"),
            emoji = read_store(emoji_path, "super_emoji")
        }
    end)

    env.super_symbols_loading = nil

    if not ok then
        env.super_symbols_stores = nil
        log.error("[super_symbols] load failed: " .. tostring(err))
        return false
    end

    return true
end

local function read_search_marks(config, path)
    local marks = {}
    local list = config:get_list(path .. "/marks")

    if list then
        for i = 0, list.size - 1 do
            local mark = config:get_string(path .. "/marks/@" .. i)
            if mark and mark ~= "" then
                marks[#marks + 1] = mark
            end
        end
    end

    if #marks == 0 then
        marks = {"?", "/"}
    end

    return marks
end

local function build_trigger_defs(config)
    local configured = config:get_list("super_symbols/triggers")
    local trigger_defs = {}

    if configured and configured.size > 0 then
        for i = 0, configured.size - 1 do
            local path = "super_symbols/triggers/@" .. i
            local kind = config:get_string(path .. "/kind")
            local exact = config:get_string(path .. "/exact")

            if kind and kind ~= "" and exact and exact ~= "" then
                trigger_defs[#trigger_defs + 1] = {
                    kind = kind,
                    exact = exact,
                    label = config:get_string(path .. "/label") or
                        (kind == "emoji" and "超级表情" or "超级符号"),
                    search_marks = read_search_marks(config, path)
                }
            end
        end
    end

    if #trigger_defs == 0 then
        trigger_defs = {
            {
                kind = "sym",
                exact = config:get_string("super_symbols/prefix_sym") or "/sym",
                label = "超级符号",
                search_marks = {"?", "/"}
            },
            {
                kind = "emoji",
                exact = config:get_string("super_symbols/prefix_emoji") or "/emoji",
                label = "超级表情",
                search_marks = {"?", "/"}
            }
        }
    end

    table.sort(trigger_defs, function(a, b)
        return #a.exact > #b.exact
    end)

    return trigger_defs
end

local function build_runtime(config)
    return {
        trigger_defs = build_trigger_defs(config),
        max_candidates = config:get_int("super_symbols/max_candidates") or 120
    }
end

local function get_runtime(env)
    if not env.super_symbols_runtime then
        env.super_symbols_runtime = build_runtime(env.engine.schema.config)
    end
    return env.super_symbols_runtime
end

local function find_first_mark(text, marks)
    local first_pos
    local first_mark

    for i = 1, #marks do
        local mark = marks[i]
        local pos = text:find(mark, 1, true)
        if pos and (not first_pos or pos < first_pos or (pos == first_pos and #mark > #first_mark)) then
            first_pos = pos
            first_mark = mark
        end
    end

    return first_pos, first_mark
end

-- 返回统一查询对象：
-- { mode="tip"|"exact"|"fuzzy", kind, label, query, scope }
local function parse_query(input, runtime)
    for i = 1, #runtime.trigger_defs do
        local trigger = runtime.trigger_defs[i]

        if input == trigger.exact then
            return {
                mode = "tip",
                kind = trigger.kind,
                label = trigger.label,
                query = "",
                scope = ""
            }
        end

        -- 全局模糊：/sym?xxx / /sym/xxx
        for j = 1, #trigger.search_marks do
            local fuzzy_prefix = trigger.exact .. trigger.search_marks[j]
            if starts_with(input, fuzzy_prefix) then
                return {
                    mode = "fuzzy",
                    kind = trigger.kind,
                    label = trigger.label,
                    query = input:sub(#fuzzy_prefix + 1),
                    scope = ""
                }
            end
        end

        -- 路径查询，以及路径内模糊：/sym.xxx?yyy
        local exact_prefix = trigger.exact .. "."
        if starts_with(input, exact_prefix) then
            local path_input = input:sub(#exact_prefix + 1)
            local mark_pos, mark = find_first_mark(path_input, trigger.search_marks)

            if mark_pos then
                return {
                    mode = "fuzzy",
                    kind = trigger.kind,
                    label = trigger.label,
                    query = path_input:sub(mark_pos + #mark),
                    scope = path_input:sub(1, mark_pos - 1)
                }
            end

            return {
                mode = "exact",
                kind = trigger.kind,
                label = trigger.label,
                query = path_input,
                scope = ""
            }
        end
    end

    return nil
end

local function set_segment_prompt(context, text)
    local composition = context and context.composition
    local segment = composition and not composition:empty() and composition:back() or nil
    if segment then
        segment.prompt = text or ""
    end
end

local function collect_prefix_matches(query, store)
    local matches = {}

    for i = 1, #store.entries do
        local entry = store.entries[i]
        if starts_with(entry.name, query) then
            matches[#matches + 1] = entry
        end
    end

    return matches
end

local function common_prefix_pair(a, b)
    local length = math.min(#a, #b)
    local index = 1

    while index <= length and a:sub(index, index) == b:sub(index, index) do
        index = index + 1
    end

    return a:sub(1, index - 1)
end

local function longest_common_prefix(values)
    if #values == 0 then
        return ""
    end

    local common = values[1]
    for i = 2, #values do
        common = common_prefix_pair(common, values[i])
        if common == "" then
            break
        end
    end

    return common
end

local function longest_entry_prefix(entries, name_getter)
    local values = {}
    for i = 1, #entries do
        values[#values + 1] = name_getter(entries[i])
    end
    return longest_common_prefix(values)
end

-- 自动补全只推进当前 token；遇到“.”立即停下，把路径/模糊选择权留给用户。
local function completion_suffix(typed, common)
    if #common <= #typed or not starts_with(common, typed) then
        return ""
    end

    local suffix = common:sub(#typed + 1)
    local dot_pos = suffix:find(".", 1, true)
    if dot_pos then
        suffix = suffix:sub(1, dot_pos - 1)
    end

    return suffix
end

local function path_after_scope(path, scope)
    if scope == "" then
        return path
    end

    local relative = path:sub(#scope + 1)
    if relative:sub(1, 1) == "." then
        relative = relative:sub(2)
    end
    return relative
end

local function fuzzy_terms(keyword)
    local lower_keyword = keyword:lower()
    if not lower_keyword:find(".", 1, true) then
        return nil, lower_keyword
    end

    return split_nonempty(lower_keyword, "."), lower_keyword
end

local function fuzzy_text_matches(search_text, terms, plain_keyword)
    if terms then
        if #terms == 0 then
            return false
        end
        for i = 1, #terms do
            if not search_text:find(terms[i], 1, true) then
                return false
            end
        end
        return true
    end

    return search_text:find(plain_keyword, 1, true) ~= nil
end

local function collect_fuzzy_matches(keyword, scope, store)
    if keyword == "" then
        return {}
    end

    local terms, plain_keyword = fuzzy_terms(keyword)
    local matches = {}

    for i = 1, #store.entries do
        local entry = store.entries[i]
        local lower_scope = scope:lower()
        if scope == "" or starts_with(entry.lower_name, lower_scope) then
            local search_text = path_after_scope(entry.lower_name, lower_scope)
            local matched = fuzzy_text_matches(search_text, terms, plain_keyword)

            if not matched and scope == "" and entry.char == keyword then
                matched = true
            end

            if matched then
                matches[#matches + 1] = entry
            end
        end
    end

    return matches
end

local function fuzzy_rank(entry, keyword, scope)
    local search_text = path_after_scope(entry.lower_name, scope:lower())
    local lower_keyword = keyword:lower()

    if scope == "" and entry.char == keyword then
        return 0
    end
    if search_text == lower_keyword then
        return 1
    end
    if starts_with(search_text, lower_keyword) then
        return 2
    end

    local components = split_nonempty(search_text, ".")
    for i = 1, #components do
        if starts_with(components[i], lower_keyword) then
            return 3
        end
    end

    return 4
end

local function candidate_comment(entry, scope)
    if scope ~= "" then
        local relative = path_after_scope(entry.name, scope)
        return relative ~= "" and relative or entry.name
    end
    return entry.name
end

local function build_items(entries, scope, ranking)
    local items = {}
    local seen = {}

    for i = 1, #entries do
        local entry = entries[i]
        local comment = candidate_comment(entry, scope)
        local dedup_key = entry.char .. "\t" .. comment

        if not seen[dedup_key] then
            seen[dedup_key] = true
            items[#items + 1] = {
                text = entry.char,
                comment = comment,
                name = entry.name,
                source_order = entry.source_order,
                rank = ranking and ranking(entry) or 0
            }
        end
    end

    return items
end

local function sort_exact_items(items, query)
    table.sort(items, function(a, b)
        local a_exact = a.name == query
        local b_exact = b.name == query
        if a_exact ~= b_exact then
            return a_exact
        end
        if #a.name ~= #b.name then
            return #a.name < #b.name
        end
        return a.source_order < b.source_order
    end)
end

local function sort_fuzzy_items(items)
    table.sort(items, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        if #a.name ~= #b.name then
            return #a.name < #b.name
        end
        return a.source_order < b.source_order
    end)
end

local function has_path_children(query, matches)
    if query == "" then
        return false
    end

    local child_prefix = query .. "."
    for i = 1, #matches do
        if starts_with(matches[i].name, child_prefix) then
            return true
        end
    end

    return false
end

local function result_count_text(total, limit)
    if limit > 0 and total > limit then
        return total .. " 条 · 前 " .. limit
    end
    return total .. " 条"
end

local function set_exact_prompt(context, total, limit, has_children)
    local parts = {result_count_text(total, limit)}
    if has_children then
        parts[#parts + 1] = ".路径"
    end
    parts[#parts + 1] = "?搜索"
    set_segment_prompt(context, "〔" .. table.concat(parts, " · ") .. "〕")
end

local function set_fuzzy_prompt(context, total, limit, scope)
    local count_text = result_count_text(total, limit)
    if scope ~= "" then
        set_segment_prompt(context, "〔" .. scope .. " · " .. count_text .. "〕")
    else
        set_segment_prompt(context, "〔" .. count_text .. "〕")
    end
end

local function yield_items(items, candidate_type, segment, limit)
    if limit <= 0 then
        return
    end

    local count = math.min(#items, limit)
    for i = 1, count do
        local item = items[i]
        yield(Candidate(candidate_type, segment.start, segment._end, item.text, item.comment))
    end
end

-- 无真实结果时用单个状态候选承接提示，保持候选区连续稳定。
local function yield_state_candidate(context, segment, kind, text, comment)
    set_segment_prompt(context, "")
    local candidate_type = "super_" .. kind .. "_hint"
    yield(Candidate(candidate_type, segment.start, segment._end, text, comment or ""))
end

local function exact_autofill_suffix(query, store)
    if query == "" then
        return ""
    end

    local matches = collect_prefix_matches(query, store)
    if #matches == 0 then
        return ""
    end

    local common = longest_entry_prefix(matches, function(entry)
        return entry.name
    end)

    return completion_suffix(query, common)
end

-- 模糊模式只有在“所有当前命中都从关键词开头”时才补全。
-- 这样不会把 contains 搜索误改成 prefix 搜索，也不会改变当前结果集合。
local function fuzzy_autofill_suffix(keyword, scope, store)
    if keyword == "" or keyword:find(".", 1, true) then
        return ""
    end

    local matches = collect_fuzzy_matches(keyword, scope, store)
    if #matches == 0 then
        return ""
    end

    local lower_keyword = keyword:lower()
    local relative_names = {}

    for i = 1, #matches do
        local relative = path_after_scope(matches[i].lower_name, scope:lower())
        if not starts_with(relative, lower_keyword) then
            return ""
        end
        relative_names[#relative_names + 1] = relative
    end

    local common = longest_common_prefix(relative_names)
    return completion_suffix(lower_keyword, common)
end

local function try_autofill(env, context)
    if env.super_symbols_autofill_busy then
        return
    end

    local input = context and context.input or ""
    if input == "" then
        return
    end

    local runtime = get_runtime(env)
    local query = parse_query(input, runtime)
    if not query or query.mode == "tip" or query.query == "" then
        return
    end

    if not load_stores(env) then
        return
    end

    local store = env.super_symbols_stores and env.super_symbols_stores[query.kind]
    if not store then
        return
    end

    local suffix
    if query.mode == "exact" then
        suffix = exact_autofill_suffix(query.query, store)
    elseif query.mode == "fuzzy" then
        suffix = fuzzy_autofill_suffix(query.query, query.scope, store)
    end

    if not suffix or suffix == "" then
        return
    end

    local target = input .. suffix
    if env.super_symbols_autofill_target == target then
        return
    end

    env.super_symbols_autofill_busy = true
    env.super_symbols_autofill_target = target

    local ok, err = pcall(function()
        context:push_input(suffix)
    end)

    env.super_symbols_autofill_busy = nil

    if not ok then
        env.super_symbols_autofill_target = nil
        log.error("[super_symbols] push_input failed: " .. tostring(err))
    end
end

local function on_context_update(env, context)
    local input = context and context.input or ""
    local previous_input = env.super_symbols_last_input
    env.super_symbols_last_input = input

    if env.super_symbols_autofill_target and input == env.super_symbols_autofill_target then
        env.super_symbols_autofill_target = nil
    end

    -- 用户主动删除时尊重当前编辑结果，不把刚删掉的自动补全立即补回来。
    if previous_input and #input < #previous_input then
        env.super_symbols_autofill_suppressed_input = input
        return
    end

    -- 同一输入状态下，即使 Context 因其他原因再次 update，也继续保持可编辑状态。
    if env.super_symbols_autofill_suppressed_input then
        if input == env.super_symbols_autofill_suppressed_input then
            return
        end
        env.super_symbols_autofill_suppressed_input = nil
    end

    try_autofill(env, context)
end

function M.init(env)
    env.super_symbols_runtime = build_runtime(env.engine.schema.config)
    env.super_symbols_stores = nil
    env.super_symbols_loading = nil
    env.super_symbols_autofill_busy = nil
    env.super_symbols_autofill_target = nil
    env.super_symbols_autofill_suppressed_input = nil
    env.super_symbols_last_input = nil
    env.super_symbols_update_connection = nil

    load_stores(env)

    local context = env.engine and env.engine.context
    if context and context.update_notifier then
        local ok, connection_or_err = pcall(function()
            return context.update_notifier:connect(function(updated_context)
                on_context_update(env, updated_context)
            end)
        end)

        if ok then
            env.super_symbols_update_connection = connection_or_err
        else
            log.error("[super_symbols] update_notifier connect failed: " .. tostring(connection_or_err))
        end
    end
end

function M.fini(env)
    local connection = env.super_symbols_update_connection
    if connection and connection.disconnect then
        pcall(function()
            connection:disconnect()
        end)
    end

    env.super_symbols_update_connection = nil
    env.super_symbols_runtime = nil
    env.super_symbols_stores = nil
    env.super_symbols_loading = nil
    env.super_symbols_autofill_busy = nil
    env.super_symbols_autofill_target = nil
    env.super_symbols_autofill_suppressed_input = nil
    env.super_symbols_last_input = nil
end

function M.func(input, segment, env)
    local context = env.engine.context
    local runtime = get_runtime(env)
    local query = parse_query(input, runtime)
    if not query then
        return
    end

    if not load_stores(env) then
        yield_state_candidate(context, segment, query.kind, "数据加载失败", "检查数据文件与配置")
        return
    end

    if query.mode == "tip" then
        yield_state_candidate(
            context,
            segment,
            query.kind,
            query.label,
            ". 精确搜索  ·  ? 模糊搜索"
        )
        return
    end

    local store = env.super_symbols_stores[query.kind]
    if not store then
        yield_state_candidate(context, segment, query.kind, "数据不可用", "检查数据配置")
        return
    end

    if query.mode == "exact" then
        local matches = collect_prefix_matches(query.query, store)
        if #matches == 0 then
            yield_state_candidate(context, segment, query.kind, "无匹配", "退格修改 · 可改用模糊搜索")
            return
        end

        local items = build_items(matches, "")
        sort_exact_items(items, query.query)
        set_exact_prompt(
            context,
            #items,
            runtime.max_candidates,
            has_path_children(query.query, matches)
        )
        yield_items(items, store.candidate_type, segment, runtime.max_candidates)
        return
    end

    -- 模糊入口尚未输入关键词时，用状态候选保持菜单连续。
    if query.query == "" then
        if query.scope ~= "" then
            yield_state_candidate(
                context,
                segment,
                query.kind,
                "模糊搜索",
                "范围 " .. query.scope .. " · 继续输入关键词"
            )
        else
            yield_state_candidate(context, segment, query.kind, "模糊搜索", "继续输入关键词")
        end
        return
    end

    local matches = collect_fuzzy_matches(query.query, query.scope, store)
    if #matches == 0 then
        local comment = query.scope ~= "" and ("范围 " .. query.scope .. " · 修改关键词") or "修改关键词"
        yield_state_candidate(context, segment, query.kind, "无匹配", comment)
        return
    end

    local items = build_items(matches, query.scope, function(entry)
        return fuzzy_rank(entry, query.query, query.scope)
    end)
    sort_fuzzy_items(items)
    set_fuzzy_prompt(context, #items, runtime.max_candidates, query.scope)
    yield_items(items, store.candidate_type, segment, runtime.max_candidates)
end

return M
