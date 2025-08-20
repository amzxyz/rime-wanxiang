-- 万象家族lua,超级提示,表情\化学式\方程式\简码等等直接上屏,不占用候选位置
-- 采用leveldb数据库,支持大数据遍历,支持多种类型混合,多种拼音编码混合,维护简单
-- 支持候选匹配和编码匹配两种，候选支持方向键高亮遍历
-- https://github.com/amzxyz/rime_wanxiang
--     - lua_processor@*super_tips
--     key_binder/tips_key: "slash" # 上屏按键配置
local wanxiang = require("wanxiang")
local bit = require("lib/bit")
local userdb = require("lib/userdb")

local tips_db = userdb.LevelDb("lua/tips")

-- 获取文件内容哈希值，使用 FNV-1a 哈希算法
local function calculate_file_hash(filepath)
    local file = io.open(filepath, "rb")
    if not file then return nil end

    -- FNV-1a 哈希参数（32位）
    local FNV_OFFSET_BASIS = 0x811C9DC5
    local FNV_PRIME = 0x01000193

    local hash = FNV_OFFSET_BASIS
    while true do
        local chunk = file:read(4096)
        if not chunk then break end
        for i = 1, #chunk do
            local byte = string.byte(chunk, i)
            hash = bit.bxor(hash, byte)
            hash = (hash * FNV_PRIME) % 0x100000000
            hash = bit.band(hash, 0xFFFFFFFF)
        end
    end

    file:close()
    return string.format("%08x", hash)
end

local tips = {}

tips.disabled_types = {}
tips.preset_file_path = wanxiang.get_filename_with_fallback("lua/tips/tips_show.txt")
tips.user_override_path = rime_api.get_user_data_dir() .. "/lua/tips/tips_user.txt"

function tips.empty_db()
    local da
    da = tips_db:query("")
    for key, _ in da:iter() do
        local is_meta_key = key:find(userdb.META_KEY_PREFIX, 1, true) == 1
        -- 仅更新非 meta fields
        if not is_meta_key then
            tips_db:erase(key)
        end
    end
    da = nil
end

function tips.has_wanxiang_version_updated()
    local meta_key = "user_tips_file_hash"
    local db_version = tips_db:meta_fetch(meta_key)
    local changed = db_version ~= wanxiang.version

    if changed then
        tips_db:meta_update(meta_key, wanxiang.version)
    end

    return changed
end

function tips.has_user_tips_file_updated()
    local meta_key = "user_tips_file_hash"
    local db_hash = tips_db:meta_fetch(meta_key)
    local file_hash = calculate_file_hash(tips.user_override_path) or ""
    local changed = file_hash ~= db_hash

    if changed then
        tips_db:meta_update(meta_key, file_hash)
    end

    return changed
end

function tips.has_disabled_types_updated()
    local meta_key = "disabled_types"
    local db_types = {}
    local value = tips_db:meta_fetch(meta_key)
    if value then
        for each in value:gmatch(",") do
            table.insert(db_types, each)
        end
    end

    local changed = not (Set(db_types) - Set(tips.disabled_types)):empty()

    if changed then
        tips_db:meta_update(meta_key, table.concat(tips.disabled_types, ","))
    end

    return changed
end

---@param tip string
function tips.is_disabled(tip)
    if #tips.disabled_types == 0 then
        return false
    end

    for _, type in ipairs(tips.disabled_types) do
        if tip:find(type .. ":", 1, true) == 1
            or tip:find(type .. "：", 1, true) == 1 then
            return true
        end
    end

    return false
end

function tips.init_db_from_file(path)
    local file = io.open(path, "r")
    if not file then return end

    for line in file:lines() do
        local value, key = line:match("([^\t]+)\t([^\t]+)")
        if key and value
            and not tips.is_disabled(value)
        then
            tips_db:update(key, value)
        end
    end

    file:close()
end

---@param config Config
function tips.init(config)
    local disabled_types_list = config:get_list("tips/disabled_types")

    if disabled_types_list then
        for i = 1, disabled_types_list.size do
            local item = disabled_types_list:get_value_at(i - 1)
            if item and #item.value > 0 then
                table.insert(tips.disabled_types, item.value)
            end
        end
    end

    tips_db:open()

    if tips.has_disabled_types_updated()
        or tips.has_wanxiang_version_updated()
        or tips.has_user_tips_file_updated()
    then
        tips.empty_db()
        tips.init_db_from_file(tips.preset_file_path)
        tips.init_db_from_file(tips.user_override_path)
    end

    tips_db:close()
    tips_db:open_read_only()
end

---@param ... string[] | string
---@return string | nil
function tips.get_tip(...)
    local key_input = ...
    if type(key_input) == 'string' then
        return tips_db:fetch(key_input)
    end

    for _, key in ipairs(key_input) do
        if key and key ~= "" then
            local tip = tips_db:fetch(key)
            if tip and #tip > 0 then
                return tip
            end
        end
    end

    return nil
end

---@class Env
---@field current_tip string | nil 当前 tips 值
---@field last_prompt string 最后一次设置的 prompt 值
---@field tips_update_connection any update notifier

---tips prompt 处理
---@param context Context
---@param env Env
local function update_tips_prompt(context, env)
    local segment = context.composition:back()
    if segment == nil then return end

    local cand = context:get_selected_candidate() or {}
    env.current_tip = segment.selected_index == 0
        and tips.get_tip({ context.input, cand.text })
        or tips.get_tip(cand.text)

    if env.current_tip ~= nil and env.current_tip ~= "" then
        -- 有 tips 则直接设置 prompt
        segment.prompt = "〔" .. env.current_tip .. "〕"
        env.last_prompt = segment.prompt
    elseif segment.prompt ~= "" and env.last_prompt == segment.prompt then
        -- 没有 tips，且当前 prompt 不为空，且是由 super_tips 设置的，则重置
        segment.prompt = ""
        env.last_prompt = segment.prompt
    end
end

local P = {}

local function ensure_dir_exist(dir)
    -- 获取系统路径分隔符
    local sep = package.config:sub(1, 1)

    dir = dir:gsub([["]], [[\"]]) -- 处理双引号

    if sep == "/" then
        local cmd = 'mkdir -p "' .. dir .. '" 2>/dev/null'
        os.execute(cmd)
    end
end

-- Processor：按键触发上屏 (S)
---@param env Env
function P.init(env)
    local dist = rime_api.get_distribution_code_name() or ""
    local user_lua_dir = rime_api.get_user_data_dir() .. "/lua"
    if dist ~= "hamster" and dist ~= "Weasel" then
        ensure_dir_exist(user_lua_dir)
        ensure_dir_exist(user_lua_dir .. "/tips")
    end

    local config = env.engine.schema.config

    tips.init(config)

    P.tips_key = config:get_string("key_binder/tips_key")

    -- 注册 tips 查找监听器
    local context = env.engine.context
    env.tips_update_connection = context.update_notifier:connect(
        function(context)
            local is_tips_enabled = context:get_option("super_tips")
            if is_tips_enabled == true then
                update_tips_prompt(context, env)
            end
        end
    )
end

function P.fini(env)
    tips_db:close()
    -- 清理连接
    if env.tips_update_connection then
        env.tips_update_connection:disconnect()
        env.tips_update_connection = nil
    end
end

---@param key KeyEvent
---@param env Env
---@return ProcessResult
function P.func(key, env)
    local context = env.engine.context

    local is_tips_enabled = context:get_option("super_tips")
    local segment = context.composition:back()
    if not is_tips_enabled or not segment then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    -- 如果启用了 tips 功能，则应使用此 workaround
    -- rime 内核在移动候选时并不会触发 update_notifier，这里做一个临时修复
    -- 如果是 paging，则主动调用 update_tips_prompt
    if segment:has_tag("paging") then
        update_tips_prompt(context, env)
    end

    -- 以下处理 tips 上屏逻辑
    if not P.tips_key                                   -- 未设置上屏键
        or P.tips_key ~= key:repr()                     -- 或者当前按下的不是上屏键
        or wanxiang.is_function_mode_active(context)    -- 或者是功能模式不用上屏
        or not env.current_tip or env.current_tip == "" --  或匹配的 tips 为空/空字符串
    then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    ---@type string 从 tips 内容中获取上屏文本
    local commit_txt = env.current_tip:match("：%s*(.*)%s*") -- 优先匹配常规的全角冒号
        or env.current_tip:match(":%s*(.*)%s*") -- 没有匹配则回落到半角冒号

    if commit_txt and #commit_txt > 0 then
        env.engine:commit_text(commit_txt)
        context:clear()
        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end

    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end

return P
