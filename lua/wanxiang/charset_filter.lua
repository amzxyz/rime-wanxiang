-- charset_filter.lua
-- 功能：独立的字符集过滤与兜底组件
-- 逻辑：
-- 1. 支持配置多个选项，开启多个选项时 Base 和 Addlist 取并集，Blacklist 一票否决。
-- 2. 单字如果不符合字符集，直接丢弃（删除），不进行兜底。
-- 3. 词组如果包含生僻字，尝试从历史记录寻找同长度拼音的词组进行兜底。

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

local function str_to_mask(s)
    if not s or s == "" then return 0 end
    local m = 0
    for i = 1, #s do
        m = bit.bor(m, bit.lshift(1, bit.band(byte(s, i), 0x3F)))
    end
    return m
end

local function get_char_mask(env, char)
    -- 先查缓存
    local mask = env.db_memo[char]
    if mask ~= nil then return mask end
    if not env.charset_db then return 0 end
    local attr = env.charset_db:lookup(char)
    if attr and attr ~= "" then
        mask = str_to_mask(attr)
        env.db_memo[char] = mask
        return mask
    else
        return 0
    end
end

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
            else
                local m = get_char_mask(env, char)
                if m ~= 0 and bit.band(m, rule.base) ~= 0 then
                    allowed = true
                end
            end
        end
    end

    local result
    if banned then
        result = false
    else
        result = allowed
    end

    cache[codepoint] = result
    return result
end

local function text_is_valid(env, text, active_rules, cache)
    if not text or text == "" then return true end

    for _, cp in utf8_codes(text) do
        local char = utf8_char(cp)
        if wanxiang.IsChineseCharacter(char) then
            if not char_is_valid(env, cp, char, active_rules, cache) then
                return false
            end
        end
    end
    return true
end

local function preprocess(raw)
    return {
        options = raw.options,
        base    = str_to_mask(raw.base_str),
        add     = raw.add,
        ban     = raw.ban,
    }
end

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
            else
                if cfg:get_bool(kp) then
                    insert(triggers, "true")
                else
                    local v = cfg:get_string(kp)
                    if v and v ~= "" and v ~= "true" then insert(triggers, v) end
                end
            end
        end

        if #triggers == 0 then goto next end

        local base_str = cfg:get_string(ep .. "/base") or ""
        local add = {}
        local ban = {}

        local function load_list(name, t)
            local lp = ep .. "/" .. name
            local sl = cfg:get_list(lp)
            if sl then
                for k = 0, sl.size - 1 do
                    local v = cfg:get_string(lp .. "/@" .. k)
                    if v and v ~= "" then
                        for _, cp in utf8_codes(v) do t[cp] = true end
                    end
                end
            end
        end

        load_list("addlist", add)
        load_list("blacklist", ban)

        insert(rules, preprocess({
            options  = triggers,
            base_str = base_str,
            add      = add,
            ban      = ban,
        }))

        ::next::
    end

    return rules
end

local function get_active_rules(env, ctx)
    local filters = env.filters
    if not filters or #filters == 0 then return nil end

    if wanxiang and wanxiang.s2t_conversion and wanxiang.s2t_conversion(ctx) then
        return nil
    end

    local active = {}
    for i = 1, #filters do
        local rule = filters[i]
        for j = 1, #rule.options do
            if rule.options[j] == "true" or ctx:get_option(rule.options[j]) then
                insert(active, rule)
                break
            end
        end
    end

    return #active > 0 and active or nil
end

function M.init(env)
    local cfg = env.engine and env.engine.schema and env.engine.schema.config

    -- 加载数据库
    local dist = (rime_api and rime_api.get_distribution_code_name and rime_api.get_distribution_code_name() or ""):lower()
    local fname
    if dist == "weasel" then
        fname = "lua/data/charset.reverse.bin"
    else
        fname = wanxiang.get_filename_with_fallback("lua/data/charset.reverse.bin") or "lua/data/charset.reverse.bin"
    end

    env.charset_db = nil
    if ReverseDb then
        local ok, db = pcall(function() return ReverseDb(fname) end)
        if ok and db then env.charset_db = db end
    end

    env.db_memo = {}
    env.filters = {}
    env.phrase_history_dict = {}

    if cfg then
        env.filters = load_rules(cfg, "charset")
    end

    env.opt_update_conn = env.engine.context.option_update_notifier:connect(function(ctx, name)
        for i = 1, #env.filters do
            local opts = env.filters[i].options
            for j = 1, #opts do
                if name == opts[j] then
                    ctx:refresh_non_confirmed_composition()
                    return
                end
            end
        end
    end)
end

function M.fini(env)
    if env.opt_update_conn then
        env.opt_update_conn:disconnect()
        env.opt_update_conn = nil
    end
    env.charset_db = nil
    env.db_memo = nil
    env.filters = nil
    env.phrase_history_dict = nil
end

function M.func(input, env)
    local ctx = env.engine.context
    local code = ctx.input or ""
    local comp = ctx.composition
    local code_len = #code
    local cache = {}
    -- 清理过期历史记录
    if not code or code == "" or (comp and comp:empty()) then
        env.phrase_history_dict = {}
    else
        for k in pairs(env.phrase_history_dict) do
            if k > code_len then env.phrase_history_dict[k] = nil end
        end
    end

    -- 获取活跃规则
    local active_rules = get_active_rules(env, ctx)
    local charset_on = (active_rules ~= nil)

    -- 5码豁免
    if charset_on and code_len == 5 then
        local last = sub(code, -1)
        if not last:match("[%w]") then charset_on = false end
    end

    local has_valid = false
    local pending = nil
    local pending_len = 0
    local recorded = false

    local function output(cand, text, text_len)
        if not recorded and text and text ~= "" and (text_len or 0) >= 1 then
            env.phrase_history_dict[code_len] = text
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
            else
                output(pending, pending.text, pending_len)
                has_valid = true
                pending = nil
            end
        end

        if not charset_on or text == "" then
            output(cand, text, text_len)
            has_valid = true
        elseif text_is_valid(env, text, active_rules, cache) then
            output(cand, text, text_len)
            has_valid = true
        elseif text_len >= 2 and (cand.type == "phrase" or cand.type == "user_phrase") then
            -- 词库中真实存在的多字词组，直接放行不过滤
            output(cand, text, text_len)
            has_valid = true
        elseif text_len >= 2 and not has_valid and not pending then
            -- 兜底,过早兜底会造成后续流程为空的判断，因此这里先放行单字
            local fb = nil

            for hl = code_len, 1, -1 do
                local h = env.phrase_history_dict[hl]
                if h and utf8_len(h) == text_len then
                    fb = h
                    break
                end
            end

            if not fb then
                for hl = code_len - 1, 1, -1 do
                    local h = env.phrase_history_dict[hl]
                    if h then
                        fb = h .. sub(code, hl + 1)
                        break
                    end
                end
            end

            if fb then
                local pre = cand.preedit or code
                if #pre > 1 and pre:sub(-1):match("[%w%p]") then
                    pre = sub(pre, 1, -2) .. " " .. sub(pre, -1)
                end
                local nc = Candidate("fallback", cand.start, cand._end, fb, cand.comment or "")
                nc.preedit = pre

                if text_is_valid(env, nc.text, active_rules, cache) then
                    pending = nc
                    pending_len = text_len
                end
            end
        end

        ::next::
    end

    if pending then
        output(pending, pending.text, pending_len)
    end
end

return M