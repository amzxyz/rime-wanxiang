-- 万象随机工具：UUID4 / UUID7 / ULID / 随机密码
-- 随机性完全来自操作系统 CSPRNG；时间仅用于 UUID v7 / ULID。
local floor, fmt, concat = math.floor, string.format, table.concat
local DEFAULT_LENGTHS = { 6, 8, 10, 16 }
local ULID_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

local function random_bytes(n)
    return assert(rime_api.secure_random_bytes(n), "system random unavailable")
end

-- 每次生成密码独立取样，拒绝采样避免取模偏差。
local function random_sampler()
    local bytes, pos = "", 1
    return function(n)
        local limit = 4294967296 - 4294967296 % n
        while true do
            if pos + 3 > #bytes then
                bytes, pos = random_bytes(128), 1
            end
            local a, b, c, d = bytes:byte(pos, pos + 3)
            pos = pos + 4
            local value = ((a * 256 + b) * 256 + c) * 256 + d
            if value < limit then
                return value % n + 1
            end
        end
    end
end

local function uuid(version)
    local b = { random_bytes(16):byte(1, 16) }
    if version == 7 then
        local timestamp = rime_api.get_unix_time_ms()
        for i = 6, 1, -1 do
            b[i] = timestamp % 256
            timestamp = floor(timestamp / 256)
        end
    end
    b[7] = b[7] % 16 + version * 16
    b[9] = b[9] % 64 + 128
    return fmt(
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        unpack(b)
    )
end

local function ulid()
    local timestamp = rime_api.get_unix_time_ms()
    local out = {}
    for i = 10, 1, -1 do
        local n = timestamp % 32 + 1
        out[i] = ULID_ALPHABET:sub(n, n)
        timestamp = floor(timestamp / 32)
    end
    local bytes = random_bytes(16)
    for i = 1, 16 do
        local n = bytes:byte(i) % 32 + 1
        out[i + 10] = ULID_ALPHABET:sub(n, n)
    end
    return concat(out)
end

local function parse_lengths(text)
    local out, seen = {}, {}
    for token in (text or ""):gmatch("[^,%s]+") do
        local n = tonumber(token)
        if n then
            n = floor(n)
            if n >= 1 and n <= 256 and not seen[n] then
                seen[n] = true
                out[#out + 1] = n
            end
        end
    end
    return #out > 0 and out or DEFAULT_LENGTHS
end

local function password(length, with_special, env)
    local groups = { env.password_upper, env.password_lower, env.password_digit }
    if with_special then
        groups[#groups + 1] = env.password_special
    end
    local pool = concat(groups)
    if pool == "" then return nil end

    local out, random = {}, random_sampler()
    local function pick(chars)
        local i = random(#chars)
        return chars:sub(i, i)
    end
    -- 长度允许时，每个非空字符类至少选一个字符。
    for _, chars in ipairs(groups) do
        if #out < length and chars ~= "" then
            out[#out + 1] = pick(chars)
        end
    end
    while #out < length do
        out[#out + 1] = pick(pool)
    end
    for i = #out, 2, -1 do
        local j = random(i)
        out[i], out[j] = out[j], out[i]
    end
    return concat(out)
end

local M = {}

local function yield_cand(seg, text, comment, quality)
    if not text or text == "" then return end
    local cand = Candidate("", seg.start, seg._end, text, comment)
    cand.quality = quality
    yield(cand)
end

function M.init(env)
    local config = env.engine.schema.config
    local function code(key, default)
        local value = config:get_string("random_tools/" .. key)
        return value and value ~= "" and value or default
    end
    local function chars(key, default)
        return config:get_string("random_tools/chars/" .. key) or default
    end
    env.uuid_code = code("uuid", "/uuid")
    env.uuid7_code = code("uuid7", "/uuidq")
    env.ulid_code = code("ulid", "/ulid")
    env.password_code = code("password", "/mima")
    env.password_special_code = code("password_special", "/mimas")
    env.password_lengths = parse_lengths(config:get_string("random_tools/password_lengths"))
    env.password_upper = chars("upper", "ABCDEFGHJKLMNPQRSTUVWXYZ")
    env.password_lower = chars("lower", "abcdefghijkmnopqrstuvwxyz")
    env.password_digit = chars("digit", "23456789")
    env.password_special = chars("special", "!@#$%^&*_-+")
end

function M.func(input, seg, env)
    if input == env.uuid_code or input == env.uuid7_code then
        local version = input == env.uuid_code and 4 or 7
        local value = uuid(version)
        local label = "UUID v" .. version
        yield_cand(seg, value, "〔" .. label .. "〕", 120)
        yield_cand(seg, value:upper(), "〔" .. label .. " · 大写〕", 110)
        yield_cand(seg, value:gsub("-", ""), "〔" .. label .. " · 紧凑〕", 100)
    elseif input == env.ulid_code then
        yield_cand(seg, ulid(), "〔ULID〕", 120)
    elseif input == env.password_code or input == env.password_special_code then
        local with_special = input ~= env.password_code
        local label = with_special and "含符号" or "字母数字"
        for i, n in ipairs(env.password_lengths) do
            yield_cand(seg, password(n, with_special, env),
                fmt("〔%d 位 · %s〕", n, label), 120 - i)
        end
    end
end

return M
