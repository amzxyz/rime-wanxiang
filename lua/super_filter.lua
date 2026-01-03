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
-- 功能G 由于在混输场景中输入comment commit等等之类的英文时候，由于直接辅助码的派生能力，会将三个好不想干的单字组合在一起，这会造成不好的体验
--      因此在首选已经是英文的时候，且type=completion且大于等于4个字符，这个时候后面如果有type=sentence的派生词则直接干掉，这个还要依赖，表翻译器
--      权重设置与主翻译器不可相差太大
-- 功能H：英文自动空格（english_spacing）
--      支持模式：off(默认), before(前), after(后), smart(连续英文时在前加空格)
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
    local text = cand.text
    if not text or text == "" then return cand end
    
    local changed = false
    -- 空白规范化
    local norm = normalize_spaces(text)
    if norm ~= text then
        text = norm
        changed = true
    end
    -- 转义替换 (\n, \t, \s 等)
    -- 必须先处理转义，因为转义可能会改变字符串开头 (如 \sApple -> Apple)
    if find(text, "\\", 1, true) then
        local t2, ch = apply_escape_fast(text)
        if ch then 
            text = t2
            changed = true
        end
    end
    -- 状态检测：转义完成后，检测当前文本是否为 ASCII 短语
    local b1 = byte(text, 1)
    local is_ascii_phrase = (b1 and b1 <= 127 and is_ascii_phrase_fast(text))
    -- 英文自动大写
    if code_ctx.enable_cap and is_ascii_phrase then
        local pure_word = is_ascii_word_fast(text)

        if cand.type == "completion" or ascii_equal_ignore_case_to_pure(text, code_ctx.pure_code_lc) then
            local new_text = nil
            
            if code_ctx.all_upper and pure_word then
                -- 全大写逻辑 (HELLO)
                new_text = upper(text)
            else
                -- 首字母大写逻辑 (Hello)
                new_text = text:gsub("^%a", string.upper)
            end

            if new_text and new_text ~= text then
                text = new_text
                changed = true
            end
        end
    end
    -- 英文自动空格
    if is_ascii_phrase and code_ctx.spacing_mode and code_ctx.spacing_mode ~= "off" then
        local mode = code_ctx.spacing_mode
        
        -- smart模式: 若“上次上屏是英文”且“当前也是英文”，则在前面补空格
        if mode == "smart" then
            if code_ctx.prev_is_eng then
                text = " " .. text
                changed = true
            end
        elseif mode == "before" then
            text = " " .. text
            changed = true
        elseif mode == "after" then
            text = text .. " "
            changed = true
        end
    end
    -- 输出结果
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
    local dist = (rime_api.get_distribution_code_name() or ""):lower()

    local charsetFile
    if dist == "weasel" then
        -- 小狼毫：直接用相对路径，避免 Win 上绝对路径 + ReverseDb 的兼容问题
        charsetFile = "lua/charset.bin"
    else
        -- 其他前端：正常用 fallback 找到 user/shared 目录里的绝对路径
        charsetFile = wanxiang.get_filename_with_fallback("lua/charset.bin") or "lua/charset.bin"
    end

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
-- =======================================================
-- 基于英文模式Preedit的智能分段空格
-- =======================================================
local function restore_sentence_spacing(cand)
    local guide = cand.preedit or ""
    -- 如果 Preedit 没空格，说明没分段，直接返回
    if not string.find(guide, " ") then return cand end

    local text = cand.text
    local text_len = #text
    local parts = {}
    local p = 1 -- 全局扫描指针
    -- 辅助：取纯字母小写指纹
    local function pure(s) return string.gsub(s, "[^a-zA-Z]", ""):lower() end
    local function find_target_in_text(start_pos, target_fp)
        -- 剪枝：如果剩下的长度比 target 还短，肯定没了
        if (text_len - start_pos + 1) < #target_fp then return nil, nil end
        -- 从 start_pos 开始，向后逐字尝试
        for i = start_pos, text_len do
            -- 首字母必须匹配，才值得进去做全词扫描
            -- 比如 target="apple"，只有遇到 'a'/'A' 才进去看
            local char_i = string.sub(text, i, i)
            local first_char_fp = string.lower(char_i)
            if first_char_fp == string.sub(target_fp, 1, 1) then
                -- 潜入匹配：尝试从位置 i 开始凑齐 target
                local scan_p = i
                local letters_acc = ""
                while scan_p <= text_len do
                    local char = string.sub(text, scan_p, scan_p)
                    -- 只收集字母
                    if string.find(char, "[a-zA-Z]") then
                        letters_acc = letters_acc .. string.lower(char)
                    end
                    if letters_acc == target_fp then
                        -- 找到了！返回 (起点, 终点)
                        return i, scan_p 
                    end
                    -- 剪枝：如果凑出来的字母已经比目标不一样或更长，说明不是这个
                    -- 比如 target="app", 凑出了 "apx" -> 失败，跳出 while，继续外层 for
                    if #letters_acc > #target_fp then break end
                    if string.sub(letters_acc, 1, #letters_acc) ~= string.sub(target_fp, 1, #letters_acc) then break end
                    scan_p = scan_p + 1
                end
            end
        end
        return nil, nil
    end
    -- 遍历 Preedit 的每一段
    for seg in string.gmatch(guide, "%S+") do
        local target = pure(seg)
        if #target > 0 then
            -- 在当前指针 p 往后无限寻找
            local match_start, match_end = find_target_in_text(p, target)
            if match_start then
                -- 隔离病灶（中间跳过不匹配的）
                if match_start > p then
                    local lesion = string.sub(text, p, match_start - 1)
                    table.insert(parts, lesion)
                end
                -- 存入正确单词
                local valid_word = string.sub(text, match_start, match_end)
                table.insert(parts, valid_word)
                -- 更新指针
                p = match_end + 1
            else
                -- 没找到：说明这个 preedit 词完全消失了（比如 preedit 有 5 个词，candidate 只有 4 个）
                -- 策略：忽略这个 guide，继续用下一个 guide 找
            end
        end
    end
    -- 尾部处理
    if p <= text_len then
        local tail = string.sub(text, p)
        if #parts > 0 then table.insert(parts, tail)
        else table.insert(parts, tail) end
    end
    -- 重组
    local new_text = table.concat(parts, " ")
    local nc = Candidate(cand.type, cand.start, cand._end, new_text, cand.comment)
    nc.preedit = cand.preedit
    return nc
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
    -- 英文自动空格配置
    -- off: 关闭; before: 前加; after: 后加; smart: 连续英文时前加
    env.english_spacing_mode = "off"
    if cfg then
        local oks, sv = pcall(function() return cfg:get_string("english_spacing") end)
        if oks and sv and (sv == "before" or sv == "after" or sv == "smart") then
            env.english_spacing_mode = sv
        end
    end
    -- 上一次上屏是否为英文（用于 smart 模式）
    env.prev_commit_is_eng = false
    -- 注册 commit 通知器来追踪上屏历史
    if env.engine and env.engine.context then
        env.commit_notifier = env.engine.context.commit_notifier:connect(function(ctx)
            local commit_text = ctx:get_commit_text()
            -- 判断是不是常规的英文单词
            local is_eng = is_ascii_phrase_fast(commit_text)
            -- 如果不是单词，再检查是不是单独的英文标点
            if not is_eng then
                -- 去掉末尾可能的空格，防止影响判断
                local clean = commit_text:gsub("%s+$", "") 
                -- 如果是 逗号、句号、感叹号、问号，也强行算作英文
                if clean == "," or clean == "." or clean == "!" or clean == "?" then
                    is_eng = true
                end
            end
            -- 更新状态
            env.prev_commit_is_eng = is_eng
            -- 屏后，立即清除打断信号
            ctx:set_property("english_spacing", "") 
        end)
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

function M.fini(env) 
    if env.commit_notifier then
        env.commit_notifier:disconnect()
        env.commit_notifier = nil
    end
end
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

    -- 1. 字符集过滤：只有在 charset_strict = true 时才启用
    if ctxs.charset_strict and cand.text and cand.text ~= "" then
        if not in_charset(env, cand.text) then
            return
        end
    end
    -- 2. 准备变量
    local is_en = ctxs.is_english and ctxs.is_english(cand) or false
    local BAGUA_SYMBOL = "\226\152\175"
    local is_bagua_sentence = (fast_type(cand) == "sentence") and (cand.comment and string.find(cand.comment, BAGUA_SYMBOL))

    -- 3. 三态语言过滤
    if ctxs.zh_only and is_en then return end
    if ctxs.en_only and (not is_en) then return end

    -- 4. 八卦图处理
    if ctxs.en_only then
        -- 英文模式：如果是八卦图，用 Preedit 还原空格
        if is_bagua_sentence then
            cand = restore_sentence_spacing(cand)
        end
    elseif (not ctxs.zh_only) then
        -- 混合模式：隐藏
        if is_bagua_sentence then return end
    end

    -- 5. 抑制句子
    if (not ctxs.en_only) and ctxs.drop_sentence_after_completion then
        if fast_type(cand) == "sentence" then return end
    end

    -- 6 镜像抑制
    if ctxs.suppress_mirror and ctxs.suppress_set and ctxs.suppress_set[cand.text] then
        return
    end

    -- 7 格式化 + 大写 + span 对齐
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

    -- 当前是否在反查/自造词/标点段
    local in_reverse_seg = is_reverse_lookup_segment(env)

    -- 本次是否启用 charset 过滤
    local charset_strict = (env.charset ~= nil)
                           and (not option_extended)
                           and (not in_reverse_seg)

    -- 状态清理
    if not code or code == "" then
        env.cache, env.locked = nil, false
    end
    if comp and comp:empty() then
        env.cache, env.locked = nil, false
    end

    local symbol = env.symbol

    -- 强制英文检测 (仅针对双击符号 \\)
    local force_english_text = nil
    local delimiter = nil
    
    -- 只有定义了符号，且输入长度足够才检测
    if symbol and #symbol == 1 then
        delimiter = symbol .. symbol -- 定义触发符为两个符号
        if code and #code >= 3 then
            local c_len = #code
            -- 严格检测：末尾最后两个字符必须等于 "符号+符号"
            if string.sub(code, c_len - 1, c_len) == delimiter then
                -- 提取基础文本 (去掉末尾的 \\)
                local base = string.sub(code, 1, c_len - 2)
                if base and #base > 0 then
                    -- 纯 ASCII 检查 (防止误把中文截断)
                    local ascii_only = true
                    for i = 1, #base do
                        if string.byte(base, i) > 127 then 
                            ascii_only = false; break 
                        end
                    end
                    if ascii_only then
                        force_english_text = base
                    end
                end
            end
        end
    end
    -- =======================================================

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
    local all_upper      = code:find("^%u%u") ~= nil
    local first_upper    = (not all_upper) and (code:find("^%u") ~= nil)
    local enable_cap     = (code_len > 1 and not code:find("^[%l%p]"))
    local break_signal = (ctx:get_property("english_spacing") == "true")  --接受空状态下的空格或者回车信号
    -- 计算最终的 prev_is_eng (上文是否为英文)
    local effective_prev_is_eng = env.prev_commit_is_eng
    if break_signal then
        -- 收到打断信号，强制认为上文不是英文（从而不自动加空格）
        effective_prev_is_eng = false
    end
    local code_ctx = {
        pure_code     = pure_code,
        pure_code_lc  = pure_code_lc,
        all_upper     = all_upper,
        first_upper   = first_upper,
        enable_cap    = enable_cap,
        spacing_mode  = env.english_spacing_mode, -- 传递空格模式配置
        prev_is_eng   = effective_prev_is_eng,     -- 传递上一次上屏是否英文
    }

    local en_only, zh_only = false, false
    if ctx then
        en_only = ctx:get_option("en_only") or false
        zh_only = ctx:get_option("zh_only") or false
    end

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
        suppress_set    = nil,
        suppress_mirror = env.suppress_mirror,
        code_ctx        = code_ctx,
        unify_tail_span = unify_tail_span,
        en_only         = en_only,
        zh_only         = zh_only,
        is_english      = is_english_candidate,
        charset_strict  = charset_strict,
        drop_sentence_after_completion = false,
    }

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
    -- 兜底逻辑 (处理无候选词的情况，如 scx\\)
    local function improved_fallback_emit()
        -- 优先处理强制英文：只要触发符匹配，即使无其他候选也必须输出
        if force_english_text then
            local start_pos = (last_seg and last_seg.start) or 0
            -- 关键点：end_pos 设为 #code，确保上屏时覆盖掉 "scx\\"
            local end_pos   = #code 
            local eng = Candidate("completion", start_pos, end_pos, force_english_text, "")
            eng.preedit = force_english_text
            
            -- 这里不设 pipeline，直接输出，保证它一定是第一个
            yield(eng) 
            return true
        end

        -- 以下是原有的 Wrap/Completion 兜底逻辑
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

    -- ===== 非分组路径 =====
    if not do_group then
        local idx = 0
        for cand in input:iter() do
            idx = idx + 1
            if idx == 1 and (not env.locked) then
                env.cache = clone_candidate(format_and_autocap(cand, code_ctx))
            end

            if idx == 1 then
                -- 有候选词时，优先插入英文
                if force_english_text then
                    local start_pos = 0 
                    local end_pos   = #code -- 覆盖全长，消除 \\
                    local eng = Candidate("completion", start_pos, end_pos, force_english_text, cand.comment)
                    eng.preedit = force_english_text 
                    emit_ctx.drop_sentence_after_completion = true
                    emit_with_pipeline(eng, emit_ctx)
                end
                
                if not emit_ctx.drop_sentence_after_completion then
                    local txt = cand.text or ""
                    if is_table_type(cand) and #txt >= 4 and has_english_token_fast(txt) then
                        emit_ctx.drop_sentence_after_completion = true
                    end
                end
                
                if (not force_english_text) and env.locked and (not wrap_key) and env.cache then
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
            -- 分组模式下同样插入英文
            if force_english_text then
                local start_pos = 0
                local end_pos   = #code -- 覆盖全长
                local eng = Candidate("completion", start_pos, end_pos, force_english_text, cand.comment)
                eng.preedit = force_english_text 

                emit_ctx.drop_sentence_after_completion = true
                emit_with_pipeline(eng, emit_ctx)
            end

            if not emit_ctx.drop_sentence_after_completion then
                local t = fast_type(cand)
                local txt = cand.text or ""
                if t == "table" and #txt >= 4 and has_english_token_fast(txt) then
                    emit_ctx.drop_sentence_after_completion = true
                end
            end

            local emitted = false
            if (not force_english_text) and env.locked and (not wrap_key) and env.cache then
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
