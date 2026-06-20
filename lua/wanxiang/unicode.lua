-- Unicode
-- Copyright (C) 2021 Shewer Lu <shewer@gmail.com>
-- This file is licensed under the MIT License.
-- amzxyz
-- 示例：输入 U62fc 得到「拼」
-- 触发前缀默认为 recognizer/patterns/unicode 的第 2 个字符，即 U
local function unicode(input, seg, env)
    -- 获取 recognizer/patterns/unicode 的第 2 个字符作为触发前缀
    env.unicode_keyword = env.unicode_keyword or
        env.engine.schema.config:get_string('recognizer/patterns/unicode'):sub(2, 2)
    if seg:has_tag("unicode") and env.unicode_keyword ~= '' and input:sub(1, 1) == env.unicode_keyword then
        local ucodestr = input:match(env.unicode_keyword .. "(%x+)")
        if ucodestr and #ucodestr > 1 then
            local segment = env.engine.context.composition:back()        
            -- 设置标签
            segment.tags = segment.tags + Set({ "unicode" })             
            local code = tonumber(ucodestr, 16)
            if code > 0x10FFFF then
                yield(Candidate("unicode", seg.start, seg._end, "数值超限！", ""))
                return
            end
            -- 检测代理区字符 (U+D800 ~ U+DFFF)
            if code >= 0xD800 and code <= 0xDFFF then
                yield(Candidate("unicode", seg.start, seg._end, "代理区字符无效！", ""))
                return
            end
            local text = utf8.char(code)
            yield(Candidate("unicode", seg.start, seg._end, text, string.format("U%x", code)))
            if code < 0x10000 then
                for i = 0, 15 do
                    local new_code = code * 16 + i
                    -- 跳过代理区码点，避免生成无效字符
                    if new_code >= 0xD800 and new_code <= 0xDFFF then
                        -- 不生成候选，直接跳过
                    else
                        local text = utf8.char(new_code)
                        yield(Candidate("unicode", seg.start, seg._end, text, string.format("U%x~%x", code, i)))
                    end
                end
            end
        end
    end
end

return unicode
