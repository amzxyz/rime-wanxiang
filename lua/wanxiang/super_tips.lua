-- 万象家族 Lua：超级提示、表情、化学式、方程式、简码等直接上屏，不占用候选位置
-- 采用 UserDb 存储数据，支持候选文本和输入编码匹配
-- https://github.com/amzxyz/rime-wanxiang
--
-- super_tips:
--   db_name: "tips"
--   tips_key: "slash"
--   disabled_types: []
--   files:
--     - lua/data/tips_show.txt

local wanxiang = require("wanxiang/wanxiang")
local userdb = require("wanxiang/userdb")

local USER_DATA_DIR = rime_api.get_user_data_dir() or "."
local SHARED_DATA_DIR = rime_api.get_shared_data_dir() or "."

local DB_FORMAT_VERSION = "7"
local META_VERSION = "db_format_version"
local META_DISABLED = "disabled_types_fingerprint"
local META_SIGNATURE = "files_signature"

local tips_db
local tips = {
    status = "pending",
    ref_count = 0,
    disabled_types = {},
    default_preset = wanxiang.get_filename_with_fallback("lua/data/tips_show.txt"),
    default_user = USER_DATA_DIR .. "/lua/data/tips_user.txt",
}

local function db_call(method, ...)
    if not tips_db then return false end

    local fn = tips_db[method]
    if type(fn) ~= "function" then return false end

    local ok, result1, result2, result3 = pcall(fn, tips_db, ...)
    if not ok then return false end
    return true, result1, result2, result3
end

local function file_exists(path)
    if not path or path == "" then return false end

    local file = io.open(path, "rb")
    if not file then return false end

    file:close()
    return true
end

local function resolve_path(path)
    if not path or path == "" then return nil end

    if path:sub(1, 1) == "/"
        or path:sub(1, 1) == "\\"
        or path:match("^[a-zA-Z]:[\\/]")
    then
        return file_exists(path) and path or nil
    end

    local user_path = USER_DATA_DIR .. "/" .. path
    if file_exists(user_path) then return user_path end

    local shared_path = SHARED_DATA_DIR .. "/" .. path
    if file_exists(shared_path) then return shared_path end

    return nil
end

local function bytes_to_hex(data)
    local parts = {}

    for i = 1, #data do
        parts[i] = string.format("%02x", data:byte(i))
    end

    return table.concat(parts)
end

local function generate_files_signature(files)
    local signatures = {}

    for _, path in ipairs(files) do
        local file = io.open(path, "rb")

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

            file:close()

            signatures[#signatures + 1] = table.concat({
                path,
                tostring(size),
                bytes_to_hex(head),
                bytes_to_hex(middle),
                bytes_to_hex(tail),
            }, "|")
        end
    end

    return table.concat(signatures, "||")
end

local function load_disabled_types(config)
    tips.disabled_types = {}

    local keys = {}
    local list = config:get_list("super_tips/disabled_types")

    if list then
        for i = 0, list.size - 1 do
            local item = list:get_value_at(i)
            local value = item and item.value

            if value and value ~= "" then
                tips.disabled_types[value] = true
                keys[#keys + 1] = value
            end
        end
    end

    table.sort(keys)
    return table.concat(keys, "|")
end

local function load_data_files(config)
    local files = {}
    local list = config:get_list("super_tips/files")

    if list then
        for i = 0, list.size - 1 do
            local item = list:get_value_at(i)
            local path = resolve_path(item and item.value)

            if path then files[#files + 1] = path end
        end
    end

    if #files == 0 then
        if file_exists(tips.default_preset) then
            files[#files + 1] = tips.default_preset
        end

        if file_exists(tips.default_user) then
            files[#files + 1] = tips.default_user
        end
    end

    return files
end

local function is_disabled(value)
    local tip_type = value:match("^(..-):") or value:match("^(..-)：")
    return tip_type and tips.disabled_types[tip_type] == true or false
end

local function close_database()
    if tips_db then
        db_call("close")
        tips_db = nil
    end

    tips.status = "pending"
end

local function rebuild_database(files, disabled_fingerprint, signature)
    local ok, opened = db_call("open")
    if not ok or not opened then return false end

    -- import_files() 使用批量直接写入，因此重建前必须先清空数据库。
    if not db_call("empty", true) then return false end

    local import_ok, _, _, failed = db_call("import_files", files, function(_, value)
        return not is_disabled(value)
    end)

    if not import_ok or (failed or 0) > 0 then return false end

    local ok_version, version_updated =
        db_call("meta_update", META_VERSION, DB_FORMAT_VERSION)
    local ok_disabled, disabled_updated =
        db_call("meta_update", META_DISABLED, disabled_fingerprint)
    local ok_signature, signature_updated =
        db_call("meta_update", META_SIGNATURE, signature)

    if not ok_version or not version_updated
        or not ok_disabled or not disabled_updated
        or not ok_signature or not signature_updated
    then
        return false
    end

    db_call("close")

    local reopen_ok, reopened = db_call("open_read_only")
    return reopen_ok and reopened == true
end

local function init_database(config)
    if tips.status == "done" then return true end
    if tips.status == "initialing" then return false end

    tips.status = "initialing"

    local db_name = config:get_string("super_tips/db_name")
    if not db_name or db_name == "" then db_name = "tips" end

    local ok, db = pcall(userdb.LevelDb, db_name)
    if not ok or not db then
        tips.status = "pending"
        return false
    end

    tips_db = db

    local disabled_fingerprint = load_disabled_types(config)
    local files = load_data_files(config)
    local signature = generate_files_signature(files)

    local open_ok, opened = db_call("open_read_only")

    if open_ok and opened then
        local _, db_version = db_call("meta_fetch", META_VERSION)
        local _, db_disabled = db_call("meta_fetch", META_DISABLED)
        local _, db_signature = db_call("meta_fetch", META_SIGNATURE)

        local unchanged = db_version == DB_FORMAT_VERSION
            and db_disabled == disabled_fingerprint
            and db_signature == signature

        if unchanged then
            tips.status = "done"
            return true
        end

        db_call("close")
    end

    if not rebuild_database(files, disabled_fingerprint, signature) then
        close_database()
        return false
    end

    tips.status = "done"
    return true
end

local function get_tip(keys)
    if tips.status ~= "done" or not tips_db then return nil end
    if type(keys) == "string" then keys = { keys } end

    for _, key in ipairs(keys) do
        if key and key ~= "" then
            local ok, value = db_call("fetch", key)
            if ok and value and value ~= "" then return value end
        end
    end

    return nil
end

local function update_prompt(context, env)
    env.current_tip = nil

    if not context:get_option("super_tips") then return end
    if not context.input or context.input == "" or context.input:find("^›") then return end

    local segment = context.composition:back()
    if not segment then return end

    local candidate = context:get_selected_candidate() or {}
    local page_size = env.engine.schema.page_size

    if segment.selected_index < page_size then
        env.current_tip = get_tip({ context.input, candidate.text })
    else
        env.current_tip = get_tip(candidate.text)
    end

    if env.current_tip and env.current_tip ~= "" then
        segment.prompt = "〔" .. env.current_tip .. "〕"
        env.last_prompt = segment.prompt
    elseif segment.prompt ~= "" and segment.prompt == env.last_prompt then
        segment.prompt = ""
        env.last_prompt = ""
    end
end

local P = {}

function P.init(env)
    local config = env.engine.schema.config
    local ready = init_database(config)

    env.tips_key = config:get_string("super_tips/tips_key")
    env.last_prompt = env.last_prompt or ""

    if ready and not env.tips_db_attached then
        tips.ref_count = tips.ref_count + 1
        env.tips_db_attached = true
    end

    local ok, connection = pcall(function()
        return env.engine.context.update_notifier:connect(function(context)
            update_prompt(context, env)
        end)
    end)

    if ok then env.tips_update_connection = connection end
end

function P.fini(env)
    if env.tips_update_connection then
        pcall(function()
            env.tips_update_connection:disconnect()
        end)

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