-- 万象家族lua,超级提示,表情\化学式\方程式\简码等等直接上屏,不占用候选位置
-- 采用leveldb数据库,支持大数据遍历,支持多种类型混合,多种拼音编码混合,维护简单
-- 支持候选匹配和编码匹配两种，候选支持方向键高亮遍历
-- https://github.com/amzxyz/rime_wanxiang
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

-- 元数据 Key
local META_KEY = {
    version = "wanxiang_version",
    disabled_types = "disabled_types_fingerprint", -- 配置指纹
    files_sig = "files_signature",                 -- 文件特征码
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
    if tips.status ~= "pending" then return end

    -- 0. 获取自定义数据库名称并实例化，缺省为 "lua/tips"
    local db_name = config:get_string("super_tips/db_name")
    if not db_name or db_name == "" then
        db_name = "lua/tips"
    end
    tips_db = userdb.LevelDb(db_name)

    -- 1. 确保目录存在 (仅非特定发行版)
    local dist = rime_api.get_distribution_code_name() or ""
    if dist ~= "hamster" and dist ~= "hamster3" and dist ~= "Weasel" then
        local user_lua_dir = rime_api.get_user_data_dir() .. "/lua"
        tips.ensure_dir_exist(user_lua_dir .. "/data")
    end

    -- 2. 读取 disabled_types 配置
    local disabled_keys = {}
    local disabled_types_list = config:get_list("super_tips/disabled_types")
    if disabled_types_list then
        for i = 1, disabled_types_list.size do
            local item = disabled_types_list:get_value_at(i - 1)
            if item and #item.value > 0 then
                tips.disabled_types[item.value] = true
                table.insert(disabled_keys, item.value)
            end
        end
    end
    table.sort(disabled_keys)
    local current_disabled_fingerprint = table.concat(disabled_keys, "|")

    -- 3. 获取数据文件列表（支持 files 配置）
    local files = {}
    local files_list = config:get_list("super_tips/files")
    if files_list then
        -- 用户显式配置了文件列表
        for i = 0, files_list.size - 1 do
            local file_entry = files_list:get_value_at(i)
            if file_entry and file_entry.value ~= "" then
                local resolved = resolve_path(file_entry.value)
                if resolved then
                    table.insert(files, resolved)
                end
            end
        end
    end

    -- 如果没有配置 files，则使用默认文件
    if #files == 0 then
        files = { tips.default_preset, tips.default_user }
    end

    -- 生成当前文件签名（所有文件组合）
    local current_signature = generate_files_signature(files)

    -- 4. 打开数据库，检查是否需要重建
    tips_db:open()
    local needs_rebuild = false

    -- 检查全局版本号
    local db_ver = tips_db:meta_fetch(META_KEY.version)
    if db_ver ~= wanxiang.version then
        needs_rebuild = true
    end

    -- 检查配置指纹
    if not needs_rebuild then
        local db_fingerprint = tips_db:meta_fetch(META_KEY.disabled_types) or ""
        if db_fingerprint ~= current_disabled_fingerprint then
            needs_rebuild = true
        end
    end

    -- 检查文件签名
    if not needs_rebuild then
        local db_sig = tips_db:meta_fetch(META_KEY.files_sig) or ""
        if db_sig ~= current_signature then
            needs_rebuild = true
        end
    end

    -- 执行重建
    if needs_rebuild then
        -- 优雅清空，防止体积膨胀
        if tips_db.clear then tips_db:clear() elseif tips_db.empty then tips_db:empty() end
        tips.load_data_from_files(files)

        -- 更新元数据
        tips_db:meta_update(META_KEY.version, wanxiang.version)
        tips_db:meta_update(META_KEY.disabled_types, current_disabled_fingerprint)
        tips_db:meta_update(META_KEY.files_sig, current_signature)
    end

    -- 切换为只读模式 (查询更快)
    tips_db:close()
    tips_db:open_read_only()
    
    tips.status = "done"
end

---从数据库中查询 tips
function tips.get_tip(keys)
    if type(keys) == 'string' then keys = { keys } end
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

    if not context.input or context.input == "" then
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
