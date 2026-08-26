-- random_tools.lua
-- 万象随机工具：UUID4 / UUID7 / ULID / 随机密码
local floor = math.floor
local fmt = string.format
local byte = string.byte
local sub = string.sub
local concat = table.concat

local U32 = 4294967296
local U16 = 65536

local function time_ms()
    if rime_api and rime_api.get_time_ms then
        return rime_api.get_time_ms()
    end
    return os.time() * 1000
end

local function u32(x)
    x = x % U32
    if x < 0 then
        x = x + U32
    end
    return x
end

-- 32 位运算兼容
local band, bxor, bor, lshift, rshift

local compile_chunk = loadstring or load
if compile_chunk then
    local fn = compile_chunk([[
        return {
            band = function(a, b) return (a & b) & 0xffffffff end,
            bxor = function(a, b) return (a ~ b) & 0xffffffff end,
            bor = function(a, b) return (a | b) & 0xffffffff end,
            lshift = function(a, n) return (a << n) & 0xffffffff end,
            rshift = function(a, n) return (a >> n) & 0xffffffff end
        }
    ]])

    if fn then
        local ok, native = pcall(fn)
        if ok and native then
            band = function(a, b) return u32(native.band(a, b)) end
            bxor = function(a, b) return u32(native.bxor(a, b)) end
            bor = function(a, b) return u32(native.bor(a, b)) end
            lshift = function(a, n) return u32(native.lshift(a, n)) end
            rshift = function(a, n) return u32(native.rshift(a, n)) end
        end
    end
end

if not band then
    local ok, lib = pcall(require, "bit")
    if not ok then
        ok, lib = pcall(require, "bit32")
    end

    if ok and lib then
        band = function(a, b) return u32(lib.band(a, b)) end
        bxor = function(a, b) return u32(lib.bxor(a, b)) end
        bor = function(a, b) return u32(lib.bor(a, b)) end
        lshift = function(a, n) return u32(lib.lshift(a, n)) end
        rshift = function(a, n) return u32(lib.rshift(a, n)) end
    end
end

if not band then
    local function bitop(a, b, mode)
        a, b = u32(a), u32(b)
        local out, p = 0, 1

        for _ = 1, 32 do
            local aa = a % 2
            local bb = b % 2
            local take = false

            if mode == "and" then
                take = aa == 1 and bb == 1
            elseif mode == "xor" then
                take = aa ~= bb
            else
                take = aa == 1 or bb == 1
            end

            if take then
                out = out + p
            end

            a = floor(a / 2)
            b = floor(b / 2)
            p = p * 2
        end

        return out
    end

    band = function(a, b) return bitop(a, b, "and") end
    bxor = function(a, b) return bitop(a, b, "xor") end
    bor = function(a, b) return bitop(a, b, "or") end

    lshift = function(a, n)
        n = n % 32
        if n == 0 then return u32(a) end
        local keep = 2 ^ (32 - n)
        return (u32(a) % keep) * 2 ^ n
    end

    rshift = function(a, n)
        n = n % 32
        if n == 0 then return u32(a) end
        return floor(u32(a) / 2 ^ n)
    end
end

local function rol32(x, n)
    n = n % 32
    if n == 0 then return u32(x) end
    return bor(lshift(x, n), rshift(x, 32 - n))
end

local function mul32(a, b)
    a, b = u32(a), u32(b)

    local al = a % U16
    local ah = floor(a / U16)
    local bl = b % U16
    local bh = floor(b / U16)

    local low = al * bl
    local mid = (al * bh + ah * bl) % U16

    return u32(low + mid * U16)
end

-- 种子混合
local function hash32(text, seed)
    local h = u32(seed or 2166136261)

    for i = 1, #text do
        h = bxor(h, byte(text, i))
        h = mul32(h, 16777619)
    end

    h = bxor(h, rshift(h, 16))
    h = mul32(h, 2246822507)
    h = bxor(h, rshift(h, 13))
    h = mul32(h, 3266489909)
    h = bxor(h, rshift(h, 16))

    return u32(h)
end

local seed_counter = 0

local function make_seed_state()
    seed_counter = seed_counter + 1

    local material = concat({
        tostring(time_ms()),
        tostring(os.clock()),
        tostring(collectgarbage("count")),
        tostring({}),
        tostring(function() end),
        tostring(seed_counter),
    }, "|")

    local s0 = hash32(material, 0x243F6A88)
    local s1 = hash32(material, 0x85A308D3)
    local s2 = hash32(material, 0x13198A2E)
    local s3 = hash32(material, 0x03707344)

    if s0 == 0 and s1 == 0 and s2 == 0 and s3 == 0 then
        s0 = 0x9E3779B9
        s1 = 0x243F6A88
        s2 = 0xB7E15162
        s3 = 0xDEADBEEF
    end

    return { s0, s1, s2, s3 }
end

-- xoshiro128**
local state = make_seed_state()

local function random_u32()
    local s0, s1, s2, s3 = state[1], state[2], state[3], state[4]

    local result = mul32(rol32(mul32(s1, 5), 7), 9)
    local t = lshift(s1, 9)

    s2 = bxor(s2, s0)
    s3 = bxor(s3, s1)
    s1 = bxor(s1, s2)
    s0 = bxor(s0, s3)
    s2 = bxor(s2, t)
    s3 = rol32(s3, 11)

    state[1], state[2], state[3], state[4] = s0, s1, s2, s3

    return result
end

local function random_below(n)
    if n <= 1 then return 0 end

    local limit = floor(U32 / n) * n
    local x

    repeat
        x = random_u32()
    until x < limit

    return x % n
end

local function random_char(chars)
    local i = random_below(#chars) + 1
    return sub(chars, i, i)
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = random_below(i) + 1
        list[i], list[j] = list[j], list[i]
    end
end

local function random_bytes(n)
    local out = {}
    for i = 1, n do
        out[i] = random_below(256)
    end
    return out
end

local function format_uuid(b)
    return fmt(
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        b[1], b[2], b[3], b[4],
        b[5], b[6],
        b[7], b[8],
        b[9], b[10],
        b[11], b[12], b[13], b[14], b[15], b[16]
    )
end

-- UUID v4
local function uuid_v4()
    local b = random_bytes(16)

    b[7] = band(b[7], 0x0F) + 0x40
    b[9] = band(b[9], 0x3F) + 0x80

    return format_uuid(b)
end

-- UUID v7
local function uuid_v7()
    local b = random_bytes(16)
    local timestamp = time_ms()

    for i = 6, 1, -1 do
        b[i] = timestamp % 256
        timestamp = floor(timestamp / 256)
    end

    b[7] = band(b[7], 0x0F) + 0x70
    b[9] = band(b[9], 0x3F) + 0x80

    return format_uuid(b)
end

-- ULID
local ULID_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

local function encode_base32_number(value, length)
    local out = {}

    for i = length, 1, -1 do
        local n = value % 32
        out[i] = sub(ULID_ALPHABET, n + 1, n + 1)
        value = floor(value / 32)
    end

    return concat(out)
end

local function ulid()
    local timestamp = time_ms()
    local out = { encode_base32_number(timestamp, 10) }

    for i = 1, 16 do
        out[#out + 1] = random_char(ULID_ALPHABET)
    end

    return concat(out)
end

-- 密码 / PIN
local UPPER = "ABCDEFGHJKLMNPQRSTUVWXYZ"
local LOWER = "abcdefghijkmnopqrstuvwxyz"
local DIGIT = "23456789"
local SPECIAL = "!@#$%^&*_-+"

local ALNUM = UPPER .. LOWER .. DIGIT
local ALNUM_SPECIAL = ALNUM .. SPECIAL

local function password(length, with_special)
    local out = {}

    if length >= 1 then out[#out + 1] = random_char(UPPER) end
    if length >= 2 then out[#out + 1] = random_char(LOWER) end
    if length >= 3 then out[#out + 1] = random_char(DIGIT) end

    if with_special and length >= 4 then
        out[#out + 1] = random_char(SPECIAL)
    end

    local pool = with_special and ALNUM_SPECIAL or ALNUM

    while #out < length do
        out[#out + 1] = random_char(pool)
    end

    shuffle(out)
    return concat(out)
end

local M = {}

local function yield_cand(seg, text, comment, quality)
    local cand = Candidate("", seg.start, seg._end, text, comment or "")
    cand.quality = quality or 100
    yield(cand)
end

function M.init(env)
    local config = env.engine.schema.config

    M.uuid_code = config:get_string("random_tools/uuid") or "/uuid"
    M.uuid7_code = config:get_string("random_tools/uuid7") or "/uuidq"
    M.ulid_code = config:get_string("random_tools/ulid") or "/ulid"
    M.password_code = config:get_string("random_tools/password") or "/mima"
    M.password_special_code = config:get_string("random_tools/password_special") or "/mimas"
end

function M.func(input, seg, _)
    if input == M.uuid_code then
        local value = uuid_v4()

        yield_cand(seg, value, "〔UUID v4〕", 120)
        yield_cand(seg, value:upper(), "〔UUID v4 · 大写〕", 110)
        yield_cand(seg, value:gsub("-", ""), "〔UUID v4 · 紧凑〕", 100)
        return
    end

    if input == M.uuid7_code then
        local value = uuid_v7()

        yield_cand(seg, value, "〔UUID v7〕", 120)
        yield_cand(seg, value:upper(), "〔UUID v7 · 大写〕", 110)
        yield_cand(seg, value:gsub("-", ""), "〔UUID v7 · 紧凑〕", 100)
        return
    end

    if input == M.ulid_code then
        yield_cand(seg, ulid(), "〔ULID〕", 120)
        return
    end

    if input == M.password_code then
        local lengths = { 6, 8, 10, 16 }
        for i, n in ipairs(lengths) do
            yield_cand(
                seg,
                password(n, false),
                fmt("〔%d 位 · 字母数字〕", n),
                120 - i
            )
        end
        return
    end

    if input == M.password_special_code then
        local lengths = { 6, 8, 10, 16 }
        for i, n in ipairs(lengths) do
            yield_cand(
                seg,
                password(n, true),
                fmt("〔%d 位 · 含符号〕", n),
                120 - i
            )
        end
        return
    end

end

return M
