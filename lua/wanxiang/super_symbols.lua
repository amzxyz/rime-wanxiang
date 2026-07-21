-- 万象家族 lua / 超级符号（super_symbols）
-- 来源：https://github.com/typst/codex  (符号命名 + 修饰符体系)
--
-- 数据格式：
--   lua/data/codex_sym.txt    每行: typst_name<TAB>char
--   lua/data/codex_emoji.txt  同上
--   typst_name 是完整的 Typst 写法（如 arrow.r.double、chess.king.white），只有一个标识符字段，
--   不含 sym./emoji. 前缀；前缀由本模块在注释中按需补回。
--
-- 触发方式：
--   /sym.<name>[.<mod>...]   精确匹配（点分链式任意顺序匹配）
--   /sym?<keyword> 或 /sym/<keyword>   模糊搜索（点分链式任意顺序模糊匹配）
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
-- 精确匹配规则（点分链式）：
--   1) 查询按 "." 拆成 v1.v2...vn（末尾悬垂点视为最后一个值空串 ""）。
--   2) 首值 v1 必须匹配字典首值（根/分类）：
--        - 一旦 v1 被 "." 结束（即 n>=2，链式继续），v1 改用 EXACT match 匹配根；
--        - 若 v1 是整串唯一值（n==1，无末尾点），v1 用子串（prefix）match 匹配根。
--   3) 中间值 v2..v(n-1) 与尾值 vn 在字典中“任意乱序”匹配非首值内容（修饰符）：
--        - 中间值：EXACT match 某个修饰符；
--        - 尾值 vn：永远 PREFIX match 某个修饰符（空串=""匹配全部）；
--        - 重复修饰符自动合并成一个。
--   4) 首值单值（n==1）只投“根字符”进候选；若根无裸字符则投占位符（字符分类）<根>。
--   5) 候选按匹配度排序（修饰符更少者更贴合），注释永远为标准 Typst 表示法
--      （含 sym./emoji. 前缀，顺序依字典，提供完整版）。
--
-- 模糊匹配规则（点分链式任意顺序模糊匹配）：
--   关键字按 "." 拆成若干组件，每个组件必须是某条目标名字的子串（任意顺序、可乱序）；
--   无 "." 时退化为旧式子串匹配（名字含关键字 或 字符精确相等）。
--
-- 候选注释显示完整 Typst 代码（sym./emoji. + 字典原序名），并强制显示：
--   super_comment_preedit.lua 识别 candidate.type == "super_sym" 或 "super_emoji" 时跳过清空逻辑。
-- pcall 保护：本模块并不依赖 wanxiang 命名空间，仅在 RIME 运行时由环境提供；
-- 单测环境下缺失也不影响加载（见文件末尾暴露的 _internals）。
local ok_w, wanxiang = pcall(require, "wanxiang/wanxiang")

local M = {}

-- ===== 数据结构 =====
M.name_to_char_sym = nil
M.name_to_char_emoji = nil
M.entries_sym = nil
M.entries_emoji = nil
M.by_root_sym = nil
M.by_root_emoji = nil
M.roots_sym = nil
M.roots_emoji = nil
M.bare_root_sym = nil
M.bare_root_emoji = nil
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

---构建索引：name_to_char + by_root + roots + bare_root
---by_root[root] = 该根下所有条目（mods_list 为有序修饰符数组，mods_set 为修饰符集合）
---roots        = 所有“根/分类”（条目的首个点分组件）去重列表（用于首值 prefix match）
---bare_root[root] = 存在裸条目（name 恰为 root）时的字符，否则 nil
---单次遍历，无二次扫描
local function build_index(entries)
    local name_to_char = {}
    local by_root = {}
    local roots = {}
    local root_set = {}
    local bare_root = {}
    for _, e in ipairs(entries) do
        name_to_char[e.name] = e.char
        local parts = {}
        for p in e.name:gmatch("[^.]+") do
            parts[#parts + 1] = p
        end
        local r = parts[1]
        if not root_set[r] then
            root_set[r] = true
            roots[#roots + 1] = r
        end
        if #parts == 1 then
            bare_root[r] = e.char
        end
        local mods_list = {}
        for i = 2, #parts do
            mods_list[#mods_list + 1] = parts[i]
        end
        local mods_set = parse_modset(e.name:sub(#r + 2))
        local list = by_root[r]
        if not list then
            list = {}
            by_root[r] = list
        end
        list[#list + 1] = {
            name = e.name,
            char = e.char,
            mods_list = mods_list,
            mods_set = mods_set
        }
    end
    return name_to_char, by_root, roots, bare_root
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
    M.name_to_char_sym, M.by_root_sym, M.roots_sym, M.bare_root_sym = build_index(sym_entries)
    M.name_to_char_emoji, M.by_root_emoji, M.roots_emoji, M.bare_root_emoji = build_index(emoji_entries)
    M.loaded = true
    M.load_lock = false
    rime.log.info("[super_symbols] loaded sym=" .. #sym_entries .. " emoji=" .. #emoji_entries)
end

---按 "." 拆分字符串；末尾悬垂点视为最后一个值空串 ""
local function split_dot(s)
    local parts = {}
    local start = 1
    while true do
        local dot = s:find(".", start, true)
        if dot then
            parts[#parts + 1] = s:sub(start, dot - 1)
            start = dot + 1
        else
            parts[#parts + 1] = s:sub(start)
            break
        end
    end
    return parts
end

---去重并保持顺序
local function dedup_list(lst)
    local seen = {}
    local out = {}
    for _, v in ipairs(lst) do
        if not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    return out
end

---精确匹配（点分链式任意顺序匹配）
---返回 { kind = "list", items = {...} } / { kind = "placeholder", code = ... } / { kind = "nomatch" }
---item: { text = 候选文本, comment = 完整 Typst 注释 }
local function do_exact(query, store, kind_prefix)
    local parts = split_dot(query)
    if #parts == 0 then
        return { kind = "nomatch" }
    end
    local v1 = parts[1]
    local has_dot = (#parts >= 2)

    if has_dot then
        -- 首值被 "." 结束 → EXACT match 根
        if not store.by_root[v1] then
            -- 非精确根：若 v1 是某根前缀（分类存在）给出占位符；否则无匹配
            local exists = false
            for _, r in ipairs(store.roots) do
                if r:sub(1, #v1) == v1 then
                    exists = true
                    break
                end
            end
            if exists then
                return { kind = "placeholder", code = v1 }
            end
            return { kind = "nomatch" }
        end
        -- n>=2：中间值 EXACT、尾值 PREFIX、任意乱序匹配修饰符
        local middles = {}
        for i = 2, #parts - 1 do
            middles[#middles + 1] = parts[i]
        end
        middles = dedup_list(middles)
        local last = parts[#parts] -- 尾值永远 prefix match（"" 匹配全部）

        local items = {}
        local seen = {}
        for _, e in ipairs(store.by_root[v1]) do
            local ok = true
            for _, m in ipairs(middles) do
                if not e.mods_set[m] then
                    ok = false
                    break
                end
            end
            if ok and last ~= "" then
                local lm = false
                for _, em in ipairs(e.mods_list) do
                    if em:sub(1, #last) == last then
                        lm = true
                        break
                    end
                end
                if not lm then
                    ok = false
                end
            end
            if ok then
                local comment = kind_prefix .. e.name
                local key = e.char .. "\t" .. comment
                if not seen[key] then
                    seen[key] = true
                    items[#items + 1] = { text = e.char, comment = comment, entry = e }
                end
            end
        end
        -- 排序：修饰符更少者更贴合（匹配度优先），再按字典序
        table.sort(items, function(a, b)
            local na = #a.entry.mods_list
            local nb = #b.entry.mods_list
            if na ~= nb then
                return na < nb
            end
            return a.entry.name < b.entry.name
        end)
        return { kind = "list", items = items }
    end

    -- n==1（首值无末尾点）：子串 match 根，仅投根字符 / 分类占位
    local items = {}
    local seen = {}
    for _, r in ipairs(store.roots) do
        if r:sub(1, #v1) == v1 then
            local char = store.bare_root[r]
            local text = char or ("（字符分类）" .. r)
            local comment = kind_prefix .. r
            local key = text .. "\t" .. comment
            if not seen[key] then
                seen[key] = true
                items[#items + 1] = { text = text, comment = comment }
            end
        end
    end
    if #items == 0 then
        return { kind = "nomatch" }
    end
    return { kind = "list", items = items }
end

---模糊搜索（点分链式任意顺序模糊匹配）
---返回 { kind = "list", items = {...} } / { kind = "need_keyword" }
local function do_fuzzy(keyword, store, kind_prefix)
    if not keyword or keyword == "" then
        return { kind = "need_keyword", items = {} }
    end
    if keyword:find(".", 1, true) then
        -- 点分链式：每个组件是名字的子串（任意顺序）
        local comps = dedup_list(split_dot(keyword))
        local items = {}
        local seen = {}
        for _, e in ipairs(store.entries) do
            local name_l = e.name:lower()
            local all = true
            for _, c in ipairs(comps) do
                if not name_l:find(c:lower(), 1, true) then
                    all = false
                    break
                end
            end
            if all then
                local comment = kind_prefix .. e.name
                local key = e.char .. "\t" .. comment
                if not seen[key] then
                    seen[key] = true
                    items[#items + 1] = { text = e.char, comment = comment, entry = e }
                end
            end
        end
        table.sort(items, function(a, b)
            return a.entry.name < b.entry.name
        end)
        return { kind = "list", items = items }
    end

    -- 无 "."：旧式子串匹配 + 字符精确匹配
    local kw = keyword:lower()
    local items = {}
    local seen = {}
    for _, e in ipairs(store.entries) do
        local hit = e.name:lower():find(kw, 1, true) or e.char == keyword
        if hit then
            local comment = kind_prefix .. e.name
            local key = e.char .. "\t" .. comment
            if not seen[key] then
                seen[key] = true
                items[#items + 1] = { text = e.char, comment = comment, entry = e }
            end
        end
    end
    return { kind = "list", items = items }
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
local function translator(input, seg, env)
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
        sym = { by_root = M.by_root_sym, roots = M.roots_sym, bare_root = M.bare_root_sym, entries = M.entries_sym, type = "super_sym" },
        emoji = { by_root = M.by_root_emoji, roots = M.roots_emoji, bare_root = M.bare_root_emoji, entries = M.entries_emoji, type = "super_emoji" },
    }
    local store = STORES[kind] or { by_root = {}, roots = {}, bare_root = {}, entries = {}, type = "super_" .. kind }
    local by_root, roots, bare_root, entries, type_label = store.by_root, store.roots, store.bare_root,
        store.entries, store.type
    local kind_prefix = kind .. "."

    if mode == "exact" then
        local res = do_exact(query, store, kind_prefix)
        if res.kind == "nomatch" then
            yield(Candidate(type_label, seg.start, seg._end, "（无匹配）",
                "尝试 /" .. kind .. "?" .. query .. " 或 /" .. kind .. "/" .. query))
            return
        end
        if res.kind == "placeholder" then
            yield(Candidate(type_label, seg.start, seg._end, "（字符分类）" .. res.code, kind_prefix .. res.code))
            return
        end
        if #res.items == 0 then
            yield(Candidate(type_label, seg.start, seg._end, "（无匹配）", ""))
            return
        end
        local count = 0
        for _, it in ipairs(res.items) do
            if count >= max_cands then
                break
            end
            yield(Candidate(type_label, seg.start, seg._end, it.text, it.comment))
            count = count + 1
        end
        return
    end

    -- search 模式
    if query == "" then
        -- /sym? 或 /sym/ 后无关键字：显示提示
        local kind_label = label_by_kind[kind] or kind
        yield(Candidate(type_label, seg.start, seg._end, kind_label .. "：请输入关键字",
            "如 /" .. kind .. "?arrow  或  /" .. kind .. "/arrow"))
        return
    end
    local res = do_fuzzy(query, store, kind_prefix)
    if #res.items == 0 then
        yield(Candidate(type_label, seg.start, seg._end, "（无匹配）", ""))
        return
    end
    local count = 0
    for _, it in ipairs(res.items) do
        if count >= max_cands then
            break
        end
        yield(Candidate(type_label, seg.start, seg._end, it.text, it.comment))
        count = count + 1
    end
end

-- 暴露内部纯函数，便于独立单元测试（不影响运行期行为）
-- 用可调用表包装 translator：RIME 仍以 translator(input, seg, env) 方式调用，
-- 单测可通过 _internals 访问纯函数。
local export = setmetatable({}, {
    __call = function(_, input, seg, env)
        return translator(input, seg, env)
    end,
})
export._internals = {
    split_dot = split_dot,
    dedup_list = dedup_list,
    build_index = build_index,
    read_data_file = read_data_file,
    do_exact = do_exact,
    do_fuzzy = do_fuzzy,
}

return export
