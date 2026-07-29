-- charset_filter.lua
-- 功能：独立的字符集过滤与兜底组件
-- 逻辑：
-- 1. 支持配置多个选项，开启多个选项时 Base 和 Addlist 取并集，Blacklist 一票否决。
-- 2. 单字如果不符合字符集，直接丢弃（删除），不进行兜底。
-- 3. 只有词组末尾为生僻字时，才尝试从历史记录生成兜底。
-- 4. table、user_table 和 completion 候选不能写入兜底历史。
-- 5. 兜底只允许复用完全相同编码和词长的历史，不拼接剩余编码。

local wanxiang = require("wanxiang/wanxiang")
local M = {}

local sub = string.sub
local byte = string.byte
local utf8_codes = utf8.codes
local utf8_len = utf8.len
local utf8_char = utf8.char
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local insert = table.insert
local type = type
local bit = require("wanxiang/bit")

-- 将字符集属性字符串转换为位掩码。
local function str_to_mask(s)
    if not s or s == "" then return 0 end

    local m = 0
    for i = 1, #s do
        m = bit.bor(m, bit.lshift(1, bit.band(byte(s, i), 0x3F)))
    end
    return m
end

-- 延迟加载并缓存字符集反查数据库。
local function get_charset_db(env)
    if env.charset_db_checked then return env.charset_db end
    env.charset_db_checked = true

    if not ReverseDb then return nil end

    local dist = (rime_api and rime_api.get_distribution_code_name
        and rime_api.get_distribution_code_name() or ""):lower()
    local fname = dist == "weasel"
        and "lua/data/charset.reverse.bin"
        or wanxiang.get_filename_with_fallback("lua/data/charset.reverse.bin")
        or "lua/data/charset.reverse.bin"

    local ok, db = pcall(function() return ReverseDb(fname) end)
    if ok then env.charset_db = db end
    return env.charset_db
end

-- 查询并缓存单个汉字所属字符集的位掩码。
local function get_char_mask(env, char)
    local mask = env.db_memo[char]
    if mask ~= nil then return mask end

    local db = get_charset_db(env)
    if not db then return 0 end

    local attr = db:lookup(char)
    if attr and attr ~= "" then
        mask = str_to_mask(attr)
        env.db_memo[char] = mask
        return mask
    end

    return 0
end

-- 判断单个汉字是否符合当前启用规则。
local function char_is_valid(env, codepoint, char, active_rules, cache)
    local r = cache[codepoint]
    if r ~= nil then return r end

    local allowed = false
    local banned = false

    for i = 1, #active_rules do
        local rule = active_rules[i]

        -- blacklist 一票否决
        if rule.ban[codepoint] then
            banned = true
            break
        end

        if not allowed then
            if rule.add[codepoint] then
                allowed = true
            elseif rule.base ~= 0 then
                local m = get_char_mask(env, char)
                if m ~= 0 and bit.band(m, rule.base) ~= 0 then
                    allowed = true
                end
            end
        end
    end

    local result = not banned and allowed
    cache[codepoint] = result
    return result
end

-- 判断文本中的全部汉字是否符合当前字符集规则。
local function text_is_valid(env, text, active_rules, cache)
    if not text or text == "" then return true end

    for _, cp in utf8_codes(text) do
        local char = utf8_char(cp)
        if wanxiang.IsChineseCharacter(char)
            and not char_is_valid(env, cp, char, active_rules, cache)
        then
            return false
        end
    end

    return true
end

-- 将原始规则转换为运行时结构。
local function preprocess(raw)
    return {
        options = raw.options,
        base = str_to_mask(raw.base_str),
        add = raw.add,
        ban = raw.ban,
    }
end

-- 从配置中加载全部字符集过滤规则。
local function load_rules(cfg, path)
    local rules = {}
    local list = cfg:get_list(path)
    if not list then return rules end

    for i = 0, list.size - 1 do
        local ep = path .. "/@" .. i
        local triggers = {}

        for _, key in ipairs({"option", "options"}) do
            local kp = ep .. "/" .. key
            local sl = cfg:get_list(kp)

            if sl then
                for k = 0, sl.size - 1 do
                    local v = cfg:get_string(kp .. "/@" .. k)
                    if v and v ~= "" then insert(triggers, v) end
                end
            elseif cfg:get_bool(kp) then
                insert(triggers, "true")
            else
                local v = cfg:get_string(kp)
                if v and v ~= "" and v ~= "true" then insert(triggers, v) end
            end
        end

        if #triggers == 0 then goto next end

        local base_str = cfg:get_string(ep .. "/base") or ""
        local add = {}
        local ban = {}

        -- 将字符列表加载为码点查找表。
        local function load_list(name, target)
            local lp = ep .. "/" .. name
            local sl = cfg:get_list(lp)
            if not sl then return end

            for k = 0, sl.size - 1 do
                local v = cfg:get_string(lp .. "/@" .. k)
                if v and v ~= "" then
                    for _, cp in utf8_codes(v) do target[cp] = true end
                end
            end
        end

        load_list("addlist", add)
        load_list("blacklist", ban)

        insert(rules, preprocess({
            options = triggers,
            base_str = base_str,
            add = add,
            ban = ban,
        }))

        ::next::
    end

    return rules
end

-- 返回当前输入状态下已经启用的规则。
local function get_active_rules(env, ctx)
    local filters = env.filters
    if not filters or #filters == 0 then return nil end

    if wanxiang and wanxiang.s2t_conversion
        and wanxiang.s2t_conversion(ctx)
    then
        return nil
    end

    local active = {}

    for i = 1, #filters do
        local rule = filters[i]

        for j = 1, #rule.options do
            if rule.options[j] == "true"
                or ctx:get_option(rule.options[j])
            then
                insert(active, rule)
                break
            end
        end
    end

    return #active > 0 and active or nil
end

-- 排除 table 类候选和补全候选，不允许它们写入兜底历史。
local function can_record_history(cand)
    local cand_type = cand and cand.type or ""

    return cand_type ~= "table"
        and cand_type ~= "user_table"
        and cand_type ~= "completion"
end

-- 只有最后一个字符为非法汉字时才允许启动兜底。
local function can_fallback_from_text(
    env, text, text_len, active_rules, cache
)
    if not text or text == "" or text_len < 2 then return false end

    local position = 0
    local found_invalid = false

    for _, cp in utf8_codes(text) do
        position = position + 1

        local char = utf8_char(cp)
        if wanxiang.IsChineseCharacter(char)
            and not char_is_valid(
                env, cp, char, active_rules, cache
            )
        then
            if position ~= text_len or found_invalid then
                return false
            end

            found_invalid = true
        end
    end

    return found_invalid
end

-- 判断候选是否完整覆盖当前活动编码段。
local function covers_current_segment(cand, comp, code_len)
    local seg = comp and comp:back()

    if seg then
        return cand.start == seg.start and cand._end == seg._end
    end

    return cand.start == 0 and cand._end == code_len
end

-- 读取完全相同输入编码下、相同词长的历史候选。
local function get_exact_history(env, code, text_len)
    local history = env.phrase_history
    if not history or history.code ~= code then return nil end
    if history.text_len ~= text_len then return nil end

    return history.text
end

-- 初始化过滤规则、历史缓存和选项监听。
function M.init(env)
    local cfg = env.engine and env.engine.schema
        and env.engine.schema.config

    env.charset_db = nil
    env.charset_db_checked = false
    env.db_memo = {}
    env.filters = {}
    env.phrase_history = nil

    if cfg then env.filters = load_rules(cfg, "charset") end

    env.opt_update_conn =
        env.engine.context.option_update_notifier:connect(
            function(ctx, name)
                for i = 1, #env.filters do
                    local opts = env.filters[i].options

                    for j = 1, #opts do
                        if name == opts[j] then
                            ctx:refresh_non_confirmed_composition()
                            return
                        end
                    end
                end
            end
        )
end

-- 断开选项监听并释放数据库和缓存引用。
function M.fini(env)
    if env.opt_update_conn then
        env.opt_update_conn:disconnect()
        env.opt_update_conn = nil
    end

    local db = env.charset_db
    env.charset_db = nil

    if db and db.close then
        pcall(function() db:close() end)
    end

    env.charset_db_checked = nil
    env.db_memo = nil
    env.filters = nil
    env.phrase_history = nil
end

-- 过滤非法字符，并在必要时生成同长度历史兜底候选。
function M.func(input, env)
    local ctx = env.engine.context
    local code = ctx.input or ""
    local comp = ctx.composition
    local code_len = #code
    local cache = {}

    -- 输入清空时结束当前兜底历史上下文。
    if code == "" or comp and comp:empty() then
        env.phrase_history = nil
    end

    -- 获取活跃规则
    local active_rules = get_active_rules(env, ctx)
    local charset_on = active_rules ~= nil

    -- 5码豁免
    if charset_on and code_len == 5 then
        local last = sub(code, -1)
        if not last:match("[%w]") then charset_on = false end
    end

    local has_valid = false
    local pending = nil
    local pending_len = 0
    local recorded = false

    -- 输出候选，并记录当前完整编码对应的可靠历史候选。
    local function output(cand, text, text_len)
        if not recorded and can_record_history(cand)
            and text and text ~= "" and (text_len or 0) >= 1
        then
            env.phrase_history = {
                code = code,
                text = text,
                text_len = text_len,
            }
            recorded = true
        end

        yield(cand)
    end

    for cand in input:iter() do
        local text = cand.text
        local text_len = utf8_len(text)

        -- 处理 pending 的兜底候选
        if pending then
            if text_len == pending_len then
                output(pending, pending.text, pending_len)
                has_valid = true
                pending = nil
                goto next
            end

            output(pending, pending.text, pending_len)
            has_valid = true
            pending = nil
        end

        if not charset_on or text == "" then
            output(cand, text, text_len)
            has_valid = true
        elseif text_is_valid(env, text, active_rules, cache) then
            output(cand, text, text_len)
            has_valid = true
        elseif text_len >= 2
            and (cand.type == "phrase" or cand.type == "user_phrase")
        then
            -- 词库中真实存在的多字词组，直接放行不过滤
            output(cand, text, text_len)
            has_valid = true
        elseif not has_valid and not pending
            and covers_current_segment(cand, comp, code_len)
            and can_fallback_from_text(
                env, text, text_len, active_rules, cache
            )
        then
            local fb = get_exact_history(env, code, text_len)

            if fb then
                local pre = cand.preedit or code

                if #pre > 1 and pre:sub(-1):match("[%w%p]") then
                    pre = sub(pre, 1, -2) .. " " .. sub(pre, -1)
                end

                local nc = Candidate(
                    "fallback",
                    cand.start,
                    cand._end,
                    fb,
                    cand.comment or ""
                )
                nc.preedit = pre

                if text_is_valid(
                    env, nc.text, active_rules, cache
                ) then
                    pending = nc
                    pending_len = text_len
                end
            end
        end

        ::next::
    end

    if pending then output(pending, pending.text, pending_len) end
end

return M