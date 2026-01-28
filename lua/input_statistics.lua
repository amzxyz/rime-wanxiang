-- amzxyz@https://github.com/amzxyz/rime_wanxiang
-- input_stats.lua
-- Rime 统计增强版 (LevelDB / 滚动时间窗口 / 效率仪表盘 / 汉字提纯)
-- 维度升级：1, 2, 3, 4, ≥5 字独立统计
-- 允许多设备同步

local userdb = require("lib/userdb")
-- 1. 初始化数据库
local db = userdb.LevelDb("lua/stats")

-- 硬编码信息
local schema_name = "万象拼音"
local raw_software_name = rime_api.get_distribution_code_name()

-- 新增：全局配置变量
local device_id = ""
local sync_dir = "sync_stats"
local potential_peers = {}
-- 定义一个唯一的哨兵对象，用于代替 "all" 字符串
-- 由于这是一个表(table)，它永远不可能等于任何用户输入的字符串(string)，防止用户使用 "all"来作为设备名
local ALL_DEVICES_SENTINEL = {}

-- -----------------------------------------------------------------------------
-- 辅助工具：路径与配置
-- -----------------------------------------------------------------------------
local function get_rime_user_dir()
    local dir = "."
    if rime_api and rime_api.get_user_data_dir then
        dir = rime_api.get_user_data_dir()
    end
    -- 处理路径末尾分隔符
    local last_char = string.sub(dir, -1)
    if last_char == "/" or last_char == "\\" then
        dir = string.sub(dir, 1, -2)
    end
    return dir
end

local function detect_separator(user_dir)
    return string.find(user_dir, "\\") and "\\" or "/"
end

local function get_sync_file_path(filename)
    local user_dir = get_rime_user_dir()
    local sep = detect_separator(user_dir)
    return string.format("%s%s%s%s%s", user_dir, sep, sync_dir, sep, filename)
end

-- -----------------------------------------------------------------------------
-- 平台信息处理中心
-- -----------------------------------------------------------------------------
local function process_platform_info(name, ver)
    name = name or ""
    ver = ver or ""
    -- 1. 清洗版本号：去除第二个"-"及其后的内容 (例如 -gda909f96)
    ver = ver:gsub("^(.-%-[^%-]+)%-.*$", "%1")
    
    -- 2. 平台名称本地化
    if name == "Weasel" then name = "小狼毫" end
    if name == "trime" then name = "同文输入法" end
    if name == "hamster3" then name = "元书输入法" end
    if name == "hamster" then name = "仓输入法" end
    if name == "squirrel" then name = "鼠须管" end
    if name == "fcitx" then name = "小企鹅" end
    if name == "fcitx-rime" then name = "小企鹅㞢" end
    return name, ver
end

-- -----------------------------------------------------------------------------
-- 汉字识别核心逻辑
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 内存缓存：实时分速
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 数据库操作
-- -----------------------------------------------------------------------------
local function ensure_db_open()
    if not db:loaded() then return db:open() end
    return true
end

local function db_get(key)
    return tonumber(db:fetch(key)) or 0
end

local function db_get_str(key)
    return db:fetch(key)
end

local function db_incr_day_and_total(key_suffix, amount, day_key)
    amount = amount or 1
    local d_key = day_key .. key_suffix
    db:update(d_key, tostring(db_get(d_key) + amount))
    local t_key = "total" .. key_suffix
    db:update(t_key, tostring(db_get(t_key) + amount))
end

local function db_set_max_day(key_suffix, new_val, day_key)
    local d_key = day_key .. key_suffix
    if new_val > db_get(d_key) then db:update(d_key, tostring(new_val)) end
    local t_key = "total" .. key_suffix
    if new_val > db_get(t_key) then db:update(t_key, tostring(new_val)) end
end

local function clear_all_data()
    if not ensure_db_open() then return false end
    if db.empty then
        db:empty()
        speed_buffer = {}
        return true
    end
    local ok, iter = pcall(function() return db:query("") end)
    if ok and iter then
        local keys = {}
        for key, _ in iter do table.insert(keys, key) end
        for _, key in ipairs(keys) do db:erase(key) end
        speed_buffer = {}
        return true
    end
    return false
end

-- 新增：获取已知对端设备
local function get_known_peers()
    local str = db:fetch("_sys_known_peers") or ""
    local peers = {}
    for p in string.gmatch(str, "([^,]+)") do peers[p] = true end
    return peers
end

local function add_known_peer(peer_id)
    if peer_id == device_id then return end
    local peers = get_known_peers()
    if not peers[peer_id] then
        peers[peer_id] = true
        local list = {}
        for k, _ in pairs(peers) do table.insert(list, k) end
        db:update("_sys_known_peers", table.concat(list, ","))
    end
end

-- -----------------------------------------------------------------------------
-- 同步功能 (新增模块)
-- -----------------------------------------------------------------------------
local function sync_export()
    if not ensure_db_open() then return "数据库错误" end
    
    local filename = string.format("stats_%s.txt", device_id)
    local tmp_path = get_sync_file_path(filename .. ".tmp")
    local final_path = get_sync_file_path(filename)
    
    local f = io.open(tmp_path, "w")
    if not f then return "IO错误: 请检查目录 " .. sync_dir end
    
    local count = 0
    f:write("# Rime Stats Export V7\n# ID: " .. device_id .. "\n")
    
    -- 遍历数据库，仅导出非 rem_ 开头且非内部系统变量的数据
    db:query_with("", function(key, val)
        if string.sub(key, 1, 4) ~= "rem_" and string.sub(key, 1, 4) ~= "loc_" then
            local is_sys_ctrl = (key == "_sys_known_peers" or key == "_sys_migrated_v4")
            if not is_sys_ctrl then
                f:write(key .. "=" .. val .. "\n")
                count = count + 1
            end
        end
    end)

    f:write("# EOF\n")
    f:close()
    
    os.remove(final_path)
    os.rename(tmp_path, final_path)
    return string.format("导出(%d)至%s", count, device_id)
end

local function sync_import_file(peer_id)
    local path = get_sync_file_path(string.format("stats_%s.txt", peer_id))
    local f = io.open(path, "r")
    if not f then return -1 end
    
    local lines = {}
    local valid_eof = false
    for line in f:lines() do
        line = line:gsub("[\r\n]", "")
        table.insert(lines, line)
        if line == "# EOF" then valid_eof = true end
    end
    f:close()
    
    if not valid_eof then return -2 end
    
    local updates = 0
    for _, line in ipairs(lines) do
        if string.sub(line, 1, 1) ~= "#" then
            local s, e = string.find(line, "=")
            if s then
                local key = string.sub(line, 1, s-1)
                local val_str = string.sub(line, e+1)
                
                -- 构建远程键名: rem_{peer_id}_{original_key}
                local db_key = string.format("rem_%s_%s", peer_id, key)
                local old_val = db:fetch(db_key)
                
                if val_str ~= old_val then
                    db:update(db_key, val_str)
                    updates = updates + 1
                end
            end
        end
    end
    
    if updates >= 0 then add_known_peer(peer_id) end
    return updates
end

local function sync_import_all()
    if not ensure_db_open() then return "数据库错误" end
    local total_updates = 0
    local files_found = 0
    
    for _, pid in ipairs(potential_peers) do
        if pid ~= device_id then
            local status = sync_import_file(pid)
            if status >= 0 then
                files_found = files_found + 1
                total_updates = total_updates + status
            end
        end
    end
    local total_files_found = files_found + 1
    return string.format("发现%d文件, 更新%d条", total_files_found, total_updates)
end

-- -----------------------------------------------------------------------------
-- 记录逻辑
-- -----------------------------------------------------------------------------
local function record_stats(hanzi_len, code_len)
    if not ensure_db_open() then return end
    
    local now = os.time()
    local t = os.date("*t", now)
    local day_key = string.format("d_%04d%02d%02d", t.year, t.month, t.day)
    
    table.insert(speed_buffer, {ts = now, len = hanzi_len})
    local current_kpm = get_current_kpm(now)
    
    db_incr_day_and_total("_len", hanzi_len, day_key)
    db_incr_day_and_total("_cnt", 1, day_key)
    db_incr_day_and_total("_code", code_len, day_key)
    
    if hanzi_len == 1 then db_incr_day_and_total("_l1", 1, day_key)
    elseif hanzi_len == 2 then db_incr_day_and_total("_l2", 1, day_key)
    elseif hanzi_len == 3 then db_incr_day_and_total("_l3", 1, day_key)
    elseif hanzi_len == 4 then db_incr_day_and_total("_l4", 1, day_key)
    elseif hanzi_len > 4  then db_incr_day_and_total("_l_gt4", 1, day_key)
    end
    
    db_set_max_day("_spd", current_kpm, day_key)
end

-- -----------------------------------------------------------------------------
-- 聚合查询逻辑
-- -----------------------------------------------------------------------------
-- 内部辅助：获取单个统计值（支持本机/远程/合并）
local function get_stat_value(key_name, target_id)
    local val = 0
    local is_speed = string.find(key_name, "_spd$")
    
    -- 本机数据 (无前缀)
    if target_id == ALL_DEVICES_SENTINEL or target_id == device_id then
        local loc_val = db_get(key_name)
        if is_speed then
            if loc_val > val then val = loc_val end
        else
            val = val + loc_val
        end
    end

    -- 远程数据 (rem_ID_前缀)
    local peers = get_known_peers()
    for pid, _ in pairs(peers) do
        if target_id == ALL_DEVICES_SENTINEL or target_id == pid then
            local rem_key = string.format("rem_%s_%s", pid, key_name)
            local rem_val = db_get(rem_key)
            if is_speed then
                if rem_val > val then val = rem_val end
            else
                val = val + rem_val
            end
        end
    end
    return val
end

local function aggregate_stats(days_lookback, target_id)
    if not ensure_db_open() then return nil end
    target_id = target_id or device_id

    local function get_dims(prefix)
        return {
            len   = get_stat_value(prefix .. "_len", target_id),
            cnt   = get_stat_value(prefix .. "_cnt", target_id),
            code  = get_stat_value(prefix .. "_code", target_id),
            spd   = get_stat_value(prefix .. "_spd", target_id),
            l1    = get_stat_value(prefix .. "_l1", target_id),
            l2    = get_stat_value(prefix .. "_l2", target_id),
            l3    = get_stat_value(prefix .. "_l3", target_id),
            l4    = get_stat_value(prefix .. "_l4", target_id),
            l_gt4 = get_stat_value(prefix .. "_l_gt4", target_id)
        }
    end
    
    if days_lookback == 0 then
        return get_dims("total")
    end

    local res = {len=0, cnt=0, code=0, spd=0, l1=0, l2=0, l3=0, l4=0, l_gt4=0}
    local now_ts = os.time()
    
    for i = 0, days_lookback - 1 do
        local target_ts = now_ts - (i * 86400)
        local t = os.date("*t", target_ts)
        local day_key = string.format("d_%04d%02d%02d", t.year, t.month, t.day)
        
        local d = get_dims(day_key)
        
        res.len = res.len + d.len
        res.cnt = res.cnt + d.cnt
        res.code = res.code + d.code
        res.l1 = res.l1 + d.l1
        res.l2 = res.l2 + d.l2
        res.l3 = res.l3 + d.l3
        res.l4 = res.l4 + d.l4
        res.l_gt4 = res.l_gt4 + d.l_gt4
        
        if d.spd > res.spd then res.spd = d.spd end
    end
    return res
end

-- -----------------------------------------------------------------------------
-- UI 渲染
-- -----------------------------------------------------------------------------
local function draw_bar(percent)
    local length = 10
    local filled_len = math.floor((percent / 100) * length)
    local empty_len = length - filled_len
    return string.rep("▓", filled_len) .. string.rep("░", empty_len)
end

local function format_summary(title, data, target_id)
    if not data or data.cnt == 0 then return "※ " .. title .. "暂无数据" end
    
    local avg_code = 0
    if data.len > 0 then avg_code = data.code / data.len end
    
    local phrase_rate = 0
    if data.len > 0 then phrase_rate = (data.len - data.l1) / data.len * 100 end

    -- 估算均速
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
    
    -- 获取平台信息 (支持多端显示)
    local sys_name, sys_ver = "", ""
    if target_id == ALL_DEVICES_SENTINEL then
        sys_name, sys_ver = "多端聚合", "Cluster"
    elseif target_id == device_id then
        sys_name = db_get_str("_sys_platform") or raw_software_name
        sys_ver = db_get_str("_sys_version") or rime_api.get_distribution_version()
    else
        sys_name = db_get_str("rem_" .. target_id .. "__sys_platform") or "未知"
        sys_ver = db_get_str("rem_" .. target_id .. "__sys_version") or "?"
    end
    local clean_name, clean_ver = process_platform_info(sys_name, sys_ver)
    
    -- 组装标题
    local device_label = ""
    if target_id == ALL_DEVICES_SENTINEL then
        local count = 1 -- 默认为本机 1 台
        for _ in pairs(get_known_peers()) do count = count + 1 end
        device_label = string.format("☁️ 全网(%d机)", count)
    elseif target_id == device_id then
        device_label = "💻 本机"
    else
        device_label = "📱 " .. target_id
    end
    return string.format(
        "※ %s统计 · %s\n" ..
        "───────────────\n" ..
        "📊 综合数据\n" ..
        "  均速：%d\t 上屏：%d\n" ..
        "  峰速：%d\t 字数：%d\n" ..
        "───────────────\n" ..
        "⚡ 核心效率\n" ..
        "  平均编码：%.2f 键/字\n" ..
        "  词组连打：%.1f %%\n" ..
        "───────────────\n" ..
        "📈 字词分布\n" ..
        "  [1] %3d%% %s\n" ..
        "  [2] %3d%% %s\n" ..
        "  [3] %3d%% %s\n" ..
        "  [4] %3d%% %s\n" ..
        "  [∞] %2d%% %s\n" ..
        "───────────────\n" ..
        "◉ 方案：%s\n" ..
        "◉ 平台：%s %s",
        title, device_label,
        math.floor(estimated_avg_spd), math.floor(data.cnt),
        math.floor(data.spd), math.floor(data.len),
        avg_code, phrase_rate,
        math.floor(p1), draw_bar(p1), 
        math.floor(p2), draw_bar(p2), 
        math.floor(p3), draw_bar(p3), 
        math.floor(p4), draw_bar(p4), 
        math.floor(p_gt4), draw_bar(p_gt4),
        schema_name, clean_name, clean_ver
    )
end

-- -----------------------------------------------------------------------------
-- Init & Fini
-- -----------------------------------------------------------------------------
local function resolve_device_id()
    -- 读取 installation.yaml
    local id = "unknown"
    local filename = "installation.yaml"
    local user_dir = get_rime_user_dir()
    local sep = detect_separator(user_dir)
    
    local f = io.open(user_dir .. sep .. filename, "r")
    if not f then f = io.open(filename, "r") end -- fallback

    if f then
        for line in f:lines() do
            if line:find("^installation_id:") then
                id = line:gsub("^installation_id:%s*", ""):gsub("[\"']", ""):gsub("%s+$", "")
                break
            end
        end
        f:close()
    end
    return (id ~= "unknown") and id or "default_device"
end

local function init(env)
    -- 防止重复：每次初始化前清空旧列表
    potential_peers = {}
    ensure_db_open()
    
    -- 加载配置
    local config = env.engine.schema.config
    sync_dir = config:get_string("input_statistics/sync_dir") or "sync_stats"
    local config_id = config:get_string("input_statistics/device_id")
    device_id = (config_id and config_id ~= "") and config_id or resolve_device_id()
    
    -- 读取对端列表
    local peer_str = config:get_string("input_statistics/potential_peers_str")
    if peer_str then
        for p in string.gmatch(peer_str, "([^,]+)") do
            table.insert(potential_peers, p:match("^%s*(.-)%s*$"))
        end
    end
    -- 尝试读取列表格式
    local rime_list = config:get_list("input_statistics/potential_peers")
    if rime_list then
        for i = 0, rime_list.size - 1 do
            local val = rime_list:get_value_at(i)
            if val then table.insert(potential_peers, val.value) end
        end
    end
    
    -- 记录本机平台信息
    db:update("_sys_platform", rime_api.get_distribution_code_name())
    db:update("_sys_version", rime_api.get_distribution_version())

    if env.stat_notifier then env.stat_notifier:disconnect() end
    local ctx = env.engine.context
    
    env.stat_notifier = ctx.commit_notifier:connect(function(ctx)
        local commit_text = ctx:get_commit_text()
        if not commit_text or commit_text == "" then return end
        if commit_text:sub(1, 1) == "/" then return end
        if commit_text:find("^[※◉]") then return end

        local hanzi_len = get_pure_chinese_length(commit_text)
        if hanzi_len == 0 then return end
        
        local script_text = ctx:get_script_text() or ""
        local code_len = string.len(script_text)
        if code_len == 0 then code_len = hanzi_len * 2 end 

        local now_ms = os.clock()
        if env.last_commit_time and (now_ms - env.last_commit_time < 0.05) then
             if env.last_commit_text == commit_text then return end
        end
        env.last_commit_time = now_ms
        env.last_commit_text = commit_text

        record_stats(hanzi_len, code_len)
    end)
end

local function fini(env)
    if env.stat_notifier then 
        env.stat_notifier:disconnect() 
        env.stat_notifier = nil
    end
    -- 重新部署时关闭数据库，释放文件锁
    if db and db:loaded() then
        db:close()
    end
end

local function translator(input, seg, env)
    if input:sub(1, 1) ~= "/" then return end
    
    if input == "/tjsync" then
        yield(Candidate("stat", seg.start, seg._end, 
            "📤 " .. sync_export() .. "\n📥 " .. sync_import_all(), 
            "🔄"))
        return
	elseif input == "/tjpath" then
         yield(Candidate("stat", seg.start, seg._end, 
            "📂 " .. get_rime_user_dir() .. 
            "\n🆔 " .. device_id ..
            "\n🔗 Peers: " .. table.concat(potential_peers, ", "), 
            "🐞"))
        return
    elseif input == "/tjql" then
        if clear_all_data() then
            yield(Candidate("stat", seg.start, seg._end, "※ 统计数据已全部清空。", "🗑️"))
        else
            yield(Candidate("stat", seg.start, seg._end, "※ 数据清空失败，请检查权限。", "❌"))
        end
        return
    end

    local title = nil
    local days = 0

    if input == "/rtj" then title = "今日"; days = 1
    elseif input == "/ztj" then title = "七日"; days = 7
    elseif input == "/ytj" then title = "卅日"; days = 30
    elseif input == "/ntj" then title = "本年"; days = 365
    elseif input == "/tj" then title = "生涯"; days = 0
    end

    if title then
        -- 1. 全网汇总
        local all_data = aggregate_stats(days, ALL_DEVICES_SENTINEL)
        yield(Candidate("stat", seg.start, seg._end, format_summary(title, all_data, ALL_DEVICES_SENTINEL), "☁️"))
        
        -- 2. 本机数据
        local loc_data = aggregate_stats(days, device_id)
        yield(Candidate("stat", seg.start, seg._end, format_summary(title, loc_data, device_id), "💻"))

        -- 3. 远端设备轮询
        local peers = get_known_peers()
        for pid, _ in pairs(peers) do
            local peer_data = aggregate_stats(days, pid)
            yield(Candidate("stat", seg.start, seg._end, format_summary(title, peer_data, pid), "🔗"))
        end
    end
end

return { init = init, func = translator, fini = fini }
