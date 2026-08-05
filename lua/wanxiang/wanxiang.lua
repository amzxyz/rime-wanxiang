---@diagnostic disable: undefined-global

-- 万象的一些共用工具函数
local wanxiang = {}

-- x-release-please-start-version

wanxiang.version = "v17.2.2"

-- x-release-please-end

-- 全局内容
---@alias PROCESS_RESULT ProcessResult
wanxiang.RIME_PROCESS_RESULTS = {
    kRejected = 0, -- 表示处理器明确拒绝了这个按键，停止处理链但不返回 true
    kAccepted = 1, -- 表示处理器成功处理了这个按键，停止处理链并返回 true
    kNoop = 2,     -- 表示处理器没有处理这个按键，继续传递给下一个处理器
}

-- 整个生命周期内不变，缓存判断结果
local is_mobile_device = nil
-- 判断是否为手机设备
---@author amzxyz
---@return boolean
function wanxiang.is_mobile_device()
    local function _is_mobile_device()
        local dist = rime_api.get_distribution_code_name() or ""
        local user_data_dir = rime_api.get_user_data_dir() or ""
        local sys_dir = rime_api.get_shared_data_dir() or ""
        -- 转换为小写以便比较
        local lower_dist = dist:lower()
        local lower_path = user_data_dir:lower()
        local sys_lower_path = sys_dir:lower()
        -- 主判断：常见移动端输入法
        if lower_dist == "trime" or
            lower_dist == "hamster" or
            lower_dist == "hamster3" or
            lower_dist == "default" or --超越
            lower_dist == "xime" or --曦码
            lower_dist == "lyraime" then  --灵韵
            return true
        end

        -- 补充判断：路径中包含移动设备特征，很可以mac的运行逻辑和手机一球样
        if lower_path:find("/android/") or
            lower_path:find("/mobile/") or
            lower_path:find("/sdcard/") or
            lower_path:find("/data/storage/") or
            lower_path:find("/storage/emulated/") then
            return true
        end

        -- 特定平台判断（Android/Linux）
        if jit and jit.os then
            local os_name = jit.os:lower()
            if os_name:find("android") then
                return true
            end
        end

        -- 所有检查未通过则默认为桌面设备
        return false
    end

    if is_mobile_device == nil then
        is_mobile_device = _is_mobile_device()
    end
    return is_mobile_device
end

local is_special_desktop = nil

--- 判断是否为需要特殊处理的桌面环境（squirrel、Cobra 或 fcitx-rime+library）
---@return boolean
function wanxiang.is_special_desktop()
    if is_special_desktop == nil then
        local dist = rime_api.get_distribution_code_name() or ""
        local sys_dir = rime_api.get_shared_data_dir() or ""
        local lower_dist = dist:lower()
        local lower_sys = sys_dir:lower()

        local exclude = false
        if lower_dist == "squirrel" or lower_dist == "cobra" then
            exclude = true
        elseif lower_dist == "fcitx-rime" and lower_sys:find("library") then
            exclude = true
        end
        is_special_desktop = exclude
    end
    return is_special_desktop
end

--- 检测是否为万象专业版
---@param env Env
---@return boolean
function wanxiang.is_pro_scheme(env)
    -- local schema_name = env.engine.schema.schema_name
    -- return schema_name:gsub("PRO$", "") ~= schema_name
    return env.engine.schema.schema_id == "wanxiang_pro"
end

-- 以 `tag` 方式检测是否处于反查模式
function wanxiang.is_in_radical_mode(env)
    local seg = env.engine.context.composition:back()
    return seg and (
        seg:has_tag("wanxiang_reverse")
    ) or false
end

---判断是否在命令模式
---@param context Context | nil
---@return boolean
function wanxiang.is_function_mode_active(context)
    if not context or not context.composition or context.composition:empty() then
        return false
    end

    local seg = context.composition:back()
    if not seg then return false end

    return seg:has_tag("number") or  -- number_translator.lua 数字金额转换 R+数字
        seg:has_tag("unicode") or    -- unicode.lua 输出 Unicode 字符 U+小写字母或数字
        --seg:has_tag("punct") or      -- 标点符号 全角半角提示
        seg:has_tag("calculator") or -- super_calculator.lua V键计算器
        seg:has_tag("shijian") or    -- shijian.lua /rq /sr 等与时间日期相关功能
        seg:has_tag("Ndate")       -- shijian.lua N日期功能
end

---@param context Context | nil
---@return boolean
function wanxiang.s2t_conversion(context)
    if not context or not context.composition or context.composition:empty() then
        return false
    end

    local seg = context.composition:back()
    if not seg then return false end

    return seg:has_tag("number") or  -- number_translator.lua 数字金额转换 R+数字
        seg:has_tag("unicode") or    -- unicode.lua 输出 Unicode 字符 U+小写字母或数字
        seg:has_tag("punct") or      -- 标点符号 全角半角提示
        seg:has_tag("calculator") or -- super_calculator.lua V键计算器
        seg:has_tag("shijian") or    -- shijian.lua /rq /sr 等与时间日期相关功能
        seg:has_tag("Ndate") or      -- shijian.lua N日期功能
        seg:has_tag("wanxiang_reverse")
end
---判断文件是否存在
function wanxiang.file_exists(filename)
    local f = io.open(filename, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

-- 判断字符是否为汉字
function wanxiang.IsChineseCharacter(text)
    local codepoint = utf8.codepoint(text)
    return
        (codepoint >= 0x4E00 and codepoint <= 0x9FFF)   -- Basic
        or (codepoint >= 0x3400 and codepoint <= 0x4DBF)  -- Ext A
        or (codepoint >= 0x20000 and codepoint <= 0x2A6DF) -- Ext B
        or (codepoint >= 0x2A700 and codepoint <= 0x2B73F) -- Ext C
        or (codepoint >= 0x2B740 and codepoint <= 0x2B81F) -- Ext D
        or (codepoint >= 0x2B820 and codepoint <= 0x2CEAF) -- Ext E
        or (codepoint >= 0x2CEB0 and codepoint <= 0x2EBEF) -- Ext F
        or (codepoint >= 0x30000 and codepoint <= 0x3134F) -- Ext G
        or (codepoint >= 0x31350 and codepoint <= 0x323AF) -- Ext H
        or (codepoint >= 0x2EBF0 and codepoint <= 0x2EE5F) -- Ext I
        or (codepoint >= 0xF900  and codepoint <= 0xFAFF)  -- Compatibility
        or (codepoint >= 0x2F800 and codepoint <= 0x2FA1F) -- Compatibility Supplement
        or (codepoint >= 0x2E80  and codepoint <= 0x2EFF)  -- Radicals Supplement
        or (codepoint >= 0x2F00  and codepoint <= 0x2FDF)  -- Kangxi Radicals
end

---按照优先顺序获取文件：用户目录 > 系统目录
---@param filename string 相对路径
---@retur string | nil
-- 辅助函数：检测路径是否为绝对路径（以 / 或盘符开头）
local function is_absolute_path(path)
    if not path then return false end
    if path:sub(1, 1) == "/" or path:sub(1, 1) == "\\" then
        return true
    end
    if path:match("^[a-zA-Z]:[\\/]") then
        return true 
    end
    return false
end

function wanxiang.get_filename_with_fallback(filename)
    local _path = filename:gsub("^[\\/]+", "")
    local user_dir = rime_api.get_user_data_dir()
    
    if not is_absolute_path(user_dir) then
        return filename
    end

    local user_path = user_dir .. "/" .. _path
    if wanxiang.file_exists(user_path) then
        return user_path
    end

    local shared_dir = rime_api.get_shared_data_dir()
    
    if not is_absolute_path(shared_dir) then
        return filename
    end
    local shared_path = shared_dir .. "/" .. _path
    if wanxiang.file_exists(shared_path) then
        return shared_path
    end
    return nil
end

-- 按照优先顺序加载文件：用户目录 > 系统目录
---@param filename string 相对路径
---@retur file* | nil, function
function wanxiang.load_file_with_fallback(filename, mode)
    mode = mode or "r" -- 默认读取模式

    local _filename = wanxiang.get_filename_with_fallback(filename)

    local file, err
    local function close()
        if not file then return end
        file:close()
        file = nil
    end

    if _filename then
        file, err = io.open(_filename, mode)
    end

    return file, close, err
end

local USER_ID_DEFAULT = "unknown"
---作为「小狼毫」和「仓」 `rime_api.get_user_id()` 的一个 workaround
---详见：
---1. https://github.com/rime/weasel/pull/1649
---2. https://github.com/rime/librime/issues/1038
---@return string
function wanxiang.get_user_id()
    local user_id = rime_api.get_user_id()
    if user_id ~= USER_ID_DEFAULT then return user_id end

    local user_data_dir = rime_api.get_user_data_dir()
    local installation_path = user_data_dir .. "/installation.yaml"
    local installation_file, _ = io.open(installation_path, "r")
    if not installation_file then return user_id end

    for line in installation_file:lines() do
        local key, value = line:match('^([^#:]+):%s+"?([^"]%S+[^"])"?')
        if key == "installation_id" then
            user_id = value
            break
        end
    end

    installation_file:close()
    return user_id
end
wanxiang.INPUT_METHOD_MARKERS = {
    ["Ⅰ"] = "pinyin",   -- 全拼
    ["Ⅱ"] = "zrm",      -- 自然码双拼
    ["Ⅲ"] = "flypy",    -- 小鹤双拼
    ["Ⅳ"] = "mspy",     -- 微软双拼
    ["Ⅴ"] = "sogou",    -- 搜狗双拼
    ["Ⅵ"] = "abc",      -- 智能ABC双拼
    ["Ⅶ"] = "ziguang",  -- 紫光双拼
    ["Ⅷ"] = "pyjj",     -- 拼音加加
    ["Ⅸ"] = "gbpy",     -- 国标双拼
    ["Ⅺ"] = "zrlong",   -- 自然龙
    ["Ⅻ"] = "hxlong",   -- 汉心龙
    ["Ⅿ"] = "ltsp",     -- 蓝天双拼
    ["Ⅼ"] = "lxsq",     -- 乱序17
    ["Ⅽ"] = "dnsp",    -- 大牛双拼
    ["Ⅾ"] = "sdpy",     -- 首道双拼
    ["ⅲ"] = "ⅲ",        -- 间接辅助标记
    ["ⅱ"] = "t9",       -- 拼音九键
--Ⅹ  --万象保留
--ↀ  --备用名额不多了，谁再发明双拼掂量一下必要性。。。
--ↁ
--ↂ
}

-- 固定检测顺序，避免使用 pairs() 时顺序不确定。
-- “ⅲ”属于辅助标记，单独检测，不放入正常输入类型顺序。
local INPUT_METHOD_MARKER_ORDER = {
    "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ",
    "Ⅸ", "Ⅹ", "Ⅺ", "Ⅻ", "Ⅿ", "Ⅼ", "Ⅽ", "ⅱ",
}

local INPUT_METHOD_MD_MARKER = "ⅲ"

--- 返回形式：
---   id
---   id, "ⅲ"  -- 命中辅助标记时
---@param env Env
---@return string id
---@return string|nil md
function wanxiang.get_input_method_type(env)
    local config = env.engine.schema.config
    local algebra = config:get_list("speller/algebra")
    if not algebra then return "unknown" end

    local result_id = "unknown"
    local md = nil

    for i = 0, algebra.size - 1 do
        local value = algebra:get_value_at(i)
        local rule = value and value:get_string()

        if rule then
            if not md and rule:find(INPUT_METHOD_MD_MARKER, 1, true) then
                md = INPUT_METHOD_MD_MARKER
            end

            if result_id == "unknown" then
                for j = 1, #INPUT_METHOD_MARKER_ORDER do
                    local symbol = INPUT_METHOD_MARKER_ORDER[j]

                    if rule:find(symbol, 1, true) then
                        result_id = wanxiang.INPUT_METHOD_MARKERS[symbol]
                        break
                    end
                end
            end

            if result_id ~= "unknown" and md then break end
        end
    end

    if md then return result_id, md end
    return result_id
end

-- Wanxiang Regex > Lua Pattern
-- 支持：分组、嵌套分支、? 可选项、常用字符类及基础转义
-- 不支持：断言、反向引用、{m,n}、分组后的 * 和 +

local RegexParser = {}

local s_sub = string.sub
local t_concat = table.concat

-- Lua Pattern 中需要使用 % 转义的字符。
-- "|"虽然不是Lua魔法字符，但在解析阶段表示分支，也需要转义保护。
local LUA_MAGIC = {
    ["^"] = true,
    ["$"] = true,
    ["("] = true,
    [")"] = true,
    ["%"] = true,
    ["."] = true,
    ["["] = true,
    ["]"] = true,
    ["*"] = true,
    ["+"] = true,
    ["-"] = true,
    ["?"] = true,
    ["|"] = true,
}

local REGEX_CLASSES = {
    d = true,
    D = true,
    w = true,
    W = true,
    s = true,
    S = true,
}

local function escape_lua_literal(char)
    if LUA_MAGIC[char] then return "%" .. char end
    return char
end

-- 转换字符类内部内容，例如：
-- [0-9]
-- [a-zA-Z]
-- [^\d]
-- [a\-z]
local function normalize_class(regex, start_pos, result)
    local len = #regex
    local i = start_pos + 1

    result[#result + 1] = "["

    -- 字符类开头的 ^ 表示取反
    if s_sub(regex, i, i) == "^" then
        result[#result + 1] = "^"
        i = i + 1
    end

    -- ] 位于字符类首位时表示字面量
    if s_sub(regex, i, i) == "]" then
        result[#result + 1] = "]"
        i = i + 1
    end

    while i <= len do
        local char = s_sub(regex, i, i)

        if char == "\\" then
            local next_char = s_sub(regex, i + 1, i + 1)

            if next_char == "" then
                result[#result + 1] = "\\"
                return i + 1
            end

            if REGEX_CLASSES[next_char] then
                result[#result + 1] = "%" .. next_char
            else
                result[#result + 1] = escape_lua_literal(next_char)
            end

            i = i + 2
        elseif char == "%" then
            -- Regex 中的普通 % 在 Lua Pattern 中必须写成 %%
            result[#result + 1] = "%%"
            i = i + 1
        else
            result[#result + 1] = char
            i = i + 1

            if char == "]" then return i end
        end
    end

    return i
end

--- 将受支持的Regex语法转换为中间Lua Pattern格式。
---@param regex string
---@return string
function RegexParser.normalize(regex)
    local result = {}
    local i = 1
    local len = #regex

    while i <= len do
        local char = s_sub(regex, i, i)

        if char == "\\" then
            local next_char = s_sub(regex, i + 1, i + 1)

            if next_char == "" then
                result[#result + 1] = "\\"
                i = i + 1
            elseif REGEX_CLASSES[next_char] then
                -- \d、\w、\s等转换为Lua字符类
                result[#result + 1] = "%" .. next_char
                i = i + 2
            else
                -- \.、\?、\|等转为Lua字面量
                result[#result + 1] = escape_lua_literal(next_char)
                i = i + 2
            end
        elseif char == "[" then
            i = normalize_class(regex, i, result)
        elseif char == "%" then
            result[#result + 1] = "%%"
            i = i + 1
        elseif char == "(" and s_sub(regex, i + 1, i + 2) == "?:" then
            -- Lua Pattern不区分捕获组和非捕获组；
            -- 后续解析会直接展开并移除分组。
            result[#result + 1] = "("
            i = i + 3
        elseif char == "-" then
            -- Regex中字符类外的 - 是普通字符；
            -- Lua Pattern中 - 是最短匹配量词，需要转义。
            result[#result + 1] = "%-"
            i = i + 1
        else
            result[#result + 1] = char
            i = i + 1
        end
    end

    return t_concat(result)
end

local function append_all(target, source)
    for i = 1, #source do
        target[#target + 1] = source[i]
    end
end

-- 将左侧已有组合与右侧原子/分支做笛卡尔积
local function combine(left, right)
    local result = {}

    for i = 1, #left do
        local prefix = left[i]

        for j = 1, #right do
            result[#result + 1] = prefix .. right[j]
        end
    end

    return result
end

-- 从已经normalize后的Lua Pattern中读取完整字符类
local function read_class(pattern, start_pos)
    local len = #pattern
    local i = start_pos + 1

    if s_sub(pattern, i, i) == "^" then i = i + 1 end
    if s_sub(pattern, i, i) == "]" then i = i + 1 end

    while i <= len do
        local char = s_sub(pattern, i, i)

        if char == "%" then
            -- 跳过Lua转义字符，例如 %]、%-、%d
            i = i + 2
        elseif char == "]" then
            return s_sub(pattern, start_pos, i), i + 1
        else
            i = i + 1
        end
    end

    return nil, start_pos
end

local parse_expression

-- 递归解析分支与分组。
--
-- 例如：
--   (ab|cd)e
-- 转换为：
--   abe
--   cde
--
--   (ab|cd)?e
-- 转换为：
--   abe
--   cde
--   e
parse_expression = function(pattern, start_pos, stop_char)
    local alternatives = {}
    local sequence = { "" }
    local len = #pattern
    local pos = start_pos

    while pos <= len do
        local char = s_sub(pattern, pos, pos)

        if stop_char and char == stop_char then
            append_all(alternatives, sequence)
            return alternatives, pos + 1
        elseif char == "|" then
            append_all(alternatives, sequence)
            sequence = { "" }
            pos = pos + 1
        elseif char == ")" or char == "?" or char == "*" or char == "+" then
            -- 出现未配对右括号或没有前置原子的量词
            return nil, pos
        else
            local atom
            local is_group = false

            if char == "(" then
                atom, pos = parse_expression(pattern, pos + 1, ")")
                if not atom then return nil, pos end
                is_group = true
            elseif char == "[" then
                local token, next_pos = read_class(pattern, pos)
                if not token then return nil, next_pos end

                atom = { token }
                pos = next_pos
            elseif char == "%" then
                if pos >= len then return nil, pos end

                atom = { s_sub(pattern, pos, pos + 1) }
                pos = pos + 2
            else
                atom = { char }
                pos = pos + 1
            end

            local quantifier = s_sub(pattern, pos, pos)

            if quantifier == "?" then
                -- 原子或整个分组可选
                atom[#atom + 1] = ""
                pos = pos + 1
            elseif quantifier == "*" or quantifier == "+" then
                -- Lua Pattern支持单原子重复，但不支持整个分组重复
                if is_group then return nil, pos end

                atom[1] = atom[1] .. quantifier
                pos = pos + 1
            end

            sequence = combine(sequence, atom)
        end
    end

    -- 指定了结束括号但扫描结束，说明分组未闭合
    if stop_char then return nil, pos end

    append_all(alternatives, sequence)
    return alternatives, pos
end

local function is_escaped(pattern, pos)
    local count = 0
    pos = pos - 1

    while pos >= 1 and s_sub(pattern, pos, pos) == "%" do
        count = count + 1
        pos = pos - 1
    end

    return count % 2 == 1
end

local function ensure_anchor(pattern)
    -- 空分支对应精确匹配空字符串
    if pattern == "" then return "^$" end

    if s_sub(pattern, 1, 1) ~= "^" then
        pattern = "^" .. pattern
    end

    local len = #pattern
    local last = s_sub(pattern, len, len)

    -- 末尾不是未转义的 $ 时补齐结束锚点
    if last ~= "$" or is_escaped(pattern, len) then
        pattern = pattern .. "$"
    end

    return pattern
end

--- 将Regex字符串转换为一组确定的Lua Pattern。
---@param regex_str string
---@return table
function RegexParser.convert(regex_str)
    if type(regex_str) ~= "string" or regex_str == "" then return {} end

    local normalized = RegexParser.normalize(regex_str)
    local expanded = parse_expression(normalized, 1, nil)

    -- 出现未闭合分组、字符类或不支持的语法时忽略本条规则
    if not expanded then return {} end

    local patterns = {}
    local seen = {}

    for i = 1, #expanded do
        local pattern = ensure_anchor(expanded[i])

        if not seen[pattern] then
            seen[pattern] = true
            patterns[#patterns + 1] = pattern
        end
    end

    return patterns
end

--- 从ConfigMap中加载并转换Regex规则。
---@param config Config
---@param path string
---@return table
function wanxiang.load_regex_patterns(config, path)
    local patterns = {}
    local seen = {}

    local map = config:get_map(path)
    if not map then return patterns end

    -- ConfigMap:keys()正式返回Lua键名列表
    local keys = map:keys()
    if not keys then return patterns end

    for i = 1, #keys do
        local value = map:get_value(keys[i])
        local regex = value and value.value

        if type(regex) == "string" and regex ~= "" then
            local converted = RegexParser.convert(regex)

            for j = 1, #converted do
                local pattern = converted[j]

                if not seen[pattern] then
                    seen[pattern] = true
                    patterns[#patterns + 1] = pattern
                end
            end
        end
    end

    return patterns
end
return wanxiang