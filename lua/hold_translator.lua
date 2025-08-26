-- 该脚本用于封装script_translator@translator，对翻译结果进行筛选限制，提供默认词库词序置顶、固定词序模型生成环境等功能
-- 谨慎设置超过候选项数量的pin值，会导致前后页候选项带词频效果的混乱
-- 无条件丢弃翻译结果可实现对主翻译器的弃用，但仍有翻译性能开销（不推荐）

local function translator(input, seg, env)
    local translation = Component.Translator(env.engine, "", "script_translator@translator"):query(input, seg)
    if not translation then return end

    -- 读一个参数：pin（默认 1），并限制到 0..6
    local config = env.engine.schema.config
    local pin = 1
    do
        local s = config and config:get_string("hold_translator") or nil
        local v = tonumber(s)
        if v then
            v = math.floor(v)
            if v < 0 then v = 0 end
            if v > 6 then v = 6 end
            pin = v
        end
    end

    if pin == 0 then
        for cand in translation:iter() do
            if cand.type == "sentence" then
                yield(cand)
            end
            break
        end
    else
        local i = 0
        for cand in translation:iter() do
            yield(cand)
            i = i + 1
            if i >= pin then break end
        end
    end
end
return translator
