local bit_native = nil

if jit and jit.version then -- 首先尝试 LuaJIT 的 bit 库
    bit_native = require("bit")
else                        -- 再尝试 Lua 5.2 中的 bit32 库
    local bit32_ok, bit32 = pcall(require, "bit32")
    if bit32_ok then
        bit_native = bit32
    end
end

local bit = {}

function bit.bxor(a, b)
    if bit_native then
        return bit_native.bxor(a, b)
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
    if bit_native then
        return bit_native.band(a, b)
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
