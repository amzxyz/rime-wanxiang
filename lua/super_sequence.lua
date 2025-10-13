-- 万象拼音 · 手动自由排序
-- 核心规则： 向前移动 = "Control+j", 向后移动 = "Control+k", 重置 = "Control+l", 置顶 = "Control+p
-- 1) p>0：有效排序（DB upsert + 导出）
-- 2) p=0：墓碑（DB 删除 + 导出墓碑）
-- 3) 初始化：先 flush 本机增量到导出 → 外部合并(所有设备文件+本机DB，LWW) → 重写本机导出(含墓碑) → 导入覆盖DB，p=0删除键，不导入
-- 4) 关于同步的使用方法：先点击同步确保同步目录已经创建，建立sequence_device_list.txt设备清单，内部填写不同设备导出文件名称
-- sequence_ff9b2823-8733-44bb-a497-daf382b74ca5.txt
-- sequence_deepin.txt
-- 可能是自定义名称，可能是随机串号
-- sequence_开头，后面跟着installation_id，这个参数来自用户目录installation.yaml
-- 清单有什么文件就会读取什么文件
-- 仅使用 installation.yaml 的 sync_dir；读不到就回退到 user_dir/sync
-- 核心规则： 向前移动 = "Control+j", 向后移动 = "Control+k", 重置 = "Control+l", 置顶 = "Control+p"
-- 1) p>0：有效排序（DB upsert + 导出）
-- 2) p=0：墓碑（DB 删除 + 导出墓碑）
-- 3) 初始化：先 flush 本机增量到导出 → 外部合并(所有设备文件+本机DB，LWW) → 重写本机导出(含墓碑) → 导入覆盖DB，p=0删除键，不导入
-- 4) 同步路径策略：能从 installation.yaml 读取到 sync_dir 就用它；读不到才用默认 user_dir/sync

local wanxiang = require("wanxiang")
local userdb   = require("lib/userdb")

------------------------------------------------------------
-- 一、常量与键位
------------------------------------------------------------
local DEFAULT_SEQ_KEY = { up = "Control+j", down = "Control+k", reset = "Control+l", pin = "Control+p" }
local SYNC_FILE_PREFIX, SYNC_FILE_SUFFIX = "sequence", ".txt"

-- 运行期是否立刻写出到导出文件（只在重新部署时写出→设为 false）
local RUNTIME_EXPORT = false

-- ☆☆ 前向声明，避免被当作全局导致 nil ☆☆
local _normalize_path, _is_abs_path, _path_join, _manifest_path

------------------------------------------------------------
-- 二、通用工具（仅处理 "\" 与 "\\", 统一成 "/"）
------------------------------------------------------------
_normalize_path = function(p)
    if not p or p == "" then return "" end
    if p:sub(1, 2) == "\\\\" then
        -- UNC：\\server\share\foo -> //server/share/foo
        return "//" .. p:sub(3):gsub("\\", "/"):gsub("/+", "/")
    else
        -- 普通：D:\dir\\file -> D:/dir/file
        return p:gsub("\\", "/"):gsub("/+", "/")
    end
end

_is_abs_path = function(p)
    p = _normalize_path(p)
    return p:sub(1, 2) == "//" or p:match("^[A-Za-z]:/")
end

_path_join = function(a, b)
    a = _normalize_path(a)
    b = _normalize_path(b)
    if not a or a == "" then return b end
    if not b or b == "" then return a end
    if _is_abs_path(b) then return b end
    if a:sub(-1) ~= "/" then a = a .. "/" end
    return a .. b
end

_manifest_path = function(dir)
    return _path_join(dir, "sequence_device_list.txt")
end

local function _read_lines(path)
    local t, f = {}, io.open(path, "r")
    if not f then return t end
    for line in f:lines() do t[#t + 1] = line end
    f:close()
    return t
end

local function _write_lines(path, lines)
    local f = io.open(path, "w"); if not f then return false end
    for _, line in ipairs(lines) do f:write(line, "\n") end
    f:close()
    return true
end

local function _trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function _file_exists(path)
    if not path or path == "" then return false end
    local f = io.open(path, "r"); if f then f:close(); return true end
    return false
end

------------------------------------------------------------
-- 三、安装信息 & 同步目录（仅看 YAML；读不到就默认）
------------------------------------------------------------
local function _read_installation_yaml()
    local user_dir = rime_api.get_user_data_dir()
    if not user_dir or user_dir == "" then return nil, nil end
    local path = _path_join(user_dir, "installation.yaml")
    local f = io.open(path, "r"); if not f then return nil, nil end
    local installation_id, sync_dir
    for line in f:lines() do
        line = line:gsub("%s+#.*$", "")
        local key, val = line:match("^%s*([%w_]+)%s*:%s*(.+)$")
        if key and val then
            -- 去引号
            val = val:gsub('^%s*"(.*)"%s*$', "%1"):gsub("^%s*'(.*)'%s*$", "%1")
            val = val:gsub("^%s+", ""):gsub("%s+$", "")
            if key == "installation_id" then
                installation_id = val
            elseif key == "sync_dir" then
                sync_dir = _normalize_path(val)
            end
        end
    end
    f:close()
    return installation_id, sync_dir
end

-- 只看 installation.yaml，读到就用；读不到就 user_dir/sync
local function _sync_dir()
    local user_dir = rime_api.get_user_data_dir() or ""
    local _, ysync = _read_installation_yaml()

    local function fix(x)
        if not x or x == "" then return "" end
        if x == "sync" then
            return (user_dir ~= "" and _path_join(user_dir, "sync")) or "sync"
        end
        return _normalize_path(x)
    end

    if ysync and ysync ~= "" then
        return fix(ysync)
    end
    return _path_join(user_dir, "sync")
end

local function _sync_ready()
    local install_id, ysync = _read_installation_yaml()
    local user_dir = rime_api.get_user_data_dir() or ""
    local dir
    if ysync and ysync ~= "" then
        dir = _normalize_path(ysync)
        if dir == "sync" then dir = _path_join(user_dir, "sync") end
    else
        dir = _path_join(user_dir, "sync")
    end
    local ok = (install_id and install_id ~= "") and (dir and dir ~= "")
    return ok, dir, install_id
end

local function _detect_device_name()
    local installation_id = select(1, _read_installation_yaml())
    local function _san(s) return tostring(s):gsub("[%s/\\:%*%?\"<>|]", "_") end
    if installation_id and installation_id ~= "" then return _san(installation_id) end
    local dir = _sync_dir()
    for _, raw in ipairs(_read_lines(_manifest_path(dir))) do
        local name = _trim(raw or "")
        local m = name:match("^sequence_(.+)%.txt$")
        if m and not _is_abs_path(name) then return _san(m) end
    end
    return "device"
end

------------------------------------------------------------
-- 四、时间
------------------------------------------------------------
local function get_timestamp()
    local ms = type(rime_api.get_time_ms) == "function" and tonumber(rime_api.get_time_ms()) or nil
    return ms and (os.time() + ms / 1000.0) or os.time()
end

------------------------------------------------------------
-- 五、DB 与状态
------------------------------------------------------------
local seq_db = userdb.LevelDb("lua/sequence")

local seq_property = {
    ADJUST_KEY = "sequence_adjustment_code",
}
---@param context Context
function seq_property.get(context)
    return context:get_property(seq_property.ADJUST_KEY)
end

---@param context Context
function seq_property.reset(context)
    local code = seq_property.get(context)
    if code ~= nil and code ~= "" then
        context:set_property(seq_property.ADJUST_KEY, "")
    end
end

local curr_state = {}
curr_state.ADJUST_MODE = { None = -1, Reset = 0, Pin = 1, Adjust = 2 }
curr_state.default = {
    selected_phrase = nil, offset = 0, mode = curr_state.ADJUST_MODE.None,
    highlight_index = nil, adjust_code = nil, adjust_key = nil,
    dirty = false, last_dirty_ts = 0,
}
function curr_state.reset()
    if curr_state.mode == curr_state.ADJUST_MODE.None then return end
    for k, v in pairs(curr_state.default) do curr_state[k] = v end
end
function curr_state.is_pin_mode()    return curr_state.mode == curr_state.ADJUST_MODE.Pin end
function curr_state.is_reset_mode()  return curr_state.mode == curr_state.ADJUST_MODE.Reset end
function curr_state.is_adjust_mode() return curr_state.mode == curr_state.ADJUST_MODE.Adjust end
function curr_state.has_adjustment() return curr_state.mode ~= curr_state.ADJUST_MODE.None end

------------------------------------------------------------
-- 六、关键日志（精简）
------------------------------------------------------------
local function _print_sync_probe(phase)
    local user_dir = tostring(rime_api.get_user_data_dir() or "")
    local iid, ysync = _read_installation_yaml()
    local chosen = _sync_dir()
    local inst_yaml = _path_join(user_dir, "installation.yaml")
    log.warning(string.format(
        "[sequence][%s] installation_id=%s yaml_sync_dir=%s chosen_sync_dir=%s inst_yaml=%s exists=%s",
        phase, tostring(iid), tostring(ysync), tostring(chosen),
        inst_yaml, tostring(_file_exists(inst_yaml))
    ))
end

local function _debug_paths_once()
    local dir = _sync_dir()
    local device_name = _detect_device_name()
    local export_name = string.format("%s_%s%s", SYNC_FILE_PREFIX, device_name, SYNC_FILE_SUFFIX)
    local export_path = _path_join(dir, export_name)
    log.info(string.format("[sequence] chosen_sync_dir=%s manifest_exists=%s",
                           tostring(dir), tostring(_file_exists(_manifest_path(dir)))))
    log.info(string.format("[sequence] export_path=%s exists=%s",
                           tostring(export_path), tostring(_file_exists(export_path))))
end

------------------------------------------------------------
-- 七、记录解析（新格式）
------------------------------------------------------------
local function parse_adjustment_value_item(value_item)
    local item, p, o, t = value_item:match("i=(.+) p=(%S+) o=(%S*) t=(%S+)")
    if not item then return nil, nil end
    return item, { fixed_position = tonumber(p) or 0, offset = tonumber(o) or 0, updated_at = tonumber(t) }
end

local function parse_adjustment_values(values_str)
    local mp = {}
    for seg in values_str:gmatch("[^\t]+") do
        local item, adj = parse_adjustment_value_item(seg)
        if item then mp[item] = adj end
    end
    return next(mp) and mp or nil
end

local function get_input_adjustments(input)
    if not input or input == "" then return nil end
    local value_str = seq_db:fetch(input)
    return value_str and parse_adjustment_values(value_str) or nil
end

------------------------------------------------------------
-- 八、导出缓冲（去重 + 节流）
------------------------------------------------------------
local seq_data = {
    status = "pending",
    device_name = "device",
    last_export_ts = 0,
    export_interval = 1.2,      -- 秒
    pending_map = {},           -- key: input.."\t"..item  =>  line
}

local function _pending_count() local n = 0; for _ in pairs(seq_data.pending_map) do n = n + 1 end; return n end

function seq_data._current_paths()
    local dir = _sync_dir()
    local device_name = seq_data.device_name or "device"
    local export_name = string.format("%s_%s%s", SYNC_FILE_PREFIX, device_name, SYNC_FILE_SUFFIX)
    local export_path = _path_join(dir, export_name)
    local manifest = _manifest_path(dir)
    return dir, device_name, export_name, export_path, manifest
end

function seq_data._ensure_export_file()
    local ok = _sync_ready()
    if not ok then
        log.info("[sequence] installation_id 或 sync_dir 缺失，跳过导出")
        return false
    end
    local _, _, export_name, export_path, manifest = seq_data._current_paths()
    if not _file_exists(manifest) then
        local mf = io.open(manifest, "w"); if not mf then return false end; mf:close()
    end
    if not _file_exists(export_path) then
        local f = io.open(export_path, "w"); if not f then return false end
        local user_id = wanxiang.get_user_id()
        if user_id then f:write("\001/user_id\t", user_id, "\n") end
        f:write("\001/device_name\t", seq_data.device_name or "device", "\n")
        f:close()
    end
    local names = _read_lines(manifest)
    local seen = {}; for _, n in ipairs(names) do seen[_trim(n)] = true end
    if not seen[export_name] then names[#names + 1] = export_name; _write_lines(manifest, names) end
    return true
end

local function _enqueue_export(input, item, adj)
    local k = input .. "\t" .. item
    seq_data.pending_map[k] = string.format("%s\ti=%s p=%s o=%s t=%s\n",
        input, item, adj.fixed_position or 0, adj.offset or 0, adj.updated_at or "")
end

function seq_data.flush_pending(max_lines)
    if _pending_count() == 0 then return end
    if not seq_data._ensure_export_file() then return end
    local _, _, _, export_path = seq_data._current_paths()
    local f = io.open(export_path, "a"); if not f then return end
    local wrote = 0
    for _, line in pairs(seq_data.pending_map) do
        if max_lines and wrote >= max_lines then break end
        f:write(line); wrote = wrote + 1
    end
    f:close()
    seq_data.pending_map = {}
end

function seq_data.maybe_export(force)
    if force then
        seq_data.flush_pending(nil)
        seq_data.last_export_ts = get_timestamp()
        return
    end
    if _pending_count() == 0 then return end
    local now = get_timestamp()
    if now - (seq_data.last_export_ts or 0) < (seq_data.export_interval or 1.2) then return end
    seq_data.flush_pending(200)
    seq_data.last_export_ts = now
end

------------------------------------------------------------
-- 九、保存（本机操作）：p=0 也导出墓碑（运行期不写盘；DB 暂存墓碑以便重部署覆盖）
------------------------------------------------------------
local function save_adjustment(input, item, adjustment, no_export)
    if not input or input == "" or not item or item == "" then return end
    local p = tonumber(adjustment.fixed_position) or 0
    local o = tonumber(adjustment.offset) or 0
    local t = adjustment.updated_at

    local mp = get_input_adjustments(input) or {}
    if p <= 0 then
        -- 关键：DB 内也保留 p=0 墓碑（含时间戳），用于重部署时 LWW 覆盖外部文件
        mp[item] = { fixed_position = 0, offset = o, updated_at = t }
    else
        mp[item] = { fixed_position = p, offset = o, updated_at = t }
    end

    local arr = {}
    for it, a in pairs(mp) do
        arr[#arr + 1] = string.format("i=%s p=%s o=%s t=%s",
            it, a.fixed_position, a.offset or 0, a.updated_at or "")
    end
    seq_db:update(input, table.concat(arr, "\t"))

    -- 仅在允许运行期写出时才入队（默认 RUNTIME_EXPORT=false，不入队）
    if (not no_export) and RUNTIME_EXPORT then
        _enqueue_export(input, item, { fixed_position = p, offset = o, updated_at = t }) -- 包含 p=0 墓碑
    end
end

------------------------------------------------------------
-- 十、合并器：收集“所有文件 + 本机DB”，按 t 取最新（包含 p=0）
------------------------------------------------------------
local function _keep_latest(latest, input, item, adj)
    latest[input] = latest[input] or {}
    local prev = latest[input][item]
    if (not prev) or ((adj.updated_at or 0) > (prev.updated_at or 0)) then
        latest[input][item] = {
            fixed_position = tonumber(adj.fixed_position) or 0,
            offset         = tonumber(adj.offset) or 0,
            updated_at     = tonumber(adj.updated_at) or 0
        }
    end
end

local function collect_latest_from_all_sources()
    local latest = {}

    -- A) 本机 DB（包含 p=0 墓碑：让 DB 能覆盖外部）
    seq_db:query_with("", function(key, value)
        local mp = parse_adjustment_values(value)
        if mp then
            for item, a in pairs(mp) do
                _keep_latest(latest, key, item, a)
            end
        end
    end)

    -- B) 清单里的所有导出文件（包含 p=0）
    local dir = _sync_dir()
    local names = _read_lines(_manifest_path(dir))
    for _, raw in ipairs(names) do
        local name = _trim(raw or "")
        if name ~= "" and name:sub(1, 1) ~= "#" then
            if name:sub(1, #SYNC_FILE_PREFIX) == SYNC_FILE_PREFIX
                and name:sub(-#SYNC_FILE_SUFFIX) == SYNC_FILE_SUFFIX then
                local path = _is_abs_path(name) and name or _path_join(dir, name)
                local f = io.open(path, "r")
                if f then
                    for line in f:lines() do
                        if line ~= "" and line:sub(1, 2) ~= "\001" .. "/" then
                            local key, value = line:match("^(%S+)\t(.+)$")
                            if key and value then
                                local item, adj1 = parse_adjustment_value_item(value)
                                if item then
                                    _keep_latest(latest, key, item, adj1)
                                else
                                    local mp = parse_adjustment_values(value)
                                    if mp then for it, a in pairs(mp) do _keep_latest(latest, key, it, a) end end
                                end
                            end
                        end
                    end
                    f:close()
                end
            end
        end
    end

    return latest
end

------------------------------------------------------------
-- 十一、把“合并结果”重写到我机导出（含 p=0）
------------------------------------------------------------
local function rewrite_export_from_latest(latest)
    local ok = _sync_ready()
    if not ok then return end
    local dir = _sync_dir()
    local installation_id = select(1, _read_installation_yaml())
    local device_name = (installation_id and installation_id ~= "") and tostring(installation_id):gsub("[%s/\\:%*%?\"<>|]", "_") or "device"
    local export_name = string.format("%s_%s%s", SYNC_FILE_PREFIX, device_name, SYNC_FILE_SUFFIX)
    local export_path = _path_join(dir, export_name)
    local manifest = _manifest_path(dir)

    if not _file_exists(manifest) then local mf = io.open(manifest, "w"); if mf then mf:close() end end
    do
        local names = _read_lines(manifest); local seen = {}; for _, n in ipairs(names) do seen[_trim(n)] = true end
        if not seen[export_name] then names[#names + 1] = export_name; _write_lines(manifest, names) end
    end

    local f = io.open(export_path, "w"); if not f then return end
    local user_id = wanxiang.get_user_id()
    if user_id then f:write("\001/user_id\t", user_id, "\n") end
    f:write("\001/device_name\t", device_name, "\n")

    local inputs = {}
    for input, _ in pairs(latest) do inputs[#inputs + 1] = input end
    table.sort(inputs)
    for _, input in ipairs(inputs) do
        local items, keys = latest[input], {}
        for item, _ in pairs(items) do keys[#keys + 1] = item end
        table.sort(keys)
        for _, item in ipairs(keys) do
            local a = items[item]
            f:write(string.format("%s\ti=%s p=%s o=%s t=%s\n",
                input, item, a.fixed_position or 0, a.offset or 0, a.updated_at or ""))
        end
    end

    f:close()
    log.info(string.format("[sequence] export rewritten (merged LWW, incl tombstones): %s", export_path))
end

------------------------------------------------------------
-- 十二、把“合并结果”导入覆盖 DB（p<=0 删）
------------------------------------------------------------
local function apply_latest_to_db(latest)
    local updated_keys = 0
    for input, kv in pairs(latest) do
        local keep = {}
        for item, a in pairs(kv) do
            if (tonumber(a.fixed_position) or 0) > 0 then
                keep[item] = { fixed_position = a.fixed_position, offset = a.offset or 0, updated_at = a.updated_at }
            end
        end
        if next(keep) == nil then
            seq_db:erase(input)
        else
            local arr = {}
            for item, a in pairs(keep) do
                arr[#arr + 1] = string.format("i=%s p=%s o=%s t=%s", item, a.fixed_position, a.offset or 0, a.updated_at or "")
            end
            seq_db:update(input, table.concat(arr, "\t"))
        end
        updated_keys = updated_keys + 1
    end
    log.info(string.format("[sequence] DB applied from merged LWW: %d keys", updated_keys))
end

------------------------------------------------------------
-- 十三、初始化：先导出→合并→重写导出→导入DB
------------------------------------------------------------
local function init_once()
    -- 1) 先导出：把本机 pending 增量写出去（如果是旧版本留下的队列，这里可一次性落盘；RUNTIME_EXPORT 与此无关）
    seq_data._ensure_export_file()
    seq_data.maybe_export(true)

    -- 2) 外部合并（所有设备文件 + 本机 DB），LWW（含 p=0）
    local latest = collect_latest_from_all_sources()

    -- 3) 用合并结果重写我机导出（包含 p=0）——始终写盘
    rewrite_export_from_latest(latest)

    -- 4) 导入合并结果覆盖 DB（p<=0 删）
    apply_latest_to_db(latest)
end

------------------------------------------------------------
-- 十四、Pipeline：P / F
------------------------------------------------------------
local P = {}
function P.init(env)
    seq_db:open()
    seq_data.device_name = _detect_device_name()
    _print_sync_probe("init")   -- 关键：一次性输出最终使用的 sync_dir
    _debug_paths_once()         -- 关键：简要输出导出与清单路径是否存在
    init_once()
end

local function process_adjustment(context)
    local c = context:get_selected_candidate()
    curr_state.selected_phrase = c and c.text or nil
    context:refresh_non_confirmed_composition()
    if context.highlight and curr_state.highlight_index and curr_state.highlight_index > 0 then
        context:highlight(curr_state.highlight_index)
    end
end

function P.func(key_event, env)
    local context = env.engine.context
    curr_state.reset()

    local selected_cand = context:get_selected_candidate()
    if not context:has_menu() or not selected_cand or not selected_cand.text then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local key_repr = key_event:repr()
    local function get_seq_key(type)
        return env.engine.schema.config:get_string("key_binder/sequence/" .. type) or DEFAULT_SEQ_KEY[type]
    end

    if key_repr == get_seq_key("up") then
        curr_state.offset = -1; curr_state.mode = curr_state.ADJUST_MODE.Adjust
    elseif key_repr == get_seq_key("down") then
        curr_state.offset = 1;  curr_state.mode = curr_state.ADJUST_MODE.Adjust
    elseif key_repr == get_seq_key("reset") then
        curr_state.offset = nil; curr_state.mode = curr_state.ADJUST_MODE.Reset
    elseif key_repr == get_seq_key("pin") then
        curr_state.offset = nil; curr_state.mode = curr_state.ADJUST_MODE.Pin
    else
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    process_adjustment(context)
    return wanxiang.RIME_PROCESS_RESULTS.kAccepted
end

local F = {}

function F.fini()
    -- 退出时不落盘（仅在重新部署 init_once 重写导出）
    if RUNTIME_EXPORT then
        seq_data.maybe_export(true)
    end
end

local function apply_prev_adjustment(cands, prev)
    local list = {}
    for _, info in pairs(prev or {}) do
        if info.raw_position then info.from_position = info.raw_position; table.insert(list, info) end
    end
    table.sort(list, function(a, b) return (a.updated_at or 0) < (b.updated_at or 0) end)

    local n = #cands
    for i, record in ipairs(list) do
        local fromp = record.from_position
        if fromp and (record.fixed_position or 0) > 0 then
            local top = (record.offset == 0) and record.fixed_position or (record.raw_position + record.offset)
            if top < 1 then top = 1 elseif top > n then top = n end
            if fromp ~= top then
                local cand = table.remove(cands, fromp)
                table.insert(cands, top, cand)
                local lo, hi = math.min(fromp, top), math.max(fromp, top)
                for j = i, #list do
                    local r = list[j]
                    if lo <= r.from_position and r.from_position <= hi then
                        r.from_position = r.from_position + ((top < fromp) and 1 or -1)
                    end
                end
            end
        end
    end
end

local function apply_curr_adjustment(candidates, curr_adjustment)
    if curr_adjustment == nil then return end

    ---@type integer | nil
    local from_position = nil
    for position, cand in ipairs(candidates) do
        if cand.text == curr_state.selected_phrase then
            from_position = position
            break
        end
    end

    if from_position == nil then return end

    local to_position = from_position
    if curr_state.is_adjust_mode() then
        to_position = from_position + curr_state.offset
        curr_adjustment.offset = to_position - curr_adjustment.raw_position
        curr_adjustment.fixed_position = to_position

        local min_position, max_position = 1, #candidates
        if from_position ~= to_position then
            if to_position < min_position then
                to_position = min_position
            elseif to_position > max_position then
                to_position = max_position
            end

            local candidate = table.remove(candidates, from_position)
            table.insert(candidates, to_position, candidate)

            -- 运行期仅写 DB，不入导出队列
            save_adjustment(curr_state.adjust_code, curr_state.adjust_key, curr_adjustment, true)
        end
    end

    curr_state.highlight_index = to_position - 1
end

local function extract_adjustment_code(context)
    if wanxiang.is_function_mode_active(context) then
        local code = seq_property.get(context)
        if code and code ~= "" then return code end
        return nil
    end
    return context.input:sub(1, context.caret_pos)
end

function F.func(input, env)
    local function original_list() for cand in input:iter() do yield(cand) end end

    local context = env.engine.context
    local adjustment_allowed = not (wanxiang.is_function_mode_active(context) and seq_property.get(context) == nil)
    if not adjustment_allowed then
        log.warning("[sequence] 当前指令不支持手动排序")
        return original_list()
    end

    local adjust_code = extract_adjustment_code(context)
    if not adjust_code then return original_list() end

    local prev_adjustments = get_input_adjustments(adjust_code)
    local curr_adjustment = curr_state.has_adjustment() and { fixed_position = 0, offset = 0, updated_at = get_timestamp() } or nil
    if (not curr_adjustment) and (not prev_adjustments) then return original_list() end

    local cands, seen = {}, {}
    local is_fun_mode = wanxiang.is_function_mode_active(context)
    local pos = 0
    for candidate in input:iter() do
        local phrase = candidate.text
        if not seen[phrase] then
            seen[phrase] = true; pos = pos + 1; table.insert(cands, candidate)
            local curr_key = is_fun_mode and tostring(pos - 1) or phrase
            if curr_adjustment and curr_state.selected_phrase == phrase then
                curr_state.adjust_code = adjust_code
                curr_state.adjust_key  = curr_key
                curr_adjustment.raw_position = pos
            end
            if prev_adjustments and prev_adjustments[curr_key] then
                prev_adjustments[curr_key].raw_position = pos
            end
        end
    end
    prev_adjustments = prev_adjustments or {}

    -- 非位移：置顶/重置立即仅保存到 DB（不入队）
    if curr_adjustment and not curr_state.is_adjust_mode() then
        curr_adjustment.offset = 0
        local key = tostring(curr_state.adjust_key)
        if curr_state.is_reset_mode() then
            curr_adjustment.fixed_position = 0
            prev_adjustments[key] = nil
            save_adjustment(curr_state.adjust_code, curr_state.adjust_key, curr_adjustment, true)
        elseif curr_state.is_pin_mode() then
            curr_adjustment.fixed_position = 1
            prev_adjustments[key] = curr_adjustment
            save_adjustment(curr_state.adjust_code, curr_state.adjust_key, curr_adjustment, true)
        end
    end

    apply_prev_adjustment(cands, prev_adjustments)
    apply_curr_adjustment(cands, curr_adjustment)

    for _, cand in ipairs(cands) do yield(cand) end

    -- 运行期不写盘；如需调试可改为 if RUNTIME_EXPORT then ... end
    if RUNTIME_EXPORT and (not curr_state.is_reset_mode()) then
        seq_data.maybe_export(false)
    end
end

return { P = P, F = F }
