-- @amzxyz  https://github.com/amzxyz/rime-wanxiang
-- 提供以下核心修饰与兜底能力：
-- 功能 A：转义序列解析（常驻）
--         将候选词中的 \n, \t, \s(空格) 等文本转义符格式化为实际效果。
-- 功能 B：成对符号包裹与候选锁定
--         输入 `\` 瞬间锁定并展示当前候选快照，追加对应字母即可为候选词快速穿上各类括号/引号（如【】、“”）。
-- 功能 C：三码空候选轻量兜底
--         后台静默记录 2 码时的首选单字；当输入 3 码导致系统无候选时，立刻将该单字吐出救场。
-- 功能 D：中英混输长句防污染
--         当首选词为有效的英文单词（≥4字母）时，自动斩断辅助码的无理派生，屏蔽毫无关联的凑数中文长句。

local wanxiang = require("wanxiang/wanxiang")
local M = {}

-- 全局通信通道
_G.WanxiangSharedState = _G.WanxiangSharedState or {
    sorter_active = false,
    last_input = "",
    page_cache = {}
}

-- 性能优化：本地化字符串函数
local byte = string.byte
local find = string.find
local gsub = string.gsub
local upper = string.upper
local sub = string.sub
local utf8_codes = utf8.codes
local utf8_len = utf8.len

local function get_first_utf8_char(s)
    if not s or s == "" then return "" end
    local offset = utf8.offset(s, 2)
    return offset and sub(s, 1, offset - 1) or s
end

local function fast_type(c)
    local t = c.type
    if t then 
        return t 
    end
    
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
            if (b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A) then
                return true
            end
        end
    end
    return false
end

-- 1. 内部常量与工具函数
local escape_map = {
    ["\\n"] = "\n",
    ["\\r"] = "\r",
    ["\\t"] = "\t",
    ["\\s"] = " ",
    ["\\z"] = "\226\128\139",
}

local utf8_char_pattern = "[%z\1-\127\194-\244][\128-\191]*"

local shichen_data = {
    {name = "子时", start_hour = 23, end_hour = 1},
    {name = "丑时", start_hour = 1,  end_hour = 3},
    {name = "寅时", start_hour = 3,  end_hour = 5},
    {name = "卯时", start_hour = 5,  end_hour = 7},
    {name = "辰时", start_hour = 7,  end_hour = 9},
    {name = "巳时", start_hour = 9,  end_hour = 11},
    {name = "午时", start_hour = 11, end_hour = 13},
    {name = "未时", start_hour = 13, end_hour = 15},
    {name = "申时", start_hour = 15, end_hour = 17},
    {name = "酉时", start_hour = 17, end_hour = 19},
    {name = "戌时", start_hour = 19, end_hour = 21},
    {name = "亥时", start_hour = 21, end_hour = 23},
}

local ke_names = {"初刻", "二刻", "三刻", "四刻", "五刻", "六刻", "七刻", "八刻"}

local function get_shichen_and_ke(hour, min)
    local total_minutes = hour * 60 + min
    for _, shichen in ipairs(shichen_data) do
        local shichen_name = shichen.name
        local start_hour = shichen.start_hour
        local end_hour = shichen.end_hour
        local start_minutes = start_hour * 60
        local end_minutes = end_hour * 60
        local is_match = false
        if start_hour > end_hour then
            if total_minutes >= start_minutes or total_minutes < end_minutes then
                is_match = true
            end
        else
            if total_minutes >= start_minutes and total_minutes < end_minutes then
                is_match = true
            end
        end
        if is_match then
            local calc_minutes = total_minutes
            if start_hour > end_hour and total_minutes < end_minutes then
                calc_minutes = total_minutes + 1440
            end
            
            local offset_minutes = calc_minutes - start_minutes
            local ke_index = math.floor(offset_minutes / 15)
            if ke_index >= 8 then
                ke_index = 7
            end
            
            return shichen_name, ke_names[ke_index + 1]
        end
    end
    
    return "未知时辰", "未知刻"
end

local time_tokens_pattern = "\\[AGHIKMNOPSTWYdjlmopwy]"

-- 2. 核心：处理动态时间
local function process_datetime_internal(s, dt)
    if not string.find(s, time_tokens_pattern) then
        return s
    end
    
    local current_shichen, current_ke = get_shichen_and_ke(dt.hour, dt.min)
    
    local week_table_big = {"星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"}
    local week_table_small = {"周日", "周一", "周二", "周三", "周四", "周五", "周六"}
    
    local h12 = dt.hour % 12
    if h12 == 0 then 
        h12 = 12 
    end
    
    local ampm = (dt.hour < 12) and "am" or "pm"
    local raw_tz = os.date("%z") or "+0800"
    local tz_colon = raw_tz:match("^([%+%-])(%d%d)(%d%d)$")
    if tz_colon then
        local sign, h_str, m_str = raw_tz:match("^([%+%-])(%d%d)(%d%d)$")
        tz_colon = sign .. h_str .. ":" .. m_str
    else
        tz_colon = raw_tz
    end
    
    local zh_period
    local h = dt.hour
    if h < 6 then 
        zh_period = "凌晨"
    elseif h < 12 then 
        zh_period = "上午"
    elseif h < 13 then 
        zh_period = "中午"
    elseif h < 18 then 
        zh_period = "下午"
    else 
        zh_period = "晚上" 
    end

    local time_map = {
        Y = string.format("%04d", dt.year),
        y = string.format("%02d", dt.year % 100),
        m = string.format("%02d", dt.month),
        d = string.format("%02d", dt.day),
        N = tostring(dt.month),
        j = tostring(dt.day),
        W = week_table_big[dt.wday],
        w = week_table_small[dt.wday],
        H = string.format("%02d", dt.hour),
        G = tostring(dt.hour),
        I = string.format("%02d", h12),
        l = tostring(h12),
        T = current_shichen,
        K = current_ke,
        M = string.format("%02d", dt.min),
        S = string.format("%02d", dt.sec),
        p = ampm,
        P = ampm:upper(),
        O = tz_colon,
        o = raw_tz,
        A = zh_period
    }

    return s:gsub("\\(%a)", function(char)
        return time_map[char] or ("\\" .. char) 
    end)
end

-- 3. 转义处理
local function apply_escape_fast(text, dt)
    if not text or not string.find(text, "\\", 1, true) then
        return text, false
    end

    local blocks = {}
    local s = text:gsub("%[%[(.-)%]%]", function(txt)
        blocks[#blocks+1] = txt
        return "\0BLK" .. #blocks .. "\0"
    end)

    s = s:gsub("\\[ntrsz]", escape_map)

    s = s:gsub("(" .. utf8_char_pattern .. ")\\(%d+)", function(char, count)
        local n = tonumber(count)
        if n and n > 0 and n < 200 then
            return string.rep(char, n)
        end
        return char .. "\\" .. count
    end)

    s = process_datetime_internal(s, dt)

    s = s:gsub("\0BLK(%d+)\0", function(i)
        return blocks[tonumber(i)] or ""
    end)

    return s, s ~= text
end

local function format_and_autocap(cand, env, dt)
    local text = cand.text
    if not text or text == "" then 
        return cand 
    end
    
    -- 1. 处理转义字符
    local t2, text_changed = apply_escape_fast(text, dt)
    
    -- 2. 处理尾巴符号追加
    local genuine = cand:get_genuine()
    local current_comment = genuine.comment or ""
    local symbol = env.cand_type_symbols[fast_type(cand)]
    local comment_changed = false
    
    if symbol and symbol ~= "" and current_comment ~= "~" then
        -- 防重判断，避免因为各种原因重复追加
        local escaped_symbol = symbol:gsub("[%-%^%$%(%)%%%.%[%]%*%+%?]", "%%%1")
        if not current_comment:match(escaped_symbol .. "$") then
            current_comment = current_comment .. symbol
            comment_changed = true
        end
    end
    
    -- 分流处理！保住 spans 物理边界
    if text_changed then
        local nc = Candidate(cand.type, cand.start, cand._end, t2, current_comment)
        nc.preedit = cand.preedit
        return nc
    elseif comment_changed then
        genuine.comment = current_comment
        return cand
    else
        -- 如果文本和注释都没变，直接放行原候选词，节省性能
        return cand 
    end
end

local function clone_candidate(c)
    local nc = Candidate(c.type, c.start, c._end, c.text, c.comment or "")
    nc.preedit = c.preedit
    nc.quality = c.quality
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
    u = "〈〉",        -- 数学尖括号
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
    cm = "",   -- 注释

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
    
    for k, v in pairs(default_wrap_map) do 
        symbol_map[k] = v 
    end
    
    local ok_map, map = pcall(function() 
        return config:get_map("paired_symbols/symkey") 
    end)
    
    if ok_map and map then
        local ok_keys, keys = pcall(function() 
            return map:keys() 
        end)
        
        if ok_keys and keys then
            for _, key in ipairs(keys) do
                local ok_val, v = pcall(function() 
                    return config:get_string("paired_symbols/symkey/" .. key) 
                end)
                if ok_val and v and #v > 0 then 
                    symbol_map[string.lower(key)] = v 
                end
            end
        end
    end
    
    return symbol_map
end

local function precompile_wrap_parts(wrap_map, delimiter)
    delimiter = delimiter or "|"
    local parts = {}
    
    for k, wrap_str in pairs(wrap_map) do
        if not wrap_str or wrap_str == "" then
            parts[k] = { l = "", r = "" }
        else
            local pos = find(wrap_str, delimiter, 1, true)
            if pos then
                parts[k] = { 
                    l = sub(wrap_str, 1, pos - 1) or "", 
                    r = sub(wrap_str, pos + 1) or "" 
                }
            else
                local first, last
                local count = 0
                
                for _, cp in utf8_codes(wrap_str) do
                    local char = utf8.char(cp)
                    if count == 0 then 
                        first = char 
                    end
                    last = char
                    count = count + 1
                end

                if count == 0 then
                    parts[k] = { l = "", r = "" }
                elseif count == 1 then
                    parts[k] = { l = first, r = "" }
                elseif count == 2 then
                    parts[k] = { l = first, r = last }
                else
                    parts[k] = { l = first, r = last }
                end
            end
        end
    end
    
    return parts
end

function M.init(env)
    local cfg = env.engine and env.engine.schema and env.engine.schema.config

    env.wrap_map = cfg and load_mapping_from_config(cfg) or default_wrap_map
    env.wrap_delimiter = "|"
    
    if cfg then
        local d = cfg:get_string("paired_symbols/delimiter")
        if d and #d > 0 then 
            env.wrap_delimiter = get_first_utf8_char(d) 
        end
    end
    
    env.wrap_parts = precompile_wrap_parts(env.wrap_map, env.wrap_delimiter)

    env.symbol = "\\"
    if cfg then
        local sym = cfg:get_string("paired_symbols/symbol") or cfg:get_string("paired_symbols/trigger")
        if sym and #sym > 0 then 
            env.symbol = get_first_utf8_char(sym) 
        end
    end

    env.page_size = (cfg and cfg:get_int("menu/page_size")) or 5
    
    local schema_id = env.engine.schema.schema_id
    env.enable_taichi_filter = (schema_id == "wanxiang" or schema_id == "wanxiang_pro")
    
    -- 状态初始化
    env.page_cache = {}
    env.last_2code_char = nil 
    -- 读取全局类型符号配置
    env.cand_type_symbols = {}
    local map = cfg and cfg:get_map("super_comment/cand_type")
    if map then
        for _, key in ipairs(map:keys()) do
            local val = cfg:get_string("super_comment/cand_type/" .. key)
            if val and val ~= "" then
                env.cand_type_symbols[key] = val
            end
        end
    end
end

function M.fini(env)
    env.wrap_map = nil
    env.wrap_parts = nil
    env.last_2code_char = nil
end

function M.func(input, env)
    local ctx  = env and env.engine and env.engine.context or nil
    local code = ctx and (ctx.input or "") or ""
    local comp = ctx and ctx.composition or nil
    local current_dt = os.date("*t")
    -- 1. 空环境清理
    if not code or code == "" or (comp and comp:empty()) then
        env.last_2code_char = nil 
        env.page_cache = {}
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    local last_seg = comp and comp:back()
    local code_len = #code
    local seg_len = last_seg and (last_seg._end - last_seg.start) or code_len
    local enable_taichi = env.enable_taichi_filter

    -- 及时清理兜数据
    if seg_len < 2 then
        env.last_2code_char = nil
    end

    -- 2. 探查触发符号（斜杠 \）
    local symbol = env.symbol
    local sym_len = #symbol
    local symbol_pos = symbol and sym_len > 0 and find(code, symbol, 1, true)
    local code_has_symbol = symbol_pos and symbol_pos > 1
    
    if not code_has_symbol then
        env.page_cache = {}
    end
    
    local fully_consumed = false
    local wrap_key = nil

    if code_has_symbol then
        local segm = comp and comp:toSegmentation()
        local confirmed = segm and segm.get_confirmed_position and segm:get_confirmed_position() or 0

        if last_seg and last_seg.start and last_seg._end then
            fully_consumed = (last_seg.start == confirmed) and (last_seg._end == code_len)
            
            if fully_consumed then
                local last_text = sub(code, last_seg.start + 1, last_seg._end)
                local pos = find(last_text, symbol, 1, true)
                
                if pos and pos > 1 then
                    local right = sub(last_text, pos + sym_len)
                    local k = right:lower()
                    
                    if k ~= "" and env.wrap_map[k] then 
                        wrap_key = k 
                    end
                end
            end
        end
    end

    -- 检查是否连续打出双斜杠 \\（取消包裹）
    local is_double = (code_len >= sym_len * 2) and (sub(code, -(sym_len * 2)) == symbol .. symbol)
    if is_double then 
        code_has_symbol = false 
    end

    -- 定位排序脚本是否存活并获取目标缓存
    local raw_code = ""
    if code_has_symbol then
        local pos = find(code, symbol, 1, true)
        if pos then 
            raw_code = sub(code, 1, pos - 1) 
        end
    end

    -- 保障机制：优先使用存得更多的缓存
    local target_cache = env.page_cache
    if _G.WanxiangSharedState.sorter_active and _G.WanxiangSharedState.last_input == raw_code then
        if _G.WanxiangSharedState.page_cache and #_G.WanxiangSharedState.page_cache >= #env.page_cache then
            target_cache = _G.WanxiangSharedState.page_cache
        end
    end

    -- PHASE 1: 缓存快照输出
    if code_has_symbol and target_cache and #target_cache > 0 then
        for _, c in ipairs(target_cache) do
            local final_cand = c
            
            if wrap_key then
                local pair = env.wrap_map[wrap_key]
                if pair then
                    local pr = env.wrap_parts[wrap_key] or { l = "", r = "" }
                    local wrapped_text = (pr.l or "") .. c.text .. (pr.r or "")
                    
                    local start_pos = c.start
                    local end_pos   = c._end
                    
                    if fully_consumed and last_seg then
                        end_pos = last_seg._end
                    end
                    
                    final_cand = Candidate(c.type, start_pos, end_pos, wrapped_text, "")
                    final_cand.preedit = c.preedit or ""
                end
            else
                if fully_consumed and last_seg then
                    final_cand = Candidate(c.type, c.start, last_seg._end, c.text, "")
                    
                    local typed_tail = sub(code, c._end + 1, last_seg._end)
                    final_cand.preedit = (c.preedit or "") .. typed_tail
                end
            end
            
            yield(final_cand)
        end
        return
    end

    -- PHASE 2: 直通车
    local idx = 0
    local suppress_set = {}
    local drop_sentence = false
    local wrap_limit = env.page_size * 2
    local eager_buffer = {}

    for cand in input:iter() do
        idx = idx + 1
        local text = cand.text
        local is_table = is_table_type(cand)
        local has_eng = has_english_token_fast(text)

        -- 首选特殊处理
        if idx == 1 then
            if seg_len == 2 and (utf8_len(text) or 0) == 1 and not has_eng then
                env.last_2code_char = text
            end
            
            if is_table and #text >= 4 and has_eng then
                drop_sentence = true
            end
        end

        local should_skip = false
        
        if drop_sentence and cand.type == "sentence" then 
            should_skip = true 
        end
        
        if not should_skip and enable_taichi and has_eng and cand.comment and find(cand.comment, "\226\152\175") then 
            should_skip = true 
        end
        
        if not should_skip and suppress_set[text] then 
            should_skip = true 
        end

        if not should_skip then
            suppress_set[text] = true
            
            local formatted_cand = format_and_autocap(cand, env, current_dt)
            if not code_has_symbol and #env.page_cache < wrap_limit then
                table.insert(env.page_cache, clone_candidate(formatted_cand))
            end
            
            table.insert(eager_buffer, formatted_cand)
            if #eager_buffer >= wrap_limit then
                break
            end
        end
    end
    for _, c in ipairs(eager_buffer) do
        yield(c)
    end
    for cand in input:iter() do
        idx = idx + 1
        local text = cand.text
        local has_eng = has_english_token_fast(text)
        
        local should_skip = false
        
        if drop_sentence and cand.type == "sentence" then 
            should_skip = true 
        end
        
        if not should_skip and enable_taichi and has_eng and cand.comment and find(cand.comment, "\226\152\175") then 
            should_skip = true 
        end
        
        if not should_skip and suppress_set[text] then 
            should_skip = true 
        end

        if not should_skip then
            suppress_set[text] = true
            yield(format_and_autocap(cand, env, current_dt))
        end
    end
    -- PHASE 3: 三码空候选兜底
    if idx == 0 and seg_len == 3 then
        local fallback_text = env.last_2code_char
        
        if fallback_text then
            local start_pos = last_seg and last_seg.start or (#code - 3)
            if start_pos < 0 then 
                start_pos = 0 
            end
            local end_pos = last_seg and last_seg._end or #code
            local c_type = "fallback"
            local symbol = env.cand_type_symbols[c_type] or ""
            local nc = Candidate(c_type, start_pos, end_pos, fallback_text, symbol)
            
            local seg_str = sub(code, start_pos + 1, end_pos)
            if #seg_str >= 3 then
                local offset_2 = utf8.offset(seg_str, 3)
                if offset_2 then
                    nc.preedit = sub(seg_str, 1, offset_2 - 1) .. " " .. sub(seg_str, offset_2)
                else
                    nc.preedit = seg_str
                end
            else
                nc.preedit = seg_str
            end
            
            yield(nc)
        end
    end
end
return M