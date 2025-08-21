local bit_ok, bit_ = pcall(require, "bit")       -- LuaJIT 内置 bit 库
local bit32_ok, bit32_ = pcall(require, "bit32") -- Lua 5.2 内置 bit32 库

---@alias fn_band fun(a: string, b: string): string
---@alias fn_bxor fun(a: string, b: string): string
---@type nil | { band: fn_band, bxor: fn_bxor }
local bit53_ = nil -- Lua 5.3 引入的原生位运算操作符

---@diagnostic disable-next-line: deprecated
local load_func = load or loadstring
if load_func then
    ---将新语法放入字符串中，避免在旧版 Lua 中导致语法错误
    local bit53_func, bit53_err = load_func("return {" ..
        "band = function(a, b) return a & b end," ..
        "bxor = function(a, b) return a ~ b end," ..
        "}")
    if bit53_func and not bit53_err then
        bit53_ = bit53_func()
    end
end

local bit = {}

function bit.bxor(a, b)
    if bit_ok then
        return bit_.bxor(a, b)
    elseif bit32_ok then
        return bit32_.bxor(a, b)
    elseif bit53_ then
        return bit53_.bxor(a, b)
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

function bit.band(a, b)
    if bit_ok then
        return bit_.band(a, b)
    elseif bit32_ok then
        return bit32_.band(a, b)
    elseif bit53_ then
        return bit53_.band(a, b)
    end

    local p, c = 1, 0
    while a > 0 and b > 0 do
        local ra, rb = a % 2, b % 2
        if ra + rb > 1 then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    return c
end

return bit
