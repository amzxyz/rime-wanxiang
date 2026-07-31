-- 万象家族 lua / 超级符号（super_symbols）
-- https://github.com/amzxyz/rime-wanxiang
--
-- /sym.<name>[.<mod>...]              精确匹配
-- /sym?<keyword> 或 /sym/<keyword>   模糊搜索
-- /emoji.* 同理
-- 选择「（字符分类）」候选时展开为该分类全部条目（processor 组件 *P）
local wanxiang = require("wanxiang/wanxiang")

local M = {}
local STATE = {
    loaded = false,
    loading = false,
    stores = nil
}

local find = string.find
local match = string.match
local gmatch = string.gmatch
local sub = string.sub
local lower = string.lower
local sort = table.sort

local function starts_with(text, prefix)
    return #text >= #prefix and sub(text, 1, #prefix) == prefix
end

local function split_dot(text)
    local parts = {}
    local start = 1

    while true do
        local pos = find(text, ".", start, true)
        if not pos then
            parts[#parts + 1] = sub(text, start)
            return parts
        end
        parts[#parts + 1] = sub(text, start, pos - 1)
        start = pos + 1
    end
end

local function dedup_list(list)
    local seen = {}
    local result = {}

    for i = 1, #list do
        local value = list[i]
        if not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end
    return result
end

local function new_store(cand_type)
    return {
        entries = {},
        root_map = {},
        root_list = {},
        cand_type = cand_type
    }
end

local function read_store(path, cand_type)
    local store = new_store(cand_type)
    local file, close = wanxiang.load_file_with_fallback(path, "r")
    if not file then return store end

    for line in file:lines() do
        if line ~= "" and not match(line, "^#") then
            local name, char = match(line, "^([^\t]+)\t([^\t]+)$")
            if name and char then
                local root
                local mods_list = {}
                local mods_set = {}

                for part in gmatch(name, "[^.]+") do
                    if not root then
                        root = part
                    else
                        mods_list[#mods_list + 1] = part
                        mods_set[part] = true
                    end
                end

                if root then
                    local root_entry = store.root_map[root]
                    if not root_entry then
                        root_entry = {
                            name = root,
                            bare = nil,
                            entries = {}
                        }
                        store.root_map[root] = root_entry
                        store.root_list[#store.root_list + 1] = root_entry
                    end

                    local entry = {
                        name = name,
                        search_name = find(name, "%u") and lower(name) or nil,
                        char = char,
                        mods_list = mods_list,
                        mods_set = mods_set
                    }

                    store.entries[#store.entries + 1] = entry
                    root_entry.entries[#root_entry.entries + 1] = entry
                    if #mods_list == 0 then
                        root_entry.bare = char
                    end
                end
            end
        end
    end

    close()
    return store
end

local function load_data(env)
    if STATE.loaded then
        return true
    end
    if STATE.loading then
        return false
    end
    STATE.loading = true

    local ok, err = pcall(function()
        local config = env.engine.schema.config
        local sym_path = config:get_string("super_symbols/data_sym") or "lua/data/codex_sym.txt"
        local emoji_path = config:get_string("super_symbols/data_emoji") or "lua/data/codex_emoji.txt"

        STATE.stores = {
            sym = read_store(sym_path, "super_sym"),
            emoji = read_store(emoji_path, "super_emoji")
        }
        STATE.loaded = true
    end)

    STATE.loading = false
    if not ok then
        if rime and rime.log and rime.log.error then
            rime.log.error("[super_symbols] load failed: " .. tostring(err))
        end
        return false
    end

    if rime and rime.log and rime.log.info then
        rime.log.info("[super_symbols] loaded sym=" .. #STATE.stores.sym.entries .. " emoji=" ..
                          #STATE.stores.emoji.entries)
    end
    return true
end

local function build_defs(config, prefix_sym, prefix_emoji)
    local list = config:get_list("super_symbols/triggers")
    if list and list.size > 0 then
        local defs = {}

        for i = 0, list.size - 1 do
            local path = "super_symbols/triggers/@" .. i
            local kind = config:get_string(path .. "/kind")
            local exact = config:get_string(path .. "/exact")

            if kind and exact and kind ~= "" and exact ~= "" then
                local label = config:get_string(path .. "/label") or
                                  (kind == "emoji" and "超级表情" or "超级符号")
                local marks = {}
                local mark_list = config:get_list(path .. "/marks")

                if mark_list then
                    for j = 0, mark_list.size - 1 do
                        local mark = config:get_string(path .. "/marks/@" .. j)
                        if mark and mark ~= "" then
                            marks[#marks + 1] = mark
                        end
                    end
                end
                if #marks == 0 then
                    marks = {"?", "/"}
                end

                defs[#defs + 1] = {
                    kind = kind,
                    exact = exact,
                    label = label,
                    marks = marks
                }
            end
        end

        if #defs > 0 then
            return defs
        end
    end

    return {{
        kind = "sym",
        exact = prefix_sym,
        label = "超级符号",
        marks = {"?", "/"}
    }, {
        kind = "emoji",
        exact = prefix_emoji,
        label = "超级表情",
        marks = {"?", "/"}
    }}
end

local function build_runtime(config)
    local prefix_sym = config:get_string("super_symbols/prefix_sym") or "/sym"
    local prefix_emoji = config:get_string("super_symbols/prefix_emoji") or "/emoji"
    local defs = build_defs(config, prefix_sym, prefix_emoji)
    local runtime = {
        triggers = {},
        tips = {},
        labels = {},
        max_candidates = config:get_int("super_symbols/max_candidates") or 120
    }

    for i = 1, #defs do
        local def = defs[i]
        runtime.labels[def.kind] = def.label
        runtime.tips[def.exact] = {
            text = def.label,
            comment = "~"
        }
        runtime.tips[def.exact .. "."] = {
            text = def.label,
            comment = "直接输入"
        }
        runtime.triggers[#runtime.triggers + 1] = {
            prefix = def.exact .. ".",
            kind = def.kind,
            mode = "exact"
        }

        for j = 1, #def.marks do
            local prefix = def.exact .. def.marks[j]
            runtime.tips[prefix] = {
                text = def.label,
                comment = "模糊搜索"
            }
            runtime.triggers[#runtime.triggers + 1] = {
                prefix = prefix,
                kind = def.kind,
                mode = "search"
            }
        end
    end
    return runtime
end

local function get_runtime(env)
    if not env.super_symbols_runtime then
        env.super_symbols_runtime = build_runtime(env.engine.schema.config)
    end
    return env.super_symbols_runtime
end

local function parse_trigger(input, triggers)
    for i = 1, #triggers do
        local trigger = triggers[i]
        if starts_with(input, trigger.prefix) then
            return trigger.mode, trigger.kind, sub(input, #trigger.prefix + 1)
        end
    end
    return nil, nil, nil
end

local function root_prefix_exists(store, prefix)
    for i = 1, #store.root_list do
        if starts_with(store.root_list[i].name, prefix) then
            return true
        end
    end
    return false
end

local function add_result(items, seen, text, comment, name, mods_count)
    local key = text .. "\t" .. comment
    if seen[key] then
        return
    end

    seen[key] = true
    items[#items + 1] = {
        text = text,
        comment = comment,
        name = name,
        mods_count = mods_count
    }
end

local function do_exact(query, store, kind_prefix)
    local parts = split_dot(query)
    local root = parts[1]

    if #parts >= 2 then
        local root_entry = store.root_map[root]
        if not root_entry then
            return root_prefix_exists(store, root) and {
                kind = "placeholder",
                code = root
            } or {
                kind = "nomatch"
            }
        end

        local middles = {}
        for i = 2, #parts - 1 do
            middles[#middles + 1] = parts[i]
        end
        middles = dedup_list(middles)

        local tail = parts[#parts]
        local items = {}
        local seen = {}

        for i = 1, #root_entry.entries do
            local entry = root_entry.entries[i]
            local accepted = true

            for j = 1, #middles do
                if not entry.mods_set[middles[j]] then
                    accepted = false
                    break
                end
            end

            if accepted and tail ~= "" then
                accepted = false
                for j = 1, #entry.mods_list do
                    if starts_with(entry.mods_list[j], tail) then
                        accepted = true
                        break
                    end
                end
            end

            if accepted then
                add_result(items, seen, entry.char, kind_prefix .. entry.name, entry.name, #entry.mods_list)
            end
        end

        sort(items, function(a, b)
            if a.mods_count ~= b.mods_count then
                return a.mods_count < b.mods_count
            end
            return a.name < b.name
        end)
        return {
            kind = "list",
            items = items
        }
    end

    local items = {}
    local seen = {}
    for i = 1, #store.root_list do
        local root_entry = store.root_list[i]
        if starts_with(root_entry.name, root) then
            local text = root_entry.bare or ("（字符分类）" .. root_entry.name)
            add_result(items, seen, text, kind_prefix .. root_entry.name, root_entry.name, 0)
        end
    end

    return #items > 0 and {
        kind = "list",
        items = items
    } or {
        kind = "nomatch"
    }
end

local function fuzzy_components(keyword)
    local components = dedup_list(split_dot(lower(keyword)))
    sort(components, function(a, b)
        return #a > #b
    end)
    return components
end

local function do_fuzzy(keyword, store, kind_prefix, limit)
    if not keyword or keyword == "" then
        return {
            kind = "need_keyword",
            items = {},
            matched = false
        }
    end

    local has_dot = find(keyword, ".", 1, true) ~= nil
    local components = has_dot and fuzzy_components(keyword) or nil
    local plain_keyword = has_dot and nil or lower(keyword)
    local items = {}
    local seen = {}
    local matched = false

    for i = 1, #store.entries do
        local entry = store.entries[i]
        local name = entry.search_name or entry.name
        local accepted

        if has_dot then
            accepted = true
            for j = 1, #components do
                if not find(name, components[j], 1, true) then
                    accepted = false
                    break
                end
            end
        else
            accepted = find(name, plain_keyword, 1, true) ~= nil or entry.char == keyword
        end

        if accepted then
            matched = true
            if limit == 0 then
                break
            end

            add_result(items, seen, entry.char, kind_prefix .. entry.name, entry.name, #entry.mods_list)

            -- 非点分搜索保持文件顺序，可在达到输出上限后立即停止。
            if not has_dot and limit > 0 and #items >= limit then
                break
            end
        end
    end

    if has_dot then
        sort(items, function(a, b)
            return a.name < b.name
        end)
        if limit > 0 then
            for i = #items, limit + 1, -1 do
                items[i] = nil
            end
        end
    end

    return {
        kind = "list",
        items = items,
        matched = matched
    }
end

local function yield_items(items, cand_type, seg, limit)
    if limit <= 0 then
        return
    end
    local count = #items < limit and #items or limit

    for i = 1, count do
        local item = items[i]
        yield(Candidate(cand_type, seg.start, seg._end, item.text, item.comment))
    end
end

function M.init(env)
    env.super_symbols_runtime = build_runtime(env.engine.schema.config)
    load_data(env)
end

function M.fini(env)
    env.super_symbols_runtime = nil
end

-- 选择「（字符分类）」候选时不真正上屏，而是把输入重写为
-- <前缀>.<根>. （悬垂点会列出该分类的全部条目），实现「展开分类」交互。
-- 该候选由 do_exact 在单根无裸字符时生成，其 text = "（字符分类）<根>"，
-- type 为 super_sym / super_emoji，据此可还原 kind 与前缀。
local P = {}

local CATEGORY_PREFIX = "（字符分类）"
local P_COMMIT = {
    [0x20] = true,
    [0xFF0D] = true,
    [0xFF8D] = true
} -- 空格 / 回车 / 小键盘回车
local K_NOOP, K_ACCEPT = 2, 1

-- 主键盘 1-9(0x31-0x39)/0(0x30) 与小键盘 1-9(0xFFB1-0xFFB9)/0(0xFFB0) 解析为序号（0 表示第 10 个）
local function digit_from_keycode(kc)
    if kc >= 0x31 and kc <= 0x39 then
        return kc - 0x30
    end
    if kc == 0x30 then
        return 0
    end
    if kc >= 0xFFB1 and kc <= 0xFFB9 then
        return kc - 0xFFB0
    end
    if kc == 0xFFB0 then
        return 0
    end
    return nil
end

local function build_kind_exact(config)
    local defs = build_defs(config, config:get_string("super_symbols/prefix_sym") or "/sym",
        config:get_string("super_symbols/prefix_emoji") or "/emoji")
    local map = {}
    for i = 1, #defs do
        map[defs[i].kind] = defs[i].exact
    end
    return map
end

function P.init(env)
    local config = env.engine.schema.config
    env.super_symbols_kind_exact = build_kind_exact(config)
    env.super_symbols_page_size = config:get_int("menu/page_size") or 6
end

function P.fini(env)
    env.super_symbols_kind_exact = nil
    env.super_symbols_page_size = nil
end

-- 命中分类候选时展开为 <前缀>.<根>. （悬垂点列出该分类全部条目）
local function expand_category(env, ctx, cand)
    local kind = (cand.type == "super_emoji") and "emoji" or "sym"
    local exact = (env.super_symbols_kind_exact and env.super_symbols_kind_exact[kind]) or ("/" .. kind)
    local root = sub(cand.text, #CATEGORY_PREFIX + 1)
    if root == "" then
        return K_NOOP
    end

    local new_query = exact .. "." .. root .. "."
    ctx:clear()
    if ctx.push_input then
        ctx:push_input(new_query)
    else
        ctx.input = new_query
    end
    return K_ACCEPT
end

function P.func(key, env)
    if key:release() or key:ctrl() or key:alt() or key:super() then
        return K_NOOP
    end

    local ctx = env.engine.context
    if not ctx:is_composing() or not ctx:has_menu() then
        return K_NOOP
    end

    local comp = ctx.composition
    local seg = comp and not comp:empty() and comp:back()
    if not seg or not seg.menu or seg.menu:empty() then
        return K_NOOP
    end

    local cand = nil
    if P_COMMIT[key.keycode] then
        -- 确认键：作用于当前高亮候选
        cand = ctx:get_selected_candidate()
    else
        -- 数字键：作用于所按键对应的候选（序号计算与超级处理器选词一致）
        local d = digit_from_keycode(key.keycode)
        if d == nil then
            return K_NOOP
        end
        if key:shift() then
            return K_NOOP
        end
        local dnum = (d == 0) and 10 or d
        local page_size = env.super_symbols_page_size or 6
        if dnum < 1 or dnum > page_size then
            return K_NOOP
        end
        local sel_index = seg.selected_index or 0
        local page_start = math.floor(sel_index / page_size) * page_size
        cand = seg:get_candidate_at(page_start + (dnum - 1))
    end

    if not cand or not cand.text then
        return K_NOOP
    end
    if not starts_with(cand.text, CATEGORY_PREFIX) then
        return K_NOOP
    end

    return expand_category(env, ctx, cand)
end

function M.func(input, seg, env)
    if not load_data(env) then
        return
    end

    local runtime = get_runtime(env)
    local mode_tip = runtime.tips[input]
    if mode_tip then
        yield(Candidate("super_sym", seg.start, seg._end, mode_tip.text, mode_tip.comment))
        return
    end

    local mode, kind, query = parse_trigger(input, runtime.triggers)
    if not mode then
        return
    end

    local store = STATE.stores[kind]
    local cand_type = store and store.cand_type or ("super_" .. kind)
    local kind_prefix = kind .. "."
    if not store then
        store = new_store(cand_type)
    end

    if mode == "exact" then
        local result = do_exact(query, store, kind_prefix)
        if result.kind == "nomatch" then
            yield(
                Candidate(cand_type, seg.start, seg._end, "（无匹配）", "请更换搜索词或改用模糊匹配"))
        elseif result.kind == "placeholder" then
            yield(Candidate(cand_type, seg.start, seg._end, "（字符分类）" .. result.code,
                kind_prefix .. result.code))
        elseif #result.items == 0 then
            yield(
                Candidate(cand_type, seg.start, seg._end, "（无匹配）", "请更换搜索词或改用模糊匹配"))
        else
            yield_items(result.items, cand_type, seg, runtime.max_candidates)
        end
    else
        local result = do_fuzzy(query, store, kind_prefix, runtime.max_candidates)
        if not result.matched then
            yield(Candidate(cand_type, seg.start, seg._end, "（无匹配）", "请更换搜索词"))
        else
            yield_items(result.items, cand_type, seg, runtime.max_candidates)
        end
    end
end

return {
    T = M,
    P = P
}