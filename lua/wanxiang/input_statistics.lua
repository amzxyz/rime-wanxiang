-- amzxyz@https://github.com/amzxyz/rime-wanxiang
-- input_stats.lua：分设备统计 / 最近速度 / 峰速格式去重 / 历史查询
local userdb = require("wanxiang/userdb")
local wanxiang = require("wanxiang/wanxiang")
local SOFTWARE_NAME = rime_api.get_distribution_code_name()
local RECORD_SEPARATOR = " \t"
local STATS_C_MAX = 2147483000
local DEFAULT_CONTINUOUS_GAP_MS = 1000
local DEFAULT_AVERAGE_GAP_MS = 5000
local DEFAULT_MINIMUM_AVERAGE_SESSION_MS = 1000
local DEFAULT_MINIMUM_AVERAGE_TOTAL_MS = 15000
local PEAK_WINDOW_MS = 10000
local DEFAULT_MAX_SPEED_COMMIT_LENGTH = 10
local STATISTICS_PREFIX = "statistics/"
local DAY_PREFIX = STATISTICS_PREFIX .. "day/"
local MIGRATION_KEY = "metadata/readable_statistics_migrated"
local DAY_FIELDS = {
    ["text/characters"]="characters",
    ["text/commits"]="commits",
    ["text/keystrokes"]="keystrokes",
    ["text/code_keystrokes"]="code_keystrokes",
    ["text/code_characters"]="code_characters",
    ["commit_length/1"]="length_1",
    ["commit_length/2"]="length_2",
    ["commit_length/3"]="length_3",
    ["commit_length/4"]="length_4",
    ["commit_length/5_plus"]="length_5_plus",
}
local LEGACY_FIELDS = {
    _len="text/characters",
    _cnt="text/commits",
    _code="text/keystrokes",
    _l1="commit_length/1",
    _l2="commit_length/2",
    _l3="commit_length/3",
    _l4="commit_length/4",
    _l_gt4="commit_length/5_plus",
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

-- 内部设备键固定为 8 位十六进制：
-- 1. 显式 8 位 ID / UUID 保持旧格式，兼容既有正常数据；
-- 2. installation_id 若已改成设备名称，则对完整 UTF-8 字符串做稳定哈希，
--    不再“抽取其中的 a-f/0-9 再截 8 位”，避免名称误判和 00000000 聚合。
local function stable_device_hash(value)
    value = tostring(value or "")
    local hash = 5381
    for i = 1, #value do
        hash = (hash * 33 + value:byte(i)) % 4294967296
    end
    return string.format("%08x", hash)
end

local function canonical_device_id(value)
    value = tostring(value or ""):match("^%s*(.-)%s*$") or ""
    if value == "" then return nil end

    local lower = value:lower()
    if lower:match("^%x%x%x%x%x%x%x%x$") then return lower end

    -- 兼容传统 UUID / 纯十六进制 installation_id：仍取前 8 位。
    local compact = lower:gsub("[{}%-]", "")
    if #compact >= 8 and compact:match("^%x+$") then
        return compact:sub(1, 8)
    end

    return stable_device_hash(value)
end

local function is_device_id(value)
    return type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x$") ~= nil
end

local function get_device_id(config)
    local configured = config:get_string("input_stats/device_id")
    local id = canonical_device_id(configured)
    if id then return id end

    local user_dir = rime_api.get_user_data_dir()
    if not user_dir or user_dir == "" then
        return stable_device_hash(SOFTWARE_NAME or "rime")
    end

    local file = io.open(user_dir:gsub("[/\\]+$", "") .. "/installation.yaml", "r")
    if file then
        for line in file:lines() do
            local value = line:match("^%s*installation_id%s*:%s*(.-)%s*$")
            if value then
                value = value:gsub("%s+#.*$", ""):gsub('^"(.*)"$', "%1")
                    :gsub("^'(.*)'$", "%1")
                file:close()
                return canonical_device_id(value)
                    or stable_device_hash((SOFTWARE_NAME or "rime") .. "|" .. user_dir)
            end
        end
        file:close()
    end

    -- installation.yaml 缺失时仍生成稳定键，避免所有设备退化到 00000000。
    return stable_device_hash((SOFTWARE_NAME or "rime") .. "|" .. user_dir)
end

-- 每个组件只保留自己的 Lua 包装器；同名底层 UserDb 由 wanxiang/userdb.lua 复用。
local function acquire_db(env)
    if env.stats_db then return env.stats_db end

    local db = userdb.LevelDb(env.stats_db_name)
    if not db or (not db:loaded() and not db:open()) then
        env.stats_db_error = true
        return nil
    end

    env.stats_db = db
    env.stats_db_error = nil
    return db
end

local function get_db(env)
    return env.stats_db or acquire_db(env)
end

-- 不主动 close：底层对象可能被其他组件共享，生命周期交给 userdb 弱池与 C++ 析构。
local function release_db(env)
    env.stats_db = nil

    -- DbAccessor 没有显式析构接口。所有局部访问器先置空，再执行一次
    -- 完整垃圾回收，确保其先于所引用的 LevelDb 释放。
    collectgarbage()
end

local function make_raw_key(key, device_id)
    if not key or key == "" or not is_device_id(device_id) then return nil end
    return key .. RECORD_SEPARATOR .. device_id
end

local function parse_raw_key(raw_key)
    if type(raw_key) ~= "string" then return nil, nil end
    local split = raw_key:find(RECORD_SEPARATOR, 1, true)
    if not split then return nil, nil end
    local key = raw_key:sub(1, split - 1)
    local device_id = raw_key:sub(split + #RECORD_SEPARATOR)
    if key == "" or not is_device_id(device_id) then return nil, nil end
    return key, device_id
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

local function db_get(db, key, device_id)
    local raw_key = make_raw_key(key, device_id)
    return raw_key and parse_tail(db:fetch(raw_key)) or 0
end

local function db_set(db, key, device_id, value)
    local raw_key = make_raw_key(key, device_id)
    return raw_key and db:update(raw_key,
        string.format("c=%d d=0 t=0", to_integer(value))) or false
end

local function db_add(db, key, device_id, amount)
    return db_set(db, key, device_id, db_get(db, key, device_id) + amount)
end

local function scan_prefix(db, prefix, device_id, handler)
    local accessor = db:query(prefix)
    if not accessor then return end

    do
        for raw_key, tail in accessor:iter() do
            if raw_key:sub(1, #prefix) ~= prefix then break end

            local key, record_device = parse_raw_key(raw_key)
            if key and (not device_id or record_device == device_id) then
                handler(key, record_device, parse_tail(tail), raw_key)
            end
        end
    end

    accessor = nil
end

local function monotonic_ms()
    if rime_api and rime_api.get_time_ms then
        return math.floor(rime_api.get_time_ms())
    end
    return os.time() * 1000
end

local function day_id(timestamp)
    local date = os.date("*t", timestamp or os.time())
    return string.format("%04d%02d%02d", date.year, date.month, date.day)
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

local function new_stats()
    return {
        characters=0, commits=0, keystrokes=0,
        code_keystrokes=0, code_characters=0,
        average_characters=0, average_milliseconds=0, average_sessions=0,
        peak_speed=nil,
        length_1=0, length_2=0, length_3=0, length_4=0, length_5_plus=0,
        lifetime_characters=0,
    }
end

local function stats_add(env, key, amount)
    local db = get_db(env)
    if env.stats_db_error or not db then return false end
    if not db_add(db, key, env.device_id, amount) then
        env.stats_db_error = true
        return false
    end
    return true
end

local function reset_sample(sample)
    sample.started = nil
    sample.last_activity = nil
    sample.last_commit = nil
    sample.characters = 0
    sample.day = nil
end

local function start_sample(sample, day, timestamp_ms)
    sample.started = timestamp_ms
    sample.last_activity = timestamp_ms
    sample.last_commit = nil
    sample.characters = 0
    sample.day = day
end

local function sample_values(sample, minimum_ms)
    if not sample.started or not sample.last_commit or sample.characters < 2 then
        return nil
    end
    local milliseconds = sample.last_commit - sample.started
    if milliseconds < minimum_ms then return nil end
    return sample.day, sample.characters, milliseconds
end

local function finish_average(env)
    local day, characters, milliseconds = sample_values(
        env.average_sample, env.minimum_average_session_ms
    )
    reset_sample(env.average_sample)
    if not day then return false end
    local prefix = DAY_PREFIX .. day .. "/speed_average/"
    stats_add(env, prefix .. "characters", characters)
    stats_add(env, prefix .. "milliseconds", milliseconds)
    stats_add(env, prefix .. "sessions", 1)
    return true
end

local function peak_speed(characters, milliseconds)
    return math.max(0, math.min(2000,
        math.floor(characters * 60000 / milliseconds + 0.5)))
end

local function finish_peak(env)
    local day, characters, milliseconds = sample_values(
        env.peak_sample, PEAK_WINDOW_MS
    )
    reset_sample(env.peak_sample)
    if not day then return false end
    stats_add(env, string.format("%s%s/speed_peak_window_10s/%04d",
        DAY_PREFIX, day, peak_speed(characters, milliseconds)), 1)
    return true
end

local function ensure_sample(sample, day, timestamp_ms, gap_ms, finish)
    if sample.started then
        local gap = timestamp_ms - (sample.last_activity or sample.started)
        if gap >= 0 and gap <= gap_ms and sample.day == day then return end
        finish()
    end
    start_sample(sample, day, timestamp_ms)
end

local function finish_stale(env, timestamp_ms)
    local peak = env.peak_sample
    if peak.started and timestamp_ms - (peak.last_activity or peak.started)
        > env.continuous_gap_ms
    then
        finish_peak(env)
    end
    local average = env.average_sample
    if average.started and timestamp_ms - (average.last_activity or average.started)
        > env.average_gap_ms
    then
        finish_average(env)
    end
end

local function observe_input_activity(env, input)
    local timestamp_ms = monotonic_ms()
    if not input or input == "" or input:sub(1, 1) == "/" then
        finish_stale(env, timestamp_ms)
        env.last_observed_input = input or ""
        return
    end
    if input == env.last_observed_input then return end
    env.last_observed_input = input
    local day = day_id()
    ensure_sample(env.average_sample, day, timestamp_ms, env.average_gap_ms,
        function() finish_average(env) end)
    ensure_sample(env.peak_sample, day, timestamp_ms, env.continuous_gap_ms,
        function() finish_peak(env) end)
    env.average_sample.last_activity = timestamp_ms
    env.peak_sample.last_activity = timestamp_ms
end

local function commit_to_speed(env, day, timestamp_ms, characters, allow_peak)
    ensure_sample(env.average_sample, day, timestamp_ms, env.average_gap_ms,
        function() finish_average(env) end)
    local average = env.average_sample
    average.last_activity = timestamp_ms
    average.last_commit = timestamp_ms
    average.characters = average.characters + characters

    if allow_peak then
        ensure_sample(env.peak_sample, day, timestamp_ms, env.continuous_gap_ms,
            function() finish_peak(env) end)
        local peak = env.peak_sample
        peak.last_activity = timestamp_ms
        peak.last_commit = timestamp_ms
        peak.characters = peak.characters + characters
        if peak.last_commit - peak.started >= PEAK_WINDOW_MS then finish_peak(env) end
    else
        -- user_table 等不参与峰速；当前峰值窗口一并作废，避免混合窗口失真。
        reset_sample(env.peak_sample)
    end

    env.last_observed_input = ""
end

local function is_valid_speed_commit(env, characters, code_length)
    if code_length <= 0 or characters > env.max_speed_commit_length then
        return false
    end

    return characters <= math.max(4, code_length * 2)
end

local function record_stats(env, characters, code_length, candidate_type)
    local timestamp_ms = monotonic_ms()
    local day = day_id()
    local prefix = DAY_PREFIX .. day .. "/"
    if not stats_add(env, prefix .. "text/characters", characters) then return end
    stats_add(env, prefix .. "text/commits", 1)

    -- 平均编码只使用“确实取得输入编码”的配对样本。
    -- text/keystrokes 继续保留真实编码总量；新字段保证历史脏数据不会混入新口径。
    if code_length > 0 then
        stats_add(env, prefix .. "text/keystrokes", code_length)
        stats_add(env, prefix .. "text/code_keystrokes", code_length)
        stats_add(env, prefix .. "text/code_characters", characters)
    end

    local field = characters == 1 and "commit_length/1"
        or characters == 2 and "commit_length/2"
        or characters == 3 and "commit_length/3"
        or characters == 4 and "commit_length/4"
        or "commit_length/5_plus"
    stats_add(env, prefix .. field, 1)

    if is_valid_speed_commit(env, characters, code_length) then
        commit_to_speed(env, day, timestamp_ms, characters,
            candidate_type ~= "user_table")
    else
        finish_peak(env)
        finish_average(env)
        env.last_observed_input = ""
    end
end

local function in_day_range(day, start_day, end_day)
    return (not start_day or day >= start_day) and (not end_day or day <= end_day)
end

local function calculate_peak(peaks)
    local speeds, samples = {}, 0
    for speed, count in pairs(peaks) do
        if count > 0 then
            speeds[#speeds + 1] = speed
            samples = samples + count
        end
    end
    if samples == 0 then return nil end

    table.sort(speeds, function(a, b) return a > b end)
    local target = math.min(2, samples)
    local total, used = 0, 0

    for _, speed in ipairs(speeds) do
        local take = math.min(peaks[speed], target - used)
        total = total + speed * take
        used = used + take
        if used >= target then break end
    end

    return used > 0 and math.floor(total / used + 0.5) or nil
end

local function aggregate_statistics(env, start_day, end_day, device_id,
        speed_start_day, speed_end_day)
    speed_start_day = speed_start_day or start_day
    speed_end_day = speed_end_day or end_day
    local db = get_db(env)
    if not db then return nil end
    local stats, peaks = new_stats(), {}

    scan_prefix(db, STATISTICS_PREFIX, device_id,
        function(key, record_device, value)
        local day, field = key:match("^statistics/day/(%d%d%d%d%d%d%d%d)/(.+)$")
        if not day then return end
        if field == "text/characters" then
            stats.lifetime_characters = stats.lifetime_characters + value
        end

        local target = DAY_FIELDS[field]
        if target then
            if in_day_range(day, start_day, end_day) then
                stats[target] = stats[target] + value
            end
            return
        end

        if not in_day_range(day, speed_start_day, speed_end_day) then return end

        local average_field = field:match("^speed_average/([^/]+)$")
        if average_field == "characters" then
            stats.average_characters = stats.average_characters + value
        elseif average_field == "milliseconds" then
            stats.average_milliseconds = stats.average_milliseconds + value
        elseif average_field == "sessions" then
            stats.average_sessions = stats.average_sessions + value
        else
            local speed = field:match("^speed_peak_window_10s/(%d%d%d%d)$")
            if speed then
                speed = tonumber(speed)
                peaks[speed] = (peaks[speed] or 0) + value
            end
        end
    end)
    local day, characters, milliseconds = sample_values(
        env.average_sample, env.minimum_average_session_ms
    )
    if day and in_day_range(day, speed_start_day, speed_end_day)
        and (not device_id or device_id == env.device_id)
    then
        stats.average_characters = stats.average_characters + characters
        stats.average_milliseconds = stats.average_milliseconds + milliseconds
        stats.average_sessions = stats.average_sessions + 1
    end
    day, characters, milliseconds = sample_values(env.peak_sample, PEAK_WINDOW_MS)
    if day and in_day_range(day, speed_start_day, speed_end_day)
        and (not device_id or device_id == env.device_id)
    then
        local speed = peak_speed(characters, milliseconds)
        peaks[speed] = (peaks[speed] or 0) + 1
    end
    if stats.average_milliseconds < env.minimum_average_total_ms then
        stats.average_characters = 0
        stats.average_milliseconds = 0
        stats.average_sessions = 0
    end

    stats.peak_speed = calculate_peak(peaks)
    if stats.peak_speed and stats.average_milliseconds > 0 then
        local average_speed = math.floor(
            stats.average_characters * 60000 / stats.average_milliseconds + 0.5)
        if stats.peak_speed < average_speed then
            stats.peak_speed = average_speed
        end
    end

    return stats.commits > 0 and stats or nil
end

local function migrate_database(env)
    local db = get_db(env)
    if not db then return end
    local additions, old_keys = {}, {}
    scan_prefix(db, "d_", nil, function(key, device_id, value, raw_key)
        old_keys[#old_keys + 1] = raw_key
        local day, suffix = key:match("^d_(%d%d%d%d%d%d%d%d)(_.+)$")
        local target = day and LEGACY_FIELDS[suffix]
        if target and value > 0 and db_get(db, MIGRATION_KEY, device_id) == 0 then
            local device = additions[device_id] or {}
            additions[device_id] = device
            local new_key = DAY_PREFIX .. day .. "/" .. target
            device[new_key] = (device[new_key] or 0) + value
        end
    end)
    scan_prefix(db, "total_", nil, function(_, _, _, raw_key)
        old_keys[#old_keys + 1] = raw_key
    end)
    for device_id, values in pairs(additions) do
        local success = true
        for key, value in pairs(values) do
            if value > db_get(db, key, device_id)
                and not db_set(db, key, device_id, value)
            then
                success = false
                break
            end
        end
        if success then db_set(db, MIGRATION_KEY, device_id, 1) end
    end
    for _, raw_key in ipairs(old_keys) do db:erase(raw_key) end
    local obsolete = {}
    scan_prefix(db, STATISTICS_PREFIX, nil, function(key, _, _, raw_key)
        if key:match("^statistics/day/%d%d%d%d%d%d%d%d/speed/[^/]+$")
            or key:match("^statistics/day/%d%d%d%d%d%d%d%d/average_speed/[^/]+$")
            or key:match("^statistics/day/%d%d%d%d%d%d%d%d/peak_speed/[^/]+$")
            or key:match("^statistics/day/%d%d%d%d%d%d%d%d/speed_peak/")
            or key:match("^statistics/day/%d%d%d%d%d%d%d%d/speed_peak_window/")
            or key:match("^statistics/hour/") then
            obsolete[#obsolete + 1] = raw_key
        end
    end)
    for _, raw_key in ipairs(obsolete) do db:erase(raw_key) end
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

local function user_title(env, characters)
    for _, item in ipairs(ensure_titles(env)) do
        if characters >= item[1] then return item[2] end
    end
    return "初学乍练"
end

local function draw_bar(percent)
    percent = math.max(0, math.min(100, tonumber(percent) or 0))
    local filled = math.floor(percent / 10)
    return string.rep("▓", filled) .. string.rep("░", 10 - filled)
end

local function format_summary(title, subtitle, data, env)
    if not data or data.commits == 0 then return "※ " .. title .. "暂无数据" end
    local average_code = data.code_characters > 0
        and string.format("%.2f", data.code_keystrokes / data.code_characters)
        or "--"
    local phrase_rate = data.characters > 0
        and (data.characters - data.length_1) / data.characters * 100 or 0
    local average_speed = data.average_milliseconds > 0
        and math.floor(data.average_characters * 60000
            / data.average_milliseconds + 0.5) or nil
    local p = {
        data.length_1 / data.commits * 100, data.length_2 / data.commits * 100,
        data.length_3 / data.commits * 100, data.length_4 / data.commits * 100,
        data.length_5_plus / data.commits * 100,
    }
    local software, version = platform_info(
        SOFTWARE_NAME, rime_api.get_distribution_version()
    )
    local style = wanxiang.get_input_method_type(env)
    local zwsp = "\226\128\139"
    local header = string.format("※ %s统计 · 效率仪表盘\n", title)
    if subtitle and subtitle ~= "" then
        header = header .. string.format("📅 %s" .. zwsp .. "\n", subtitle)
    end
    return header .. string.format(
        "───────────────" .. zwsp .. "\n" ..
        "📊 综合数据" .. zwsp .. "\n" ..
        "  均速:%-5s 上屏:%d" .. zwsp .. "\n" ..
        "  峰速:%-5s 字数:%d" .. zwsp .. "\n" ..
        "🏆 段位：%s" .. zwsp .. "\n" ..
        "───────────────" .. zwsp .. "\n" ..
        "⚡ 核心效率" .. zwsp .. "\n" ..
        "  平均编码：%s 键/字" .. zwsp .. "\n" ..
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
        average_speed and tostring(average_speed) or "--", math.floor(data.commits),
        data.peak_speed and tostring(data.peak_speed) or "--",
        math.floor(data.characters), user_title(env, data.lifetime_characters),
        average_code, phrase_rate,
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
    finish_stale(env, monotonic_ms())
end

local function standard_report(input, env)
    local today = day_id()
    local recent = day_id(os.time() - (env.speed_history_days - 1) * 86400)

    if input == env.triggers.local_total then
        return "本设备", "设备 " .. env.device_id, nil, nil, env.device_id,
            recent, today
    elseif input == env.triggers.today then
        return "今日", "", today, today, nil, today, today
    elseif input == env.triggers.week then
        local start_day = day_id(os.time() - 6 * 86400)
        return "七日", "", start_day, today, nil, start_day, today
    elseif input == env.triggers.month then
        return "卅日", "", recent, today, nil, recent, today
    elseif input == env.triggers.year then
        local start_day = day_id(os.time() - 364 * 86400)
        return "本年", "", start_day, today, nil, start_day, today
    elseif input == env.triggers.total then
        return "生涯", "", nil, nil, nil, recent, today
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
        return aggregate_statistics(env, sy .. sm .. sd, ey .. em .. ed),
            "区间", string.format("%s.%s.%s - %s.%s.%s", sy, sm, sd, ey, em, ed),
            "※ 该区间内没有留下打字记录哦"
    end
    local y, m, d = query:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if y then
        prepare_report(env)
        local day = y .. m .. d
        return aggregate_statistics(env, day, day), "单日",
            string.format("%s.%s.%s", y, m, d), "※ 这一天没有留下打字记录哦"
    end
    y, m = query:match("^(%d%d%d%d)(%d%d)$")
    if y then
        prepare_report(env)
        return aggregate_statistics(env, y .. m .. "01", y .. m .. "31"),
            "月份", string.format("%s年%s月", y, m), "※ 该月没有留下打字记录哦"
    end
    y = query:match("^(%d%d%d%d)$")
    if y then
        prepare_report(env)
        return aggregate_statistics(env, y .. "0101", y .. "1231"),
            "年度", string.format("%s年", y), "※ 该年没有留下打字记录哦"
    end
    return false, query:find("t", 1, true) and "※ 正在输入区间查询..."
        or "※ 正在查询中... 请继续输入完整的年/月/日", "⏳"
end

local function on_commit(context, env)
    local text = context:get_commit_text()
    if not text or text == "" or text:sub(1, 1) == "/"
        or text:find("^[※◉🏆📊⚡📈]") then return end

    local characters = chinese_length(text)
    if characters == 0 then return end

    local candidate_type = ""
    local cand = context:get_selected_candidate()
    if cand then
        candidate_type = cand.type or ""
        local genuine = cand.get_genuine and cand:get_genuine() or nil
        if genuine and genuine.type then candidate_type = genuine.type end
    end

    local code = context.input or ""
    if code == "" then code = env.last_observed_input or "" end
    local code_length = #code

    record_stats(env, characters, code_length, candidate_type)
end

local function bounded_int(config, key, default, minimum, maximum)
    return math.max(minimum, math.min(maximum, config:get_int(key) or default))
end

local function init(env)
    local config = env.engine.schema.config
    env.schema_name = env.engine.schema.schema_name or "万象方案"
    env.stats_db_name = config:get_string("input_stats/db_name") or "stats"
    if env.stats_db_name == "" then env.stats_db_name = "stats" end
    env.device_id = get_device_id(config)
    env.continuous_gap_ms = bounded_int(config, "input_stats/continuous_gap_ms",
        DEFAULT_CONTINUOUS_GAP_MS, 200, 5000)
    env.average_gap_ms = bounded_int(config, "input_stats/average_gap_ms",
        DEFAULT_AVERAGE_GAP_MS, env.continuous_gap_ms, 30000)
    env.minimum_average_session_ms = bounded_int(config,
        "input_stats/minimum_average_session_ms",
        DEFAULT_MINIMUM_AVERAGE_SESSION_MS, 500, 10000)
    env.minimum_average_total_ms = bounded_int(config,
        "input_stats/minimum_average_total_ms",
        DEFAULT_MINIMUM_AVERAGE_TOTAL_MS, 3000, 120000)
    env.max_speed_commit_length = bounded_int(config,
        "input_stats/max_speed_commit_length",
        DEFAULT_MAX_SPEED_COMMIT_LENGTH, 1, 10)
    env.speed_history_days = bounded_int(config,
        "input_stats/speed_history_days", 30, 1, 365)
    env.stats_db_error = nil
    env.last_observed_input = ""
    env.titles = nil
    env.average_sample = {}
    env.peak_sample = {}
    reset_sample(env.average_sample)
    reset_sample(env.peak_sample)
    env.triggers = {
        local_total=config:get_string("input_stats/triggers/local_total") or "/btj",
        today=config:get_string("input_stats/triggers/today") or "/rtj",
        week=config:get_string("input_stats/triggers/week") or "/ztj",
        month=config:get_string("input_stats/triggers/month") or "/ytj",
        year=config:get_string("input_stats/triggers/year") or "/ntj",
        total=config:get_string("input_stats/triggers/total") or "/tj",
        history=config:get_string("input_stats/triggers/history") or "/htj",
    }
    if acquire_db(env) then migrate_database(env) end
    if env.stat_notifier then env.stat_notifier:disconnect() end
    env.stat_notifier = env.engine.context.commit_notifier:connect(
        function(context) on_commit(context, env) end
    )
end

local function fini(env)
    finish_peak(env)
    finish_average(env)
    env.last_observed_input = ""
    if env.stat_notifier then
        env.stat_notifier:disconnect()
        env.stat_notifier = nil
    end
    env.titles = nil
    env.average_sample, env.peak_sample = nil, nil
    release_db(env)
end

local function translator(input, seg, env)
    observe_input_activity(env, input)
    local title, subtitle, start_day, end_day, device_id,
        speed_start_day, speed_end_day = standard_report(input, env)
    local data
    if title then
        prepare_report(env)
        data = aggregate_statistics(env, start_day, end_day, device_id,
            speed_start_day, speed_end_day)
        if not data and env.stats_db_error then
            return yield_msg(seg,
                "※ 统计数据库打开失败", "⚠️")
        end
    else
        local history, first, second, empty_message = history_report(input, env)
        if history == false then return yield_msg(seg, first, second) end
        if history == nil then return end
        data, title, subtitle = history, first, second
        if not data and env.stats_db_error then
            return yield_msg(seg,
                "※ 统计数据库打开失败", "⚠️")
        end
        if not data then return yield_msg(seg, empty_message) end
    end
    yield(Candidate("stat", seg.start, seg._end,
        format_summary(title, subtitle, data, env), "📊"))
end

return {init=init, func=translator, fini=fini}