local wanxiang = require('wanxiang')

local corrector = {}

---重置纠错状态
function corrector:init(key)
    self.key = key or nil    -- 纠错规则的唯一标识
    self.correction_map = {} -- 纠错规则缓存在内存中
    self.min_depth = 0       -- 纠错规则中的最小长度
    self.max_depth = 0       -- 纠错规则中的最大长度
end

-- 全局重置一次
corrector:init()

---纠错是否开启
---@return boolean
function corrector:is_enabled()
    return self.min_depth > 0
end

--- 按输入类型挑选纠错表并加载
---@param env Env
function corrector:load_corrections_from_file(env)
    local input_method_type = wanxiang.get_input_method_type(env)
    local new_key = input_method_type

    -- 如果当前规则已经初始化了，则不需要再次初始化
    if self.key ~= nil and self.key == new_key then
        return
    end

    self:init(new_key)

    local candidates = {
        ("lua/data/typo_%s.txt"):format(input_method_type),
    }

    for _, path in ipairs(candidates) do
        local file, close_file, _ = wanxiang.load_file_with_fallback(path, "r")

        if not file then
            log.info(("[typo_corrector] 纠错数据未找到（方案：%s，文件：%s），功能已禁用"):format(input_method_type, path))
            goto continue
        end

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

        ::continue::

        close_file()
    end
end

--- 从末尾扫描并返回可纠错的片段
---@param input string
---@return { length: number, corrected: string } | nil
function corrector:get_correct(input)
    if not self:is_enabled()
        or #input < self.min_depth
    then
        return nil
    end

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

---@class Env
---@field update_connection Connection
---@field property_update_connection Connection

local P = {}

P.updating = false

---键盘输入纠错
---@param context Context
---@return integer
function P.fix_typo(context)
    if P.updating or not context or not context:is_composing() then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    -- 开关关闭时直接不处理
    local is_corrector_enabled = context:get_option("corrector") or false
    if not is_corrector_enabled then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local input = context.input
    local correct = corrector:get_correct(input)
    if correct == nil then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    P.updating = true
    context:pop_input(correct.length)
    context:push_input(correct.corrected)
    P.updating = false

    return wanxiang.RIME_PROCESS_RESULTS.kAccepted
end

--- 初始化：加载纠错表 + 绑定监听器
---@param env Env
function P.init(env)
    corrector:load_corrections_from_file(env)

    local context = env.engine.context

    -- 方案变更时重新初始化纠错规则
    env.property_update_connection = context.property_update_notifier:connect(
        function(ctx)
            corrector:load_corrections_from_file(env)
        end
    )

    env.update_connection = context.update_notifier:connect(P.fix_typo)
end

--- 结束：断开监听
function P.fini(env)
    if env.update_connection then
        env.update_connection:disconnect()
        env.update_connection = nil
    end
    if env.property_update_connection then
        env.property_update_connection:disconnect()
        env.property_update_connection = nil
    end
end

---@param key KeyEvent
---@param env Env
---@return ProcessResult
function P.func(key, env)
    return P.fix_typo(env.engine.context)
end

return P
