--@amzxyz https://github.com/amzxyz/rime_wanxiang

--wanxiang_lookup: #设置归属于super_lookup.lua
  --tags: [ abc ]  # 检索当前tag的候选
  --key: "`"       # 输入中反查引导符，要添加到 speller/alphabet
  --lookup: [ wanxiang_reverse ] #反查滤镜数据库，万象都合并为一个了

-- 获取 wanxiang 模块
local function get_wanxiang()
    local ok, mod = pcall(function() return require('wanxiang') end)
    if ok and type(mod) == 'table' then return mod end
    if type(_G.wanxiang) == 'table' then return _G.wanxiang end
    return nil
end

-- 各输入法类型对应的转换规则
-- flypy/mspy/sogou/abc/ziguang/pyjj/gbpy/lxsq/zrlong/hxlong
local LOCAL_PROJECTION_RULES = {
    -- 全拼（pinyin）
    pinyin = {
        "xform/'//",
        "derive/^([nl])ue$/$1ve/",
        "derive/'([nl])ue$/'$1ve/",
        "derive/^([jqxy])u/$1v/",
        "derive/'([jqxy])u/'$1v/",
    },

    -- 自然码（zrm）
    zrm = {
        "derive/^([jqxy])u(?=^|$|')/$1v/",
        "derive/'([jqxy])u(?=^|$|')/'$1v/",
        "derive/^([aoe])([ioun])(?=^|$|')/$1$1$2/",
        "derive/'([aoe])([ioun])(?=^|$|')/'$1$1$2/",
        "xform/^([aoe])(ng)?(?=^|$|')/$1$1$2/",
        "xform/'([aoe])(ng)?(?=^|$|')/'$1$1$2/",
        "xform/iu(?=^|$|')/<q>/",
        "xform/[iu]a(?=^|$|')/<w>/",
        "xform/[uv]an(?=^|$|')/<r>/",
        "xform/[uv]e(?=^|$|')/<t>/",
        "xform/ing(?=^|$|')|uai(?=^|$|')/<y>/",
        "xform/^sh/<u>/",
        "xform/^ch/<i>/",
        "xform/^zh/<v>/",
        "xform/'sh/'<u>/",
        "xform/'ch/'<i>/",
        "xform/'zh/'<v>/",
        "xform/uo(?=^|$|')/<o>/",
        "xform/[uv]n(?=^|$|')/<p>/",
        "xform/([a-z>])i?ong(?=^|$|')/$1<s>/",
        "xform/[iu]ang(?=^|$|')/<d>/",
        "xform/([a-z>])en(?=^|$|')/$1<f>/",
        "xform/([a-z>])eng(?=^|$|')/$1<g>/",
        "xform/([a-z>])ang(?=^|$|')/$1<h>/",
        "xform/ian(?=^|$|')/<m>/",
        "xform/([a-z>])an(?=^|$|')/$1<j>/",
        "xform/iao(?=^|$|')/<c>/",
        "xform/([a-z>])ao(?=^|$|')/$1<k>/",
        "xform/([a-z>])ai(?=^|$|')/$1<l>/",
        "xform/([a-z>])ei(?=^|$|')/$1<z>/",
        "xform/ie(?=^|$|')/<x>/",
        "xform/ui(?=^|$|')/<v>/",
        "xform/([a-z>])ou(?=^|$|')/$1<b>/",
        "xform/in(?=^|$|')/<n>/",
        "xform/'|<|>//",
    },

    -- 小鹤（flypy）
    flypy = {
        "derive/^([jqxy])u(?=^|$|')/$1v/",
        "derive/'([jqxy])u(?=^|$|')/'$1v/",
        "derive/^([aoe])([ioun])(?=^|$|')/$1$1$2/",
        "derive/'([aoe])([ioun])(?=^|$|')/'$1$1$2/",
        "xform/^([aoe])(ng)?(?=^|$|')/$1$1$2/",
        "xform/'([aoe])(ng)?(?=^|$|')/'$1$1$2/",
        "xform/iu(?=^|$|')/<q>/",
        "xform/(.)ei(?=^|$|')/$1<w>/",
        "xform/uan(?=^|$|')/<r>/",
        "xform/[uv]e(?=^|$|')/<t>/",
        "xform/un(?=^|$|')/<y>/",
        "xform/^sh/<u>/",
        "xform/^ch/<i>/",
        "xform/^zh/<v>/",
        "xform/'sh/'<u>/",
        "xform/'ch/'<i>/",
        "xform/'zh/'<v>/",
        "xform/uo(?=^|$|')/<o>/",
        "xform/ie(?=^|$|')/<p>/",
        "xform/([a-z>])i?ong(?=^|$|')/$1<s>/",
        "xform/ing(?=^|$|')|uai(?=^|$|')/<k>/",
        "xform/([a-z>])ai(?=^|$|')/$1<d>/",
        "xform/([a-z>])en(?=^|$|')/$1<f>/",
        "xform/([a-z>])eng(?=^|$|')/$1<g>/",
        "xform/[iu]ang(?=^|$|')/<l>/",
        "xform/([a-z>])ang(?=^|$|')/$1<h>/",
        "xform/ian(?=^|$|')/<m>/",
        "xform/([a-z>])an(?=^|$|')/$1<j>/",
        "xform/([a-z>])ou(?=^|$|')/$1<z>/",
        "xform/[iu]a(?=^|$|')/<x>/",
        "xform/iao(?=^|$|')/<n>/",
        "xform/([a-z>])ao(?=^|$|')/$1<c>/",
        "xform/ui(?=^|$|')/<v>/",
        "xform/in(?=^|$|')/<b>/",
        "xform/'|<|>//",
    },

    -- 微软（mspy）
    mspy = {
        "derive/^([jqxy])u(?=^|$|')/$1v/",
        "derive/'([jqxy])u(?=^|$|')/'$1v/",
        "derive/^([aoe].*)(?=^|$|')/o$1/",
        "derive/'([aoe].*)(?=^|$|')/'o$1/",
        "xform/^([ae])(.*)(?=^|$|')/$1$1$2/",
        "xform/'([ae])(.*)(?=^|$|')/'$1$1$2/",
        "xform/iu(?=^|$|')/<q>/",
        "xform/[iu]a(?=^|$|')/<w>/",
        "xform/er(?=^|$|')|[uv]an(?=^|$|')/<r>/",
        "xform/[uv]e(?=^|$|')/<t>/",
        "xform/v(?=^|$|')|uai(?=^|$|')/<y>/",
        "xform/^sh/<u>/",
        "xform/^ch/<i>/",
        "xform/^zh/<v>/",
        "xform/'sh/'<u>/",
        "xform/'ch/'<i>/",
        "xform/'zh/'<v>/",
        "xform/uo(?=^|$|')/<o>/",
        "xform/[uv]n(?=^|$|')/<p>/",
        "xform/([a-z>])i?ong(?=^|$|')/$1<s>/",
        "xform/[iu]ang(?=^|$|')/<d>/",
        "xform/([a-z>])en(?=^|$|')/$1<f>/",
        "xform/([a-z>])eng(?=^|$|')/$1<g>/",
        "xform/([a-z>])ang(?=^|$|')/$1<h>/",
        "xform/ian(?=^|$|')/<m>/",
        "xform/([a-z>])an(?=^|$|')/$1<j>/",
        "xform/iao(?=^|$|')/<c>/",
        "xform/([a-z>])ao(?=^|$|')/$1<k>/",
        "xform/([a-z>])ai(?=^|$|')/$1<l>/",
        "xform/([a-z>])ei(?=^|$|')/$1<z>/",
        "xform/ie(?=^|$|')/<x>/",
        "xform/ui(?=^|$|')/<v>/",
        "derive/<t>(?=^|$|')/<v>/",
        "xform/([a-z>])ou(?=^|$|')/$1<b>/",
        "xform/in(?=^|$|')/<n>/",
        "xform/ing(?=^|$|')/;/",
        "xform/'|<|>//",
    },

    -- 搜狗双拼（sogou）
    sogou = {
        "derive/^([jqxy])u(?=^|$|')/$1v/",
        "derive/'([jqxy])u(?=^|$|')/'$1v/",
        "derive/^([aoe].*)(?=^|$|')/o$1/",
        "derive/'([aoe].*)(?=^|$|')/'o$1/",
        "xform/^([ae])(.*)(?=^|$|')/$1$1$2/",
        "xform/'([ae])(.*)(?=^|$|')/'$1$1$2/",
        "xform/iu(?=^|$|')/<q>/",
        "xform/[iu]a(?=^|$|')/<w>/",
        "xform/er(?=^|$|')|[uv]an(?=^|$|')/<r>/",
        "xform/[uv]e(?=^|$|')/<t>/",
        "xform/v(?=^|$|')|uai(?=^|$|')/<y>/",
        "xform/^sh/<u>/",
        "xform/^ch/<i>/",
        "xform/^zh/<v>/",
        "xform/'sh/'<u>/",
        "xform/'ch/'<i>/",
        "xform/'zh/'<v>/",
        "xform/uo(?=^|$|')/<o>/",
        "xform/[uv]n(?=^|$|')/<p>/",
        "xform/([a-z>])i?ong(?=^|$|')/$1<s>/",
        "xform/[iu]ang(?=^|$|')/<d>/",
        "xform/([a-z>])en(?=^|$|')/$1<f>/",
        "xform/([a-z>])eng(?=^|$|')/$1<g>/",
        "xform/([a-z>])ang(?=^|$|')/$1<h>/",
        "xform/ian(?=^|$|')/<m>/",
        "xform/([a-z>])an(?=^|$|')/$1<j>/",
        "xform/iao(?=^|$|')/<c>/",
        "xform/([a-z>])ao(?=^|$|')/$1<k>/",
        "xform/([a-z>])ai(?=^|$|')/$1<l>/",
        "xform/([a-z>])ei(?=^|$|')/$1<z>/",
        "xform/ie(?=^|$|')/<x>/",
        "xform/ui(?=^|$|')/<v>/",
        "xform/([a-z>])ou(?=^|$|')/$1<b>/",
        "xform/in(?=^|$|')/<n>/",
        "xform/ing(?=^|$|')/;/",
        "xform/'|<|>//",
    },

    -- 智能（abc）
    abc = {
        "xform/^zh/<a>/",
        "xform/^ch/<e>/",
        "xform/^sh/<v>/",
        "xform/'zh/'<a>/",
        "xform/'ch/'<e>/",
        "xform/'sh/'<v>/",
        "xform/^([aoe].*)(?=^|$|')/<o>$1/",
        "xform/'([aoe].*)(?=^|$|')/'<o>$1/",
        "xform/ei(?=^|$|')/<q>/",
        "xform/ian(?=^|$|')/<w>/",
        "xform/er(?=^|$|')|iu(?=^|$|')/<r>/",
        "xform/[iu]ang(?=^|$|')/<t>/",
        "xform/ing(?=^|$|')/<y>/",
        "xform/uo(?=^|$|')/<o>/",
        "xform/uan(?=^|$|')/<p>/",
        "xform/([a-z>])i?ong(?=^|$|')/$1<s>/",
        "xform/[iu]a(?=^|$|')/<d>/",
        "xform/en(?=^|$|')/<f>/",
        "xform/eng(?=^|$|')/<g>/",
        "xform/ang(?=^|$|')/<h>/",
        "xform/an(?=^|$|')/<j>/",
        "xform/iao(?=^|$|')/<z>/",
        "xform/ao(?=^|$|')/<k>/",
        "xform/in(?=^|$|')|uai(?=^|$|')/<c>/",
        "xform/ai(?=^|$|')/<l>/",
        "xform/ie(?=^|$|')/<x>/",
        "xform/ou(?=^|$|')/<b>/",
        "xform/un(?=^|$|')/<n>/",
        "xform/[uv]e(?=^|$|')|ui(?=^|$|')/<m>/",
        "xform/'|<|>//",
    },

    -- 紫光（ziguang）
    ziguang = {
        "derive/^([jqxy])u(?=^|$|')/$1v/",
        "derive/'([jqxy])u(?=^|$|')/'$1v/",
        "xform/'([aoe].*)(?=^|$|')/'<o>$1/",
        "xform/^([aoe].*)(?=^|$|')/<o>$1/",
        "xform/en(?=^|$|')/<w>/",
        "xform/eng(?=^|$|')/<t>/",
        "xform/in(?=^|$|')|uai(?=^|$|')/<y>/",
        "xform/^zh/<u>/",
        "xform/^sh/<i>/",
        "xform/'zh/'<u>/",
        "xform/'sh/'<i>/",
        "xform/uo(?=^|$|')/<o>/",
        "xform/ai(?=^|$|')/<p>/",
        "xform/^ch/<a>/",
        "xform/'ch/'<a>/",
        "xform/[iu]ang(?=^|$|')/<g>/",
        "xform/ang(?=^|$|')/<s>/",
        "xform/ie(?=^|$|')/<d>/",
        "xform/ian(?=^|$|')/<f>/",
        "xform/([a-z>])i?ong(?=^|$|')/$1<h>/",
        "xform/er(?=^|$|')|iu(?=^|$|')/<j>/",
        "xform/ei(?=^|$|')/<k>/",
        "xform/uan(?=^|$|')/<l>/",
        "xform/ing(?=^|$|')/;/",
        "xform/ou(?=^|$|')/<z>/",
        "xform/[iu]a(?=^|$|')/<x>/",
        "xform/iao(?=^|$|')/<b>/",
        "xform/ue(?=^|$|')|ui(?=^|$|')|ve(?=^|$|')/<n>/",
        "xform/un(?=^|$|')/<m>/",
        "xform/ao(?=^|$|')/<q>/",
        "xform/an(?=^|$|')/<r>/",
        "xform/'|<|>//",
    },

    -- 拼音加加（pyjj）
    pyjj = {
        "derive/^([jqxy])u(?=^|$|')/$1v/",
        "derive/'([jqxy])u(?=^|$|')/'$1v/",
        "derive/^([aoe])([ioun])(?=^|$|')/$1$1$2/",
        "derive/'([aoe])([ioun])(?=^|$|')/'$1$1$2/",
        "xform/^([aoe])(ng)?(?=^|$|')/$1$1$2/",
        "xform/'([aoe])(ng)?(?=^|$|')/'$1$1$2/",
        "xform/iu(?=^|$|')/<n>/",
        "xform/[iu]a(?=^|$|')/<b>/",
        "xform/[uv]an(?=^|$|')/<c>/",
        "xform/[uv]e(?=^|$|')|uai(?=^|$|')/<x>/",
        "xform/ing(?=^|$|')|er(?=^|$|')/<q>/",
        "xform/^sh/<i>/",
        "xform/^ch/<u>/",
        "xform/^zh/<v>/",
        "xform/'sh/'<i>/",
        "xform/'ch/'<u>/",
        "xform/'zh/'<v>/",
        "xform/uo(?=^|$|')/<o>/",
        "xform/[uv]n(?=^|$|')/<z>/",
        "xform/([a-z>])i?ong(?=^|$|')/$1<y>/",
        "xform/[iu]ang(?=^|$|')/<h>/",
        "xform/([a-z>])en(?=^|$|')/$1<r>/",
        "xform/([a-z>])eng(?=^|$|')/$1<t>/",
        "xform/([a-z>])ang(?=^|$|')/$1<g>/",
        "xform/ian(?=^|$|')/<j>/",
        "xform/([a-z>])an(?=^|$|')/$1<f>/",
        "xform/iao(?=^|$|')/<k>/",
        "xform/([a-z>])ao(?=^|$|')/$1<d>/",
        "xform/([a-z>])ai(?=^|$|')/$1<s>/",
        "xform/([a-z>])ei(?=^|$|')/$1<w>/",
        "xform/ie(?=^|$|')/<m>/",
        "xform/ui(?=^|$|')/<v>/",
        "xform/([a-z>])ou(?=^|$|')/$1<p>/",
        "xform/in(?=^|$|')/<l>/",
        "xform/'|<|>//",
    },

    -- 国标双拼（gbpy）
    gbpy = {
        "derive/^([aoe])([ioun])(?=^|$|')/$1$1$2/",
        "derive/'([aoe])([ioun])(?=^|$|')/'$1$1$2/",
        "xform/^([aoe])(ng)?(?=^|$|')/$1$1$2/",
        "xform/'([aoe])(ng)?(?=^|$|')/'$1$1$2/",
        "xform/iu(?=^|$|')/<y>/",
        "xform/(.)ei(?=^|$|')/$1<b>/",
        "xform/uan(?=^|$|')/<w>/",
        "xform/[uv]e(?=^|$|')/<x>/",
        "xform/un(?=^|$|')/<z>/",
        "xform/^sh/<u>/",
        "xform/^ch/<i>/",
        "xform/^zh/<v>/",
        "xform/'sh/'<u>/",
        "xform/'ch/'<i>/",
        "xform/'zh/'<v>/",
        "xform/uo(?=^|$|')/<o>/",
        "xform/ie(?=^|$|')/<t>/",
        "xform/([a-z>])i?ong(?=^|$|')/$1<s>/",
        "xform/ing(?=^|$|')|uai(?=^|$|')/<j>/",
        "xform/([a-z>])ai(?=^|$|')/$1<k>/",
        "xform/([a-z>])en(?=^|$|')/$1<r>/",
        "xform/([a-z>])eng(?=^|$|')/$1<h>/",
        "xform/[iu]ang(?=^|$|')/<n>/",
        "xform/([a-z>])ang(?=^|$|')/$1<g>/",
        "xform/ian(?=^|$|')/<d>/",
        "xform/([a-z>])an(?=^|$|')/$1<f>/",
        "xform/([a-z>])ou(?=^|$|')/$1<p>/",
        "xform/[iu]a(?=^|$|')/<q>/",
        "xform/iao(?=^|$|')/<m>/",
        "xform/([a-z>])ao(?=^|$|')/$1<c>/",
        "xform/ui(?=^|$|')/<v>/",
        "xform/in(?=^|$|')/<l>/",
        "xform/'|<|>//",
    },
}

-- 根据输入法类型选择一套规则（只看 id）
local function pick_rules(env)
    local wanx = get_wanxiang()
    local id = 'pinyin'
    if wanx and type(wanx.get_input_method_type) == 'function' then
        local ok, ret_id = pcall(wanx.get_input_method_type, env)
        if ok and type(ret_id) == 'string' and #ret_id > 0 then
            id = ret_id
        end
    end
    return LOCAL_PROJECTION_RULES[id] or LOCAL_PROJECTION_RULES['pinyin'] or {}
end

------------------------------------------------------------
-- 工具函数
------------------------------------------------------------
local function alt_lua_punc(s)
    if s then
        return s:gsub('([%.%+%-%*%?%[%]%^%$%(%)%%])', '%%%1')
    else
        return ''
    end
end

-- 仅保留纯小写字母
local function is_pure_lower_alpha(s)
    return type(s) == "string" and s:match("^[a-z]+$") ~= nil
end

local function is_all_upper(s) return s:match('^%u+$') ~= nil end
local function is_all_lower(s) return s:match('^%l+$') ~= nil end

local function add_to_set_list(set_map, list, elem)
    if not elem or #elem == 0 then return end
    if not set_map[elem] then
        set_map[elem] = true
        table.insert(list, elem)
    end
end

------------------------------------------------------------
-- 规则应用 / 反查逻辑
------------------------------------------------------------
local function expand_code_variant(code_projection, part)
    local out, seen = {}, {}
    local function add(s) add_to_set_list(seen, out, s) end
    add(part)
    if code_projection then
        local p = code_projection:apply(part, true)
        if p and #p > 0 then add(p) end
    end
    local base = {}
    for i = 1, #out do base[i] = out[i] end
    for _, s in ipairs(base) do
        if is_all_upper(s) then add(string.lower(s)) end         -- 笔画：仅转小写参与
        if #s == 4 and is_all_lower(s) then                      -- 4 小写 → 取 1/3
            local s13 = s:sub(1,1) .. s:sub(3,3)
            add(s13)
        end
    end
    return out
end

local function build_reverse_group(code_projection, db_table, text)
    local group, seen = {}, {}
    for _, db in ipairs(db_table) do
        local code = db:lookup(text)
        if code and #code > 0 then
            for part in code:gmatch('%S+') do
                local variants = expand_code_variant(code_projection, part)
                for _, v in ipairs(variants) do add_to_set_list(seen, group, v) end
            end
        end
    end
    -- 最终清理：只保留纯小写字母
    local cleaned, seen2 = {}, {}
    for _, v in ipairs(group) do
        v = tostring(v)
        if is_pure_lower_alpha(v) then add_to_set_list(seen2, cleaned, v) end
    end
    return cleaned
end

-- 不支持通配；global_match=true 为“包含”，否则“前缀”
local function group_match(group, fuma, global_match)
    if not fuma or #fuma == 0 then return false end
    local patt = alt_lua_punc(string.lower(fuma))
    for _, elem in ipairs(group) do
        local e = string.lower(elem)
        if global_match then
            if e:find(patt) then return true end
        else
            if e:find('^' .. patt) then return true end
        end
    end
    return false
end

-- 单字优先
local function handle_long_cand(if_single_char_first, cand, long_word_cands)
    if if_single_char_first and utf8.len(cand.text) > 1 then
        table.insert(long_word_cands, cand)
    else
        yield(cand)
    end
end

------------------------------------------------------------
-- 过滤器主体
------------------------------------------------------------
local f = {}

function f.init(env)
    local config = env.engine.schema.config

    -- 反查 db
    env.if_reverse_lookup = false
    env.db_table = nil
    local db = config:get_list("wanxiang_lookup/lookup")
    if db and db.size > 0 then
        env.db_table = {}
        for i = 0, db.size - 1 do
            table.insert(env.db_table, ReverseLookup(db:get_value_at(i).value))
        end
        env.if_reverse_lookup = true
    end
    if not env.if_reverse_lookup then return end

    -- 内置规则 + 自动选择（不读 schema 的 format）
    do
        local rules = pick_rules(env)
        if type(rules) == 'table' and #rules > 0 then
            env.code_projection = Projection()
            env.code_projection:load(rules)
        else
            env.code_projection = nil
        end
    end

    -- 引导键：优先从 wanxiang_lookup/key 读；否则默认 `
    env.search_key_str = config:get_string('wanxiang_lookup/key') or '`'
    env.search_key_alt = alt_lua_punc(env.search_key_str)

    -- tags
    local tag = config:get_list('wanxiang_lookup/tags')
    if tag and tag.size > 0 then
        env.tag = {}
        for i = 0, tag.size - 1 do
            table.insert(env.tag, tag:get_value_at(i).value)
        end
    else
        env.tag = { 'abc' }
    end

    -- 选词接管：词组保留引导码，否则上屏
    env.notifier = env.engine.context.select_notifier:connect(function(ctx)
        local input = ctx.input
        local code = input:match('^(.-)' .. env.search_key_alt)
        if (not code or #code == 0) then return end
        local preedit = ctx:get_preedit()
        local no_search_string = ctx.input:match('^(.-)' .. env.search_key_alt)
        local edit = preedit.text:match('^(.-)' .. env.search_key_alt)
        if edit and edit:match('[%w;]') then
            ctx.input = no_search_string .. env.search_key_str
        else
            ctx.input = no_search_string
            env.commit_code = no_search_string
            ctx:commit()
        end
    end)

    env._group_cache = setmetatable({}, { __mode = 'kv' })
end

function f.func(input, env)
    if not env.if_reverse_lookup then
        for cand in input:iter() do yield(cand) end
        return
    end

    local code, fuma = env.engine.context.input:match('^(.-)' .. env.search_key_alt .. '(.+)$')
    if (not code or #code == 0) or (not fuma or #fuma == 0) then
        for cand in input:iter() do yield(cand) end
        return
    end

    -- 双段辅码：a`X`Y（第二段匹配第二字或第一字“包含”）
    local fuma_2
    if fuma:find(env.search_key_alt) then
        fuma, fuma_2 = fuma:match('^(.-)' .. env.search_key_alt .. '(.*)$')
    end

    local if_single_char_first = env.engine.context:get_option('char_priority')
    local long_word_cands = {}

    for cand in input:iter() do
        if cand.type == 'sentence' then goto skip end

        local cand_text = cand.text
        local text = cand_text
        local text_2 = nil

        if utf8.len(cand_text) and utf8.len(cand_text) > 1 then
            text = cand_text:sub(1, utf8.offset(cand_text, 2) - 1)
            local cand_text_2 = cand_text:gsub('^' .. text, '')
            text_2 = cand_text_2:sub(1, utf8.offset(cand_text_2, 2) - 1)
        end

        local group1 = env._group_cache[text]
        if not group1 then
            group1 = build_reverse_group(env.code_projection, env.db_table, text)
            env._group_cache[text] = group1
        end

        local ok = false
        if fuma_2 and #fuma_2 > 0 then
            local group2 = nil
            if text_2 then
                group2 = env._group_cache[text_2]
                if not group2 then
                    group2 = build_reverse_group(env.code_projection, env.db_table, text_2)
                    env._group_cache[text_2] = group2
                end
            end
            ok =
                group_match(group1, fuma, false) and
                (
                    (group2 and group_match(group2, fuma_2, false)) or
                    group_match(group1, fuma_2, true)   -- 第一字“包含”
                )
        else
            ok = group_match(group1, fuma, false)   -- 单段：前缀匹配第一字
        end

        if ok then
            handle_long_cand(if_single_char_first, cand, long_word_cands)
        end
        ::skip::
    end

    for _, c in ipairs(long_word_cands) do yield(c) end
end

function f.tags_match(seg, env)
    for _, v in ipairs(env.tag) do if seg.tags[v] then return true end end
    return false
end

function f.fini(env)
    if env.if_reverse_lookup and env.notifier then env.notifier:disconnect() end
    env.db_table = nil
    env._group_cache = nil
    collectgarbage('collect')
end

return f