-- 万象家族 lua / 超级符号（super_symbols）
-- 来源：https://github.com/typst/codex  (符号命名 + 修饰符体系 + best_match 模糊匹配)
--
-- 数据格式：
--   lua/data/codex_sym.txt    每行: typst_name<TAB>char
--   lua/data/codex_emoji.txt  同上
--   typst_name 是完整的 Typst 写法（如 arrow.r.double、chess.king.white），只有一个标识符字段。
--
-- 触发方式：
--   /sym.<name>[.<mod>...]   精确匹配 + best_match 模糊匹配（修饰符可省略、顺序无关）
--   /sym?<keyword> 或 /sym/<keyword>   模糊搜索
--   /emoji.* 同理
--
-- 模式提示：仅输入 /sym /sym. /sym? /sym/ /emoji 等前缀时，候选区显示引导提示：
--   /sym     → 超级符号
--   /sym.    → 超级符号：直输
--   /sym?    → 超级符号：搜索
--   /sym/    → 超级符号：搜索
--   /emoji   → 超级表情
--   /emoji.  → 超级表情：直输
--   /emoji?  → 超级表情：搜索
--   /emoji/  → 超级表情：搜索
--
-- 候选注释显示完整 Typst 代码（即 typst_name 本身），并强制显示：
--   super_comment_preedit.lua 识别 candidate.type == "super_sym" 或 "super_emoji" 时跳过清空逻辑。
local wanxiang = require("wanxiang/wanxiang")

local M = {}

-- ===== 数据结构 =====
M.name_to_char_sym = nil
M.name_to_char_emoji = nil
M.entries_sym = nil
M.entries_emoji = nil
M.by_prefix_sym = nil
M.by_prefix_emoji = nil
M.loaded = false
M.load_lock = false

---把点分修饰符字符串解析为 set
local function parse_modset(s)
    local set = {}
    if s and s ~= "" then
        for part in s:gmatch("[^.]+") do
            set[part] = true
        end
    end
    return set
end

local function is_subset(a, b)
    for k, _ in pairs(a) do
        if not b[k] then
            return false
        end
    end
    return true
end

local function common_count(a, b)
    local n = 0
    for k, _ in pairs(a) do
        if b[k] then
            n = n + 1
        end
    end
    return n
end

local function set_size(s)
    local n = 0
    for _ in pairs(s) do
        n = n + 1
    end
    return n
end

---best_match：在候选中选最佳匹配
---规则：候选必须是查询的超集（query ⊆ candidate）；优先共同修饰符多，其次总修饰符少
local function best_match(query_set, candidates)
    local best = nil
    local best_common = -1
    local best_total = 1e9
    for _, c in ipairs(candidates) do
        if is_subset(query_set, c.mods_set) then
            local common = common_count(query_set, c.mods_set)
            local total = set_size(c.mods_set)
            if common > best_common or (common == best_common and total < best_total) then
                best = c
                best_common = common
                best_total = total
            end
        end
    end
    return best
end

---读取数据文件
---格式：typst_name<TAB>char
local function read_data_file(path)
    local f = io.open(path, "r")
    if not f then
        return {}
    end
    local entries = {}
    for line in f:lines() do
        if line and not line:match("^#") and line ~= "" then
            local name, char = line:match("^([^\t]+)\t([^\t]+)$")
            if name and char then
                table.insert(entries, {
                    name = name,
                    char = char,
                    mods_set = parse_modset(name)
                })
            end
        end
    end
    f:close()
    return entries
end

---构建索引：name_to_char + by_prefix + by_valid
---by_prefix[prefix] = 该前缀下所有变体的列表（mods_set 为相对前缀的修饰符集合）
---by_valid[prefix]  = 该前缀下所有合法修饰符的并集（供 parse_query 直接查表，免去每次重算）
---边遍历条目边按前缀分组并累计 valid 并集，单次 O(条目数 × 平均点分段数)，无二次扫描
local function build_index(entries)
    local name_to_char = {}
    local by_prefix = {}
    local by_valid = {}
    for _, e in ipairs(entries) do
        name_to_char[e.name] = e.char
        local parts = {}
        for p in e.name:gmatch("[^.]+") do
            parts[#parts + 1] = p
        end
        local acc = {}
        for i = 1, #parts - 1 do
            acc[i] = parts[i]
            local prefix = table.concat(acc, ".")
            local list = by_prefix[prefix]
            if not list then
                list = {}
                by_prefix[prefix] = list
            end
            local ms = parse_modset(e.name:sub(#prefix + 2))
            list[#list + 1] = {
                name = e.name,
                char = e.char,
                mods_set = ms
            }
            local valid = by_valid[prefix]
            if not valid then
                valid = {}
                by_valid[prefix] = valid
            end
            for m, _ in pairs(ms) do
                valid[m] = true
            end
        end
    end
    return name_to_char, by_prefix, by_valid
end

---加载所有数据
function M.load(env)
    if M.loaded then
        return
    end
    if M.load_lock then
        return
    end
    M.load_lock = true

    local config = env.engine.schema.config
    local function resolve(p)
        if not p then
            return nil
        end
        local user = rime_api.get_user_data_dir() .. "/" .. p
        local f = io.open(user, "r")
        if f then
            f:close();
            return user
        end
        local shared = rime_api.get_shared_data_dir() .. "/" .. p
        return shared
    end

    local sym_path = resolve(config:get_string("super_symbols/data_sym") or "lua/data/codex_sym.txt")
    local emoji_path = resolve(config:get_string("super_symbols/data_emoji") or "lua/data/codex_emoji.txt")

    local sym_entries = sym_path and read_data_file(sym_path) or {}
    local emoji_entries = emoji_path and read_data_file(emoji_path) or {}

    M.entries_sym = sym_entries
    M.entries_emoji = emoji_entries
    M.name_to_char_sym, M.by_prefix_sym, M.by_valid_sym = build_index(sym_entries)
    M.name_to_char_emoji, M.by_prefix_emoji, M.by_valid_emoji = build_index(emoji_entries)
    M.loaded = true
    M.load_lock = false
    rime.log.info("[super_symbols] loaded sym=" .. #sym_entries .. " emoji=" .. #emoji_entries)
end

---模糊搜索
local function fuzzy_search(keyword, entries, max_n)
    if not keyword or keyword == "" then
        return {}
    end
    local kw_lower = keyword:lower()
    local results = {}
    for _, e in ipairs(entries) do
        local hit = false
        if e.name and e.name:lower():find(kw_lower, 1, true) then
            hit = true
        elseif e.char == keyword then
            hit = true
        end
        if hit then
            table.insert(results, e)
            if #results >= max_n then
                break
            end
        end
    end
    return results
end

---解析用户查询为 (symbol_prefix, modset)
---符号前缀取首个点分组件（必为 by_prefix key），其后的所有组件均视为修饰符，顺序无关。
---这样 /sym.arrow.double.r 与 /sym.arrow.r.double 等价，乱序也能正确匹配变体：
---旧实现从最长前缀贪心匹配，会把修饰符（如 r）误并入符号前缀（arrow.r 因 arrow.r.double 成为合法 key），
---导致后续修饰符（如 l）被丢弃，乱序匹配失效。
---valid_mods 直接在 build_index 阶段预计算为 by_valid，此处仅查表，避免每次重算修饰符并集。
local function parse_query(query_str, by_prefix, by_valid)
    if query_str == "" then
        return nil, {}
    end
    local parts = {}
    for p in query_str:gmatch("[^.]+") do
        parts[#parts + 1] = p
    end
    if #parts == 0 then
        return nil, {}
    end

    -- 从最短前缀起尝试：符号前缀应使其余组件均为合法修饰符。
    -- 优先最短，避免把修饰符误并入符号前缀；若最短前缀无法解释全部组件，则尝试更长的符号前缀。
    -- 前缀增量拼接，避免反复 table.concat。
    local prefix = parts[1]
    for k = 1, #parts do
        local list = by_prefix[prefix]
        if list then
            local vmods = by_valid[prefix]
            local ok = true
            local mods = {}
            for j = k + 1, #parts do
                mods[parts[j]] = true
                if not vmods[parts[j]] then
                    ok = false
                end
            end
            if ok then
                return prefix, mods
            end
        end
        if k < #parts then
            prefix = prefix .. "." .. parts[k + 1]
        end
    end
    return nil, {}
end

-- ===== 触发定义（可 patch）=====
-- 默认由 super_symbols/triggers 配置列表驱动；未配置时回退到 prefix_sym / prefix_emoji。
-- 每条含：kind（类型键）、exact（精确前缀）、label（提示语）、marks（模糊搜索标记，默认 ? 与 /）。
-- 精确与模糊两种模式的 trigger 均可经此列表 patch，例如：
--   super_symbols/triggers:
--     - { kind: sym,    exact: /sym,   label: 超级符号 }
--     - { kind: emoji,  exact: /emoji, label: 超级表情 }
--     - { kind: kaomoji, exact: /kk,   label: 颜文字, marks: ["?"] }
local function build_defs(config, prefix_sym, prefix_emoji)
    local list = config:get_list("super_symbols/triggers")
    if list and list.size > 0 then
        local defs = {}
        for i = 0, list.size - 1 do
            local ep = "super_symbols/triggers/@" .. i
            local kind = config:get_string(ep .. "/kind")
            local exact = config:get_string(ep .. "/exact")
            if kind and exact and kind ~= "" and exact ~= "" then
                local label = config:get_string(ep .. "/label")
                    or (kind == "emoji" and "超级表情" or "超级符号")
                local marks = {}
                local ml = config:get_list(ep .. "/marks")
                if ml then
                    for k = 0, ml.size - 1 do
                        local m = config:get_string(ep .. "/marks/@" .. k)
                        if m and m ~= "" then marks[#marks + 1] = m end
                    end
                end
                if #marks == 0 then marks = { "?", "/" } end
                defs[#defs + 1] = { kind = kind, exact = exact, label = label, marks = marks }
            end
        end
        if #defs > 0 then return defs end
    end
    -- 回退：沿用 prefix_sym / prefix_emoji（保持旧配置可用）
    return {
        { kind = "sym",   exact = prefix_sym,   label = "超级符号", marks = { "?", "/" } },
        { kind = "emoji", exact = prefix_emoji, label = "超级表情", marks = { "?", "/" } },
    }
end

---按前缀从 input 解析出 query
---exact 模式需前缀后紧跟分隔符 sep（如 "."）；search 模式前缀后直接跟关键字
---命中返回 query 字符串，否则返回 nil
local function match_prefix(input, prefix, sep)
    if sep then
        local p2 = #prefix + 1
        if #input >= p2 and input:sub(1, #prefix) == prefix and input:sub(p2, p2) == sep then
            return input:sub(p2 + 1)
        end
        return nil
    end
    if #input >= #prefix and input:sub(1, #prefix) == prefix then
        return input:sub(#prefix + 1)
    end
    return nil
end

---主翻译函数
return function(input, seg, env)
    M.load(env)

    local config = env.engine.schema.config
    -- 读取 super_symbols/* 配置，缺省用默认值
    local function conf(key, default)
        return config:get_string("super_symbols/" .. key) or default
    end
    local prefix_sym   = conf("prefix_sym", "/sym")
    local prefix_emoji = conf("prefix_emoji", "/emoji")
    local max_cands    = config:get_int("super_symbols/max_candidates") or 120

    -- 1) 由触发定义（可 patch）派生 triggers 与模式提示，提示语自动从触发符号列表生成
    local defs = build_defs(config, prefix_sym, prefix_emoji)
    local triggers = {}
    local MODE_TIPS = {}
    local label_by_kind = {}
    for _, d in ipairs(defs) do
        label_by_kind[d.kind] = d.label
        -- 精确模式：前缀后接 "." 直输（如 /sym.arrow.r）
        triggers[#triggers + 1] = { kind = d.kind, mode = "exact", prefixes = { d.exact }, sep = "." }
        MODE_TIPS[d.exact] = d.label
        MODE_TIPS[d.exact .. "."] = d.label .. "：直输"
        -- 模糊模式：前缀后接各标记（? 与 / 平级，如 /sym?arrow 与 /sym/arrow 等价）
        local sp = {}
        for _, mark in ipairs(d.marks) do
            sp[#sp + 1] = d.exact .. mark
            MODE_TIPS[d.exact .. mark] = d.label .. "：搜索"
        end
        triggers[#triggers + 1] = { kind = d.kind, mode = "search", prefixes = sp }
    end

    local function get_mode_tip(input)
        return MODE_TIPS[input]
    end

    -- 2) 模式提示：仅输入前缀时显示引导
    local mode_tip = get_mode_tip(input)
    if mode_tip then
        yield(Candidate("super_sym", seg.start, seg._end, mode_tip, ""))
        return
    end

    local mode, kind, query
    for _, t in ipairs(triggers) do
        for _, p in ipairs(t.prefixes) do
            local q = match_prefix(input, p, t.sep)
            if q then
                mode, kind, query = t.mode, t.kind, q
                break
            end
        end
        if mode then
            break
        end
    end

    if not mode then
        return
    end

    -- 标记 segment 的 tag
    local segment = env.engine.context.composition:back()
    if segment and segment.tags then
        pcall(function()
            segment.tags = segment.tags + Set({type_label})
        end)
    end

    -- 按类型取出对应存储；未知类型回退到空存储（patch 的新类型若无数据则不报错）
    -- candidate type 用 super_<kind>，super_comment_preedit.lua 据此强制保留注释（显示完整 Typst 代码）
    local STORES = {
        sym = { name_to_char = M.name_to_char_sym, by_prefix = M.by_prefix_sym, by_valid = M.by_valid_sym, entries = M.entries_sym, type = "super_sym" },
        emoji = { name_to_char = M.name_to_char_emoji, by_prefix = M.by_prefix_emoji, by_valid = M.by_valid_emoji, entries = M.entries_emoji, type = "super_emoji" },
    }
    local store = STORES[kind] or { name_to_char = {}, by_prefix = {}, by_valid = {}, entries = {}, type = "super_" .. kind }
    local name_to_char, by_prefix, by_valid, entries, type_label = store.name_to_char, store.by_prefix, store.by_valid,
        store.entries, store.type

    -- 注释 = typst_name 本身（完整 Typst 代码）
    local function make_comment(e)
        return e.name
    end

    if mode == "exact" then
        -- 1. 精确匹配
        if name_to_char[query] then
            yield(Candidate(type_label, seg.start, seg._end, name_to_char[query], query))
            return
        end

        -- 2. best_match
        local symbol, modset = parse_query(query, by_prefix, by_valid)
        if not symbol then
            yield(Candidate(type_label, seg.start, seg._end, "（无匹配）",
                "尝试 /" .. kind .. "?" .. query .. " 或 /" .. kind .. "/" .. query))
            return
        end

        local candidates = by_prefix[symbol]
        if not candidates or #candidates == 0 then
            yield(Candidate(type_label, seg.start, seg._end, "（无匹配）", ""))
            return
        end

        -- 无修饰符：返回该前缀下所有变体
        if next(modset) == nil then
            for i, e in ipairs(candidates) do
                if i > max_cands then
                    break
                end
                yield(Candidate(type_label, seg.start, seg._end, e.char, make_comment(e)))
            end
            return
        end

        -- best_match
        local best = best_match(modset, candidates)
        if best then
            yield(Candidate(type_label, seg.start, seg._end, best.char, make_comment(best)))
            local count = 0
            for _, e in ipairs(candidates) do
                if e ~= best and is_subset(modset, e.mods_set) then
                    yield(Candidate(type_label, seg.start, seg._end, e.char, make_comment(e)))
                    count = count + 1
                    if count >= 5 then
                        break
                    end
                end
            end
        else
            for i, e in ipairs(candidates) do
                if i > max_cands then
                    break
                end
                yield(Candidate(type_label, seg.start, seg._end, e.char, make_comment(e)))
            end
        end
    else
        -- search 模式
        if query == "" then
            -- /sym? 或 /sym/ 后无关键字：显示提示
            local kind_label = label_by_kind[kind] or kind
            yield(Candidate(type_label, seg.start, seg._end, kind_label .. "：请输入关键字",
                "如 /" .. kind .. "?arrow  或  /" .. kind .. "/arrow"))
            return
        end
        local results = fuzzy_search(query, entries, max_cands)
        if #results == 0 then
            yield(Candidate(type_label, seg.start, seg._end, "（无匹配）", ""))
            return
        end
        for _, e in ipairs(results) do
            yield(Candidate(type_label, seg.start, seg._end, e.char, make_comment(e)))
        end
    end
end
