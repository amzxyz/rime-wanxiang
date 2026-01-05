---@diagnostic disable: undefined-global

-- 万象的一些共用工具函数
local wanxiang = {}

-- x-release-please-start-version

wanxiang.version = "v14.1.0"

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
            lower_dist == "squirrel" then
            return true
        end

        -- 补充判断：路径中包含移动设备特征，很可以mac的运行逻辑和手机一球样
        if lower_path:find("/android/") or
            lower_path:find("/mobile/") or
            lower_path:find("/sdcard/") or
            lower_path:find("/data/storage/") or
            lower_path:find("/storage/emulated/") or
            lower_path:find("applications") or
            lower_path:find("library") then
            return true
        end
        -- 补充判断：路径中包含移动设备特征，很可以mac的运行逻辑和手机一球样
        if sys_lower_path:find("applications") or
            sys_lower_path:find("library") then
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
        seg:has_tag("Ndate")         -- shijian.lua N日期功能
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
function wanxiang.get_filename_with_fallback(filename)
    local _path = filename:gsub("^/+", "") -- 去掉开头的斜杠

    local user_path = rime_api.get_user_data_dir() .. '/' .. _path
    if wanxiang.file_exists(user_path) then
        return user_path
    end

    local shared_path = rime_api.get_shared_data_dir() .. '/' .. _path
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
    ["Ⅰ"] = "pinyin", --全拼
    ["Ⅱ"] = "zrm", --自然码双拼
    ["Ⅲ"] = "flypy", --小鹤双拼
    ["Ⅳ"] = "mspy", --微软双拼
    ["Ⅴ"] = "sogou", --搜狗双拼
    ["Ⅵ"] = "abc", --智能abc双拼
    ["Ⅶ"] = "ziguang", --紫光双拼
    ["Ⅷ"] = "pyjj", --拼音加加
    ["Ⅸ"] = "gbpy", --国标双拼
    ["Ⅹ"] = "wxsp", --万象双拼
    ["Ⅺ"] = "zrlong", --自然龙
    ["Ⅻ"] = "hxlong", --汉心龙
    ["Ⅼ"] = "lxsq", --乱序17
    ["ⅲ"] = "ⅲ", -- 间接辅助标记：命中则额外返回 md="ⅲ"
}

local __input_type_cache = {}      -- 缓存首个命中的 id（兼容旧用法）
local __input_md_cache   = {}      -- 新增：是否命中“ⅲ”（若命中则为 "ⅲ"，否则为 nil）

--- 根据 speller/algebra 中的特殊符号返回输入类型：
--- - 若未命中“ⅲ”，只返回 id（保持旧行为）
--- - 若命中“ⅲ”，返回两个值：id, "ⅲ"
---@param env Env
---@return string                -- id
---@return string|nil            -- md（仅在命中“ⅲ”时返回 "ⅲ"）
function wanxiang.get_input_method_type(env)
    local schema_id = env.engine.schema.schema_id or "unknown"

    -- 命中缓存则按是否有 md 决定返回 1 个或 2 个值
    local cached_id = __input_type_cache[schema_id]
    if cached_id then
        local cached_md = __input_md_cache[schema_id]
        if cached_md then
            return cached_id, cached_md   -- 返回两个值：id, "ⅲ"
        else
            return cached_id              -- 只返回 id
        end
    end

    local cfg = env.engine.schema.config
    local result_id = "unknown"
    local md        = nil                 -- 只有命中“ⅲ”时设为 "ⅲ"

    local n = cfg:get_list_size("speller/algebra")
    for i = 0, n - 1 do
        local s = cfg:get_string(("speller/algebra/@%d"):format(i))
        if s then
            -- 不提前返回：需要把整段都扫描完，才能知道是否命中“ⅲ”
            for symbol, id in pairs(wanxiang.INPUT_METHOD_MARKERS) do
                if s:find(symbol, 1, true) then
                    if symbol == "ⅲ" or id == "ⅲ" then
                        md = "ⅲ"                  -- 记录辅助标记
                    else
                        if result_id == "unknown" then
                            result_id = id        -- 只记录第一个“正常映射”的 id
                        end
                    end
                end
            end
        end
    end

    -- 写缓存
    __input_type_cache[schema_id] = result_id
    __input_md_cache[schema_id]   = md   -- 命中则为 "ⅲ"，否则为 nil

    -- 返回：命中“ⅲ”→两个值；否则一个值
    if md then
        return result_id, md
    else
        return result_id
    end
end

-- Wanxiang Regex > lua --不支持断言够用了
local RegexParser = {}

function RegexParser.normalize(regex)
    local p = regex
    p = p:gsub("%(%?%:", "%(") -- 清理 (?:
    -- 基础转义
    p = p:gsub("\\d", "%%d"); p = p:gsub("\\D", "%%D")
    p = p:gsub("\\w", "%%w"); p = p:gsub("\\W", "%%W")
    p = p:gsub("\\s", "%%s"); p = p:gsub("\\S", "%%S")
    -- 符号转义 (注意：\? -> %?，保留字面量问号)
    p = p:gsub("\\%.", "%%."); p = p:gsub("\\%^", "%%^")
    p = p:gsub("\\%$", "%%$"); p = p:gsub("\\%*", "%%*")
    p = p:gsub("\\%+", "%%+"); p = p:gsub("\\%-", "%%-")
    p = p:gsub("\\%?", "%%?")
    p = p:gsub("\\%(", "%%("); p = p:gsub("\\%)", "%%)")
    p = p:gsub("\\%[", "%%["); p = p:gsub("\\%]", "%%]")
    
    return p
end

-- 递归展开 ? 量词
-- 输入: "N[0-9]?A"
-- 输出: { "N[0-9]A", "NA" }
local function expand_optional(pattern_list)
    local result = {}
    local has_expansion = false

    for _, pat in ipairs(pattern_list) do
        -- 寻找第一个未转义的 ? (Regex量词)
        -- 我们需要找到 ? 的位置，并判断它修饰的前一个原子是什么
        local q_idx = nil
        local atom_start = nil
        local atom_end = nil

        local i = 1
        local len = #pat
        while i <= len do
            local char = string.sub(pat, i, i)
            
            if char == "%" then
                -- 转义符，跳过下一个
                i = i + 2
            elseif char == "[" then
                -- 集合 [...]
                local j = i + 1
                while j <= len do
                    if string.sub(pat, j, j) == "]" and string.sub(pat, j-1, j-1) ~= "%" then
                        break
                    end
                    j = j + 1
                end
                -- 检查后面是不是 ?
                if j < len and string.sub(pat, j+1, j+1) == "?" then
                    atom_start = i
                    atom_end = j
                    q_idx = j + 1
                    break -- 找到目标
                end
                i = j + 1
            elseif char == "?" then
                -- 找到一个 ?，修饰前面一个字符
                -- 注意：如果前面没有字符（比如开头），则是非法正则，忽略
                if i > 1 then
                    q_idx = i
                    atom_end = i - 1
                    -- 判断前一个字符是否是转义结果 (如 %d)
                    if atom_end > 1 and string.sub(pat, atom_end-1, atom_end-1) == "%" then
                        atom_start = atom_end - 1
                    else
                        atom_start = atom_end
                    end
                    break
                end
                i = i + 1
            else
                i = i + 1
            end
        end

        if q_idx then
            has_expansion = true
            -- 1. 保留原子 (去掉 ?)
            local p1 = string.sub(pat, 1, atom_end) .. string.sub(pat, q_idx + 1)
            -- 2. 删除原子 (去掉 原子+?)
            local p2 = string.sub(pat, 1, atom_start - 1) .. string.sub(pat, q_idx + 1)
            
            table.insert(result, p1)
            table.insert(result, p2)
        else
            table.insert(result, pat)
        end
    end

    if has_expansion then
        if #result > 100 then return result end
        return expand_optional(result)
    end
    
    return result
end

function RegexParser.smart_split(str, sep)
    local results = {}
    local current = ""
    local paren_depth = 0
    local brack_depth = 0
    for i = 1, #str do
        local char = string.sub(str, i, i)
        local prev = (i > 1) and string.sub(str, i-1, i-1) or ""
        if prev == "%" then
            current = current .. char
        else
            if char == '(' then paren_depth = paren_depth + 1 end
            if char == ')' then paren_depth = paren_depth - 1 end
            if char == '[' then brack_depth = brack_depth + 1 end
            if char == ']' then brack_depth = brack_depth - 1 end
            if char == sep and paren_depth == 0 and brack_depth == 0 then
                table.insert(results, current); current = ""
            else
                current = current .. char
            end
        end
    end
    table.insert(results, current)
    return results
end

function RegexParser.expand_groups(str_list)
    local expanded = {}
    for _, str in ipairs(str_list) do
        local s_idx, e_idx = nil, nil
        local depth = 0
        for i = 1, #str do
            local char = string.sub(str, i, i)
            local prev = (i > 1) and string.sub(str, i-1, i-1) or ""
            if prev ~= "%" then
                if char == "(" then
                    if depth == 0 then s_idx = i end
                    depth = depth + 1
                elseif char == ")" then
                    depth = depth - 1
                    if depth == 0 and s_idx then e_idx = i; break end
                end
            end
        end
        if s_idx and e_idx then
            local prefix = string.sub(str, 1, s_idx - 1)
            local content = string.sub(str, s_idx + 1, e_idx - 1)
            local suffix = string.sub(str, e_idx + 1)
            local parts = RegexParser.smart_split(content, "|")
            for _, part in ipairs(parts) do
                table.insert(expanded, prefix .. part .. suffix)
            end
        else
            table.insert(expanded, str)
        end
    end
    return expanded
end

local function ensure_anchor(p)
    if not p or p == "" then return p end
    -- 补 $
    local last = string.sub(p, -1)
    local prev = string.sub(p, -2, -2)
    if last ~= "$" or (last == "$" and prev == "%") then p = p .. "$" end
    -- 补 ^
    local first = string.sub(p, 1, 1)
    if first ~= "^" then p = "^" .. p end
    return p
end

function RegexParser.convert(regex_str)
    if not regex_str or regex_str == "" then return {} end
    local norm = RegexParser.normalize(regex_str)
    -- 1. 拆分 |
    local list = RegexParser.smart_split(norm, "|")
    -- 2. 展开 () 分组
    local loop = 0
    local changed = true
    while changed and loop < 5 do
        local new_list = RegexParser.expand_groups(list)
        if #new_list > #list then list = new_list else changed = false end
        loop = loop + 1
    end
    -- 3. 展开 ? 量词
    -- 这会将带 ? 的正则裂变成多个确定的正则
    list = expand_optional(list)
    -- 4. 补全锚点
    for i, p in ipairs(list) do list[i] = ensure_anchor(p) end
    return list
end

--- 调用加载函数
function wanxiang.load_regex_patterns(config, path)
    local patterns = {}
    local map = config:get_map(path)
    if not map then return patterns end
    local keys = map:keys()
    if not keys then return patterns end
    
    local count = 0
    local is_ud = (type(keys) == "userdata")
    if is_ud then
        if keys.size then count = keys.size 
        else pcall(function() count = keys:size() end) end
    else
        count = #keys
    end

    for i = 0, count - 1 do
        local k_str
        if is_ud then
            local it = keys:get_value_at(i)
            if it then k_str = it.value end
            if not k_str then pcall(function() k_str = keys[i] end) end
        else
            k_str = keys[i+1]
        end

        if k_str then
            local val = map:get_value(k_str)
            if val and val.value and val.value ~= "" then
                local lua_pats = RegexParser.convert(val.value)
                for _, p in ipairs(lua_pats) do
                    table.insert(patterns, p)
                end
            end
        end
    end
    return patterns
end
return wanxiang