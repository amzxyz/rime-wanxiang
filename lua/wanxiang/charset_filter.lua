-- charset_filter.lua
-- 功能：独立的字符集过滤与兜底组件
-- 逻辑：
-- 1. 支持配置多个选项，开启多个选项时 Base 和 Addlist 取并集，Blacklist 一票否决。
-- 2. 单字如果不符合字符集，直接丢弃（删除），不进行兜底。
-- 3. 候选中仅有一个字符不符合字符集时，才尝试从历史记录生成兜底。
-- 4. table、user_table、completion 和 fallback 候选不能写入兜底历史。
-- 5. 兜底只复用上一输入编码对应、相同词长的历史；候选文字不拼接剩余编码，预编辑沿用上一稳定切分并追加新输入。
-- 6. user_phrase 和 user_table 完全豁免字符集过滤。
-- 7. 配置根节点为 charset_filter，使用 Rime Config 对象直接加载。

local wanxiang = require("wanxiang/wanxiang")
local M = {}

local sub = string.sub
local byte = string.byte
local match = string.match
local utf8_codes = utf8.codes
local utf8_len = utf8.len
local utf8_char = utf8.char
local pairs = pairs
local pcall = pcall
local bit = require("wanxiang/bit")
local bit_bor = bit.bor
local bit_band = bit.band
local bit_lshift = bit.lshift

local function clear_array(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function clear_map(t)
    for k in pairs(t) do t[k] = nil end
end

-- 释放当前组件持有的 notifier 与 ReverseDb；init 重入和 fini 共用。
local function release_runtime(env)
    if env.opt_update_conn then
        pcall(function() env.opt_update_conn:disconnect() end)
        env.opt_update_conn = nil
    end

    local db = env.charset_db
    env.charset_db = nil

    if db and db.close then
        pcall(function() db:close() end)
    end
end

-- 将字符集属性字符串转换为位掩码。
local function str_to_mask(s)
    if not s or s == "" then return 0 end

    local mask = 0
    for i = 1, #s do
        mask = bit_bor(mask, bit_lshift(1, bit_band(byte(s, i), 0x3F)))
    end
    return mask
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
-- 使用码点作为缓存键；数据库未命中时也缓存 0。
local function get_char_mask(env, codepoint)
    local mask = env.db_memo[codepoint]
    if mask ~= nil then return mask end

    local db = get_charset_db(env)
    if not db then
        env.db_memo[codepoint] = 0
        return 0
    end

    local attr = db:lookup(utf8_char(codepoint))
    mask = attr and attr ~= "" and str_to_mask(attr) or 0
    env.db_memo[codepoint] = mask
    return mask
end

-- 判断单个码点是否符合当前启用规则。
-- 同一轮候选流中按码点缓存结果，非汉字也缓存为 true。
local function codepoint_is_valid(env, codepoint, active_rules, cache)
    local result = cache[codepoint]
    if result ~= nil then return result end

    local char = utf8_char(codepoint)
    if not wanxiang.IsChineseCharacter(char) then
        cache[codepoint] = true
        return true
    end

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
                local mask = get_char_mask(env, codepoint)
                if mask ~= 0 and bit_band(mask, rule.base) ~= 0 then
                    allowed = true
                end
            end
        end
    end

    result = not banned and allowed
    cache[codepoint] = result
    return result
end

-- 一次 UTF-8 遍历同时得到：
-- 1. 文本码点长度；
-- 2. 全部汉字是否合法；
-- 3. 是否仅有一个汉字非法，可用于兜底。
local function inspect_text(env, text, active_rules, cache)
    if not text or text == "" then return 0, true, false end

    local text_len = 0
    local invalid_count = 0

    for _, codepoint in utf8_codes(text) do
        text_len = text_len + 1

        if not codepoint_is_valid(env, codepoint, active_rules, cache) then
            invalid_count = invalid_count + 1
        end
    end

    local all_valid = invalid_count == 0
    -- 允许唯一非法字符出现在任意位置；真正兜底仍受“完整覆盖当前编码段 +
    -- 直接上一输入状态 + 相同词长”三重约束，避免无关历史误替换。
    local can_fallback = text_len >= 2
        and invalid_count == 1

    return text_len, all_valid, can_fallback
end

-- 直接读取 Rime ConfigItem，不再拼接 /@n 配置路径。
local function append_config(item, target, as_codepoints)
    if not item then return end

    local function append(value, scalar)
        if not value then return end
        local text = value:get_string()

        if scalar then
            if value:get_bool() then text = "true"
            elseif text == "true" then return end
        end
        if not text or text == "" then return end

        if as_codepoints then
            for _, codepoint in utf8_codes(text) do target[codepoint] = true end
        else
            target[#target + 1] = text
        end
    end

    if item.type == "kList" then
        local list = item:get_list()
        for i = 0, list.size - 1 do append(list:get_value_at(i), false) end
    elseif item.type == "kScalar" and not as_codepoints then
        append(item:get_value(), true)
    end
end

local function load_rules(cfg)
    local rules = {}
    local list = cfg:get_list("charset_filter")
    if not list then return rules end

    for i = 0, list.size - 1 do
        local item = list:get_at(i)
        local rule = item and item:get_map()
        if not rule then goto continue end

        local triggers = {}
        append_config(rule:get("option"), triggers, false)
        append_config(rule:get("options"), triggers, false)
        if #triggers == 0 then goto continue end

        local add = {}
        local ban = {}
        local base = rule:get_value("base")
        append_config(rule:get("addlist"), add, true)
        append_config(rule:get("blacklist"), ban, true)

        rules[#rules + 1] = {
            options = triggers,
            base = str_to_mask(base and base:get_string() or ""),
            add = add,
            ban = ban,
        }

        ::continue::
    end

    return rules
end

-- 返回当前输入状态下已经启用的规则。
-- 复用 env.active_rules，避免每轮创建临时数组。
local function get_active_rules(env, ctx)
    local active = env.active_rules
    clear_array(active)

    local filters = env.filters
    if not filters or #filters == 0 then return nil end

    if wanxiang and wanxiang.is_special_mode
        and wanxiang.is_special_mode(ctx)
    then
        return nil
    end

    for i = 1, #filters do
        local rule = filters[i]

        for j = 1, #rule.options do
            local option = rule.options[j]
            if option == "true" or ctx:get_option(option) then
                active[#active + 1] = rule
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
        and cand_type ~= "fallback"
end

-- 判断候选是否完整覆盖当前活动编码段。
local function covers_current_segment(cand, comp, code_len)
    local seg = comp and comp:back()

    if seg then
        return cand.start == seg.start and cand._end == seg._end
    end

    return cand.start == 0 and cand._end == code_len
end

-- 读取当前编码的直接前一输入状态中、相同词长的历史候选。
local function get_previous_history(env, code, text_len)
    if not code or #code <= 1 then return nil end

    local history = env.phrase_history
    local previous = history and history[sub(code, 1, -2)]
    if not previous or previous.text_len ~= text_len then return nil end

    return previous
end

-- 兜底时复用上一稳定状态的预编辑切分，只把本轮新增编码作为新尾段追加。
local function build_fallback_preedit(history, code)
    local previous_code = sub(code, 1, -2)
    local preedit = history.preedit or previous_code
    local suffix = sub(code, #previous_code + 1)

    if suffix == "" then return preedit end
    return preedit .. (sub(preedit, -1) == " " and "" or " ") .. suffix
end

-- 初始化过滤规则、历史缓存和选项监听。
function M.init(env)
    local cfg = env.engine and env.engine.schema
        and env.engine.schema.config

    env.charset_db = nil
    env.charset_db_checked = false
    env.db_memo = {}
    env.filters = {}
    env.active_rules = {}
    env.valid_cache = {}
    env.phrase_history = {}

    if cfg then env.filters = load_rules(cfg) end

    env.opt_update_conn =
        env.engine.context.option_update_notifier:connect(
            function(ctx, name)
                for i = 1, #env.filters do
                    local options = env.filters[i].options

                    for j = 1, #options do
                        if name == options[j] then
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
    release_runtime(env)

    env.charset_db_checked = nil
    env.db_memo = nil
    env.filters = nil
    env.active_rules = nil
    env.valid_cache = nil
    env.phrase_history = nil
end

-- 过滤非法字符，并在必要时生成同长度历史兜底候选。
function M.func(input, env)
    local ctx = env.engine.context
    local code = ctx.input or ""
    local comp = ctx.composition
    local code_len = #code
    local cache = env.valid_cache

    clear_map(cache)

    -- 输入清空时结束当前兜底历史上下文。
    if code == "" or (comp and comp:empty()) then
        clear_map(env.phrase_history)
    end

    local active_rules = get_active_rules(env, ctx)
    local charset_on = active_rules ~= nil

    -- 5码豁免
    if charset_on and code_len == 5 then
        local last = sub(code, -1)
        if not match(last, "[%w]") then charset_on = false end
    end

    local has_valid = false
    local recorded = false

    -- 输出候选；只有完整覆盖当前编码段的可靠候选才写入历史。
    local function output(cand, text, text_len, remember)
        if remember and not recorded and code ~= ""
            and can_record_history(cand)
            and covers_current_segment(cand, comp, code_len)
            and text and text ~= "" and (text_len or 0) >= 1
        then
            env.phrase_history[code] = {
                text = text,
                text_len = text_len,
                preedit = cand.preedit or code,
            }
            recorded = true
        end

        yield(cand)
    end

    for cand in input:iter() do
        local text = cand.text or ""
        local cand_type = cand.type or ""
        local bypass_charset = charset_on
            and (cand_type == "user_phrase" or cand_type == "user_table")

        local text_len
        local all_valid = true
        local can_fallback = false

        if charset_on and text ~= "" and not bypass_charset then
            text_len, all_valid, can_fallback =
                inspect_text(env, text, active_rules, cache)
        else
            text_len = text == "" and 0 or (utf8_len(text) or 0)
        end

        if not charset_on or text == "" or bypass_charset then
            -- user_phrase / user_table 在字符集检查前完全放行。
            output(cand, text, text_len, text ~= "")
            has_valid = true
        elseif all_valid then
            output(cand, text, text_len, true)
            has_valid = true
        elseif text_len >= 2 and cand_type == "phrase" then
            -- phrase 保持原有逻辑：完成字符集检查后，多字词仍直接放行。
            output(cand, text, text_len, false)
            has_valid = true
        elseif not has_valid
            and covers_current_segment(cand, comp, code_len)
            and can_fallback
        then
            local fallback = get_previous_history(env, code, text_len)

            if fallback then
                local replacement = Candidate(
                    "fallback",
                    cand.start,
                    cand._end,
                    fallback.text,
                    cand.comment or ""
                )
                replacement.preedit = build_fallback_preedit(fallback, code)

                local fallback_len, fallback_valid =
                    inspect_text(env, replacement.text, active_rules, cache)

                if fallback_valid then
                    output(replacement, replacement.text, fallback_len, false)
                    has_valid = true
                end
            end
        end

    end

end

return M
