-- 万象家族lua,超级提示,表情\化学式\方程式\简码等等直接上屏,不占用候选位置
-- 采用leveldb数据库,支持大数据遍历,支持多种类型混合,多种拼音编码混合,维护简单
-- 支持候选匹配和编码匹配两种，候选支持方向键高亮遍历
-- https://github.com/amzxyz/rime-wanxiang
-- 配置示例：
-- super_tips:
--   db_name: "lua/tips"   # 可选，自定义数据库名称/路径，默认值为 "lua/tips"
--   tips_key: "slash"     # 上屏按键配置
--   disabled_types: []    # 禁用的 tips 类型
--   files:                # 可选，自定义数据文件列表，不配置时使用默认文件
--     - lua/data/my_tips.txt
--     - lua/data/tips_show.txt

local wanxiang = require("wanxiang/wanxiang")
local userdb = require("wanxiang/userdb")

-- 声明数据库变量，待配置加载后初始化
local tips_db 

local tips = {}

---@type "pending" | "initialing" | "done"
tips.status = "pending"

---@type table<string, boolean>
tips.disabled_types = {}

-- 默认文件路径（在未配置 files 时使用）
tips.default_preset = wanxiang.get_filename_with_fallback("lua/data/tips_show.txt")
tips.default_user = rime_api.get_user_data_dir() .. "/lua/data/tips_user.txt"

-- 路径解析：优先用户目录，其次共享目录
local function resolve_path(relative)
    if not relative then return nil end
    local user_path = rime_api.get_user_data_dir() .. "/" .. relative
    local f = io.open(user_path, "r")
    if f then f:close(); return user_path end
    local shared_path = rime_api.get_shared_data_dir() .. "/" .. relative
    f = io.open(shared_path, "r")
    if f then f:close(); return shared_path end
    return user_path  -- 即使不存在也返回用户路径，避免后续操作失败
end

-- 光速文件特征采样（支持多个文件）
local function generate_files_signature(paths)
    local sig_parts = {}
    for _, path in ipairs(paths) do
        local f = io.open(path, "rb")
        if f then
            local size = f:seek("end")
            local head, mid, tail = "", "", ""
            if size > 0 then
                f:seek("set", 0)
                head = f:read(64) or ""
                local tail_pos = size - 64
                if tail_pos < 0 then tail_pos = 0 end
                f:seek("set", tail_pos)
                tail = f:read(64) or ""
                f:seek("set", math.floor(size / 2))
                mid = f:read(64) or ""
            end
            f:close()
            table.insert(sig_parts, size .. head .. mid .. tail)
        end
    end
    return table.concat(sig_parts, "||")
end

-- 仅在数据库结构或解析格式变化时递增，不能使用万象整体版本号。
local DB_FORMAT_VERSION = "1"

local META_KEY = {
    version = "db_format_version",
    disabled_types = "disabled_types_fingerprint",
    files_sig = "files_signature",
}

---判断某个类型是否被禁用
---@param tip string
function tips.is_disabled(tip)
    local type = tip:match("^(..-):") or tip:match("^(..-)：")
    if not type then return false end
    return tips.disabled_types[type] == true
end

---从文件加载数据到 DB（通用）
function tips.load_data_from_files(files)
    for _, file_path in ipairs(files) do
        local file = io.open(file_path, "r")
        if not file then
            -- 文件不存在，静默跳过
            goto continue
        end
        for line in file:lines() do
            -- 格式：值 [tab] 键
            local value, key = line:match("([^\t]+)\t([^\t]+)")
            if key and value and not tips.is_disabled(value) then
                tips_db:update(key, value)
            end
        end
        file:close()
        ::continue::
    end
end

function tips.ensure_dir_exist(dir)
    local sep = package.config:sub(1, 1)
    dir = dir:gsub([["]], [[\"]]) -- 处理双引号
    if sep == "/" then
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    end
end

---初始化核心逻辑
---@param config Config
function tips.init(config)
    if tips.status == "done" then return true end
    if tips.status == "initialing" then return false end
    tips.status = "initialing"

    -- 暂时保留：部分打包程序在用户目录尚无数据库时，不能主动创建 lua/data。
    -- 上游支持完善后再移除这层兼容。
    local dist = rime_api.get_distribution_code_name() or ""
    if dist ~= "hamster" and dist ~= "hamster3" and dist ~= "Weasel" then
        local user_lua_dir = rime_api.get_user_data_dir() .. "/lua"
        tips.ensure_dir_exist(user_lua_dir .. "/data")
    end

    local db_name = config:get_string("super_tips/db_name")
    if not db_name or db_name == "" then db_name = "lua/tips" end
    tips_db = userdb.LevelDb(db_name)
    if not tips_db then
        tips.status = "pending"
        return false
    end

    -- 每次真正初始化时重建配置状态，避免失败重试后残留旧类型。
    tips.disabled_types = {}
    local disabled_keys = {}
    local disabled_types_list = config:get_list("super_tips/disabled_types")
    if disabled_types_list then
        for i = 0, disabled_types_list.size - 1 do
            local item = disabled_types_list:get_value_at(i)
            local value = item and item.value
            if value and value ~= "" then
                tips.disabled_types[value] = true
                disabled_keys[#disabled_keys + 1] = value
            end
        end
    end
    table.sort(disabled_keys)
    local current_disabled_fingerprint = table.concat(disabled_keys, "|")

    local files = {}
    local files_list = config:get_list("super_tips/files")
    if files_list then
        for i = 0, files_list.size - 1 do
            local entry = files_list:get_value_at(i)
            if entry and entry.value ~= "" then
                local resolved = resolve_path(entry.value)
                if resolved then files[#files + 1] = resolved end
            end
        end
    end
    if #files == 0 then files = { tips.default_preset, tips.default_user } end

    local current_signature = generate_files_signature(files)
    local needs_rebuild = true

    -- 稳定路径只读打开一次；元数据一致时直接保留句柄，不再读写打开后又关闭重开。
    if tips_db:open_read_only() then
        local db_ver = tips_db:meta_fetch(META_KEY.version) or ""
        local db_disabled = tips_db:meta_fetch(META_KEY.disabled_types) or ""
        local db_signature = tips_db:meta_fetch(META_KEY.files_sig) or ""

        needs_rebuild = db_ver ~= DB_FORMAT_VERSION
            or db_disabled ~= current_disabled_fingerprint
            or db_signature ~= current_signature

        if not needs_rebuild then
            tips.status = "done"
            return true
        end
        tips_db:close()
    end

    -- 只有数据库不存在或数据确实变化时，才进入读写模式并重建。
    if not tips_db:open() then
        tips.status = "pending"
        return false
    end

    if tips_db.clear then tips_db:clear() elseif tips_db.empty then tips_db:empty() end
    tips.load_data_from_files(files)
    tips_db:meta_update(META_KEY.version, DB_FORMAT_VERSION)
    tips_db:meta_update(META_KEY.disabled_types, current_disabled_fingerprint)
    tips_db:meta_update(META_KEY.files_sig, current_signature)
    tips_db:close()

    if not tips_db:open_read_only() then
        tips.status = "pending"
        return false
    end

    tips.status = "done"
    return true
end

---从数据库中查询 tips
function tips.get_tip(keys)
    if tips.status ~= "done" or not tips_db then return nil end
    if type(keys) == "string" then keys = { keys } end
    for _, key in ipairs(keys) do
        if key and key ~= "" then
            local tip = tips_db:fetch(key)
            if tip and #tip > 0 then return tip end
        end
    end
    return nil
end

---@class Env
---@field current_tip string | nil
---@field last_prompt string
---@field tips_update_connection Connection

---tips prompt 处理
local function update_tips_prompt(context, env)
    env.current_tip = nil
    
    if not context:get_option("super_tips") then return end

    if not context.input or context.input == "" or string.find(context.input, "^›") then
        return 
    end

    local segment = context.composition:back()
    if not segment then return end

    local cand = context:get_selected_candidate() or {}

    local page_size = env.engine.schema.page_size
    -- 只要在第一页，都支持编码匹配，且翻页后失效
    if segment.selected_index < page_size then
        -- 在第一页：同时尝试匹配 [编码] 和 [候选词]
        env.current_tip = tips.get_tip({ context.input, cand.text })
    else
        -- 翻页后只匹配 [候选词]
        env.current_tip = tips.get_tip(cand.text)
    end

    if env.current_tip and env.current_tip ~= "" then
        segment.prompt = "〔" .. env.current_tip .. "〕"
        env.last_prompt = segment.prompt
    elseif segment.prompt ~= "" and env.last_prompt == segment.prompt then
        segment.prompt = ""
        env.last_prompt = segment.prompt
    end
end

local P = {}

function P.init(env)
    local config = env.engine.schema.config
    tips.init(config)
    P.tips_key = config:get_string("super_tips/tips_key")
    local context = env.engine.context
    env.tips_update_connection = context.update_notifier:connect(function(ctx)
        update_tips_prompt(ctx, env)
    end)
end

function P.fini(env)
    if env.tips_update_connection then
        env.tips_update_connection:disconnect()
        env.tips_update_connection = nil
    end
end

function P.func(key, env)
    local context = env.engine.context
    local is_tips_enabled = context:get_option("super_tips")
    if not is_tips_enabled then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    if not P.tips_key 
        or P.tips_key ~= key:repr() 
        or wanxiang.is_function_mode_active(context)
        or not env.current_tip 
        or env.current_tip == "" 
    then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    -- 提取上屏文本 (支持全角/半角冒号)
    local commit_txt = env.current_tip:match("：%s*(.*)%s*") 
        or env.current_tip:match(":%s*(.*)%s*")
    
    if commit_txt and #commit_txt > 0 then
        env.engine:commit_text(commit_txt)
        context:clear()
        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end
    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end

return P