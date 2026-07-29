-- 万象 UserDb 公共封装
--
-- 外部接口保持不变：
--
--   db:update(key, value, tail)
--   local value, tail = db:fetch(key)
--
-- 只在调用底层 UserDb 前后转换数据：
--
--   raw key   = key .. " \t" .. value
--   raw value = c/d/t

local META_PREFIX = "\001/"
local RECORD_SEPARATOR = " \t"
local DEFAULT_TAIL = "c=0 d=0 t=0"

local db_pool = setmetatable({}, { __mode = "v" })
local methods = {}
local accessor_methods = {}

local userdb = {
    RECORD_KEY_SEPARATOR = RECORD_SEPARATOR,
    FILE_KEY_SEPARATOR = RECORD_SEPARATOR,
    FIELD_SEPARATOR = "\t",
    DEFAULT_RECORD_TAIL = DEFAULT_TAIL,
}

-- 判断字符串是否为合法的 c/d/t 记录尾部。
function userdb.is_record_tail(tail)
    return type(tail) == "string" and tail:match("^c=[^%s\t]+%s+d=[^%s\t]+%s+t=[^%s\t]+$") ~= nil
end

-- 生成标准的 c/d/t 记录尾部。
function userdb.make_record_tail(c, d, t)
    return "c=" .. tostring(c or 0) .. " d=" .. tostring(d or 0) .. " t=" .. tostring(t or 0)
end

-- 规范并校验记录尾部，缺省时返回默认尾部。
local function normalize_tail(tail)
    if tail == nil or tail == "" then
        return DEFAULT_TAIL
    end

    tail = tostring(tail):match("^%s*(.-)%s*$")
    return userdb.is_record_tail(tail) and tail or nil
end

-- 拆分 value 中可能内嵌的尾部并返回规范化结果。
local function normalize_value(value, tail)
    if value == nil then
        return nil, nil
    end

    value = tostring(value)

    local plain, embedded = value:match("^(.*)\t(c=[^%s\t]+%s+d=[^%s\t]+%s+t=[^%s\t]+)$")

    if plain then
        value = plain
        if tail == nil or tail == "" then
            tail = embedded
        end
    end

    if value == "" then
        return nil, nil
    end

    tail = normalize_tail(tail)
    if not tail then
        return nil, nil
    end

    return value, tail
end

-- 使用逻辑 key 和 value 生成完整 raw key。
function userdb.make_record_key(key, value)
    if key == nil or value == nil then
        return nil
    end

    key, value = tostring(key), tostring(value)
    if key == "" or value == "" then
        return nil
    end

    return key .. RECORD_SEPARATOR .. value
end

-- 从完整 raw key 中解析逻辑 key 和 value。
function userdb.parse_record_key(raw_key)
    if type(raw_key) ~= "string" then
        return nil, nil
    end

    local key, value = raw_key:match("^(.-) \t(.*)$")
    if not key or key == "" or not value or value == "" then
        return nil, nil
    end

    return key, value
end

-- 解析源文件行或 Rime UserDb 导出行。
--
-- 支持：
--   value<Tab>key
--   key<Space><Tab>value
--   key<Space><Tab>value<Tab>c=... d=... t=...
function userdb.parse_line(line)
    if type(line) ~= "string" or line == "" then
        return nil, nil, nil, nil
    end

    line = line:gsub("\r$", "")
    if line:match("^%s*$") or line:match("^%s*#") then
        return nil, nil, nil, nil
    end

    local key, rest = line:match("^(.-) \t(.*)$")
    if key and key ~= "" and rest and rest ~= "" then
        local value, tail = rest:match("^(.*)\t(c=[^%s\t]+%s+d=[^%s\t]+%s+t=[^%s\t]+)$")

        if not value then
            value = rest
        end
        if value ~= "" then
            return key, value, tail, "rime"
        end
    end

    local value, source_key = line:match("^([^\t]+)\t([^\t]+)$")
    if not value or not source_key then
        return nil, nil, nil, nil
    end

    value = value:match("^%s*(.-)%s*$")
    source_key = source_key:match("^%s*(.-)%s*$")
    if value == "" or source_key == "" then
        return nil, nil, nil, nil
    end

    return source_key, value, nil, "source"
end

-- 将逻辑记录格式化为标准 UserDb 文本行。
function userdb.format_line(key, value, tail)
    value, tail = normalize_value(value, tail)

    local raw_key = value and userdb.make_record_key(key, value)
    if not raw_key then
        return nil
    end

    return raw_key .. "\t" .. tail
end

-- 读取指定元数据。
function methods:meta_fetch(key)
    return self._db:fetch(META_PREFIX .. key)
end

-- 写入指定元数据。
function methods:meta_update(key, value)
    return self._db:update(META_PREFIX .. key, value)
end

-- 精确删除指定元数据。
function methods:meta_erase(key)
    return self._db:erase(META_PREFIX .. key)
end

-- 按前缀查询元数据。
function methods:meta_query(prefix)
    return self._db:query(META_PREFIX .. (prefix or ""))
end

-- 删除同一逻辑 key 下除保留项以外的旧记录。
local function erase_old(self, key, keep)
    local accessor = self._db:query(key .. RECORD_SEPARATOR)
    if not accessor then
        return true
    end

    local old_keys = {}

    for raw_key in accessor:iter() do
        local record_key = userdb.parse_record_key(raw_key)

        if record_key == key and raw_key ~= keep then
            old_keys[#old_keys + 1] = raw_key
        end
    end

    for _, raw_key in ipairs(old_keys) do
        if not self._db:erase(raw_key) then
            return false
        end
    end

    return true
end

-- 更新逻辑记录，并保证同一逻辑 key 只保留当前 value。
function methods:update(key, value, tail)
    value, tail = normalize_value(value, tail)

    local raw_key = value and userdb.make_record_key(key, value)
    if not raw_key then
        return false
    end

    key = tostring(key)

    if not erase_old(self, key, raw_key) then
        return false
    end
    return self._db:update(raw_key, tail)
end

-- 按逻辑 key 读取对应的 value 和记录尾部。
function methods:fetch(key)
    if key == nil then
        return nil, nil
    end

    key = tostring(key)
    if key == "" then
        return nil, nil
    end

    local accessor = self._db:query(key .. RECORD_SEPARATOR)
    if not accessor then
        return nil, nil
    end

    for raw_key, tail in accessor:iter() do
        local record_key, value = userdb.parse_record_key(raw_key)
        if record_key == key then
            return value, tail
        end
    end

    return nil, nil
end

-- 使用完整 raw key 精确读取底层记录。
function methods:fetch_raw(raw_key)
    if raw_key == nil then
        return nil
    end
    return self._db:fetch(tostring(raw_key))
end

-- 使用完整 raw key 精确写入底层记录。
function methods:update_raw(raw_key, raw_value)
    if raw_key == nil or raw_value == nil then
        return false
    end
    return self._db:update(tostring(raw_key), tostring(raw_value))
end

-- 使用原始前缀查询底层记录。
function methods:query_raw(prefix)
    return self._db:query(prefix or "")
end

-- 查询逻辑记录并返回解析后的访问器。
function methods:query(prefix)
    local accessor = self._db:query(prefix or "")
    if not accessor then
        return nil
    end

    return setmetatable({ _accessor = accessor }, {
        __index = function(wrapper, key)
            if accessor_methods[key] then
                return accessor_methods[key]
            end

            local value = wrapper._accessor[key]
            if type(value) ~= "function" then
                return value
            end

            return function(_, ...)
                return value(wrapper._accessor, ...)
            end
        end,
    })
end

-- 查询逻辑记录并逐条交给回调处理。
function methods:query_with(prefix, handler)
    if type(handler) ~= "function" then
        return
    end

    local accessor = self:query(prefix)
    if not accessor then
        return
    end

    for key, value, tail in accessor:iter() do
        handler(key, value, tail)
    end
end

-- 读取文本文件并通过 writer 写入解析后的记录。
local function read_file(file_path, filter, writer)
    local file = io.open(file_path, "r")
    if not file then
        return 0, 0, 1
    end

    local imported, skipped, failed = 0, 0, 0

    for line in file:lines() do
        local key, value, tail = userdb.parse_line(line)

        if not key or filter and filter(key, value, tail) == false then
            skipped = skipped + 1
        elseif writer(key, value, tail) then
            imported = imported + 1
        else
            failed = failed + 1
        end
    end

    file:close()
    return imported, skipped, failed
end

-- 导入单个文本文件并使用标准 update 语义写入。
function methods:import_file(file_path, filter)
    return read_file(file_path, filter, function(key, value, tail)
        return self:update(key, value, tail)
    end)
end

-- 依次导入多个文本文件并统一复用标准 update 语义。
function methods:import_files(file_paths, filter)
    local imported, skipped, failed = 0, 0, 0

    -- 使用标准 update 语义写入当前导入记录。
    local function write(key, value, tail)
        return self:update(key, value, tail)
    end

    for _, file_path in ipairs(file_paths or {}) do
        local a, b, c = read_file(file_path, filter, write)
        imported = imported + a
        skipped = skipped + b
        failed = failed + c
    end

    return imported, skipped, failed
end

-- 清空数据库记录，并按参数决定是否同时清除元数据。
function methods:empty(include_metafield)
    local raw_keys = {}
    local accessor = self._db:query("")

    if accessor then
        for raw_key in accessor:iter() do
            local is_meta = raw_key:find(META_PREFIX, 1, true) == 1

            if include_metafield or not is_meta then
                raw_keys[#raw_keys + 1] = raw_key
            end
        end
    end

    local success = true

    for _, raw_key in ipairs(raw_keys) do
        if not self._db:erase(raw_key) then
            success = false
        end
    end

    return success
end

-- 遍历底层访问器并解析为逻辑 key、value 和尾部。
function accessor_methods:iter()
    local iterator, state, control = self._accessor:iter()

    if type(iterator) ~= "function" then
        return function()
            return nil
        end, nil, nil
    end

    return function()
        while true do
            local raw_key, tail = iterator(state, control)
            if raw_key == nil then
                return nil
            end

            control = raw_key

            local key, value = userdb.parse_record_key(raw_key)
            if key then
                return key, value, tail
            end
        end
    end,
        nil,
        nil
end

local wrapper_mt = {
    __index = function(wrapper, key)
        if methods[key] then
            return methods[key]
        end

        local value = wrapper._db[key]
        if type(value) ~= "function" then
            return value
        end

        return function(_, ...)
            return value(wrapper._db, ...)
        end
    end,
}

-- 获取或复用指定名称和类别的原生 UserDb 包装对象。
function userdb.UserDb(db_name, db_class)
    db_class = db_class or "userdb"

    local pool_key = db_name .. "." .. db_class
    local db = db_pool[pool_key]

    if not db then
        db = UserDb(db_name, db_class)
        db_pool[pool_key] = db
    end

    return setmetatable({ _db = db }, wrapper_mt)
end

-- 创建或复用同步型 LevelDb。
function userdb.LevelDb(db_name)
    return userdb.UserDb(db_name, "userdb")
end

-- 创建或复用只读文本型 TableDb。
function userdb.TableDb(db_name)
    return userdb.UserDb(db_name, "plain_userdb")
end

return userdb
