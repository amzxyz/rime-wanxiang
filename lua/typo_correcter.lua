local wanxiang = require('wanxiang')

local correcter = {}

correcter.correction_map = {}
correcter.min_depth = 0
correcter.max_depth = 0

function correcter:load_corrections_from_file()
    self.correction_map = {}
    local file, close_file, err = wanxiang.load_file_with_fallback("lua/data/typo.txt")
    if err then
        log.error(string.format("[typo_corrector]：纠错数据加载失败，错误：%s", err))
        return
    end

    self.min_depth = 0
    self.max_depth = 0

    for line in file:lines() do
        if not line:match("^#") then
            local corrected, typo = line:match("^([^\t]+)\t([^\t]+)")
            if typo and corrected then
                local typo_len = #typo
                if self.min_depth == 0 or typo_len < self.min_depth then
                    self.min_depth = typo_len
                end
                if typo_len > self.max_depth then
                    self.max_depth = typo_len
                end

                self.correction_map[typo] = corrected
            end
        end
    end
    close_file()
end

function correcter:get_correct(input)
    if #input < self.min_depth then return nil end

    for scan_len = self.min_depth, math.min(#input, self.max_depth), 1 do
        local scan_pos = #input - scan_len + 1
        local scan_input = input:sub(scan_pos)
        local corrected = self.correction_map[scan_input]
        if corrected then
            return { length = scan_len, corrected = corrected }
        end
    end

    return nil
end

local P = {}

function P.init()
    correcter:load_corrections_from_file()
end

---@param key KeyEvent
---@param env Env
---@return ProcessResult
function P.func(key, env)
    local context = env.engine.context
    if not context or not context:is_composing() then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local input = context.input

    local correct = correcter:get_correct(input)
    if correct then
        context:pop_input(correct.length)
        context:push_input(correct.corrected)
        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end

    return wanxiang.RIME_PROCESS_RESULTS.kNoop
end

return P
