-- 欢迎使用万象拼音方案（quick_symbol_text）
-- @amzxyz
-- https://github.com/amzxyz/rime_wanxiang
-- 触发：由 schema.yaml -> quick_symbol_text/trigger 加载（默认 ^([a-z])/$ ）
-- a/、b/ ... 单字母触发预设编码自动上屏；值可设为 "repeat" 实现重复上屏上一条提交内容
-- custom>schema>lua 合并键值（仅合并单字母 a-z 键）

local wanxiang = require("wanxiang")

-- 读取 symkey
local function load_mapping_from_config(config)
    local symbol_map = {}
    local ok_map, map = pcall(function() return config:get_map("quick_symbol_text/symkey") end)
    if not ok_map or not map then return symbol_map end
    local ok_keys, keys = pcall(function() return map:keys() end)
    if not ok_keys or not keys then return symbol_map end
    for _, key in ipairs(keys) do
        local v = config:get_string("quick_symbol_text/symkey/" .. key)
        if v ~= nil then
        symbol_map[string.lower(tostring(key))] = v
        end
    end
    return symbol_map
end

-- 读取 trigger
local function load_trigger_from_config(config)
    local default_pat = "^([a-z])/$"
    if not config then return default_pat end
    local ok, s = pcall(function() return config:get_string("quick_symbol_text/trigger") end)
    if ok and type(s) == "string" and #s > 0 then return s end
    return default_pat
end

-- 默认单字母映射
local default_mapping = {
    q = "：",
    w = "？",
    e = "（",
    r = "）",
    t = "~",
    y = "·",
    u = "『",
    i = "』",
    o = "〖",
    p = "〗",
    a = "！",
    s = "……",
    d = "、",
    f = "“",
    g = "”",
    h = "‘",
    j = "’",
    k = "【",
    l = "】",
    z = "。",
    x = "？",
    c = "！",
    v = "——",
    b = "%",
    n = "《",
    m = "》",
}

local function init(env)
    local config = env.engine.schema.config
    env.single_symbol_pattern = load_trigger_from_config(config)

    -- 默认表
    env.mapping = {}
    for k, v in pairs(default_mapping) do
        if #k == 1 and k:match("^[a-z]$") then env.mapping[k] = v end
    end
    -- 覆盖（仅单字母）
    local custom = load_mapping_from_config(config)
    for k, v in pairs(custom) do
        local key = tostring(k):lower()
        if #key == 1 and key:match("^[a-z]$") then
        env.mapping[key] = v  -- ""=禁用；"repeat"=特殊语义
        end
    end

    env.last_commit_text = "欢迎使用万象拼音！"

    -- 记录上屏文本（供 repeat）
    env.quick_symbol_text_commit_notifier =
        env.engine.context.commit_notifier:connect(function(ctx)
        local t = ctx:get_commit_text()
        if t ~= "" then env.last_commit_text = t end
        end)

    -- 命中触发则上屏并清空
    env.quick_symbol_text_update_notifier =
        env.engine.context.update_notifier:connect(function(context)
        local input = context.input or ""
        local key = string.match(input, env.single_symbol_pattern)
        if not key then return end
        key = string.lower(key)
        local symbol = env.mapping[key]
        if symbol == nil or symbol == "" then return end           -- 未配置/禁用
        if type(symbol) == "string" and symbol:lower() == "repeat" then
            if env.last_commit_text ~= "" then
            env.engine:commit_text(env.last_commit_text)
            context:clear()
            end
        else
            env.engine:commit_text(symbol)
            context:clear()
        end
    end)
end

local function fini(env)
    if env.quick_symbol_text_commit_notifier then
        env.quick_symbol_text_commit_notifier:disconnect()
        env.quick_symbol_text_commit_notifier = nil
    end
    if env.quick_symbol_text_update_notifier then
        env.quick_symbol_text_update_notifier:disconnect()
        env.quick_symbol_text_update_notifier = nil
    end
end

-- 命中时吃键，避免后续流程处理
local function processor(key_event, env)
    local input = env.engine.context.input or ""
    local key = string.match(input, env.single_symbol_pattern)
    if key then
        key = string.lower(key)
        local symbol = env.mapping[key]
        if symbol ~= nil and symbol ~= "" then
        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
        end
    end
    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end
return { init = init, fini = fini, func = processor }