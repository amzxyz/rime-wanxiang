-- @amzxyz  https://github.com/amzxyz/rime-wanxiang
-- 提供以下核心修饰与兜底能力：
-- 功能 A：转义序列解析（常驻）
--         将候选词中的 \n, \t, \s(空格) 等文本转义符格式化为实际效果。
-- 功能 B：成对符号包裹与候选锁定
--         输入 `\` 瞬间锁定并展示当前候选快照，追加对应字母即可为候选词快速穿上各类括号/引号（如【】、“”）。
-- 功能 C：三码空候选轻量兜底
--         后台静默记录 2 码时的首选单字；当输入 3 码导致系统无候选时，立刻将该单字吐出救场。
local wanxiang = require("wanxiang/wanxiang")
local M = {}

-- 全局通信通道
_G.WanxiangSharedState = _G.WanxiangSharedState or { sorter_active = false, last_input = "", page_cache = {} }

-- 性能优化：本地化字符串函数
local byte = string.byte
local find = string.find
local sub = string.sub
local concat = table.concat
local utf8_codes = utf8.codes
local utf8_len = utf8.len

local function get_first_utf8_char(s)
    if not s or s == "" then
        return ""
    end
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
local zwsp = "\226\128\139"

local escape_map = {
    n = zwsp .. "\n",  --用来应对electron开发的软件行尾字符被转移到内容最后一行的问题
    r = "\r",
    t = "\t",
    s = " ",
    z = zwsp,
}

local time_token_chars = "ACDEFGHIKMNOPSTYdjlmopwy"

local shichen_data = {
    { name = "子时", start_hour = 23, end_hour = 1 },
    { name = "丑时", start_hour = 1,  end_hour = 3 },
    { name = "寅时", start_hour = 3,  end_hour = 5 },
    { name = "卯时", start_hour = 5,  end_hour = 7 },
    { name = "辰时", start_hour = 7,  end_hour = 9 },
    { name = "巳时", start_hour = 9,  end_hour = 11 },
    { name = "午时", start_hour = 11, end_hour = 13 },
    { name = "未时", start_hour = 13, end_hour = 15 },
    { name = "申时", start_hour = 15, end_hour = 17 },
    { name = "酉时", start_hour = 17, end_hour = 19 },
    { name = "戌时", start_hour = 19, end_hour = 21 },
    { name = "亥时", start_hour = 21, end_hour = 23 },
}

local ke_names = { "初刻", "二刻", "三刻", "四刻", "五刻", "六刻", "七刻", "八刻" }

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

-- 简易 ISO 周数计算
local function iso_week_number(year, month, day)
    local function get_iso_weekday(y, m, d)
        local t = os.time({ year = y, month = m, day = d })
        local w = tonumber(os.date("%w", t))
        return (w == 0) and 7 or w
    end

    local t = os.time({ year = year, month = month, day = day })
    local iso_day = get_iso_weekday(year, month, day)
    local thursday_time = t + (4 - iso_day) * 86400
    local thursday = os.date("*t", thursday_time)

    local first_thursday = os.time({ year = thursday.year, month = 1, day = 4 })
    local first_thursday_weekday = get_iso_weekday(thursday.year, 1, 4)
    local start_of_week1 = first_thursday - (first_thursday_weekday - 1) * 86400

    local week_number = math.floor((thursday_time - start_of_week1) / (7 * 86400)) + 1
    return thursday.year, week_number
end

-- 2. 构造动态时间映射；仅在扫描到时间转义符时调用。
local function build_datetime_map(dt)
    local current_shichen, current_ke = get_shichen_and_ke(dt.hour, dt.min)

    local week_table_big = { "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六" }
    local week_table_small = { "周日", "周一", "周二", "周三", "周四", "周五", "周六" }
    local week_en = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
    local week_en_short = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

    local h12 = dt.hour % 12
    if h12 == 0 then h12 = 12 end

    local ampm = (dt.hour < 12) and "am" or "pm"
    local raw_tz = os.date("%z") or "+0800"
    local sign, h_str, m_str = raw_tz:match("^([%+%-])(%d%d)(%d%d)$")
    local tz_colon = sign and (sign .. h_str .. ":" .. m_str) or raw_tz

    local h = dt.hour
    local zh_period
    if h < 6 then zh_period = "凌晨"
    elseif h < 12 then zh_period = "上午"
    elseif h < 13 then zh_period = "中午"
    elseif h < 18 then zh_period = "下午"
    else zh_period = "晚上" end

    local iso_week_str = ""
    if dt.year and dt.year > 0 then
        local _, wk = iso_week_number(dt.year, dt.month, dt.day)
        iso_week_str = tostring(wk)
    end

    return {
        Y = string.format("%04d", dt.year),
        y = string.format("%02d", dt.year % 100),
        m = string.format("%02d", dt.month),
        d = string.format("%02d", dt.day),
        N = tostring(dt.month),
        j = tostring(dt.day),
        C = week_table_big[dt.wday],
        D = week_table_small[dt.wday],
        E = week_en[dt.wday],
        F = week_en_short[dt.wday],
        w = iso_week_str,
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
        A = zh_period,
    }
end

-- 3. 转义处理：严格按源文本从左到右消费，每个片段只解释一次。
local function apply_escape_fast(text)
    if not text or not find(text, "\\", 1, true) then return text, false end

    local parts = {}
    local count = 0
    local changed = false
    local last_char = nil
    local time_map = nil
    local i = 1
    local len = #text

    local function push(value)
        if not value or value == "" then return end
        count = count + 1
        parts[count] = value
        local pos = utf8.offset(value, -1)
        last_char = pos and sub(value, pos) or value
    end

    while i <= len do
        -- [[...]] 为原样块：去掉包裹标记，内部内容不参与任何转义解析。
        if sub(text, i, i + 1) == "[[" then
            local close_pos = find(text, "]]", i + 2, true)
            if close_pos then
                push(sub(text, i + 2, close_pos - 1))
                changed = true
                i = close_pos + 2
                goto continue
            end
        end

        local b = byte(text, i)
        if b == 0x5C then
            if i == len then
                push("\\")
                break
            end

            local next_char = sub(text, i + 1, i + 1)

            -- \\ 优先级最高：两个反斜杠只生成一个字面反斜杠，生成结果不再二次解析。
            if next_char == "\\" then
                push("\\")
                changed = true
                i = i + 2
                goto continue
            end

            local escaped = escape_map[next_char]
            if escaped then
                push(escaped)
                changed = true
                i = i + 2
                goto continue
            end

            -- \数字：重复已经输出的前一个 UTF-8 字符，总次数为数字本身。
            if next_char >= "0" and next_char <= "9" then
                local j = i + 1
                while j <= len do
                    local c = sub(text, j, j)
                    if c < "0" or c > "9" then break end
                    j = j + 1
                end

                local digits = sub(text, i + 1, j - 1)
                local n = tonumber(digits)
                if last_char and n and n > 0 and n < 200 then
                    if n > 1 then push(string.rep(last_char, n - 1)) end
                    changed = true
                else
                    push("\\" .. digits)
                end
                i = j
                goto continue
            end

            -- 时间变量只解析源文本中真实出现的 \X；由 \\ 产生的字面内容不会再次进入这里。
            if find(time_token_chars, next_char, 1, true) then
                if not time_map then time_map = build_datetime_map(os.date("*t")) end
                push(time_map[next_char] or ("\\" .. next_char))
                changed = true
                i = i + 2
                goto continue
            end

            -- 未知转义保持原样，同时整体消费，避免后续规则重新解释其中字符。
            push("\\" .. next_char)
            i = i + 2
        else
            local char_len
            if b < 0x80 then char_len = 1
            elseif b < 0xE0 then char_len = 2
            elseif b < 0xF0 then char_len = 3
            else char_len = 4 end

            push(sub(text, i, i + char_len - 1))
            i = i + char_len
        end

        ::continue::
    end

    local result = concat(parts, "", 1, count)
    return result, changed or result ~= text
end

local function format_and_autocap(cand, env)
    local text = cand.text
    if not text or text == "" then
        return cand
    end

    local t2, text_changed = apply_escape_fast(text)

    local genuine = cand:get_genuine()
    local current_comment = genuine.comment or ""
    local symbol = env.cand_type_symbols[fast_type(cand)]
    local comment_changed = false

    if symbol and symbol ~= "" and current_comment ~= "~" then
        local escaped_symbol = symbol:gsub("[%-%^%$%(%)%%%.%[%]%*%+%?]", "%%%1")
        if not current_comment:match(escaped_symbol .. "$") then
            current_comment = current_comment .. symbol
            comment_changed = true
        end
    end

    -- 分流处理
    if text_changed then
        local nc = Candidate(cand.type, cand.start, cand._end, t2, current_comment)
        nc.preedit = cand.preedit
        return nc
    elseif comment_changed then
        genuine.comment = current_comment
        return cand
    else
        return cand
    end
end

-- 候选锁定缓存采用扁平纯数据快照，避免 Candidate userdata 进入 table。
-- 每个候选固定占 5 个连续数组槽：type/start/end/text/preedit。
local SNAP_STRIDE = 5

local function clear_array(t)
    if not t then return end
    for i = #t, 1, -1 do
        t[i] = nil
    end
end

local function append_snapshot(cache, cand)
    local n = #cache
    cache[n + 1] = cand.type or ""
    cache[n + 2] = tonumber(cand.start) or 0
    cache[n + 3] = tonumber(cand._end) or 0
    cache[n + 4] = cand.text or ""
    cache[n + 5] = cand.preedit or ""
end

--  包裹映射
local default_wrap_map = {
    -- 单字母：常用成对括号/引号（每项恰好两个字符）
    a = "[]", -- 方括号
    b = "【】", -- 黑方头括号
    c = "❲❳", -- 双大括号 / 装饰括号
    d = "〔〕", -- 方头括号
    e = "⟮⟯", -- 小圆括号 / 装饰括号
    f = "⟦⟧", -- 双方括号 / 数学集群括号
    g = "「」", -- 直角引号
    -- h 预留用于 Markdown 一级标题
    i = "『』", -- 双直角引号
    j = "<>", -- 尖括号
    k = "《》", -- 书名号（双）
    l = "〈〉", -- 书名号（单）
    m = "‹›", -- 法文单书名号
    n = "«»", -- 法文双书名号
    o = "⦅⦆", -- 白圆括号
    p = "⦇⦈", -- 白方括号
    q = "()", -- 圆括号
    r = "|儿", --儿化候选
    s = "［］", -- 全角方括号
    t = "⟨⟩", -- 数学角括号
    u = "〈〉", -- 数学尖括号
    v = "❰❱", -- 装饰角括号
    w = "（）", -- 全角圆括号
    x = "｛｝", -- 全角花括号
    y = "⟪⟫", -- 双角括号
    z = "{}", -- 花括号

    --  扩展括号族 / 引号
    dy = "''", -- 英文单引号
    sy = '""', -- 英文双引号
    zs = "“”", -- 中文弯双引号
    zd = "‘’", -- 中文弯单引号
    fy = "``", -- 反引号

    --  双字母括号族
    aa = "〚〛", -- 双中括号
    bb = "〘〙", -- 双中括号（小）
    cc = "〚〛", -- 双中括号（重复，可用于 Lua 匹配）
    dd = "❨❩", -- 小圆括号装饰
    ee = "❪❫", -- 小圆括号装饰
    ff = "❬❭", -- 小尖括号装饰
    gg = "⦉⦊", -- 双弯方括号
    ii = "⦍⦎", -- 双弯方括号
    jj = "⦏⦐", -- 双弯方括号
    kk = "⦑⦒", -- 双弯方括号
    ll = "❮❯", -- 小尖括号装饰
    mm = "⌈⌉", -- 上取整 / 数学符号
    nn = "⌊⌋", -- 下取整 / 数学符号
    oo = "⦗⦘", -- 双方括号装饰（补齐）
    pp = "⦙⦚", -- 双方括号装饰（补齐）
    qq = "⟬⟭", -- 小双角括号
    rr = "❴❵", -- 花括号装饰
    ss = "⌜⌝", -- 数学上角符号
    tt = "⌞⌟", -- 数学下角符号
    uu = "⸢⸣", -- 装饰方括号
    vv = "⸤⸥", -- 装饰方括号
    ww = "﹁﹂", -- 中文书名号 / 注释引号
    xx = "﹃﹄", -- 中文书名号 / 注释引号
    yy = "⌠⌡", -- 数学 / 程序符号
    zz = "⟅⟆", -- 数学 / 装饰括号

    --  Markdown / 标记
    md = "**|**", --Markdown 粗体
    jc = "**|**", -- 加粗
    it = "__|__", -- 斜体
    st = "~~|~~", -- 删除线
    eq = "==|==", -- 高亮
    ln = "`|`", -- 行内代码
    cb = "```|```", -- 代码块
    qt = "> |", -- 引用
    ul = "- |", -- 无序列表项
    ol = "1. |", -- 有序列表项
    lk = "[|](url)", -- 链接
    im = "![|](img)", -- 图片
    h = "# |", -- 一级标题
    hh = "## |", -- 二级标题
    hhh = "### |", -- 三级标题
    hhhh = "#### |", -- 四级标题
    sp = "\\|", -- 反斜杠转义
    br = "|  ", -- 换行
    cm = "", -- 注释

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
                    r = sub(wrap_str, pos + 1) or "",
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

    -- 本地锁定缓存只保存扁平纯数据快照，不保存 Candidate。
    env.page_cache = {}
    env.last_2code_char = nil

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
    clear_array(env.page_cache)
    env.page_cache = nil
    env.wrap_map = nil
    env.wrap_parts = nil
    env.wrap_delimiter = nil
    env.symbol = nil
    env.page_size = nil
    env.cand_type_symbols = nil
    env.last_2code_char = nil

    -- _G.WanxiangSharedState 是排序器与本过滤器的通信通道，不能在这里销毁。
end

function M.func(input, env)
    local ctx = env and env.engine and env.engine.context or nil
    local code = ctx and (ctx.input or "") or ""
    local comp = ctx and ctx.composition or nil

    -- 1. 空环境清理
    if not code or code == "" or (comp and comp:empty()) then
        env.last_2code_char = nil
        clear_array(env.page_cache)
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    local last_seg = comp and comp:back()
    local code_len = #code
    local seg_len = last_seg and (last_seg._end - last_seg.start) or code_len

    if seg_len < 2 then
        env.last_2code_char = nil
    end

    -- 2. 探查触发符号（斜杠 \）
    local symbol = env.symbol
    local sym_len = #symbol
    local symbol_pos = symbol and sym_len > 0 and find(code, symbol, 1, true)
    local code_has_symbol = symbol_pos and symbol_pos > 1 or false

    local wrap_key = nil
    if code_has_symbol then
        local right = sub(code, symbol_pos + sym_len)
        local key = right:lower()
        if key ~= "" and env.wrap_map[key] then
            wrap_key = key
        end
    end

    -- 连续输入两个触发符表示取消包裹；此时应先清掉上一轮锁定快照再重建。
    local is_double = (code_len >= sym_len * 2) and (sub(code, -(sym_len * 2)) == symbol .. symbol)
    if is_double then
        code_has_symbol = false
    end

    if not code_has_symbol then
        clear_array(env.page_cache)
    end

    -- 定位排序脚本是否存活并获取目标缓存。
    local raw_code = ""
    if code_has_symbol then
        local pos = find(code, symbol, 1, true)
        if pos then
            raw_code = sub(code, 1, pos - 1)
        end
    end

    -- 全局通信必须保留。
    -- 新排序器可把 shared.page_cache 写成 flat5 扁平快照；旧排序器若仍传 Candidate 数组，
    -- 这里继续兼容读取，避免两个模块必须同时升级才能工作。
    local target_cache = env.page_cache
    local target_is_flat = true
    local shared = _G.WanxiangSharedState
    if shared and shared.sorter_active and shared.last_input == raw_code and shared.page_cache and #shared.page_cache > 0 then
        target_cache = shared.page_cache
        target_is_flat = shared.page_cache_format == "flat5"
    end

    -- PHASE 1: 输出锁定快照。
    if code_has_symbol and target_cache and #target_cache > 0 then
        local pr = wrap_key and env.wrap_parts[wrap_key] or nil
        local left = pr and pr.l or ""
        local right = pr and pr.r or ""

        if target_is_flat then
            for i = 1, #target_cache, SNAP_STRIDE do
                local cand_type = target_cache[i] or ""
                local cand_start = tonumber(target_cache[i + 1]) or 0
                local cand_end = tonumber(target_cache[i + 2]) or 0
                local cand_text = target_cache[i + 3] or ""
                local cand_preedit = target_cache[i + 4] or ""

                local final_text
                local final_preedit
                if wrap_key then
                    final_text = left .. cand_text .. right
                    final_preedit = cand_preedit
                else
                    local typed_tail = cand_end < code_len and sub(code, cand_end + 1, code_len) or ""
                    final_text = cand_text
                    final_preedit = cand_preedit .. typed_tail
                end

                local final_cand = Candidate(cand_type, cand_start, code_len, final_text, "")
                final_cand.preedit = final_preedit
                yield(final_cand)
            end
        else
            -- 兼容旧版排序器的 Candidate 数组；待排序器同步改成 flat5 后即可完全消除
            -- 全局 Candidate -> table 引用。
            for _, c in ipairs(target_cache) do
                local cand_end = tonumber(c._end) or 0
                local final_text
                local final_preedit

                if wrap_key then
                    final_text = left .. (c.text or "") .. right
                    final_preedit = c.preedit or ""
                else
                    local typed_tail = cand_end < code_len and sub(code, cand_end + 1, code_len) or ""
                    final_text = c.text or ""
                    final_preedit = (c.preedit or "") .. typed_tail
                end

                local final_cand = Candidate(c.type or "", tonumber(c.start) or 0, code_len, final_text, "")
                final_cand.preedit = final_preedit
                yield(final_cand)
            end
        end
        return
    end

    -- PHASE 2: 直通车。
    local idx = 0
    local suppress_set = {}
    local drop_sentence = false
    local wrap_limit = env.page_size * 2
    local iterator, iterator_state, iterator_control = input:iter()
    local is_exhausted = false

    local function next_candidate()
        if is_exhausted then return nil end
        local cand = iterator(iterator_state, iterator_control)
        iterator_control = cand
        if not cand then
            is_exhausted = true
            return nil
        end
        return cand
    end

    -- 预取两页必须在首个 yield 前完成，保证用户随后输入触发符时锁定快照已经完整。
    -- Candidate 只暂存在 Lua 调用栈的多返回值中，不进入 table/env/global。
    local function collect_eager(accepted)
        if accepted >= wrap_limit or is_exhausted then return end

        local cand = next_candidate()
        if not cand then return end

        idx = idx + 1
        local text = cand.text or ""

        if idx == 1 then
            local has_eng = has_english_token_fast(text)

            if seg_len == 2 and (utf8_len(text) or 0) == 1 and not has_eng then
                env.last_2code_char = text
            end

            local cand_type = fast_type(cand)
            if (cand_type == "table" or cand_type == "user_table" or cand_type == "fixed" or cand_type == "completion") and #text >= 4 and has_eng then
                drop_sentence = true
            end
        end

        if (drop_sentence and fast_type(cand) == "sentence") or suppress_set[text] then
            -- 被抑制的候选无需留在调用栈，尾递归继续找下一项。
            return collect_eager(accepted)
        end

        suppress_set[text] = true
        local formatted_cand = format_and_autocap(cand, env)

        if not code_has_symbol then
            append_snapshot(env.page_cache, formatted_cand)
        end

        return formatted_cand, collect_eager(accepted + 1)
    end

    local function yield_eager(cand, ...)
        if not cand then return end
        yield(cand)
        return yield_eager(...)
    end

    yield_eager(collect_eager(0))

    -- 继续消费同一个上游 Translation。
    while not is_exhausted do
        local cand = next_candidate()
        if not cand then break end

        idx = idx + 1
        local text = cand.text or ""

        if not (drop_sentence and fast_type(cand) == "sentence") and not suppress_set[text] then
            suppress_set[text] = true
            yield(format_and_autocap(cand, env))
        end
    end

    -- PHASE 3: 三码空候选兜底
    if idx == 0 and seg_len == 3 and sub(code, 1, 1) ~= "/" and not wanxiang.is_special_mode(ctx) then
        local fallback_text = env.last_2code_char

        if fallback_text then
            local start_pos = last_seg and last_seg.start or (#code - 3)
            if start_pos < 0 then
                start_pos = 0
            end
            local end_pos = last_seg and last_seg._end or #code
            local c_type = "fallback"
            local comment_symbol = env.cand_type_symbols[c_type] or ""
            local nc = Candidate(c_type, start_pos, end_pos, fallback_text, comment_symbol)

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
