-- 万象家族 Lua：超级提示、表情、化学式、方程式、简码等直接上屏，不占用候选位置
-- 采用 LevelDb 数据库，支持大数据遍历、多种类型及编码混合
-- 支持候选匹配和编码匹配，候选支持方向键高亮遍历
-- https://github.com/amzxyz/rime-wanxiang
--
-- super_tips:
--   db_name: "tips"
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

local DEFAULT_PRESET = "lua/data/tips_show.txt"
local DEFAULT_USER = "lua/data/tips_user.txt"
local db_states = {}

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
local function is_disabled(value, disabled_types)
    local tip_type = value:match("^(..-):") or value:match("^(..-)：")
    return tip_type and disabled_types[tip_type] == true or false
end

-- 从文件逐行加载提示；数据文件应自行保证 key 唯一。
local function load_data_from_files(files, db, disabled_types)
    for _, file_path in ipairs(files) do
        local file, close = wanxiang.load_file_with_fallback(file_path, "r")

        if file then
            for line in file:lines() do
                local current_line = line:gsub("\r$", "")
                local value, key =
                    current_line:match("^([^\t]+)\t([^\t]+)$")

                if key and value and not is_disabled(value, disabled_types) then
                    local raw_key = key .. RECORD_SEPARATOR .. value

                    if not db:update(
                        raw_key, DEFAULT_RECORD_TAIL
                    ) then
                        close()
                        return false
                    end
                end
            end

            close()
        end
    end

    return true
end

-- 关闭数据库包装器；共享池只保存成功打开的实例。
local function close_database(db)
    if not db then return end
    collectgarbage()
    if db:loaded() then db:close() end
end

-- 初始化或复用按 db_name 隔离的模块私有数据库。
local function init_database(config)
    local db_name = config:get_string("super_tips/db_name")
    if not db_name or db_name == "" then db_name = "tips" end

    local state = db_states[db_name]
    if state then
        state.refs = state.refs + 1
        return state.db, db_name
    end

    local disabled_types = {}
    local disabled_keys = {}
    local disabled_list = config:get_list("super_tips/disabled_types")

    if disabled_list then
        for i = 0, disabled_list.size - 1 do
            local item = disabled_list:get_value_at(i)
            local value = item and item.value

            if value and value ~= "" then
                disabled_types[value] = true
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

    if #files == 0 then files = {DEFAULT_PRESET, DEFAULT_USER} end

    local db = userdb.LevelDb(db_name)
    if not db then return nil end

    local signature = generate_files_signature(files)
    local needs_rebuild = true

    -- 稳定路径只读打开一次，元数据一致时直接保留句柄。
    if db:open_read_only() then
        local db_version = db:meta_fetch(META_KEY.version) or ""
        local db_disabled = db:meta_fetch(META_KEY.disabled_types) or ""
        local db_signature = db:meta_fetch(META_KEY.files_sig) or ""

        needs_rebuild = db_version ~= DB_FORMAT_VERSION
            or db_disabled ~= disabled_fingerprint
            or db_signature ~= signature

        if not needs_rebuild then
            db_states[db_name] = {db = db, refs = 1}
            return db, db_name
        end

        db:close()
    end

    -- 仅在数据库不存在或数据变化时进入读写模式。
    if not db:open() then
        close_database(db)
        return nil
    end

    local cleared
    if db.clear then
        cleared = db:clear()
    else
        cleared = db:empty(true)
    end

    if cleared == false
        or not load_data_from_files(files, db, disabled_types)
        or not db:meta_update(META_KEY.version, DB_FORMAT_VERSION)
        or not db:meta_update(
            META_KEY.disabled_types, disabled_fingerprint
        )
        or not db:meta_update(META_KEY.files_sig, signature)
    then
        close_database(db)
        return nil
    end

    db:close()

    if not db:open_read_only() then
        close_database(db)
        return nil
    end

    collectgarbage("collect")
    db_states[db_name] = {db = db, refs = 1}
    return db, db_name
end

-- 释放当前组件引用，并在最后一个使用者退出时关闭数据库。
local function release_database(env)
    local db_name = env.tips_db_name

    env.tips_db = nil
    env.tips_db_name = nil

    local state = db_name and db_states[db_name]
    if not state then return end

    state.refs = state.refs - 1
    if state.refs > 0 then return end

    db_states[db_name] = nil
    close_database(state.db)
end

-- 按逻辑 key 查询并解析提示 value。
local function fetch_tip(db, key)
    local prefix = key .. RECORD_SEPARATOR
    local accessor = db:query(prefix)
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
local function get_tip(env, keys)
    local db = env.tips_db
    if not db then return nil end
    if type(keys) == "string" then keys = {keys} end

    for _, key in ipairs(keys) do
        if key and key ~= "" then
            local value = fetch_tip(db, key)
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
        env.current_tip = get_tip(env, {context.input, candidate.text})
    else
        env.current_tip = get_tip(env, candidate.text)
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

-- 初始化处理器、共享数据库引用和提示更新通知器。
function P.init(env)
    if env.tips_update_connection then
        env.tips_update_connection:disconnect()
        env.tips_update_connection = nil
    end

    release_database(env)

    local config = env.engine.schema.config
    env.tips_db, env.tips_db_name = init_database(config)
    env.tips_key = config:get_string("super_tips/tips_key")
    env.last_prompt = env.last_prompt or ""

    env.tips_update_connection =
        env.engine.context.update_notifier:connect(function(context)
            update_tips_prompt(context, env)
        end)
end

-- 断开通知器，并在最后一个同名数据库使用者退出时关闭数据库。
function P.fini(env)
    if env.tips_update_connection then
        env.tips_update_connection:disconnect()
        env.tips_update_connection = nil
    end

    env.current_tip = nil
    env.last_prompt = nil
    env.tips_key = nil

    release_database(env)
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