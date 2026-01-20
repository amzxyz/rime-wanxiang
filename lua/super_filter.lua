-- @amzxyz  https://github.com/amzxyz/rime_wanxiang
-- 功能 A：候选文本中的转义序列格式化（始终开启）
--         \n \t \r \\ \s(空格) \d(-)
-- 功能 B：候选重排（仅编码长度 2..6 时）
--         - 第一候选不动
--         - 其余按组输出：①不含字母(table/user_table) → ②其他
--         - 若第二候选为 table/user_table，则不排序，直接透传
-- 功能 C：成对符号包裹（触发：最后分段完整消耗且出现 prefix\suffix；suffix 命中映射时吞掉 \suffix）
-- 缓存/锁定：
--   - 未锁定时记录第一候选为缓存
--   - 出现 prefix\suffix 且 prefix 非空 ⇒ 锁定
--   - 兜底重建，当有些单词类型输入斜杠后不产出候选就将前面产生的进行构造候选
--   - 输入为空时释放缓存/锁定
-- 镜像：
--   - schema: paired_symbols/mirror (bool，默认 true)
--   - 包裹后可抑制"包裹前文本/包裹后文本"再次出现在后续候选里
-- 功能D 字符集过滤，默认8105+𰻝𰻝，可以在方案中定义黑白名单来实现用户自己的范围微调addlist: []和blacklist: [𰻝, 𰻞]
-- 功能E 由于在混输场景中输入comment commit等等之类的英文时候，由于直接辅助码的派生能力，会将三个好不想干的单字组合在一起，这会造成不好的体验
--      因此在首选已经是英文的时候，且type=completion且大于等于4个字符，这个时候后面如果有type=sentence的派生词则直接干掉，这个还要依赖，表翻译器
--      权重设置与主翻译器不可相差太大

local wanxiang = require("wanxiang")
local M = {}

-- 性能优化：本地化字符串函数
local byte, find, gsub, upper, sub = string.byte, string.find, string.gsub, string.upper, string.sub
local utf8_codes = utf8.codes -- 本地化 utf8 迭代器

-- ================= 工具函数 =================

local function fast_type(c)
    local t = c.type
    if t then return t end
    local g = c.get_genuine and c:get_genuine() or nil
    return (g and g.type) or ""
end

local function is_table_type(c)
    local t = fast_type(c)
    return t == "table" or t == "user_table" or t == "fixed"
end

local function has_english_token_fast(s)
    local len = #s
    for i = 1, len do
        local b = byte(s, i)
        if b < 0x80 then
            -- A-Z (0x41-0x5A) or a-z (0x61-0x7A)
            if (b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A) then
                return true
            end
        end
    end
    return false
end
-- 纯ASCII判定
local function is_english_candidate(cand)
    local txt = cand and cand.text
    if not txt or txt == "" then return false end
    if not has_english_token_fast(txt) then
        return false
    end
    -- 使用局部变量 find，而非 string.find
    if find(txt, "[\128-\255]") then
        return false
    end
    return true
end

local escape_map = {
    ["\\n"] = "\n",            -- 换行
    ["\\r"] = "\r",            -- 回车
    ["\\t"] = "\t",            -- 制表符
    ["\\s"] = " ",             -- 空格
    ["\\z"] = "\226\128\139",  -- 零宽空格
}

local utf8_char_pattern = "[%z\1-\127\194-\244][\128-\191]*"

local function apply_escape_fast(text)
    if not text or (not find(text, "\\", 1, true) and not find(text, "{", 1, true)) then
        return text, false
    end

    local new_text = text
    if find(new_text, "\\{", 1, true) then
        new_text = gsub(new_text, "\\{", "\1")
    end
    if find(new_text, "\\", 1, true) then
        new_text = gsub(new_text, "\\[ntrsz]", escape_map)
    end
    if find(new_text, "{", 1, true) then
        new_text = gsub(new_text, "(" .. utf8_char_pattern .. ")%{(%d+)}", function(char, count)
            local n = tonumber(count)
            if n and n > 0 and n < 200 then
                return string.rep(char, n)
            end
            return char .. "{" .. count .. "}"
        end)
    end
    if find(new_text, "\1", 1, true) then
        new_text = gsub(new_text, "\1", "{")
    end
    return new_text, new_text ~= text
end

local function format_and_autocap(cand)
    local text = cand.text
    if not text or text == "" then return cand end
    local t2, changed = apply_escape_fast(text)
    if not changed then return cand end
    local nc = Candidate(cand.type, cand.start, cand._end, t2, cand.comment)
    nc.preedit = cand.preedit
    return nc
end

local function clone_candidate(c)
    local nc = Candidate(c.type, c.start, c._end, c.text, c.comment)
    nc.preedit = c.preedit
    return nc
end
--  包裹映射
local default_wrap_map = {
    -- 单字母：常用成对括号/引号（每项恰好两个字符）
    a = "[]",        -- 方括号
    b = "【】",       -- 黑方头括号
    c = "❲❳",        -- 双大括号 / 装饰括号
    d = "〔〕",       -- 方头括号
    e = "⟮⟯",        -- 小圆括号 / 装饰括号
    f = "⟦⟧",        -- 双方括号 / 数学集群括号
    g = "「」",       -- 直角引号
    -- h 预留用于 Markdown 一级标题
    i = "『』",       -- 双直角引号
    j = "<>",         -- 尖括号
    k = "《》",       -- 书名号（双）
    l = "〈〉",       -- 书名号（单）
    m = "‹›",         -- 法文单书名号
    n = "«»",         -- 法文双书名号
    o = "⦅⦆",          -- 白圆括号
    p = "⦇⦈",         -- 白方括号
    q = "()",         -- 圆括号
    r = "|儿",          --儿化候选
    s = "［］",        -- 全角方括号
    t = "⟨⟩",         -- 数学角括号
    u = "〈〉",        -- 数学尖括号
    v = "❰❱",        -- 装饰角括号
    w = "（）",       -- 全角圆括号
    x = "｛｝",       -- 全角花括号
    y = "⟪⟫",       -- 双角括号
    z = "{}",        -- 花括号

    --  扩展括号族 / 引号
    dy = "''",       -- 英文单引号
    sy = "\"\"",     -- 英文双引号
    zs = "“”",       -- 中文弯双引号
    zd = "‘’",       -- 中文弯单引号
    fy = "``",       -- 反引号

    --  双字母括号族
    aa = "〚〛",      -- 双中括号
    bb = "〘〙",      -- 双中括号（小）
    cc = "〚〛",      -- 双中括号（重复，可用于 Lua 匹配）
    dd = "❨❩",      -- 小圆括号装饰
    ee = "❪❫",      -- 小圆括号装饰
    ff = "❬❭",      -- 小尖括号装饰
    gg = "⦉⦊",      -- 双弯方括号
    ii = "⦍⦎",      -- 双弯方括号
    jj = "⦏⦐",      -- 双弯方括号
    kk = "⦑⦒",      -- 双弯方括号
    ll = "❮❯",      -- 小尖括号装饰
    mm = "⌈⌉",      -- 上取整 / 数学符号
    nn = "⌊⌋",      -- 下取整 / 数学符号
    oo = "⦗⦘",      -- 双方括号装饰（补齐）
    pp = "⦙⦚",      -- 双方括号装饰（补齐）
    qq = "⟬⟭",      -- 小双角括号
    rr = "❴❵",      -- 花括号装饰
    ss = "⌜⌝",      -- 数学上角符号
    tt = "⌞⌟",      -- 数学下角符号
    uu = "⸢⸣",      -- 装饰方括号
    vv = "⸤⸥",      -- 装饰方括号
    ww = "﹁﹂",      -- 中文书名号 / 注释引号
    xx = "﹃﹄",      -- 中文书名号 / 注释引号
    yy = "⌠⌡",      -- 数学 / 程序符号
    zz = "⟅⟆",      -- 数学 / 装饰括号

    --  Markdown / 标记
    md = "**|**",      -- Markdown 粗体
    jc = "**|**",      -- 加粗
    it = "__|__",      -- 斜体
    st = "~~|~~",      -- 删除线
    eq = "==|==",      -- 高亮
    ln = "`|`",        -- 行内代码
    cb = "```|```",    -- 代码块
    qt = "> |",        -- 引用
    ul = "- |",        -- 无序列表项
    ol = "1. |",       -- 有序列表项
    lk = "[|](url)",   -- 链接
    im = "![|](img)",  -- 图片
    h = "# |",         -- 一级标题
    hh = "## |",       -- 二级标题
    hhh = "### |",     -- 三级标题
    hhhh = "#### |",   -- 四级标题
    sp = "\\|",        -- 反斜杠转义
    br = "|  ",        -- 换行
    cm = "<!--|-->",   -- 注释

    --  运算与标记符
    pl = "++",
    mi = "--",
    sl = "//",
    bs = "\\\\",
    at = "@@",
    dl = "$$",
    pc = "%%",
    an = "&&",
    cr = "^^",
    cl = "::",
    sc = ";;",
    ex = "!!",
    qu = "??",
    sb = "sb",
}

local function load_mapping_from_config(config)
    local symbol_map = {}
    for k, v in pairs(default_wrap_map) do symbol_map[k] = v end
    local ok_map, map = pcall(function() return config:get_map("paired_symbols/symkey") end)
    if ok_map and map then
        local ok_keys, keys = pcall(function() return map:keys() end)
        if ok_keys and keys then
            for _, key in ipairs(keys) do
                local ok_val, v = pcall(function() return config:get_string("paired_symbols/symkey/" .. key) end)
                if ok_val and v and #v > 0 then symbol_map[string.lower(key)] = v end
            end
        end
    end
    return symbol_map
end

-- 优化：删除 utf8_chars 函数，直接在预编译中使用 utf8_codes
local function precompile_wrap_parts(wrap_map, delimiter)
    delimiter = delimiter or "|"
    local parts = {}
    for k, wrap_str in pairs(wrap_map) do
        if not wrap_str or wrap_str == "" then
            parts[k] = { l = "", r = "" }
        else
            local pos = find(wrap_str, delimiter, 1, true)
            if pos then
                local left = sub(wrap_str, 1, pos - 1) or ""
                local right = sub(wrap_str, pos + 1) or ""
                parts[k] = { l = left, r = right }
            else
                -- 优化：使用 utf8_codes 避免创建 table
                local first, last
                local count = 0
                for _, cp in utf8_codes(wrap_str) do
                    local char = utf8.char(cp)
                    if count == 0 then first = char end
                    last = char
                    count = count + 1
                end
               
                if count == 0 then
                    parts[k] = { l = "", r = "" }
                elseif count == 1 then
                    parts[k] = { l = first, r = "" }
                elseif count == 2 then
                    parts[k] = { l = first, r = last } -- 修正：双字时左右各一
                else
                    parts[k] = { l = first, r = last } -- 多字时首尾各一
                end
            end
        end
    end
    return parts
end

-- 检查交集
local function check_intersection(db_attr, config_base_set)
    if not db_attr or db_attr == "" then return false end
    for i = 1, #db_attr do
        -- 优化：使用局部变量 sub
        local c = sub(db_attr, i, i)
        if config_base_set[c] then
            return true
        end
    end
    return false
end

-- 初始化字符集过滤配置
local function init_charset_filter(env, cfg)
    -- 1. 加载数据库文件
    local dist = (rime_api.get_distribution_code_name() or ""):lower()
    local charsetFile
    if dist == "weasel" then
        charsetFile = "lua/data/charset.reverse.bin"
    else
        charsetFile = wanxiang.get_filename_with_fallback("lua/data/charset.reverse.bin") or "lua/data/charset.reverse.bin"
    end
   
    env.charset_db = nil
    if ReverseDb then
        local ok, db = pcall(function() return ReverseDb(charsetFile) end)
        if ok and db then env.charset_db = db end
    end
    env.db_memo = {}
    env.filters = {}

    if not cfg then return end
   
    local root_path = "charset"
    local list = cfg:get_list(root_path)
    if not list then return end

    local list_size = list.size
    for i = 0, list_size - 1 do
        local entry_path = root_path .. "/@" .. i
       
        -- 解析开关
        local triggers = {}
        local opts_keys = {"option", "options"}
        for _, key in ipairs(opts_keys) do
            local key_path = entry_path .. "/" .. key
            local sub_list = cfg:get_list(key_path)
            if sub_list then
                for k = 0, sub_list.size - 1 do
                    local val = cfg:get_string(key_path .. "/@" .. k)
                    if val and val ~= "" then table.insert(triggers, val) end
                end
            else
                if cfg:get_bool(key_path) == true then
                    table.insert(triggers, "true")
                else
                    local val = cfg:get_string(key_path)
                    if val and val ~= "" and val ~= "true" then
                        table.insert(triggers, val)
                    end
                end
            end
        end

        if #triggers > 0 then
            -- 物理隔离变量
            local rule_base_set = {}
            local rule_add = {}
            local rule_ban = {}

            -- 解析 Base
            local base_str = cfg:get_string(entry_path .. "/base")
            if base_str and #base_str > 0 then
                for j = 1, #base_str do
                    rule_base_set[sub(base_str, j, j)] = true
                end
            end

            -- 解析 Addlist (内联处理，避免闭包开销)
            local function load_list_to_map(list_name, map)
                local lp = entry_path .. "/" .. list_name
                local sl = cfg:get_list(lp)
                if sl then
                    for k = 0, sl.size - 1 do
                        local val = cfg:get_string(lp .. "/@" .. k)
                        if val and val ~= "" then
                            for _, cp in utf8_codes(val) do map[cp] = true end
                        end
                    end
                end
            end

            load_list_to_map("addlist", rule_add)
            load_list_to_map("blacklist", rule_ban)

            table.insert(env.filters, {
                options  = triggers,
                base_set = rule_base_set,
                add      = rule_add,
                ban      = rule_ban
            })
        end
    end
end

-- 核心判定逻辑
local function codepoint_in_charset(env, ctx, codepoint, text)
    if not env.charset_db then return true end

    local filters = env.filters
    if not filters or #filters == 0 then return true end

    local active_options_count = 0

    for _, rule in ipairs(filters) do
        -- 检查开关
        local is_rule_active = false
        for _, opt_name in ipairs(rule.options) do
            if opt_name == "true" or ctx:get_option(opt_name) then
                is_rule_active = true
                break
            end
        end

        if is_rule_active then
            active_options_count = active_options_count + 1
           
            -- 1. 黑名单 (最高优先级)
            if rule.ban[codepoint] then
            -- 2. 白名单 (次高优先级)
            elseif rule.add[codepoint] then
                return true -- 显式白名单，直接放行 (Short-circuit)
           
            -- 3. Base 属性检查
            else
                local attr = env.db_memo[text]
                if attr == nil then
                    attr = env.charset_db:lookup(text)
                    env.db_memo[text] = attr
                end
               
                if check_intersection(attr, rule.base_set) then
                    return true -- 属性符合，直接放行 (Short-circuit)
                end
            end
        end
    end

    -- 如果没有开启任何规则 -> 显示所有
    if active_options_count == 0 then
        return true
    end

    -- 开启了规则，但没有任何一个规则返回 true -> 隐藏
    return false
end

local function in_charset(env, ctx, text)
    if not text or text == "" then return true end
   
    local cp_count = 0
    local target_cp = nil
    for _, cp in utf8_codes(text) do
        cp_count = cp_count + 1
        if cp_count > 1 then return true end
        target_cp = cp
    end
   
    if cp_count == 0 or not target_cp then return true end
    local char = utf8.char(target_cp)

    if not wanxiang.IsChineseCharacter(char) then return true end

    return codepoint_in_charset(env, ctx, target_cp, char)
end

--  生命周期
function M.init(env)
    local cfg = env.engine and env.engine.schema and env.engine.schema.config or nil
    env.wrap_map   = cfg and load_mapping_from_config(cfg) or default_wrap_map
    env.wrap_delimiter = "|"
    if cfg then
        local okd, d = pcall(function() return cfg:get_string("paired_symbols/delimiter") end)
        if okd and d and #d > 0 then
            env.wrap_delimiter = d:sub(1,1)
        end
    end

    env.wrap_parts = precompile_wrap_parts(env.wrap_map, env.wrap_delimiter)

    -- 触发分隔符：默认取 "\\"，支持 schema 自定义
    env.symbol = "\\"
    if cfg then
        local ok_sym, sym = pcall(function() return cfg:get_string("paired_symbols/symbol") end)
        if ok_sym and sym and #sym > 0 then
            env.symbol = sub(sym, 1, 1)
        else
            local ok_tr, tr = pcall(function() return cfg:get_string("paired_symbols/trigger") end)
            if ok_tr and tr and #tr > 0 then env.symbol = sub(tr, 1, 1) end
        end
    end

    -- 镜像抑制开关
    env.suppress_mirror = true
    if cfg then
        local okb, bv = pcall(function() return cfg:get_bool("paired_symbols/mirror") end)
        if okb and bv ~= nil then env.suppress_mirror = bv end
    end

    env.cache  = nil   -- 首候选缓存（已格式化）
    env.locked = false -- 是否进入锁定态（检测到 prefix\suffix）

    -- 分组窗口（候选重排的采样窗口大小）
    env.settings = env.settings or {}
    if cfg then
        local ok_win, win = pcall(function() return cfg:get_string("paired_symbols/sort_window") end)
        if ok_win and tonumber(win) then env.settings.sort_window = tonumber(win) end
    end
        -- 字符集过滤
    init_charset_filter(env, cfg)
    local schema_id = env.engine.schema.schema_id
    env.enable_taichi_filter = (schema_id == "wanxiang" or schema_id == "wanxiang_pro")
end

function M.fini(env)
    env.charset_db = nil
    env.db_memo = nil
    env.filters = nil
    env.wrap_map = nil
    env.wrap_parts = nil
end
--  统一产出通道
-- ctxs:
--   charset          : 字符集过滤
--   suppress_set     : { [text] = true } 阻止镜像文本 
--   suppress_mirror  : bool
--   code_ctx         : 编码上下文
--   unify_tail_span  : 尾部 span 对齐函数
local function emit_with_pipeline(cand, ctxs)
    if not cand then return end
    local env = ctxs.env

    -- ① 字符集过滤：只有在 charset_strict = true 时才启用
    if ctxs.charset_active and cand.text and cand.text ~= "" then
        if not in_charset(env, ctxs.ctx, cand.text) then
            return
        end
    end
    -- 如果是英文句子，且注释包含 ☯ (\226\152\175)，则丢弃
    if ctxs.enable_taichi_filter then
        -- 只有在 wanxiang 或 wanxiang_pro 方案下才执行此过滤
        if cand.text and has_english_token_fast(cand.text) then
            if cand.comment and find(cand.comment, "\226\152\175") then
                return 
            end
        end
    end
    -- ② 若需抑制句子候选：删掉所有 type 为 sentence 的候选（除了首候选本身不会被标记）**
    if ctxs.drop_sentence_after_completion then
        if fast_type(cand) == "sentence" then
            return
        end
    end

    -- ③ 镜像抑制
    if ctxs.suppress_mirror and ctxs.suppress_set and ctxs.suppress_set[cand.text] then
        return
    end

    -- ④ 格式化 + 大写 + span 对齐
    cand = format_and_autocap(cand)
    cand = ctxs.unify_tail_span(cand)
    yield(cand)
end
--  主流程
function M.func(input, env)
    local ctx  = env and env.engine and env.engine.context or nil
    local code = ctx and (ctx.input or "") or ""
    local comp = ctx and ctx.composition or nil

    local is_functional = false
    if ctx and wanxiang and wanxiang.is_function_mode_active then
        is_functional = wanxiang.is_function_mode_active(ctx)
    end

    local charset_active = (env.filters and #env.filters > 0) 
                           and (not is_functional)
    -- 状态清理
    if not code or code == "" then
        env.cache, env.locked = nil, false
    end
    if comp and comp:empty() then
        env.cache, env.locked = nil, false
    end

    local symbol = env.symbol
    local code_has_symbol = symbol and #symbol == 1 and (find(code, symbol, 1, true) ~= nil)
   
    -- segmentation：用于保持原有的包裹/分段逻辑
    local last_seg, last_text, fully_consumed = nil, nil, false
    if code_has_symbol then
        last_seg = comp and comp:back()
        local segm = comp and comp:toSegmentation()
        local confirmed = 0
        if segm and segm.get_confirmed_position then confirmed = segm:get_confirmed_position() or 0 end
        if last_seg and last_seg.start and last_seg._end then
            fully_consumed = (last_seg.start == confirmed) and (last_seg._end == #code)
            if fully_consumed then
                last_text = sub(code, last_seg.start + 1, last_seg._end)
            end
        end
    end

    -- 宽松尾部
    local tail_text = (last_seg and last_seg.start and last_seg._end) and sub(code, last_seg.start + 1, #code) or code

    -- 解析 prefix\suffix（保持原有包裹逻辑）
    local lock_now, wrap_key, keep_tail_len = false, nil, 0
    if code_has_symbol and last_text and symbol and #symbol == 1 then
        local pos = last_text:find(symbol, 1, true)
        if pos and pos > 1 then
            local left  = sub(last_text, 1, pos - 1)
            local right = sub(last_text, pos + 1)
            if #left > 0 then
                lock_now = true
                keep_tail_len = 1 + #right
                local k = (right or ""):lower()
                if k ~= "" and env.wrap_map[k] then wrap_key = k end
            end
        end
    end
    env.locked = lock_now

    -- code 上下文
    local code_len       = #code
    local do_group       = (code_len >= 2 and code_len <= 6)
    local sort_window    = tonumber(env.settings.sort_window) or 30
    local pure_code      = gsub(code, "[%s%p]", "")
    local pure_code_lc   = pure_code:lower()

    local code_ctx = {
        pure_code     = pure_code,
        pure_code_lc  = pure_code_lc,
    }

    local function unify_tail_span(c)
        if fully_consumed and wrap_key and last_seg and c and c._end ~= last_seg._end then
            local nc = Candidate(c.type, c.start, last_seg._end, c.text, c.comment)
            nc.preedit = c.preedit
            return nc
        end
        return c
    end

    local emit_ctx = {
        env             = env,
        ctx             = ctx,
        suppress_set    = nil,
        suppress_mirror = env.suppress_mirror,
        code_ctx        = code_ctx,
        unify_tail_span = unify_tail_span,
        charset_active  = charset_active,
        is_english      = is_english_candidate,
        enable_taichi_filter = env.enable_taichi_filter,
        drop_sentence_after_completion = false,
    }

    local function wrap_from_base(base_cand, key)
        if not base_cand or not key then return nil end
        local pair = env.wrap_map[key]; if not pair then return nil end
        local formatted = format_and_autocap(base_cand)
        local pr = env.wrap_parts[key] or { l = "", r = "" }
        local wrapped = (pr.l or "") .. (formatted.text or "") .. (pr.r or "")
        local start_pos = (last_seg and last_seg.start) or formatted.start or 0
        local end_pos   = (last_seg and last_seg._end)  or (start_pos + #code)
        local nc = Candidate(formatted.type, start_pos, end_pos, wrapped, formatted.comment)
        nc.preedit = formatted.preedit
        return nc, (formatted.text or ""), wrapped
    end
    -- 兜底逻辑
    local function improved_fallback_emit()
        -- Wrap/Completion 兜底逻辑
        if not code_has_symbol or not tail_text then return false end
        local pos = tail_text:find(symbol, 1, true)
        if not (pos and pos > 1) then return false end
        local left  = sub(tail_text, 1, pos - 1)
        local right = sub(tail_text, pos + 1)
        if not (left and #left > 0) then return false end

        local start_pos    = (last_seg and last_seg.start) or 0
        local end_pos_full = (last_seg and last_seg._end)  or #code
        local base_text    = left

        local key = (right or ""):lower()
        if key ~= "" and env.wrap_map[key] then
            local base_cand = Candidate("completion", start_pos, end_pos_full, base_text, "")
            local nc, base_text2, wrapped_text = wrap_from_base(base_cand, key)
            if nc then
                emit_with_pipeline(nc, emit_ctx)
                if env.suppress_mirror then
                    emit_ctx.suppress_set = { [base_text2] = true, [wrapped_text] = true }
                end
                return true
            end
        end

        if not right or #right == 0 then
            -- 如果只是 abc\ 且没触发英文逻辑，默认不干涉或按需输出
            -- 如果你希望单 \ 不出候选，这里可以 return true 并不 yield
            -- 原逻辑：
            local nc = Candidate("completion", start_pos, end_pos_full, base_text, "")
            emit_with_pipeline(nc, emit_ctx)
            return true
        end

        local keep_tail = 1 + #(right or "")
        local end_pos_show = math.max(start_pos, end_pos_full - keep_tail)
        local nc = Candidate("completion", start_pos, end_pos_show, base_text, "")
        emit_with_pipeline(nc, emit_ctx)
        return true
    end

    --  非分组路径
    if not do_group then
        local idx = 0
        for cand in input:iter() do
            idx = idx + 1
            if idx == 1 and (not env.locked) then
                env.cache = clone_candidate(format_and_autocap(cand))
            end

            if idx == 1 then
                if not emit_ctx.drop_sentence_after_completion then
                    local txt = cand.text or ""
                    if is_table_type(cand) and #txt >= 4 and has_english_token_fast(txt) then
                        emit_ctx.drop_sentence_after_completion = true
                    end
                end
               
                if env.locked and (not wrap_key) and env.cache then
                    local start_pos = (last_seg and last_seg.start) or 0
                    local end_pos   = (last_seg and last_seg._end) or #code
                    if keep_tail_len and keep_tail_len > 0 then
                        end_pos = math.max(start_pos, end_pos - keep_tail_len)
                    end
                    local base = format_and_autocap(env.cache)
                    local nc = Candidate(base.type, start_pos, end_pos, base.text or "", base.comment)
                    nc.preedit = base.preedit
                    emit_with_pipeline(nc, emit_ctx)
                    goto continue_non_group
                end

                if wrap_key then
                    local base = env.cache or cand
                    local nc, base_text, wrapped_text = wrap_from_base(base, wrap_key)
                    if nc then
                        emit_with_pipeline(nc, emit_ctx)
                        if env.suppress_mirror then
                            emit_ctx.suppress_set = { [base_text] = true, [wrapped_text] = true }
                        end
                        goto continue_non_group
                    end
                end
            end

            emit_with_pipeline(cand, emit_ctx)
            ::continue_non_group::
        end

        -- 如果没有候选 (idx == 0)，调用改进后的兜底逻辑
        if idx == 0 then
            improved_fallback_emit()
        end
        return
    end

    --  分组路径（2..6 码）
    local idx2, mode, grouped_cnt = 0, "unknown", 0
    local window_closed = false
    local group2_others = {}

    local function flush_groups()
        for _, c in ipairs(group2_others) do
            emit_with_pipeline(c, emit_ctx)
        end
        for i = #group2_others, 1, -1 do group2_others[i] = nil end
    end

    for cand in input:iter() do
        idx2 = idx2 + 1
        if idx2 == 1 and (not env.locked) then
            env.cache = clone_candidate(format_and_autocap(cand))
        end

        if idx2 == 1 then
            if not emit_ctx.drop_sentence_after_completion then
                local t = fast_type(cand)
                local txt = cand.text or ""
                if t == "table" and #txt >= 4 and has_english_token_fast(txt) then
                    emit_ctx.drop_sentence_after_completion = true
                end
            end

            local emitted = false
            if env.locked and (not wrap_key) and env.cache then
                local start_pos = (last_seg and last_seg.start) or 0
                local end_pos   = (last_seg and last_seg._end) or #code
                if keep_tail_len and keep_tail_len > 0 then
                    end_pos = math.max(start_pos, end_pos - keep_tail_len)
                end
                local base = format_and_autocap(env.cache)
                local nc = Candidate(base.type, start_pos, end_pos, base.text or "", base.comment)
                nc.preedit = base.preedit
                emit_with_pipeline(nc, emit_ctx)
                emitted = true
            elseif wrap_key then
                local base = env.cache or cand
                local nc, base_text, wrapped_text = wrap_from_base(base, wrap_key)
                if nc then
                    emit_with_pipeline(nc, emit_ctx)
                    emitted = true
                    if env.suppress_mirror then
                        emit_ctx.suppress_set = { [base_text] = true, [wrapped_text] = true }
                    end
                end
            end

            if not emitted then
                emit_with_pipeline(cand, emit_ctx)
            end

        elseif idx2 == 2 and mode == "unknown" then
            if is_table_type(cand) then
                mode = "passthrough"
                emit_with_pipeline(cand, emit_ctx)
            else
                mode = "grouping"
                grouped_cnt = 1
                if is_table_type(cand) and (not has_english_token_fast(cand.text)) then
                    emit_with_pipeline(cand, emit_ctx)
                else
                    table.insert(group2_others, cand)
                end
                if sort_window > 0 and grouped_cnt >= sort_window then
                    flush_groups()
                    window_closed = true
                end
            end

        else
            if mode == "passthrough" then
                emit_with_pipeline(cand, emit_ctx)
            else
                if (not window_closed) and ((sort_window <= 0) or (grouped_cnt < sort_window)) then
                    grouped_cnt = grouped_cnt + 1
                    if is_table_type(cand) and (not has_english_token_fast(cand.text)) then
                        emit_with_pipeline(cand, emit_ctx)
                    else
                        table.insert(group2_others, cand)
                    end
                    if sort_window > 0 and grouped_cnt >= sort_window then
                        flush_groups()
                        window_closed = true
                    end
                else
                    emit_with_pipeline(cand, emit_ctx)
                end
            end
        end
    end

    if idx2 == 0 then
        improved_fallback_emit()
    end

    if mode == "grouping" and not window_closed then
        flush_groups()
    end
end
return M
