-- 万象家族lua,超级提示,表情\化学式\方程式\简码等等直接上屏,不占用候选位置
-- 采用leveldb数据库,支持大数据遍历,支持多种类型混合,多种拼音编码混合,维护简单
-- 支持候选匹配和编码匹配两种，候选支持方向键高亮遍历
-- https://github.com/amzxyz/rime_wanxiang
--     - lua_processor@*super_tips
--     key_binder/tips_key: "slash" # 上屏按键配置
--     tips/disabled_types: [] # 禁用的 tips 类型

local wanxiang = require("wanxiang")
local userdb = require("lib/userdb")

-- 尝试打开数据库
local tips_db = userdb.LevelDb("lua/tips")

local tips = {}

---@type "pending" | "initialing" | "done"
tips.status = "pending"

---@type table<string, boolean>
tips.disabled_types = {}
tips.preset_file_path = wanxiang.get_filename_with_fallback("lua/data/tips_show.txt")
tips.user_override_path = rime_api.get_user_data_dir() .. "/lua/data/tips_user.txt"

-- 元数据 Key
local META_KEY = {
    version = "wanxiang_version",
    disabled_types = "disabled_types_fingerprint", -- 改名：配置指纹
}

---判断某个类型是否被禁用
---@param tip string
function tips.is_disabled(tip)
    local type = tip:match("^(..-):") or tip:match("^(..-)：")
    if not type then return false end
    return tips.disabled_types[type] == true
end

---从文件加载数据到 DB
function tips.init_db_from_file(path)
    local file = io.open(path, "r")
    if not file then return end

    for line in file:lines() do
        -- 格式：值 [tab] 键
        local value, key = line:match("([^\t]+)\t([^\t]+)")
        if key and value and not tips.is_disabled(value) then
            tips_db:update(key, value)
        end
    end
    file:close()
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

    -- 1. 确保目录存在 (仅非特定发行版)
    local dist = rime_api.get_distribution_code_name() or ""
    if dist ~= "hamster" and dist ~= "hamster3" and dist ~= "Weasel" then
        local user_lua_dir = rime_api.get_user_data_dir() .. "/lua"
        tips.ensure_dir_exist(user_lua_dir .. "/data")
    end

    -- 2. 读取 disabled_types 配置
    -- 这是轻量级操作，必须每次读取以生成指纹
    local disabled_keys = {}
    local disabled_types_list = config:get_list("tips/disabled_types")
    if disabled_types_list then
        for i = 1, disabled_types_list.size do
            local item = disabled_types_list:get_value_at(i - 1)
            if item and #item.value > 0 then
                tips.disabled_types[item.value] = true
                table.insert(disabled_keys, item.value)
            end
        end
    end
    table.sort(disabled_keys) -- 排序，确保指纹唯一
    local current_disabled_fingerprint = table.concat(disabled_keys, "|")

    -- 3. 检查是否需要重建
    tips_db:open()
    local needs_rebuild = false

    -- A. 检查全局版本号
    local db_ver = tips_db:meta_fetch(META_KEY.version)
    if db_ver ~= wanxiang.version then
        needs_rebuild = true
    end

    -- B. 检查配置指纹 (如果版本号没变，但用户修改了禁用类型，也需要重建以清洗数据)
    if not needs_rebuild then
        local db_fingerprint = tips_db:meta_fetch(META_KEY.disabled_types) or ""
        if db_fingerprint ~= current_disabled_fingerprint then
            needs_rebuild = true
        end
    end

    -- 4. 执行重建
    if needs_rebuild then
        tips_db:empty()
        tips.init_db_from_file(tips.preset_file_path)
        tips.init_db_from_file(tips.user_override_path)

        -- 更新元数据
        tips_db:meta_update(META_KEY.version, wanxiang.version)
        tips_db:meta_update(META_KEY.disabled_types, current_disabled_fingerprint)
    end

    -- 5. 切换为只读模式 (查询更快)
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

    local segment = context.composition:back()
    if not segment then return end

    local cand = context:get_selected_candidate() or {}
    
    if segment.selected_index == 0 then
        env.current_tip = tips.get_tip({ context.input, cand.text })
    else
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

    P.tips_key = config:get_string("key_binder/tips_key")

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