-- 万象家族 Lua：超级提示、表情、化学式、方程式、简码等直接上屏，不占用候选位置
-- 采用 LevelDb 数据库，支持大数据遍历、多种类型及编码混合
-- 支持候选匹配和编码匹配，候选支持方向键高亮遍历
-- https://github.com/amzxyz/rime-wanxiang
--
-- super_tips:
--   db_name: "lua/tips"
--   tips_key: "slash"
--   disabled_types: []
--   files:
--     - lua/data/my_tips.txt
--     - lua/data/tips_show.txt

local wanxiang = require("wanxiang/wanxiang")
local userdb = require("wanxiang/userdb")

local RECORD_SEPARATOR = " \t"
local DEFAULT_RECORD_TAIL = "c=0 d=0 t=0"
local DB_FORMAT_VERSION = "1"

local tips_db
local tips = {
    status = "pending",
    ref_count = 0,
    disabled_types = {},
    default_preset = "lua/data/tips_show.txt",
    default_user = "lua/data/tips_user.txt",
}

local META_KEY = {
    version = "db_format_version",
    disabled_types = "disabled_types_fingerprint",
    files_sig = "files_signature",
}

-- 将采样字节转换为安全十六进制，避免元数据串行。
local function bytes_to_hex(data)
    local parts = {}

    for i = 1, #data do
        parts[i] = string.format("%02x", data:byte(i))
    end

    return table.concat(parts)
end

-- 采样多个文件生成只包含安全字符的特征。
local function generate_files_signature(paths)
    local parts = {}

    for _, path in ipairs(paths) do
        local file, close = wanxiang.load_file_with_fallback(path, "rb")

        if file then
            local size = file:seek("end") or 0
            local head, middle, tail = "", "", ""

            if size > 0 then
                file:seek("set", 0)
                head = file:read(64) or ""

                file:seek("set", math.floor(size / 2))
                middle = file:read(64) or ""

                file:seek("set", math.max(0, size - 64))
                tail = file:read(64) or ""
            end

            close()
            parts[#parts + 1] = table.concat({
                tostring(size),
                bytes_to_hex(head),
                bytes_to_hex(middle),
                bytes_to_hex(tail),
            }, ":")
        end
    end

    return table.concat(parts, "|")
end

-- 判断某个提示类型是否被禁用。
local function is_disabled(value)
    local tip_type = value:match("^(..-):") or value:match("^(..-)：")
    return tip_type and tips.disabled_types[tip_type] == true or false
end

-- 从文件加载提示；相同 key 由后出现的 value 覆盖。
local function load_data_from_files(files)
    local written = {}

    for _, file_path in ipairs(files) do
        local file, close = wanxiang.load_file_with_fallback(file_path, "r")

        if file then
            for line in file:lines() do
                line = line:gsub("\r$", "")
                local value, key = line:match("^([^\t]+)\t([^\t]+)$")

                if key and value and not is_disabled(value) then
                    local raw_key = key .. RECORD_SEPARATOR .. value
                    local old_raw_key = written[key]

                    if raw_key ~= old_raw_key then
                        if old_raw_key and not tips_db:erase(old_raw_key) then
                            close()
                            return false
                        end

                        if not tips_db:update(
                            raw_key, DEFAULT_RECORD_TAIL
                        ) then
                            close()
                            return false
                        end

                        written[key] = raw_key
                    end
                end
            end

            close()
        end
    end

    return true
end

-- 关闭数据库并恢复待初始化状态。
local function close_database()
    local db = tips_db
    tips_db = nil

    if db then
        collectgarbage()
        if db:loaded() then db:close() end
    end

    tips.status = "pending"
end

-- 初始化提示数据库。
local function init_database(config)
    if tips.status == "done" then return true end
    if tips.status == "initialing" then return false end
    tips.status = "initialing"

    local db_name = config:get_string("super_tips/db_name")
    if not db_name or db_name == "" then db_name = "tips" end

    tips_db = userdb.LevelDb(db_name)
    if not tips_db then
        tips.status = "pending"
        return false
    end

    tips.disabled_types = {}
    local disabled_keys = {}
    local disabled_list = config:get_list("super_tips/disabled_types")

    if disabled_list then
        for i = 0, disabled_list.size - 1 do
            local item = disabled_list:get_value_at(i)
            local value = item and item.value

            if value and value ~= "" then
                tips.disabled_types[value] = true
                disabled_keys[#disabled_keys + 1] = value
            end
        end
    end

    table.sort(disabled_keys)
    local disabled_fingerprint = table.concat(disabled_keys, "|")

    local files = {}
    local files_list = config:get_list("super_tips/files")

    if files_list then
        for i = 0, files_list.size - 1 do
            local entry = files_list:get_value_at(i)
            local value = entry and entry.value

            if value and value ~= "" then
                files[#files + 1] = value
            end
        end
    end

    if #files == 0 then files = {tips.default_preset, tips.default_user} end

    local signature = generate_files_signature(files)
    local needs_rebuild = true

    -- 稳定路径只读打开一次，元数据一致时直接保留句柄。
    if tips_db:open_read_only() then
        local db_version = tips_db:meta_fetch(META_KEY.version) or ""
        local db_disabled = tips_db:meta_fetch(META_KEY.disabled_types) or ""
        local db_signature = tips_db:meta_fetch(META_KEY.files_sig) or ""

        needs_rebuild = db_version ~= DB_FORMAT_VERSION
            or db_disabled ~= disabled_fingerprint
            or db_signature ~= signature

        if not needs_rebuild then
            tips.status = "done"
            return true
        end

        tips_db:close()
    end

    -- 仅在数据库不存在或数据变化时进入读写模式。
    if not tips_db:open() then
        close_database()
        return false
    end

    local cleared
    if tips_db.clear then
        cleared = tips_db:clear()
    else
        cleared = tips_db:empty(true)
    end

    if cleared == false
        or not load_data_from_files(files)
        or not tips_db:meta_update(META_KEY.version, DB_FORMAT_VERSION)
        or not tips_db:meta_update(
            META_KEY.disabled_types, disabled_fingerprint
        )
        or not tips_db:meta_update(META_KEY.files_sig, signature)
    then
        close_database()
        return false
    end

    tips_db:close()

    if not tips_db:open_read_only() then
        close_database()
        return false
    end

    tips.status = "done"
    return true
end

-- 按逻辑 key 查询并解析提示 value。
local function fetch_tip(key)
    local prefix = key .. RECORD_SEPARATOR
    local accessor = tips_db:query(prefix)
    if not accessor then return nil end

    local value

    for raw_key in accessor:iter() do
        if raw_key:sub(1, #prefix) ~= prefix then break end
        value = raw_key:sub(#prefix + 1)
        break
    end

    accessor = nil
    return value ~= "" and value or nil
end

-- 从编码或候选文本中查询提示。
local function get_tip(keys)
    if tips.status ~= "done" or not tips_db then return nil end
    if type(keys) == "string" then keys = {keys} end

    for _, key in ipairs(keys) do
        if key and key ~= "" then
            local value = fetch_tip(key)
            if value then return value end
        end
    end

    return nil
end

-- 更新候选提示。
local function update_tips_prompt(context, env)
    env.current_tip = nil

    if not context:get_option("super_tips") then return end
    if not context.input or context.input == "" or context.input:find("^›") then
        return
    end

    local segment = context.composition:back()
    if not segment then return end

    local candidate = context:get_selected_candidate() or {}

    if segment.selected_index < env.engine.schema.page_size then
        env.current_tip = get_tip({context.input, candidate.text})
    else
        env.current_tip = get_tip(candidate.text)
    end

    if env.current_tip then
        segment.prompt = "〔" .. env.current_tip .. "〕"
        env.last_prompt = segment.prompt
    elseif segment.prompt ~= "" and segment.prompt == env.last_prompt then
        segment.prompt = ""
        env.last_prompt = ""
    end
end

local P = {}

-- 初始化处理器和提示更新通知器。
function P.init(env)
    local config = env.engine.schema.config
    local ready = init_database(config)

    env.tips_key = config:get_string("super_tips/tips_key")
    env.last_prompt = env.last_prompt or ""

    if ready and not env.tips_db_attached then
        tips.ref_count = tips.ref_count + 1
        env.tips_db_attached = true
    end

    env.tips_update_connection =
        env.engine.context.update_notifier:connect(function(context)
            update_tips_prompt(context, env)
        end)
end

-- 断开通知器，并在最后一个实例退出时关闭数据库。
function P.fini(env)
    if env.tips_update_connection then
        env.tips_update_connection:disconnect()
        env.tips_update_connection = nil
    end

    env.current_tip = nil
    env.last_prompt = nil
    env.tips_key = nil

    if not env.tips_db_attached then return end

    env.tips_db_attached = nil
    tips.ref_count = math.max(0, tips.ref_count - 1)

    if tips.ref_count == 0 then close_database() end
end

-- 处理提示内容直接上屏。
function P.func(key, env)
    local context = env.engine.context

    if not context:get_option("super_tips")
        or not env.tips_key
        or env.tips_key ~= key:repr()
        or wanxiang.is_function_mode_active(context)
        or not env.current_tip
        or env.current_tip == ""
    then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local text = env.current_tip:match("：%s*(.*)%s*")
        or env.current_tip:match(":%s*(.*)%s*")

    if not text or text == "" then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    env.engine:commit_text(text)
    context:clear()
    return wanxiang.RIME_PROCESS_RESULTS.kAccepted
end

return P