-- amzxyz@https://github.com/amzxyz/rime-wanxiang
-- input_stats.lua
-- Rime 统计增强版 (LevelDB / 滚动时间窗口 / 效率仪表盘 / 汉字提纯)
-- 新增：配置项 YAML 外放、递进式时光机、自定义区间、UI横向自适应排版

local userdb = require("wanxiang/userdb")

local _db_pool = {}
local raw_software_name = rime_api.get_distribution_code_name()

local function get_db(env)
    local config = env.engine.schema.config
    local db_name = config:get_string("input_stats/db_name") or "lua/stats"
    if not _db_pool[db_name] then 
        _db_pool[db_name] = userdb.LevelDb(db_name) 
    end
    local db = _db_pool[db_name]
    if db and not db:loaded() then db:open() end
    return db
end

local function process_platform_info(name, ver)
    name = name or ""
    ver = ver or ""
    ver = ver:gsub("^(.-%-[^%-]+)%-.*$", "%1")
    ver = ver:gsub("^(%d+%.%d+%.%d+).*", "%1")
    if name == "Weasel" then name = "小狼毫" end
    if name == "trime" then name = "同文输入法" end
    if name == "hamster3" then name = "元书输入法" end
    if name == "hamster" then name = "仓输入法" end
    return name, ver
end

local function is_chinese_code(c)
    return (c >= 0x4E00 and c <= 0x9FFF) or (c >= 0x3400 and c <= 0x4DBF) or 
           (c >= 0x20000 and c <= 0x2A6DF) or (c >= 0x2A700 and c <= 0x2B73F) or 
           (c >= 0x2B740 and c <= 0x2B81F) or (c >= 0x2B820 and c <= 0x2CEAF) or 
           (c >= 0x2CEB0 and c <= 0x2EBEF) or (c >= 0x30000 and c <= 0x3134F) or 
           (c >= 0x31350 and c <= 0x323AF) or (c >= 0x2EBF0 and c <= 0x2EE5F) or 
           (c >= 0xF900  and c <= 0xFAFF) or (c >= 0x2F800 and c <= 0x2FA1F) or 
           (c >= 0x2E80  and c <= 0x2EFF) or (c >= 0x2F00  and c <= 0x2FDF)
end

local function get_pure_chinese_length(text)
    local count = 0
    for _, code in utf8.codes(text) do
        if is_chinese_code(code) then count = count + 1 end
    end
    return count
end

local speed_buffer = {}
local last_cleanup_ts = 0

local function get_current_kpm(now)
    if now - last_cleanup_ts > 5 then
        local new_buf = {}
        local threshold = now - 60
        for _, item in ipairs(speed_buffer) do
            if item.ts > threshold then table.insert(new_buf, item) end
        end
        speed_buffer = new_buf
        last_cleanup_ts = now
    end
    local total = 0
    local threshold = now - 60
    for _, item in ipairs(speed_buffer) do
        if item.ts > threshold then total = total + item.len end
    end
    return total
end

local function db_get(db, key)
    return tonumber(db:fetch(key)) or 0
end

local function db_incr_day_and_total(db, key_suffix, amount, day_key)
    amount = amount or 1
    local d_key = day_key .. key_suffix
    db:update(d_key, tostring(db_get(db, d_key) + amount))
    local t_key = "total" .. key_suffix
    db:update(t_key, tostring(db_get(db, t_key) + amount))
end

local function db_set_max_day(db, key_suffix, new_val, day_key)
    local d_key = day_key .. key_suffix
    if new_val > db_get(db, d_key) then db:update(d_key, tostring(new_val)) end
    local t_key = "total" .. key_suffix
    if new_val > db_get(db, t_key) then db:update(t_key, tostring(new_val)) end
end

local function clear_all_data(env)
    local db = get_db(env)
    if not db or not db:loaded() then return false end
    
    if db.empty then
        db:empty()
        speed_buffer = {}
        return true
    end
    local iter = db:query("")
    if iter then
        local keys = {}
        for key, _ in iter do table.insert(keys, key) end
        for _, key in ipairs(keys) do db:erase(key) end
        speed_buffer = {}
        return true
    end
    return false
end

local function record_stats(env, hanzi_len, code_len)
    local db = get_db(env)
    if not db or not db:loaded() then return end
    
    local now = os.time()
    local t = os.date("*t", now)
    local day_key = string.format("d_%04d%02d%02d", t.year, t.month, t.day)
    
    -- 反粘贴作弊机制：单次上屏字数 <= 30 才计入速度 buffer
    local current_kpm = 0
    if hanzi_len <= 30 then
        table.insert(speed_buffer, {ts = now, len = hanzi_len})
    end
    current_kpm = get_current_kpm(now)
    
    db_incr_day_and_total(db, "_len", hanzi_len, day_key)
    db_incr_day_and_total(db, "_cnt", 1, day_key)
    db_incr_day_and_total(db, "_code", code_len, day_key)
    
    if hanzi_len == 1 then db_incr_day_and_total(db, "_l1", 1, day_key)
    elseif hanzi_len == 2 then db_incr_day_and_total(db, "_l2", 1, day_key)
    elseif hanzi_len == 3 then db_incr_day_and_total(db, "_l3", 1, day_key)
    elseif hanzi_len == 4 then db_incr_day_and_total(db, "_l4", 1, day_key)
    elseif hanzi_len > 4  then db_incr_day_and_total(db, "_l_gt4", 1, day_key)
    end
    
    db_set_max_day(db, "_spd", current_kpm, day_key)
end

local function aggregate_stats(env, days_lookback)
    local db = get_db(env)
    if not db or not db:loaded() then return nil end
    
    if days_lookback == 0 then
        local prefix = "total"
        return {
            len = db_get(db, prefix .. "_len"), cnt = db_get(db, prefix .. "_cnt"), code = db_get(db, prefix .. "_code"),
            spd = db_get(db, prefix .. "_spd"), l1 = db_get(db, prefix .. "_l1"), l2 = db_get(db, prefix .. "_l2"),
            l3 = db_get(db, prefix .. "_l3"), l4 = db_get(db, prefix .. "_l4"), l_gt4 = db_get(db, prefix .. "_l_gt4")
        }
    end

    local res = {len=0, cnt=0, code=0, spd=0, l1=0, l2=0, l3=0, l4=0, l_gt4=0}
    local now_ts = os.time()
    
    for i = 0, days_lookback - 1 do
        local target_ts = now_ts - (i * 86400)
        local t = os.date("*t", target_ts)
        local day_key = string.format("d_%04d%02d%02d", t.year, t.month, t.day)
        
        res.len = res.len + db_get(db, day_key .. "_len")
        res.cnt = res.cnt + db_get(db, day_key .. "_cnt")
        res.code = res.code + db_get(db, day_key .. "_code")
        res.l1 = res.l1 + db_get(db, day_key .. "_l1")
        res.l2 = res.l2 + db_get(db, day_key .. "_l2")
        res.l3 = res.l3 + db_get(db, day_key .. "_l3")
        res.l4 = res.l4 + db_get(db, day_key .. "_l4")
        res.l_gt4 = res.l_gt4 + db_get(db, day_key .. "_l_gt4")
        
        local daily_spd = db_get(db, day_key .. "_spd")
        if daily_spd > res.spd then res.spd = daily_spd end
    end
    return res
end

local function aggregate_custom_period(env, year, month, day, end_year, end_month, end_day)
    local db = get_db(env)
    if not db or not db:loaded() then return nil end
    local keys = {}

    if end_year then
        local start_ts = os.time({year=year, month=month, day=day, hour=12})
        local end_ts = os.time({year=end_year, month=end_month, day=end_day, hour=12})
        if start_ts and end_ts and start_ts <= end_ts then
            local current_ts = start_ts
            while current_ts <= end_ts do
                local t = os.date("*t", current_ts)
                table.insert(keys, string.format("d_%04d%02d%02d", t.year, t.month, t.day))
                current_ts = current_ts + 86400
            end
        end
    elseif day then
        table.insert(keys, string.format("d_%04d%02d%02d", year, month, day))
    elseif month then
        for d = 1, 31 do table.insert(keys, string.format("d_%04d%02d%02d", year, month, d)) end
    elseif year then
        for m = 1, 12 do
            for d = 1, 31 do table.insert(keys, string.format("d_%04d%02d%02d", year, m, d)) end
        end
    end

    if #keys == 0 then return nil end

    local res = {len=0, cnt=0, code=0, spd=0, l1=0, l2=0, l3=0, l4=0, l_gt4=0}
    local has_data = false

    for _, day_key in ipairs(keys) do
        local len = db_get(db, day_key .. "_len")
        if len > 0 then
            has_data = true
            res.len = res.len + len
            res.cnt = res.cnt + db_get(db, day_key .. "_cnt")
            res.code = res.code + db_get(db, day_key .. "_code")
            res.l1 = res.l1 + db_get(db, day_key .. "_l1")
            res.l2 = res.l2 + db_get(db, day_key .. "_l2")
            res.l3 = res.l3 + db_get(db, day_key .. "_l3")
            res.l4 = res.l4 + db_get(db, day_key .. "_l4")
            res.l_gt4 = res.l_gt4 + db_get(db, day_key .. "_l_gt4")

            local daily_spd = db_get(db, day_key .. "_spd")
            if daily_spd > res.spd then res.spd = daily_spd end
        end
    end

    if not has_data then return nil end
    return res
end

local function get_user_title(env)
    local db = get_db(env)
    if not db or not db:loaded() then return "初学乍练" end
    
    local current_len = db_get(db, "total_len")
    for _, item in ipairs(env.titles) do
        if current_len >= item.threshold then return item.name end
    end
    return "初学乍练"
end

local function draw_bar(percent)
    local length = 10
    local filled_len = math.floor((percent / 100) * length)
    local empty_len = length - filled_len
    return string.rep("▓", filled_len) .. string.rep("░", empty_len)
end

local function format_summary(title, subtitle, data, env)
    if not data or data.cnt == 0 then return "※ " .. title .. "暂无数据" end
    
    local avg_code = 0
    if data.len > 0 then avg_code = data.code / data.len end
    
    local phrase_rate = 0
    if data.len > 0 then phrase_rate = (data.len - data.l1) / data.len * 100 end

    local estimated_avg_spd = 0
    if data.cnt > 0 then
        estimated_avg_spd = math.floor(data.len / ((data.cnt * 2) / 60))
        if estimated_avg_spd > data.spd then estimated_avg_spd = math.floor(data.spd * 0.8) end
        if estimated_avg_spd == 0 and data.len > 0 then estimated_avg_spd = data.len end
    end

    local p1 = (data.l1 / data.cnt) * 100
    local p2 = (data.l2 / data.cnt) * 100
    local p3 = (data.l3 / data.cnt) * 100
    local p4 = (data.l4 / data.cnt) * 100
    local p_gt4 = (data.l_gt4 / data.cnt) * 100
    
    local raw_ver = rime_api.get_distribution_version() or ""
    local clean_name, clean_ver = process_platform_info(raw_software_name, raw_ver)
    local user_achievement = get_user_title(env)
    local header = string.format("※ %s统计 · 效率仪表盘\n", title)
    if subtitle and subtitle ~= "" then
        header = header .. string.format("📅 %s\n", subtitle)
    end
    local zwsp = "\226\128\139" --electron框架开发的软件格式化乱码，加上零宽空格能保证末尾截取掉后格式正常
    return header .. string.format(
        "───────────────" .. zwsp .. "\n" ..
        "📊 综合数据" .. zwsp .. "\n" ..
        "  均速:%-5d 上屏:%d" .. zwsp .. "\n" ..
        "  峰速:%-5d 字数:%d" .. zwsp .. "\n" ..
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
        "◉ 平台：%s %s" .. zwsp,
        math.floor(estimated_avg_spd), math.floor(data.cnt),
        math.floor(data.spd), math.floor(data.len),
        user_achievement,
        avg_code, phrase_rate,
        math.floor(p1), draw_bar(p1), 
        math.floor(p2), draw_bar(p2), 
        math.floor(p3), draw_bar(p3), 
        math.floor(p4), draw_bar(p4), 
        math.floor(p_gt4), draw_bar(p_gt4),
        env.schema_name, clean_name, clean_ver
    )
end

local function yield_msg(seg, text, icon)
    yield(Candidate("stat", seg.start, seg._end, text, icon or "🕰️"))
end

local function init(env)
    local config = env.engine.schema.config
    env.schema_name = env.engine.schema.schema_name or "万象方案"

    get_db(env)

    env.triggers = {
        clear   = config:get_string("input_stats/triggers/clear")   or "/qctj",
        today   = config:get_string("input_stats/triggers/today")   or "/rtj",
        week    = config:get_string("input_stats/triggers/week")    or "/ztj",
        month   = config:get_string("input_stats/triggers/month")   or "/ytj",
        year    = config:get_string("input_stats/triggers/year")    or "/ntj",
        total   = config:get_string("input_stats/triggers/total")   or "/tj",
        history = config:get_string("input_stats/triggers/history") or "/htj",
    }

    env.titles = {}
    local custom_titles = config:get_list("input_stats/titles")
    if custom_titles and custom_titles.size > 0 then
        for i = 0, custom_titles.size - 1 do
            local item = custom_titles:get_value_at(i)
            if item and item.value then
                local t_val, t_name = item.value:match("^(%d+):(.+)$")
                if t_val and t_name then table.insert(env.titles, { threshold = tonumber(t_val), name = t_name }) end
            end
        end
    end
    
    if #env.titles == 0 then
        env.titles = {
            { threshold = 5000000, name = "⌨️·天人合一" },
            { threshold = 1000000, name = "⌨️·登峰造极" },
            { threshold = 500000,  name = "✨·出神入化" },
            { threshold = 100000,  name = "💨·行云流水" },
            { threshold = 50000,   name = "🚀·运指如飞" },
            { threshold = 10000,   name = "🌟·渐入佳境" },
            { threshold = 0,       name = "🌱·初学乍练" }
        }
    end
    table.sort(env.titles, function(a, b) return a.threshold > b.threshold end)

    if env.stat_notifier then env.stat_notifier:disconnect() end
    local ctx = env.engine.context
    
    env.stat_notifier = ctx.commit_notifier:connect(function(ctx)
        local commit_text = ctx:get_commit_text()
        if not commit_text or commit_text == "" then return end
        if commit_text:sub(1, 1) == "/" then return end
        if commit_text:find("^[※◉🏆📊⚡📈]") then return end

        local hanzi_len = get_pure_chinese_length(commit_text)
        if hanzi_len == 0 then return end
        
        -- 【核心修改】精准抓取用户实际敲击的按键字母
        local raw_input = ctx.input or ""
        local code_len = string.len(raw_input)
        
        -- 如果获取不到物理输入（如粘贴/非常规上屏），才做等比估算
        if code_len == 0 then code_len = hanzi_len * 2 end 
        
        record_stats(env, hanzi_len, code_len)
    end)
end

local function fini(env)
    if env.stat_notifier then 
        env.stat_notifier:disconnect() 
        env.stat_notifier = nil
    end
end

local function translator(input, seg, env)
    local summary = ""
    local data = nil
    local title = ""
    local subtitle = ""

    if input == env.triggers.clear then
        if clear_all_data(env) then yield_msg(seg, "※ 统计数据已全部清空。", "🗑️")
        else yield_msg(seg, "※ 数据清空失败，请检查权限。", "❌") end
        return
    end

    if input == env.triggers.today then title = "今日"; data = aggregate_stats(env, 1)
    elseif input == env.triggers.week then title = "七日"; data = aggregate_stats(env, 7)
    elseif input == env.triggers.month then title = "卅日"; data = aggregate_stats(env, 30)
    elseif input == env.triggers.year then title = "本年"; data = aggregate_stats(env, 365)
    elseif input == env.triggers.total then title = "生涯"; data = aggregate_stats(env, 0)
    end

    if not data then
        local trigger_len = string.len(env.triggers.history)
        
        if string.sub(input, 1, trigger_len) == env.triggers.history then
            local safe_trigger = env.triggers.history:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            local is_matched = false
            
            local s_y, s_m, s_d, e_y, e_m, e_d = input:match("^" .. safe_trigger .. "(%d%d%d%d)(%d%d)(%d%d)t(%d%d%d%d)(%d%d)(%d%d)$")
            if s_y then
                is_matched = true
                title = "区间"
                subtitle = string.format("%s.%s.%s - %s.%s.%s", s_y, s_m, s_d, e_y, e_m, e_d)
                data = aggregate_custom_period(env, tonumber(s_y), tonumber(s_m), tonumber(s_d), tonumber(e_y), tonumber(e_m), tonumber(e_d))
                if not data then return yield_msg(seg, "※ 该区间内没有留下打字记录哦") end
            else
                local y, m, d = input:match("^" .. safe_trigger .. "(%d%d%d%d)(%d%d)(%d%d)$")
                if y then
                    is_matched = true
                    title = "单日"
                    subtitle = string.format("%s.%s.%s", y, m, d)
                    data = aggregate_custom_period(env, tonumber(y), tonumber(m), tonumber(d))
                    if not data then return yield_msg(seg, "※ 这一天没有留下打字记录哦") end
                else
                    local y, m = input:match("^" .. safe_trigger .. "(%d%d%d%d)(%d%d)$")
                    if y then
                        is_matched = true
                        title = "月份"
                        subtitle = string.format("%s年%s月", y, m)
                        data = aggregate_custom_period(env, tonumber(y), tonumber(m))
                        if not data then return yield_msg(seg, "※ 该月没有留下打字记录哦") end
                    else
                        local y = input:match("^" .. safe_trigger .. "(%d%d%d%d)$")
                        if y then
                            is_matched = true
                            title = "年度"
                            subtitle = string.format("%s年", y)
                            data = aggregate_custom_period(env, tonumber(y))
                            if not data then return yield_msg(seg, "※ 该年没有留下打字记录哦") end
                        end
                    end
                end
            end
            
            if not is_matched then
                if string.len(input) == trigger_len then
                    return yield_msg(seg, "※ 请输入日期或区间 (例: 2026, 202601, 20260101t20260201)", "⌨️")
                else
                    local query_str = string.sub(input, trigger_len + 1)
                    if string.find(query_str, "t") then
                        return yield_msg(seg, "※ 正在输入区间查询...", "⏳")
                    else
                        return yield_msg(seg, "※ 正在查询中... 请继续输入完整的年/月/日", "⏳")
                    end
                end
            end
        end
    end

    if data then
        summary = format_summary(title, subtitle, data, env)
        yield(Candidate("stat", seg.start, seg._end, summary, "📊"))
    end
end

return { init = init, func = translator, fini = fini }
