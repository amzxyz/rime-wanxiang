local META_KEY_PREFIX = "\001" .. "/"

---@class MetadataUserDb: UserDb
---@field meta_query fun(self: self, prefix: string): DbAccessor
---@field meta_fetch fun(self: self, key: string): string|nil
---@field meta_update fun(self: self, key: string, value: string): boolean
---@field meta_erase fun(self: self, key: string): boolean

local db_pool_ = {}

function db_pool_.get_key(db_name, db_class)
  return db_name .. "." .. db_class
end

---从池中获取连接
---@param name string
---@param class "userdb" | "plain_userdb"
---@return UserDb|unknown
function db_pool_.get(name, class)
  local key = db_pool_.get_key(name, class)
  local db = db_pool_[key]
  if not db then
    db = UserDb(name, class)
    db_pool_[key] = db
  end
  return db
end

local userdb_mt = {}

function userdb_mt.__index(wrapper, key)
  local extends = rawget(userdb_mt, key)
  if extends then
    return extends
  end

  local real_db = db_pool_.get(wrapper._db_name, wrapper._db_class)
  local value = real_db[key]

  if type(value) == "function" then
    local proxy_fn = function(wrapper_self, ...)
      return value(real_db, ...)
    end

    if key == "close" then
      proxy_fn = function(wrapper_self, ...)
        -- 在关闭 userdb 之前手动出发垃圾回收，降低内存泄露概率
        collectgarbage()
        local result = value(real_db, ...)
        return result
      end
    end
    rawset(wrapper, key, proxy_fn)
    return proxy_fn
  end

  return value
end

function userdb_mt:meta_query(prefix)
  return self:query(META_KEY_PREFIX .. prefix)
end

function userdb_mt:meta_fetch(key)
  return self:fetch(META_KEY_PREFIX .. key)
end

function userdb_mt:meta_update(key, value)
  return self:update(META_KEY_PREFIX .. key, value)
end

function userdb_mt:meta_erase(key)
  return self:erase(META_KEY_PREFIX .. key)
end

local userdb = {}

userdb.META_KEY_PREFIX = META_KEY_PREFIX

---@return MetadataUserDb
function userdb.UserDb(db_name, db_class)
  local wrapper = {
    _db_name = db_name,
    _db_class = db_class,
  }
  return setmetatable(wrapper, userdb_mt)
end

function userdb.LevelDb(db_name)
  return userdb.UserDb(db_name, "userdb")
end

function userdb.TableDb(db_name)
  return userdb.UserDb(db_name, "plain_userdb")
end

return userdb
