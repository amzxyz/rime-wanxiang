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
        if not b[k] then return false end
    end
    return true
end

local function common_count(a, b)
    local n = 0
    for k, _ in pairs(a) do
        if b[k] then n = n + 1 end
    end
    return n
end

local function set_size(s)
    local n = 0
    for _ in pairs(s) do n = n + 1 end
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
    if not f then return {} end
    local entries = {}
    for line in f:lines() do
        if line and not line:match("^#") and line ~= "" then
            local name, char = line:match("^([^\t]+)\t([^\t]+)$")
            if name and char then
                table.insert(entries, {
                    name = name,
                    char = char,
                    mods_set = parse_modset(name),
                })
            end
        end
    end
    f:close()
    return entries
end

---构建索引：name_to_char + by_prefix
local function build_index(entries)
    local name_to_char = {}
    local prefix_set = {}
    for _, e in ipairs(entries) do
        name_to_char[e.name] = e.char
        local parts = {}
        for p in e.name:gmatch("[^.]+") do
            table.insert(parts, p)
        end
        for i = 1, #parts - 1 do
            local prefix = table.concat(parts, ".", 1, i)
            prefix_set[prefix] = true
        end
    end
    local by_prefix = {}
    for prefix, _ in pairs(prefix_set) do
        local prefix_dot = prefix .. "."
        local list = {}
        for _, e in ipairs(entries) do
            if e.name:sub(1, #prefix_dot) == prefix_dot then
                local mods_str = e.name:sub(#prefix_dot + 1)
                table.insert(list, {
                    name = e.name,
                    char = e.char,
                    mods_set = parse_modset(mods_str),
                })
            end
        end
        if #list > 0 then
            by_prefix[prefix] = list
        end
    end
    return name_to_char, by_prefix
end

---加载所有数据
function M.load(env)
    if M.loaded then return end
    if M.load_lock then return end
    M.load_lock = true

    local config = env.engine.schema.config
    local function resolve(p)
        if not p then return nil end
        local user = rime_api.get_user_data_dir() .. "/" .. p
        local f = io.open(user, "r")
        if f then f:close(); return user end
        local shared = rime_api.get_shared_data_dir() .. "/" .. p
        return shared
    end

    local sym_path = resolve(config:get_string("super_symbols/data_sym") or "lua/data/codex_sym.txt")
    local emoji_path = resolve(config:get_string("super_symbols/data_emoji") or "lua/data/codex_emoji.txt")

    local sym_entries = sym_path and read_data_file(sym_path) or {}
    local emoji_entries = emoji_path and read_data_file(emoji_path) or {}

    M.entries_sym = sym_entries
    M.entries_emoji = emoji_entries
    M.name_to_char_sym, M.by_prefix_sym = build_index(sym_entries)
    M.name_to_char_emoji, M.by_prefix_emoji = build_index(emoji_entries)
    M.loaded = true
    M.load_lock = false
    rime.log.info("[super_symbols] loaded sym=" .. #sym_entries .. " emoji=" .. #emoji_entries)
end

---模糊搜索
local function fuzzy_search(keyword, entries, max_n)
    if not keyword or keyword == "" then return {} end
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
            if #results >= max_n then break end
        end
    end
    return results
end

---解析用户查询为 (symbol_prefix, modset)
local function parse_query(query_str, by_prefix)
    if query_str == "" then return nil, {} end
    local parts = {}
    for p in query_str:gmatch("[^.]+") do
        table.insert(parts, p)
    end
    for i = #parts, 1, -1 do
        local prefix = table.concat(parts, ".", 1, i)
        if by_prefix[prefix] then
            local mods = {}
            for j = i + 1, #parts do
                mods[parts[j]] = true
            end
            return prefix, mods
        end
    end
    return nil, {}
end

-- ===== 模式提示文案 =====
-- 当用户仅输入前缀（无后续字符）时，显示引导提示
local MODE_TIPS = {
    -- sym
    ["/sym"]    = "超级符号",
    ["/sym."]   = "超级符号：直输",
    ["/sym?"]   = "超级符号：搜索",
    ["/sym/"]   = "超级符号：搜索",
    -- emoji
    ["/emoji"]  = "超级表情",
    ["/emoji."] = "超级表情：直输",
    ["/emoji?"] = "超级表情：搜索",
    ["/emoji/"] = "超级表情：搜索",
}

---判断输入是否为模式提示触发（仅前缀，无后续）
local function get_mode_tip(input)
    -- 精确匹配
    if MODE_TIPS[input] then return MODE_TIPS[input] end
    return nil
end

---主翻译函数
return function(input, seg, env)
    M.load(env)

    local config = env.engine.schema.config
    local prefix_sym = config:get_string("super_symbols/prefix_sym") or "/sym"
    local search_sym = config:get_string("super_symbols/search_sym") or "/sym?"
    local prefix_emoji = config:get_string("super_symbols/prefix_emoji") or "/emoji"
    local search_emoji = config:get_string("super_symbols/search_emoji") or "/emoji?"
    local max_cands = config:get_int("super_symbols/max_candidates") or 30

    -- 模糊搜索前缀列表（同时支持 /sym? 和 /sym/）
    local search_sym_prefixes = { search_sym, "/sym/" }
    local search_emoji_prefixes = { search_emoji, "/emoji/" }

    -- 1) 模式提示：仅输入前缀时显示引导
    local mode_tip = get_mode_tip(input)
    if mode_tip then
        yield(Candidate("super_sym", seg.start, seg._end, mode_tip, ""))
        return
    end

    -- 2) 判定模式
    local mode, kind, query

    for _, sp in ipairs(search_sym_prefixes) do
        if #input >= #sp and input:sub(1, #sp) == sp then
            mode, kind, query = "search", "sym", input:sub(#sp + 1)
            break
        end
    end
    if not mode then
        for _, sp in ipairs(search_emoji_prefixes) do
            if #input >= #sp and input:sub(1, #sp) == sp then
                mode, kind, query = "search", "emoji", input:sub(#sp + 1)
                break
            end
        end
    end

    if not mode then
        if #input >= #prefix_sym + 1
           and input:sub(1, #prefix_sym) == prefix_sym
           and input:sub(#prefix_sym + 1, #prefix_sym + 1) == "." then
            mode, kind, query = "exact", "sym", input:sub(#prefix_sym + 2)
        elseif #input >= #prefix_emoji + 1
           and input:sub(1, #prefix_emoji) == prefix_emoji
           and input:sub(#prefix_emoji + 1, #prefix_emoji + 1) == "." then
            mode, kind, query = "exact", "emoji", input:sub(#prefix_emoji + 2)
        end
    end

    if not mode then return end

    -- 标记 segment 的 tag
    local segment = env.engine.context.composition:back()
    if segment and segment.tags then
        pcall(function()
            segment.tags = segment.tags + Set({ kind == "sym" and "super_sym" or "super_emoji" })
        end)
    end

    local name_to_char = kind == "sym" and M.name_to_char_sym or M.name_to_char_emoji
    local by_prefix = kind == "sym" and M.by_prefix_sym or M.by_prefix_emoji
    local entries = kind == "sym" and M.entries_sym or M.entries_emoji
    -- candidate type 用 super_sym / super_emoji，super_comment_preedit.lua 据此强制保留注释
    local type_label = kind == "sym" and "super_sym" or "super_emoji"

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
        local symbol, modset = parse_query(query, by_prefix)
        if not symbol then
            -- 兜底：模糊搜索
            local results = fuzzy_search(query, entries, 10)
            if #results == 0 then
                yield(Candidate(type_label, seg.start, seg._end, "（无匹配）",
                    "尝试 /" .. kind .. "?" .. query .. " 或 /" .. kind .. "/" .. query))
                return
            end
            for _, e in ipairs(results) do
                yield(Candidate(type_label, seg.start, seg._end, e.char, make_comment(e)))
            end
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
                if i > max_cands then break end
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
                    if count >= 5 then break end
                end
            end
        else
            for i, e in ipairs(candidates) do
                if i > max_cands then break end
                yield(Candidate(type_label, seg.start, seg._end, e.char, make_comment(e)))
            end
        end
    else
        -- search 模式
        if query == "" then
            -- /sym? 或 /sym/ 后无关键字：显示提示
            local kind_label = kind == "sym" and "超级符号" or "超级表情"
            yield(Candidate(type_label, seg.start, seg._end,
                kind_label .. "：请输入关键字",
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
