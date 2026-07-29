-- amzxyz@https://github.com/amzxyz/rime-wanxiang
-- input_stats.lua：分设备统计 / 有效会话测速 / 历史查询

local userdb = require("wanxiang/userdb")
local wanxiang = require("wanxiang/wanxiang")

local DB_POOL = {}
local SOFTWARE_NAME = rime_api.get_distribution_code_name()
local RECORD_SEPARATOR = " \t"
local STATS_C_MAX = 2147483000
local BATCH_INTERVAL = 5
local MAX_PENDING_WORDS = 200
local DEFAULT_ACTIVE_TIMEOUT = 10
local DEFAULT_MINIMUM_SPEED_SESSION = 15
local DEFAULT_MAX_SPEED_COMMIT_LENGTH = 30

local SUM_FIELDS = {
    {"len", "_len"}, {"cnt", "_cnt"}, {"code", "_code"},
    {"slen", "_slen"}, {"ssec", "_ssec"},
    {"l1", "_l1"}, {"l2", "_l2"}, {"l3", "_l3"},
    {"l4", "_l4"}, {"l_gt4", "_l_gt4"},
}

local DEFAULT_TITLES = {
    {5000000, "⌨️·天人合一"}, {1000000, "⌨️·登峰造极"},
    {500000, "✨·出神入化"}, {100000, "💨·行云流水"},
    {50000, "🚀·运指如飞"}, {10000, "🌟·渐入佳境"},
    {0, "🌱·初学乍练"},
}

local FINGER_STYLE_MAP = {
    pinyin="全拼", zrm="自然码", flypy="小鹤双拼", mspy="微软双拼",
    sogou="搜狗双拼", abc="智能ABC", ziguang="紫光双拼",
    pyjj="拼音加加", gbpy="国标双拼", zrlong="自然龙",
    hxlong="汉心龙", ltsp="蓝天双拼", lxsq="乱序17",
    sdpy="首道双拼", t9="九键",
}

local function normalize_device_id(value)
    return tostring(value or ""):lower():gsub("[^0-9a-f]", ""):sub(1, 8)
end

local function is_device_id(value)
    return type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x$") ~= nil
end

local function get_device_id(config)
    local id = normalize_device_id(config:get_string("input_stats/device_id"))
    if #id == 8 then return id end

    local user_dir = rime_api.get_user_data_dir()
    if not user_dir or user_dir == "" then return "00000000" end

    local file = io.open(user_dir:gsub("[/\\]+$", "") .. "/installation.yaml", "r")
    if not file then return "00000000" end

    for line in file:lines() do
        local value = line:match("^%s*installation_id%s*:%s*(.-)%s*$")
        if value then
            value = value:gsub("%s+#.*$", ""):gsub('^"(.*)"$', "%1")
                :gsub("^'(.*)'$", "%1")
            file:close()
            id = normalize_device_id(value)
            return #id == 8 and id or "00000000"
        end
    end

    file:close()
    return "00000000"
end

local function acquire_db(env)
    if env.stats_db then return env.stats_db end

    local entry = DB_POOL[env.stats_db_name]
    if not entry then
        entry = {db=userdb.LevelDb(env.stats_db_name), refs=0}
        DB_POOL[env.stats_db_name] = entry
    end

    local db = entry.db
    if not db or not db:loaded() and not db:open() then
        DB_POOL[env.stats_db_name] = nil
        return nil
    end

    entry.refs = entry.refs + 1
    env.stats_db, env.stats_db_entry = db, entry
    return db
end

local function get_db(env)
    return env.stats_db or acquire_db(env)
end

local function release_db(env)
    local entry = env.stats_db_entry
    if not entry then return end

    env.stats_db, env.stats_db_entry = nil, nil
    entry.refs = math.max(0, entry.refs - 1)
    if entry.refs > 0 then return end

    DB_POOL[env.stats_db_name] = nil
    collectgarbage("collect")

    if entry.db and entry.db:loaded() then
        pcall(function() entry.db:close() end)
    end
end

-- 在统计业务层生成稳定的 UserDb raw key。
local function make_raw_key(key, device_id)
    if not key or key == "" or not is_device_id(device_id) then return nil end
    return key .. RECORD_SEPARATOR .. device_id
end

-- 从稳定 raw key 中解析统计键与设备标识。
local function parse_raw_key(raw_key)
    if type(raw_key) ~= "string" then return nil, nil end

    local split_pos = raw_key:find(RECORD_SEPARATOR, 1, true)
    if not split_pos then return nil, nil end

    local key = raw_key:sub(1, split_pos - 1)
    local device_id = raw_key:sub(split_pos + #RECORD_SEPARATOR)
    if key == "" or not is_device_id(device_id) then return nil, nil end
    return key, device_id
end

-- 生成标准 c/d/t 统计记录尾部。
local function make_record_tail(value)
    return string.format("c=%d d=0 t=0", value)
end

local function to_integer(value)
    value = tonumber(value) or 0
    if value ~= value or value == math.huge or value == -math.huge then value = 0 end
    value = value < 0 and math.ceil(value) or math.floor(value)
    return math.max(0, math.min(STATS_C_MAX, value))
end

local function parse_tail(tail)
    if type(tail) ~= "string" then return 0 end
    local c, d, t = tail:match("^c=([^%s\t]+) d=([^%s\t]+) t=([^%s\t]+)$")
    c, d, t = tonumber(c), tonumber(d), tonumber(t)

    if not c or c < 0 or c ~= math.floor(c) or d ~= 0
        or not t or t < 0 or t ~= math.floor(t)
    then
        return 0
    end
    return to_integer(c)
end

local function db_get_local(db, key, device_id)
    local raw_key = make_raw_key(key, device_id)
    return raw_key and parse_tail(db:fetch(raw_key)) or 0
end

local function db_set_local(db, key, device_id, value)
    local raw_key = make_raw_key(key, device_id)
    if not raw_key then return false end

    return db:update(raw_key, make_record_tail(to_integer(value)))
end

local function db_read(db, key, device_id, use_max)
    if device_id then return db_get_local(db, key, device_id) end

    local result = 0
    local prefix = key .. RECORD_SEPARATOR
    local accessor = db:query(prefix)
    if not accessor then return result end

    for raw_key, tail in accessor:iter() do
        if raw_key:sub(1, #prefix) ~= prefix then break end

        local record_key, record_device = parse_raw_key(raw_key)
        if record_key == key and record_device then
            local value = parse_tail(tail)
            result = use_max and math.max(result, value) or result + value
        end
    end

    accessor = nil
    return result
end

local function platform_info(name, version)
    local names = {
        Weasel="小狼毫", trime="同文输入法", hamster3="元书输入法",
        hamster="仓输入法", lyraime="灵韵输入法", xime="曦码输入法",
        ["Cobra​"]="元书输入法(PC)", default="超越输入法",
    }
    version = tostring(version or "")
    return names[name] or name or "",
        version:match("^([vV]?%d+%.%d+%.%d+)") or version
end

local function is_chinese(code)
    return (code >= 0x4E00 and code <= 0x9FFF)
        or (code >= 0x3400 and code <= 0x4DBF)
        or (code >= 0x20000 and code <= 0x2A6DF)
        or (code >= 0x2A700 and code <= 0x2B73F)
        or (code >= 0x2B740 and code <= 0x2B81F)
        or (code >= 0x2B820 and code <= 0x2CEAF)
        or (code >= 0x2CEB0 and code <= 0x2EBEF)
        or (code >= 0x30000 and code <= 0x3134F)
        or (code >= 0x31350 and code <= 0x323AF)
        or (code >= 0x2EBF0 and code <= 0x2EE5F)
        or (code >= 0xF900 and code <= 0xFAFF)
        or (code >= 0x2F800 and code <= 0x2FA1F)
        or (code >= 0x2E80 and code <= 0x2EFF)
        or (code >= 0x2F00 and code <= 0x2FDF)
end

local function chinese_length(text)
    local count = 0
    for _, code in utf8.codes(text) do
        if is_chinese(code) then count = count + 1 end
    end
    return count
end

local function day_key(timestamp)
    local date = os.date("*t", timestamp)
    return string.format("d_%04d%02d%02d", date.year, date.month, date.day)
end

local function new_stats()
    return {
        len=0, cnt=0, code=0, spd=0, slen=0, ssec=0,
        l1=0, l2=0, l3=0, l4=0, l_gt4=0,
    }
end

local function pending_add(env, key, suffix, amount)
    local fields = env.pending_stats[key]
    if not fields then fields = {}; env.pending_stats[key] = fields end
    fields[suffix] = (fields[suffix] or 0) + amount
end

local function pending_set_max(env, key, suffix, value)
    local fields = env.pending_max[key]
    if not fields then fields = {}; env.pending_max[key] = fields end
    fields[suffix] = math.max(fields[suffix] or 0, value)
end

local function has_pending(env)
    return next(env.pending_stats) ~= nil or next(env.pending_max) ~= nil
end

local function flush_pending(env)
    if not has_pending(env) then return true end

    local db = get_db(env)
    if not db or not db:loaded() then return false end

    for key, fields in pairs(env.pending_stats) do
        for suffix, amount in pairs(fields) do
            local daily = key .. suffix
            db_set_local(db, daily, env.device_id,
                db_get_local(db, daily, env.device_id) + amount)

            local total = "total" .. suffix
            db_set_local(db, total, env.device_id,
                db_get_local(db, total, env.device_id) + amount)
        end
    end

    for key, fields in pairs(env.pending_max) do
        for suffix, value in pairs(fields) do
            local daily = key .. suffix
            if value > db_get_local(db, daily, env.device_id) then
                db_set_local(db, daily, env.device_id, value)
            end

            local total = "total" .. suffix
            if value > db_get_local(db, total, env.device_id) then
                db_set_local(db, total, env.device_id, value)
            end
        end
    end

    env.pending_stats, env.pending_max = {}, {}
    env.last_flush_ts = os.time()
    return true
end

local function try_flush(env)
    if not has_pending(env) then return end

    local words = 0
    for _, fields in pairs(env.pending_stats) do words = words + (fields._len or 0) end

    if words >= MAX_PENDING_WORDS
        or os.time() - env.last_flush_ts >= BATCH_INTERVAL
    then
        flush_pending(env)
    end
end

local function reset_session(env)
    env.session_start = nil
    env.session_last_activity = nil
    env.session_last_commit = nil
    env.session_chars = 0
    env.session_day = nil
end

local function start_session(env, key, timestamp)
    env.session_start = timestamp
    env.session_last_activity = timestamp
    env.session_last_commit = nil
    env.session_chars = 0
    env.session_day = key
end

local function finish_session(env, keep_short)
    local started = env.session_start
    local finished = env.session_last_commit
    local chars = env.session_chars or 0
    local key = env.session_day

    if not started or not finished or not key then
        if not keep_short then reset_session(env) end
        return false
    end

    local elapsed = finished - started

    if elapsed < env.minimum_speed_session or chars <= 0 then
        if not keep_short then reset_session(env) end
        return false
    end

    reset_session(env)
    pending_add(env, key, "_slen", chars)
    pending_add(env, key, "_ssec", elapsed)
    pending_set_max(env, key, "_sspd",
        math.floor(chars * 60 / elapsed + 0.5))
    return true
end

local function observe_input_activity(env, input)
    if not input or input == "" or input:sub(1, 1) == "/" then
        env.last_observed_input = input or ""
        return
    end

    if input == env.last_observed_input then return end
    env.last_observed_input = input

    local timestamp = os.time()
    local key = day_key(timestamp)

    if not env.session_start then
        start_session(env, key, timestamp)
        return
    end

    local last_activity = env.session_last_activity or env.session_start
    local gap = timestamp - last_activity

    if gap < 0 or gap > env.active_timeout or key ~= env.session_day then
        finish_session(env)
        start_session(env, key, timestamp)
        return
    end

    env.session_last_activity = timestamp
end

local function commit_to_session(env, key, timestamp, chars)
    if not env.session_start then
        start_session(env, key, timestamp)
    else
        local last_activity = env.session_last_activity or env.session_start
        local gap = timestamp - last_activity

        if gap < 0 or gap > env.active_timeout or key ~= env.session_day then
            finish_session(env)
            start_session(env, key, timestamp)
        end
    end

    env.session_last_activity = timestamp
    env.session_last_commit = timestamp
    env.session_chars = env.session_chars + chars
    env.last_observed_input = ""
end

local function record_stats(env, chars, code_length)
    local timestamp = os.time()
    local key = day_key(timestamp)

    pending_add(env, key, "_len", chars)
    pending_add(env, key, "_cnt", 1)
    pending_add(env, key, "_code", code_length)

    if chars <= env.max_speed_commit_length then
        commit_to_session(env, key, timestamp, chars)
    else
        -- 长文本仍参与字数、次数、编码和字词分布统计，
        -- 但不参与测速，并结束此前的测速会话。
        finish_session(env)
        env.last_observed_input = ""
    end

    local suffix = chars == 1 and "_l1"
        or chars == 2 and "_l2"
        or chars == 3 and "_l3"
        or chars == 4 and "_l4"
        or chars > 4 and "_l_gt4"
    if suffix then pending_add(env, key, suffix, 1) end
end

local function read_prefix(db, prefix, device_id)
    local result = new_stats()
    for _, field in ipairs(SUM_FIELDS) do
        result[field[1]] = db_read(db, prefix .. field[2], device_id, false)
    end
    result.spd = db_read(db, prefix .. "_sspd", device_id, true)
    return result
end

local function add_prefix(result, db, prefix)
    for _, field in ipairs(SUM_FIELDS) do
        local name, suffix = field[1], field[2]
        result[name] = result[name] + db_read(db, prefix .. suffix, nil, false)
    end
    result.spd = math.max(result.spd, db_read(db, prefix .. "_sspd", nil, true))
end

local function aggregate_recent(env, days, device_id)
    local db = get_db(env)
    if not db or not db:loaded() then return nil end
    if days == 0 then return read_prefix(db, "total", device_id) end

    local result, now = new_stats(), os.time()
    for offset = 0, days - 1 do add_prefix(result, db, day_key(now - offset * 86400)) end
    return result
end

local function aggregate_keys(env, keys)
    local db = get_db(env)
    if not db or not db:loaded() then return nil end

    local result, has_data = new_stats(), false
    for _, key in ipairs(keys) do
        if db_read(db, key .. "_len", nil, false) > 0 then
            has_data = true
            add_prefix(result, db, key)
        end
    end
    return has_data and result or nil
end

local function period_keys(year, month, day, end_year, end_month, end_day)
    local keys = {}

    if end_year then
        local current = os.time({year=year, month=month, day=day, hour=12})
        local ending = os.time({
            year=end_year, month=end_month, day=end_day, hour=12,
        })
        while current and ending and current <= ending do
            keys[#keys + 1] = day_key(current)
            current = current + 86400
        end
    elseif day then
        keys[1] = string.format("d_%04d%02d%02d", year, month, day)
    elseif month then
        for d = 1, 31 do
            keys[#keys + 1] = string.format("d_%04d%02d%02d", year, month, d)
        end
    elseif year then
        for m = 1, 12 do
            for d = 1, 31 do
                keys[#keys + 1] = string.format("d_%04d%02d%02d", year, m, d)
            end
        end
    end

    return keys
end

local function aggregate_period(env, ...)
    local keys = period_keys(...)
    return #keys > 0 and aggregate_keys(env, keys) or nil
end

local function ensure_titles(env)
    if env.titles then return env.titles end

    local titles = {}
    local configured = env.engine.schema.config:get_list("input_stats/titles")
    if configured then
        for i = 0, configured.size - 1 do
            local item = configured:get_value_at(i)
            local value = item and item.value
            if value then
                local threshold, name = value:match("^(%d+):(.+)$")
                if threshold and name then
                    titles[#titles + 1] = {tonumber(threshold), name}
                end
            end
        end
    end

    if #titles == 0 then
        env.titles = DEFAULT_TITLES
    else
        table.sort(titles, function(a, b) return a[1] > b[1] end)
        env.titles = titles
    end
    return env.titles
end

local function user_title(env, device_id)
    local db = get_db(env)
    if not db or not db:loaded() then return "初学乍练" end

    local total = db_read(db, "total_len", device_id, false)
    for _, item in ipairs(ensure_titles(env)) do
        if total >= item[1] then return item[2] end
    end
    return "初学乍练"
end

local function draw_bar(percent)
    percent = math.max(0, math.min(100, tonumber(percent) or 0))
    local filled = math.floor(percent / 10)
    return string.rep("▓", filled) .. string.rep("░", 10 - filled)
end

local function format_summary(title, subtitle, data, env, device_id)
    if not data or data.cnt == 0 then return "※ " .. title .. "暂无数据" end

    local avg_code = data.len > 0 and data.code / data.len or 0
    local phrase_rate = data.len > 0 and (data.len - data.l1) / data.len * 100 or 0
    local avg_speed = data.ssec > 0
        and math.floor(data.slen * 60 / data.ssec + 0.5) or nil
    local avg_text = avg_speed and tostring(avg_speed) or "--"
    local peak_text = data.spd > 0 and tostring(math.floor(data.spd)) or "--"
    local p = {
        data.l1 / data.cnt * 100, data.l2 / data.cnt * 100,
        data.l3 / data.cnt * 100, data.l4 / data.cnt * 100,
        data.l_gt4 / data.cnt * 100,
    }

    local software, version = platform_info(
        SOFTWARE_NAME, rime_api.get_distribution_version()
    )
    local style = wanxiang.get_input_method_type(env)
    local header = string.format("※ %s统计 · 效率仪表盘\n", title)
    if subtitle and subtitle ~= "" then
        header = header .. string.format("📅 %s\n", subtitle)
    end

    local zwsp = "\226\128\139"
    return header .. string.format(
        "───────────────" .. zwsp .. "\n" ..
        "📊 综合数据" .. zwsp .. "\n" ..
        "  均速:%-5s 上屏:%d" .. zwsp .. "\n" ..
        "  峰速:%-5s 字数:%d" .. zwsp .. "\n" ..
        "🏆 段位：%s" .. zwsp .. "\n" ..
        "───────────────" .. zwsp .. "\n" ..
        "⚡ 核心效率" .. zwsp .. "\n" ..
        "  平均编码：%.2f 键/字" .. zwsp .. "\n" ..
        "  词组连打：%.1f %%" .. zwsp .. "\n" ..
        "───────────────" .. zwsp .. "\n" ..
        "📈 字词分布" .. zwsp .. "\n" ..
        "  [1] %3d%% %s" .. zwsp .. "\n" ..
        "  [2] %3d%% %s" .. zwsp .. "\n" ..
        "  [3] %3d%% %s" .. zwsp .. "\n" ..
        "  [4] %3d%% %s" .. zwsp .. "\n" ..
        "  [+] %2d%% %s" .. zwsp .. "\n" ..
        "───────────────" .. zwsp .. "\n" ..
        "◉ 方案：%s" .. zwsp .. "\n" ..
        "◉ 编码：%s" .. zwsp .. "\n" ..
        "◉ 前端：%s %s" .. zwsp,
        avg_text, math.floor(data.cnt), peak_text, math.floor(data.len),
        user_title(env, device_id), avg_code, phrase_rate,
        math.floor(p[1]), draw_bar(p[1]), math.floor(p[2]), draw_bar(p[2]),
        math.floor(p[3]), draw_bar(p[3]), math.floor(p[4]), draw_bar(p[4]),
        math.floor(p[5]), draw_bar(p[5]), env.schema_name,
        FINGER_STYLE_MAP[style] or style, software, version
    )
end

local function yield_msg(seg, text, icon)
    yield(Candidate("stat", seg.start, seg._end, text, icon or "🕰️"))
end

local function prepare_report(env)
    -- 查询不应清空尚未达到最小时长的会话，否则频繁查看统计会
    -- 导致测速样本永远无法积累到 minimum_speed_session。
    finish_session(env, true)
    flush_pending(env)
end

local function standard_report(input, env)
    if input == env.triggers.local_total then
        return "本设备", "设备 " .. env.device_id, 0, env.device_id
    elseif input == env.triggers.today then
        return "今日", "", 1
    elseif input == env.triggers.week then
        return "七日", "", 7
    elseif input == env.triggers.month then
        return "卅日", "", 30
    elseif input == env.triggers.year then
        return "本年", "", 365
    elseif input == env.triggers.total then
        return "生涯", "", 0
    end
end

local function history_report(input, env)
    local trigger = env.triggers.history
    if input:sub(1, #trigger) ~= trigger then return nil end

    local query = input:sub(#trigger + 1)
    if query == "" then
        return false, "※ 请输入日期或区间 (例: 2026, 202601, 20260101t20260201)", "⌨️"
    end

    local sy, sm, sd, ey, em, ed =
        query:match("^(%d%d%d%d)(%d%d)(%d%d)t(%d%d%d%d)(%d%d)(%d%d)$")
    if sy then
        prepare_report(env)
        return aggregate_period(env, tonumber(sy), tonumber(sm), tonumber(sd),
            tonumber(ey), tonumber(em), tonumber(ed)),
            "区间", string.format("%s.%s.%s - %s.%s.%s", sy, sm, sd, ey, em, ed),
            "※ 该区间内没有留下打字记录哦"
    end

    local y, m, d = query:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if y then
        prepare_report(env)
        return aggregate_period(env, tonumber(y), tonumber(m), tonumber(d)),
            "单日", string.format("%s.%s.%s", y, m, d),
            "※ 这一天没有留下打字记录哦"
    end

    y, m = query:match("^(%d%d%d%d)(%d%d)$")
    if y then
        prepare_report(env)
        return aggregate_period(env, tonumber(y), tonumber(m)),
            "月份", string.format("%s年%s月", y, m),
            "※ 该月没有留下打字记录哦"
    end

    y = query:match("^(%d%d%d%d)$")
    if y then
        prepare_report(env)
        return aggregate_period(env, tonumber(y)), "年度",
            string.format("%s年", y), "※ 该年没有留下打字记录哦"
    end

    return false, query:find("t", 1, true)
        and "※ 正在输入区间查询..."
        or "※ 正在查询中... 请继续输入完整的年/月/日", "⏳"
end

local function on_commit(context, env)
    local text = context:get_commit_text()
    if not text or text == "" or text:sub(1, 1) == "/"
        or text:find("^[※◉🏆📊⚡📈]")
    then
        return
    end

    local chars = chinese_length(text)
    if chars == 0 then return end

    local code_length = #(context.input or "")
    record_stats(env, chars, code_length > 0 and code_length or chars * 2)
    try_flush(env)
end

local function bounded_int(config, key, default, minimum, maximum)
    return math.max(minimum, math.min(maximum, config:get_int(key) or default))
end

local function init(env)
    local config = env.engine.schema.config
    env.schema_name = env.engine.schema.schema_name or "万象方案"
    env.stats_db_name = config:get_string("input_stats/db_name") or "lua/stats"
    if env.stats_db_name == "" then env.stats_db_name = "lua/stats" end

    env.device_id = get_device_id(config)
    env.active_timeout = bounded_int(
        config, "input_stats/active_timeout", DEFAULT_ACTIVE_TIMEOUT, 2, 60
    )
    env.minimum_speed_session = bounded_int(
        config, "input_stats/minimum_speed_session",
        DEFAULT_MINIMUM_SPEED_SESSION, 5, 300
    )
    env.max_speed_commit_length = bounded_int(
        config, "input_stats/max_speed_commit_length",
        DEFAULT_MAX_SPEED_COMMIT_LENGTH, 1, 10000
    )

    env.pending_stats, env.pending_max = {}, {}
    env.last_flush_ts, env.titles = os.time(), nil
    env.last_observed_input = ""
    reset_session(env)
    acquire_db(env)

    env.triggers = {
        local_total=config:get_string("input_stats/triggers/local_total") or "/btj",
        today=config:get_string("input_stats/triggers/today") or "/rtj",
        week=config:get_string("input_stats/triggers/week") or "/ztj",
        month=config:get_string("input_stats/triggers/month") or "/ytj",
        year=config:get_string("input_stats/triggers/year") or "/ntj",
        total=config:get_string("input_stats/triggers/total") or "/tj",
        history=config:get_string("input_stats/triggers/history") or "/htj",
    }

    if env.stat_notifier then env.stat_notifier:disconnect() end
    env.stat_notifier = env.engine.context.commit_notifier:connect(
        function(context) on_commit(context, env) end
    )
end

local function fini(env)
    finish_session(env)
    flush_pending(env)
    env.last_observed_input = ""

    if env.stat_notifier then
        env.stat_notifier:disconnect()
        env.stat_notifier = nil
    end
    release_db(env)
end

local function translator(input, seg, env)
    observe_input_activity(env, input)

    local title, subtitle, days, device_id = standard_report(input, env)
    local data

    if title then
        prepare_report(env)
        data = aggregate_recent(env, days, device_id)
    else
        try_flush(env)
        local history, first, second, empty_message = history_report(input, env)

        if history == false then
            return yield_msg(seg, first, second)
        elseif history == nil then
            return
        end

        data, title, subtitle = history, first, second
        if not data then return yield_msg(seg, empty_message) end
    end

    yield(Candidate(
        "stat", seg.start, seg._end,
        format_summary(title, subtitle, data, env, device_id), "📊"
    ))
end

return {init=init, func=translator, fini=fini}