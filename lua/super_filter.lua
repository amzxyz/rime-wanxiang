-- @amzxyz  https://github.com/amzxyz/rime_wanxiang
-- 功能 A：候选文本中的转义序列格式化（始终开启）
--         \n \t \r \\ \s(空格) \d(-)
-- 功能 B：英文自动大写（始终开启）
--         - 首字母大写：输入首字母大写 → 候选首字母大写（Hello）
--         - 全部大写：输入前 2+ 个大写 → 候选全大写（HEllo → HELLO）
--         - 仅对 ASCII 单词生效；若候选含空格、-、@、#、· 等也认为是英文
-- 功能 C：候选重排（仅编码长度 2..6 时）
--         - 第一候选不动
--         - 其余按组输出：①不含字母(table/user_table) → ②其他
--         - 若第二候选为 table/user_table，则不排序，直接透传
-- 功能 D：成对符号包裹（触发：最后分段完整消耗且出现 prefix\suffix；suffix 命中映射时吞掉 \suffix）
-- 缓存/锁定：
--   - 未锁定时记录第一候选为缓存
--   - 出现 prefix\suffix 且 prefix 非空 ⇒ 锁定
--   - 兜底重建，当有些单词类型输入斜杠后不产出候选就将前面产生的进行构造候选
--   - 输入为空时释放缓存/锁定
-- 镜像：
--   - schema: paired_symbols/mirror (bool，默认 true)
--   - 包裹后可抑制"包裹前文本/包裹后文本"再次出现在后续候选里
-- 功能 E：三态语言模式（通过 options 控制，仅在输出层过滤，不改变内部逻辑）
--   - ctx:get_option("en_only") == true → 仅英文：只保留英文候选
--   - ctx:get_option("zh_only") == true → 仅中文：丢弃英文候选
--   - 两者都 false → 混合模式：中英都输出
-- 功能F 字符集过滤，默认8105+𰻝𰻝，可以在方案中定义黑白名单来实现用户自己的范围微调charsetlist: []和charsetblacklist: [𰻝, 𰻞]
local wanxiang = require("wanxiang")
local M = {}

local byte, find, gsub, upper, sub = string.byte, string.find, string.gsub, string.upper, string.sub

-- ========= 工具 =========
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
            -- A-Z
            if b >= 0x41 and b <= 0x5A then
                return true
            end
            -- a-z
            if b >= 0x61 and b <= 0x7A then
                return true
            end
            -- 你自己想认的几个 ASCII 符号：
            -- 空格、#、-、@、'
            if b == 0x20   -- space
               or b == 0x23  -- '#'
               or b == 0x2D  -- '-'
               or b == 0x40  -- '@'
               or b == 0x27  -- '\''
            then
                return true
            end
            -- 如果想再加别的 ASCII 标点，也在这里列
        else
            -- b >= 0x80: UTF-8 非 ASCII 字节，直接跳过
        end
    end
    return false
end

local function is_ascii_word_fast(s)
    if s == "" then return false end
    for i = 1, #s do
        local b = byte(s, i)
        if not ((b >= 65 and b <= 90) or (b >= 97 and b <= 122)) then return false end
    end
    return true
end
local function is_ascii_phrase_fast(s)
    if s == "" then return false end
    local has_alpha = false
    for i = 1, #s do
        local b = byte(s, i)
        if b > 127 then
            return false -- 出现非 ASCII，直接不是英文短语
        end
        if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
            has_alpha = true -- 有至少一个字母
        end
    end
    return has_alpha
end
local function ascii_equal_ignore_case_to_pure(text, pure_code_lc)
    -- 提取 text 里的所有字母，转成小写
    local buf = {}
    for i = 1, #text do
        local b = byte(text, i)
        if b >= 65 and b <= 90 then b = b + 32 end -- 大写转小写
        if b >= 97 and b <= 122 then
            buf[#buf+1] = string.char(b)
        elseif b > 127 then
            -- 出现非 ASCII，直接视为不匹配，防止中文乱入
            return false
        end
    end
    local letters = table.concat(buf)
    if #letters ~= #pure_code_lc then
        return false
    end
    return letters == pure_code_lc and (false == false and true or false) or false
end

-- ========= 英文候选判定 =========
-- 使用现有的 has_english_token_fast 叠加 is_table_type：
--   - 若不属于 table/user_table/fixed：只要含英文 token 即视为英文候选
--   - 若属于 table/user_table/fixed：要求“只含 ASCII”（没有中文），且含英文 token
local function is_english_candidate(cand)
    if not cand or not cand.text or cand.text == "" then return false end
    local txt = cand.text

    if not has_english_token_fast(txt) then
        return false
    end

    if is_table_type(cand) then
        -- 表内候选如果混有非 ASCII（大概率是中文），就不当英文处理
        for i = 1, #txt do
            local b = byte(txt, i)
            if b > 127 then
                return false
            end
        end
    end

    return true
end

-- ========= 空白规范化 ==========
local NBSP = string.char(0xC2, 0xA0)       -- U+00A0 不换行空格
local FWSP = string.char(0xE3, 0x80, 0x80) -- U+3000 全角空格
local ZWSP = string.char(0xE2, 0x80, 0x8B) -- U+200B 零宽空格
local BOM  = string.char(0xEF, 0xBB, 0xBF) -- U+FEFF BOM
local ZWNJ = string.char(0xE2, 0x80, 0x8C) -- U+200C 零宽不连字
local ZWJ  = string.char(0xE2, 0x80, 0x8D) -- U+200D 零宽连字

local function normalize_spaces(s)
    if not s or s == "" then return s end
    -- opencc 中译英转换英文间隔空格为正常空格
    s = s:gsub(NBSP, " ")
    -- :gsub(FWSP, " ")
    return s
end

-- ========= 文本格式化（转义 + 自动大写）=========
local escape_map = {
    ["\\n"] = "\n", ["\\t"] = "\t", ["\\r"] = "\r",
    ["\\\\"] = "\\", ["\\s"] = " ", ["\\d"] = "-",
}
local esc_pattern = "\\[ntrsd\\\\]"

local function apply_escape_fast(text)
    if not text or find(text, "\\", 1, true) == nil then return text, false end
    local new_text = gsub(text, esc_pattern, function(esc) return escape_map[esc] or esc end)
    return new_text, new_text ~= text
end

local function format_and_autocap(cand, code_ctx)
    -- 对候选做：空白规范化 → 转义替换 → 英文大写
    local text = cand.text
    if not text or text == "" then return cand end

    -- ① 空白规范化
    local norm = normalize_spaces(text)
    local changed = (norm ~= text)
    text = norm

    local has_backslash = (find(text, "\\", 1, true) ~= nil)
    local b1 = byte(text, 1)

    -- ② 转义替换
    if has_backslash then
        local t2, ch = apply_escape_fast(text)
        if ch then text, changed = t2, true end
    end
    -- ③ 英文自动大写：
    --    - 允许 ASCII 短语（he's / e-mail）
    --    - 只有“纯字母单词”才会在 all_upper 时变成全大写
    if code_ctx.enable_cap then
        if b1 and b1 <= 127 and is_ascii_phrase_fast(text) then
            -- 纯字母单词：a..z / A..Z
            local pure_word = is_ascii_word_fast(text)

            if cand.type == "completion" or ascii_equal_ignore_case_to_pure(text, code_ctx.pure_code_lc) then
                local new_text
                if code_ctx.all_upper and pure_word then
                    -- 只有纯单词才允许全大写：HELLO
                    new_text = upper(text)
                else
                    -- 带符号（he's、e-mail…）即使 all_upper 也只做首字母大写
                    new_text = text:gsub("^%a", string.upper)
                end

                if new_text and new_text ~= text then
                    text = new_text
                    changed = true
                end
            end
        end
    end

    if not changed then return cand end
    local nc = Candidate(cand.type, cand.start, cand._end, text, cand.comment)
    nc.preedit = cand.preedit
    return nc
end

local function clone_candidate(c)
    local nc = Candidate(c.type, c.start, c._end, c.text, c.comment)
    nc.preedit = c.preedit
    return nc
end

-- ========= 包裹映射 =========
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

    -- ===== 扩展括号族 / 引号 =====
    dy = "''",       -- 英文单引号
    sy = "\"\"",     -- 英文双引号
    zs = "“”",       -- 中文弯双引号
    zd = "‘’",       -- 中文弯单引号
    fy = "``",       -- 反引号

    -- ===== 双字母括号族 =====
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

    -- ===== Markdown / 标记 =====
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

    -- ===== 运算与标记符 =====
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

local function utf8_chars(s)
    local chars = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(chars, ch)
    end
    return chars
end

-- wrap_map 预编译为左右两部分
local function precompile_wrap_parts(wrap_map, delimiter)
    delimiter = delimiter or "|"
    local parts = {}
    for k, wrap_str in pairs(wrap_map) do
        if not wrap_str or wrap_str == "" then
            parts[k] = { l = "", r = "" }
        else
            local pos = string.find(wrap_str, delimiter, 1, true)
            if pos then
                local left = string.sub(wrap_str, 1, pos - 1) or ""
                local right = string.sub(wrap_str, pos + 1) or ""
                parts[k] = { l = left, r = right }
            else
                local chars = utf8_chars(wrap_str)
                if #chars == 0 then
                    parts[k] = { l = "", r = "" }
                elseif #chars == 1 then
                    parts[k] = { l = chars[1], r = "" }
                elseif #chars == 2 then
                    parts[k] = { l = chars[1], r = chars[2] }
                else
                    parts[k] = { l = chars[1], r = chars[#chars] }
                end
            end
        end
    end
    return parts
end
-- ========= 字符集过滤工具 =========
-- 单个码点是否在 charset 里（带缓存，考虑白名单 + 黑名单）
local function codepoint_in_charset(env, codepoint)
    if not env then
        return true
    end

    local memo = env.charset_memo
    if memo and memo[codepoint] ~= nil then
        return memo[codepoint]
    end

    -- 黑名单：优先级最高，命中就直接 false
    if env.charset_block and env.charset_block[codepoint] then
        if memo then memo[codepoint] = false end
        return false
    end

    -- 白名单：命中就直接 true
    if env.charset_extra and env.charset_extra[codepoint] then
        if memo then memo[codepoint] = true end
        return true
    end

    -- 没有主表（没配 wanxiang_charset），那就只靠黑白名单
    if not env.charset then
        local ok = true   -- 不在黑名单就算通过；白名单已经在上面处理过了
        if memo then memo[codepoint] = ok end
        return ok
    end

    -- 正常情况：用表滤镜查一遍
    local ch = utf8.char(codepoint)
    local ok = env.charset:lookup(ch) ~= ""

    if memo then memo[codepoint] = ok end
    return ok
end

--[[ 整个 text 是否通过“字符集过滤”
-- 规则：只检查「汉字」，非汉字（英文/符号）直接视为通过；
--      只要出现一个不在 charset 的汉字，就整条候选丢弃。
local function in_charset(env, text)
    if not env or not env.charset or not text or text == "" then
        return true
    end
    for _, cp in utf8.codes(text) do
        local ch = utf8.char(cp)
        if wanxiang.IsChineseCharacter(ch) then
            if not codepoint_in_charset(env, cp) then
                return false
            end
        end
    end
    return true
end]]--
-- 整个 text 是否通过“字符集过滤”
-- 现在只对【单个汉字】做过滤，多字词/非汉字候选都直接通过
local function in_charset(env, text)
    if not env or not env.charset or not text or text == "" then
        return true
    end
    -- 统计码点数，只要不是恰好 1 个码点，就不做过滤
    local cp, count = nil, 0
    for _, c in utf8.codes(text) do
        cp = c
        count = count + 1
        if count > 1 then
            return true    -- 多字词：直接通过
        end
    end
    if count ~= 1 or not cp then
        return true
    end
    local ch = utf8.char(cp)
    if not wanxiang.IsChineseCharacter(ch) then
        return true       -- 单个但不是汉字：直接通过
    end
    -- 单个汉字：按 charset + 黑白名单过滤
    return codepoint_in_charset(env, cp)
end
-- 当前 composition 的最后一个 seg 是否属于「反查/造词/标点」之类
local function is_reverse_lookup_segment(env)
    if not env or not env.engine or not env.engine.context then
        return false
    end
    local comp = env.engine.context.composition
    if not comp then
        return false
    end
    local seg = comp:back()
    if not seg then
        return false
    end
    return seg:has_tag("wanxiang_reverse")
        or seg:has_tag("add_user_dict")
        or seg:has_tag("punct")
end
-- ========= 字符集过滤初始化 =========
-- 从 schema 里读取 charsetlist / charsetblacklist
local function init_charset_filter(env, cfg)
    -- 主字符集（表滤镜）
    local charsetFile = wanxiang.get_filename_with_fallback("lua/charset.bin") or "lua/charset.bin"
    env.charset       = ReverseDb(charsetFile)
    env.charset_memo  = {}
    env.charset_extra = {}  -- 白名单
    env.charset_block = {}  -- 黑名单

    if not cfg then
        return
    end

    -- 通用读取函数：把一个 list 里所有码点放入 target 表
    local function load_charset_list(key, target_table)
        local ok_list, list = pcall(function()
            return cfg:get_list(key)
        end)
        if not ok_list or not list or list.size <= 0 then
            return
        end

        for i = 0, list.size - 1 do
            local item = list:get_value_at(i)
            if item then
                local v = item:get_string()
                if v and #v > 0 then
                    for _, cp in utf8.codes(v) do
                        target_table[cp] = true
                    end
                end
            end
        end
    end
    -- charsetlist: 白名单
    load_charset_list("charsetlist", env.charset_extra)
    -- charsetblacklist: 黑名单
    load_charset_list("charsetblacklist", env.charset_block)
end

-- ========= 生命周期 =========
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
end

function M.fini(env) end

-- ========= 统一产出通道 =========
-- ctxs:
--   charset          : 字符集过滤
--   suppress_set     : { [text] = true } 阻止镜像文本
--   suppress_mirror  : bool
--   code_ctx         : 编码上下文
--   unify_tail_span  : 尾部 span 对齐函数
--   en_only / zh_only: 三态语言模式
--   is_english       : 函数(cand) → bool
local function emit_with_pipeline(cand, ctxs)
    if not cand then return end

    local env = ctxs.env

    -- ① 字符集过滤：只有在 charset_strict = true 时才启用
    if ctxs.charset_strict and cand.text and cand.text ~= "" then
        if not in_charset(env, cand.text) then
            return
        end
    end

    -- ② 三态语言模式
    local is_en = ctxs.is_english and ctxs.is_english(cand) or false

    if ctxs.en_only and (not is_en) then
        return
    end

    if ctxs.zh_only and is_en then
        return
    end

    -- ③ 镜像抑制
    if ctxs.suppress_mirror and ctxs.suppress_set and ctxs.suppress_set[cand.text] then
        return
    end

    -- ④ 格式化 + 大写 + span 对齐
    cand = format_and_autocap(cand, ctxs.code_ctx)
    cand = ctxs.unify_tail_span(cand)
    yield(cand)
end



-- ========= 主流程 =========
function M.func(input, env)
    local ctx  = env and env.engine and env.engine.context or nil
    local code = ctx and (ctx.input or "") or ""
    local comp = ctx and ctx.composition or nil
    local option_extended = false
    if ctx then
        option_extended = ctx:get_option("charset_filter") or false
    end

    -- 当前是否在反查/自造词/标点段：这些段不做过滤
    local in_reverse_seg = is_reverse_lookup_segment(env)

    -- 本次是否启用 charset 过滤：
    --   1) env.charset 存在（schema 里定义了 wanxiang_charset）
    --   2) 没开扩展开关（charset_filter = false 或未设）
    --   3) 当前段不是反查/自造词/标点
    local charset_strict = (env.charset ~= nil)
                           and (not option_extended)
                           and (not in_reverse_seg)
    -- 输入为空：释放状态
    if not code or code == "" then
        env.cache, env.locked = nil, false
    end

    -- composition 为空：只重置状态，不 return（避免输入 "\" 后空候选）
    if comp and comp:empty() then
        env.cache, env.locked = nil, false
    end

    local symbol = env.symbol
    local code_has_symbol = symbol and #symbol == 1 and (find(code, symbol, 1, true) ~= nil)

    -- segmentation：用于判断最后一段是否"完全消耗"
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

    -- 宽松尾部：失败时退化为整个 code（给兜底逻辑用）
    local tail_text = (last_seg and last_seg.start and last_seg._end) and sub(code, last_seg.start + 1, #code) or code

    -- 解析 prefix\suffix（严格路径：需 fully_consumed）
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

    -- code 上下文（供格式化/大写逻辑使用）
    local code_len       = #code
    local do_group       = (code_len >= 2 and code_len <= 6)
    local sort_window    = tonumber(env.settings.sort_window) or 30
    local pure_code      = gsub(code, "[%s%p]", "")
    local pure_code_lc   = pure_code:lower()
    local all_upper      = code:find("^%u%u") ~= nil
    local first_upper    = (not all_upper) and (code:find("^%u") ~= nil)
    local enable_cap     = (code_len > 1 and not code:find("^[%l%p]"))
    local code_ctx = {
        pure_code     = pure_code,
        pure_code_lc  = pure_code_lc,
        all_upper     = all_upper,
        first_upper   = first_upper,
        enable_cap    = enable_cap,
    }

    -- 三态语言模式：en_only / zh_only / mixed
    local en_only, zh_only = false, false
    if ctx then
        en_only = ctx:get_option("en_only") or false
        zh_only = ctx:get_option("zh_only") or false
    end

    -- 吞尾对齐：包裹时把 end 对齐到最后段，避免露出 \suffix
    local function unify_tail_span(c)
        if fully_consumed and wrap_key and last_seg and c and c._end ~= last_seg._end then
            local nc = Candidate(c.type, c.start, last_seg._end, c.text, c.comment)
            nc.preedit = c.preedit
            return nc
        end
        return c
    end

    -- 产出上下文（统一传入）
    local emit_ctx = {
        env             = env,
        suppress_set    = nil,
        suppress_mirror = env.suppress_mirror,
        code_ctx        = code_ctx,
        unify_tail_span = unify_tail_span,
        en_only         = en_only,
        zh_only         = zh_only,
        is_english      = is_english_candidate,
        charset_strict  = charset_strict,
    }

    -- 生成包裹候选（统一写法）
    local function wrap_from_base(base_cand, key)
        if not base_cand or not key then return nil end
        local pair = env.wrap_map[key]; if not pair then return nil end
        local formatted = format_and_autocap(base_cand, code_ctx)
        local pr = env.wrap_parts[key] or { l = "", r = "" }
        local wrapped = (pr.l or "") .. (formatted.text or "") .. (pr.r or "")
        local start_pos = (last_seg and last_seg.start) or formatted.start or 0
        local end_pos   = (last_seg and last_seg._end)  or (start_pos + #code)
        local nc = Candidate(formatted.type, start_pos, end_pos, wrapped, formatted.comment)
        nc.preedit = formatted.preedit
        return nc, (formatted.text or ""), wrapped
    end

    -- ========= 改进的兜底逻辑：无候选时使用输入码 =========
    local function improved_fallback_emit()
        if not code_has_symbol or not tail_text then
            return false
        end

        -- tail_text 通常是最后一段编码，例如 "nide\" 或 "nide\k"
        local pos = tail_text:find(symbol, 1, true)
        if not (pos and pos > 1) then
            return false
        end

        local left  = sub(tail_text, 1, pos - 1)  -- "\" 前的部分
        local right = sub(tail_text, pos + 1)     -- "\" 后的部分（可能为空）
        if not (left and #left > 0) then
            return false
        end

        local start_pos    = (last_seg and last_seg.start) or 0
        local end_pos_full = (last_seg and last_seg._end)  or #code
        local base_text    = left   -- ★ 上屏文本只用 "\" 左边这段

        -- 情况 1："\suffix" 命中 wrap_key，走包裹候选
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

        -- 情况 2：只有一个结尾 "\"（right 为空）
        -- 期望：整段编码被消费（不留下 "\" 残留），但只上屏 left。
        if not right or #right == 0 then
            local nc = Candidate("completion", start_pos, end_pos_full, base_text, "")
            emit_with_pipeline(nc, emit_ctx)
            return true
        end

        -- 情况 3："\suffix" 但 suffix 不合法（既不是 wrap_key，也不想自动吃掉）
        -- 只消费前半段，把 "\" + suffix 留在编码里，方便用户编辑
        local keep_tail = 1 + #(right or "")
        local end_pos_show = math.max(start_pos, end_pos_full - keep_tail)
        local nc = Candidate("completion", start_pos, end_pos_show, base_text, "")
        emit_with_pipeline(nc, emit_ctx)
        return true
    end

    -- ===== 非分组路径 =====
    if not do_group then
        local idx = 0
        for cand in input:iter() do
            idx = idx + 1
            if idx == 1 and (not env.locked) then
                -- 缓存"已格式化"的第一候选（确保后续 \ 包裹保持形态）
                env.cache = clone_candidate(format_and_autocap(cand, code_ctx))
            end

            if idx == 1 then
                -- 仅锁定：置顶缓存，保留尾长（吞掉 \suffix）
                if env.locked and (not wrap_key) and env.cache then
                    local start_pos = (last_seg and last_seg.start) or 0
                    local end_pos   = (last_seg and last_seg._end) or #code
                    if keep_tail_len and keep_tail_len > 0 then
                        end_pos = math.max(start_pos, end_pos - keep_tail_len)
                    end
                    local base = format_and_autocap(env.cache, code_ctx)
                    local nc = Candidate(base.type, start_pos, end_pos, base.text or "", base.comment)
                    nc.preedit = base.preedit
                    emit_with_pipeline(nc, emit_ctx)
                    goto continue_non_group
                end

                -- 锁定 + 命中包裹键：直接生成包裹候选
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

            -- 常规产出
            emit_with_pipeline(cand, emit_ctx)
            ::continue_non_group::
        end

        -- 上游 0 候选但包含 "\"：兜底产出
        if idx == 0 then
            if improved_fallback_emit() then return end
        end
        return
    end

    -- ===== 分组路径（2..6 码）=====
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
            env.cache = clone_candidate(format_and_autocap(cand, code_ctx))
        end

        if idx2 == 1 then
            local emitted = false

            -- 仅锁定：置顶缓存，保留尾长
            if env.locked and (not wrap_key) and env.cache then
                local start_pos = (last_seg and last_seg.start) or 0
                local end_pos   = (last_seg and last_seg._end) or #code
                if keep_tail_len and keep_tail_len > 0 then
                    end_pos = math.max(start_pos, end_pos - keep_tail_len)
                end
                local base = format_and_autocap(env.cache, code_ctx)
                local nc = Candidate(base.type, start_pos, end_pos, base.text or "", base.comment)
                nc.preedit = base.preedit
                emit_with_pipeline(nc, emit_ctx)
                emitted = true

            -- 锁定 + 包裹
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
            -- 第二候选为 table/user_table：透传模式
            if is_table_type(cand) then
                mode = "passthrough"
                emit_with_pipeline(cand, emit_ctx)
            else
                -- 分组模式：①不含字母(table/user_table) → ②其他
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

    -- 上游 0 候选但包含 "\"：兜底产出（分组路径）
    if idx2 == 0 then
        improved_fallback_emit()
    end

    -- 结束时刷新分组缓存
    if mode == "grouping" and not window_closed then
        flush_groups()
    end
end

return M
