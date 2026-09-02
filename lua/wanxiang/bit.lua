---跨运行时的位运算模块（API 兼容 LuaJIT bit 库，并统一使用 64 位掩码）
---
---自动检测运行环境，按优先级选用可用后端：
---  Lua 5.3+ 原生位运算符 > LuaJIT/Lua 5.2 32 位原生库（高低半字拆分） > 纯算术模拟

local function split(x)
    local lo = x % 2^32
    local hi = (x - lo) / 2^32
    if hi < 0 then hi = hi + 2^32 end
    return lo, hi
end

local function combine(lo, hi)
    if lo < 0 then lo = lo + 2^32 end
    if hi < 0 then hi = hi + 2^32 end
    return lo + hi * 2^32
end

---@param a integer
---@param b integer
---@return integer
local function band_arith(a, b)
    if a < 0 or b < 0 then
        local al, ah = split(a); local bl, bh = split(b)
        return combine(band_arith(al, bl), band_arith(ah, bh))
    end
    local p, c = 1, 0
    while a > 0 and b > 0 do
        local ra, rb = a % 2, b % 2
        if ra + rb > 1 then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    return c
end

---@param a integer
---@param b integer
---@return integer
local function bxor_arith(a, b)
    if a < 0 or b < 0 then
        local al, ah = split(a); local bl, bh = split(b)
        return combine(bxor_arith(al, bl), bxor_arith(ah, bh))
    end
    local p, c = 1, 0
    while a > 0 and b > 0 do
        local ra, rb = a % 2, b % 2
        if ra ~= rb then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    if a < b then a = b end
    while a > 0 do
        local ra = a % 2
        if ra > 0 then c = c + p end
        a, p = (a - ra) / 2, p * 2
    end
    return c
end

---@param a integer
---@param b integer
---@return integer
local function bor_arith(a, b)
    return band_arith(a, b) + bxor_arith(a, b)
end

---@param a integer
---@param n integer
---@return integer
local function lshift_arith(a, n)
    return a * 2^n
end

---@class bit
---@field band fun(a: integer, b: integer): integer
---@field bor  fun(a: integer, b: integer): integer
---@field bxor fun(a: integer, b: integer): integer
---@field lshift fun(a: integer, n: integer): integer
---@type bit
local m = {
    band = band_arith,
    bor  = bor_arith,
    bxor = bxor_arith,
    lshift = lshift_arith,
}

-- Lua 5.3+（原生 `&` `|` `<<` 运算符，需通过 load 检测）
if load then
    local fn = load(
        "return {" ..
            "band = function(a, b) return a & b end," ..
            "bor = function(a, b) return a | b end," ..
            "bxor = function(a, b) return a ~ b end," ..
            "lshift = function(a, b) return a << b end" ..
        "}"
    )
    if fn then
        local lua53_bit = fn()
        m.band = lua53_bit.band
        m.bor  = lua53_bit.bor
        m.bxor = lua53_bit.bxor
        m.lshift = lua53_bit.lshift
        return m
    end
end

-- LuaJIT（bit）/ Lua 5.2（bit32）：原生库仅 32 位，按高低半字拆分实现 64 位
local native32_ok, native32_lib = pcall(require, "bit")
if not native32_ok then
    native32_ok, native32_lib = pcall(require, "bit32")
end
if native32_ok then
    local function native32_op(op)
        return function(a, b)
            local al, ah = split(a); local bl, bh = split(b)
            return combine(op(al, bl), op(ah, bh))
        end
    end
    m.band = native32_op(native32_lib.band)
    m.bor  = native32_op(native32_lib.bor)
    m.bxor = native32_op(native32_lib.bxor)
    m.lshift = function(a, n) return a * 2^n end
    return m
end

-- 算术模拟兜底（Lua 5.1 / 受限环境）
return m
