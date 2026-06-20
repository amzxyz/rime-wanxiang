-- charset_filter.lua
-- 功能：独立的字符集过滤与兜底组件
-- 逻辑：
-- 1. 支持配置多个选项，开启多个选项时 Base 和 Addlist 取并集，Blacklist 一票否决。
-- 2. 单字如果不符合字符集，直接丢弃（删除），不进行兜底。
-- 3. 词组如果包含生僻字，尝试从历史记录寻找同长度拼音的词组进行兜底。

local wanxiang = require("wanxiang/wanxiang")
local M = {}

-- 性能优化：本地化函数
local sub = string.sub
local utf8_codes = utf8.codes
local utf8_len = utf8.len

-- 检查交集
local function check_intersection(db_attr, config_base_set)
    if not db_attr or db_attr == "" then return false end
    for i = 1, #db_attr do
        local c = sub(db_attr, i, i)
        if config_base_set[c] then
            return true
        end
    end
    return false
end

-- 核心判定逻辑：检查单个 codepoint 是否在允许的字符集中
local function codepoint_in_charset(env, ctx, codepoint, text)
    if not env.charset_db then return true end

    local filters = env.filters
    if not filters or #filters == 0 then return true end

    local active_options_count = 0
    local is_allowed = false
    local is_blacklisted = false

    for _, rule in ipairs(filters) do
        local is_rule_active = false
        for _, opt_name in ipairs(rule.options) do
            if opt_name == "true" or ctx:get_option(opt_name) then
                is_rule_active = true
                break
            end
        end

        if is_rule_active then
            active_options_count = active_options_count + 1

            -- 1. 黑名单一票否决
            if rule.ban[codepoint] then
                is_blacklisted = true
                break
            end

            -- 2. Base 和 白名单取并集
            if not is_allowed then
                if rule.add[codepoint] then
                    is_allowed = true
                else
                    local attr = env.db_memo[text]
                    if attr == nil then
                        attr = env.charset_db:lookup(text) or ""
                        env.db_memo[text] = attr
                    end

                    if check_intersection(attr, rule.base_set) then
                        is_allowed = true
                    end
                end
            end
        end
    end

    -- 如果没有任何规则开启，默认全放行
    if active_options_count == 0 then return true end
    -- 命中黑名单，直接丢弃
    if is_blacklisted then return false end

    return is_allowed
end

-- 严格检查整个文本（单字/词组）是否完全符合字符集
local function is_text_in_charset(env, ctx, text)
    if not text or text == "" then return true end
    for _, codepoint in utf8_codes(text) do
        local character = utf8.char(codepoint)
        if wanxiang.IsChineseCharacter(character) then
            if not codepoint_in_charset(env, ctx, codepoint, character) then
                return false -- 只要遇到一个生僻字/黑名单字，直接返回 false
            end
        end
    end
    return true
end

-- 生命周期管理
function M.init(env)
    local cfg = env.engine and env.engine.schema and env.engine.schema.config
    
    local dist = (rime_api and rime_api.get_distribution_code_name and rime_api.get_distribution_code_name() or ""):lower()
    local charsetFile
    if dist == "weasel" then
        charsetFile = "lua/data/charset.reverse.bin"
    else
        charsetFile = wanxiang.get_filename_with_fallback("lua/data/charset.reverse.bin") or "lua/data/charset.reverse.bin"
    end

    env.charset_db = nil
    if ReverseDb then
        local ok, db = pcall(function() return ReverseDb(charsetFile) end)
        if ok and db then env.charset_db = db end
    end
    
    env.db_memo = {}
    env.filters = {}
    env.phrase_history_dict = {}

    if not cfg then return end

    local root_path = "charset"
    local list = cfg:get_list(root_path)
    if not list then return end

    for i = 0, list.size - 1 do
        local entry_path = root_path .. "/@" .. i
        local triggers = {}
        local opts_keys = {"option", "options"}
        
        for _, key in ipairs(opts_keys) do
            local key_path = entry_path .. "/" .. key
            local sub_list = cfg:get_list(key_path)
            if sub_list then
                for k = 0, sub_list.size - 1 do
                    local val = cfg:get_string(key_path .. "/@" .. k)
                    if val and val ~= "" then table.insert(triggers, val) end
                end
            else
                if cfg:get_bool(key_path) == true then
                    table.insert(triggers, "true")
                else
                    local val = cfg:get_string(key_path)
                    if val and val ~= "" and val ~= "true" then
                        table.insert(triggers, val)
                    end
                end
            end
        end

        if #triggers > 0 then
            local rule_base_set = {}
            local rule_add = {}
            local rule_ban = {}

            local base_str = cfg:get_string(entry_path .. "/base")
            if base_str and #base_str > 0 then
                for j = 1, #base_str do
                    rule_base_set[sub(base_str, j, j)] = true
                end
            end

            local function load_list_to_map(list_name, map)
                local lp = entry_path .. "/" .. list_name
                local sl = cfg:get_list(lp)
                if sl then
                    for k = 0, sl.size - 1 do
                        local val = cfg:get_string(lp .. "/@" .. k)
                        if val and val ~= "" then
                            for _, cp in utf8_codes(val) do map[cp] = true end
                        end
                    end
                end
            end

            load_list_to_map("addlist", rule_add)
            load_list_to_map("blacklist", rule_ban)

            table.insert(env.filters, {
                options  = triggers,
                base_set = rule_base_set,
                add      = rule_add,
                ban      = rule_ban
            })
        end
    end
end

function M.fini(env)
    env.charset_db = nil
    env.db_memo = nil
    env.filters = nil
    env.phrase_history_dict = nil
end
-- 核心过滤流水线
function M.func(input, env)
    local ctx = env.engine.context
    local code = ctx.input or ""
    local comp = ctx.composition

    -- 1. 维护历史输入字典
    if not code or code == "" or (comp and comp:empty()) then
        env.phrase_history_dict = {}
    else
        local current_code_length = #code
        for key_length in pairs(env.phrase_history_dict) do
            if key_length > current_code_length then
                env.phrase_history_dict[key_length] = nil
            end
        end
    end

    -- 2. 判断当前是否需要开启字符集过滤
    local is_functional = false
    if wanxiang and wanxiang.s2t_conversion then
        is_functional = wanxiang.s2t_conversion(ctx)
    end
    
    local charset_active = (env.filters and #env.filters > 0) and (not is_functional)
    
    if #code == 5 and code:sub(-1):find("[^%w]") then
        charset_active = false
    end

    -- 3. 遍历候选词
    local has_recorded_history = false 
    
    -- 内部帮助函数：记录第一个合法词并推入管道
    local function yield_and_record(cand, text)
        if not has_recorded_history and text and text ~= "" and (utf8_len(text) or 0) >= 1 then
            env.phrase_history_dict[#code] = text
            has_recorded_history = true
        end
        yield(cand)
    end

    for cand in input:iter() do
        local text = cand.text
        
        -- 如果未开启过滤，直接放行并记录历史
        if not charset_active or text == "" then
            yield_and_record(cand, text)
        else
            local text_length = utf8_len(text)
            -- 判断文本（无论单字还是词组）是否合规
            local text_is_valid = is_text_in_charset(env, ctx, text)

            if text_length < 2 then
                -- 【单字逻辑】：如果不符合就直接丢弃，不执行兜底
                if text_is_valid then
                    yield_and_record(cand, text)
                end
            else
                -- 【词组逻辑】
                if text_is_valid then
                    -- 不含生僻字，直接放行
                    yield_and_record(cand, text)
                else
                    -- 含有生僻字，开始词组兜底
                    local fallback_text = nil
                    local current_code_length = #code
                    
                    -- 必须从 current_code_length 开始找，否则会错过刚打出来的首选词！
                    for history_length = current_code_length, 1, -1 do
                        local history_text = env.phrase_history_dict[history_length]
                        if history_text and utf8_len(history_text) == text_length then
                            fallback_text = history_text
                            break
                        end
                    end

                    if fallback_text then
                        -- 构造兜底候选
                        local preedit_text = cand.preedit or code
                        if #preedit_text > 1 and preedit_text:sub(-1):match("[%w%p]") then
                            preedit_text = sub(preedit_text, 1, -2) .. " " .. sub(preedit_text, -1)
                        end
                        
                        local nc = Candidate(cand.type, cand.start, cand._end, fallback_text, cand.comment or "")
                        nc.preedit = preedit_text
                        
                        -- 验证兜底词自身绝对不含生僻字
                        if is_text_in_charset(env, ctx, nc.text) then
                            yield_and_record(nc, nc.text)
                        end
                    end
                end
            end
        end
    end
end

return M