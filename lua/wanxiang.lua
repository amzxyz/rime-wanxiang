---@diagnostic disable: undefined-global

-- 万象的一些共用工具函数
local wanxiang = {}

-- x-release-please-start-version

wanxiang.version = "v13.4.0"

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
wanxiang.tone_matrix = {
    ["a"] = {1,2,3,4},
    ["ai"] = {1,2,3,4},
    ["an"] = {1,2,3,4},
    ["ang"] = {1,2,3,4},
    ["ao"] = {1,2,3,4},
    ["ba"] = {1,2,3,4},
    ["bai"] = {1,2,3,4},
    ["ban"] = {1,3,4},
    ["bang"] = {1,3,4},
    ["bao"] = {1,2,3,4},
    ["bei"] = {1,3,4},
    ["ben"] = {1,3,4},
    ["beng"] = {1,2,3,4},
    ["bi"] = {1,2,3,4},
    ["bian"] = {1,3,4},
    ["biang"] = {2},
    ["biao"] = {1,2,3,4},
    ["bie"] = {1,2,3,4},
    ["bin"] = {1,4},
    ["bing"] = {1,3,4},
    ["bo"] = {1,2,3,4},
    ["bu"] = {1,2,3,4},
    ["bun"] = {1},
    ["ca"] = {1,3,4},
    ["cai"] = {1,2,3,4},
    ["can"] = {1,2,3,4},
    ["cang"] = {1,2,4},
    ["cao"] = {1,2,3,4},
    ["ce"] = {4},
    ["cei"] = {4},
    ["cen"] = {1,2},
    ["ceng"] = {1,2,4},
    ["ceok"] = {},
    ["ceon"] = {},
    ["cha"] = {1,2,3,4},
    ["chai"] = {1,2,3,4},
    ["chan"] = {1,2,3,4},
    ["chang"] = {1,2,3,4},
    ["chao"] = {1,2,3,4},
    ["che"] = {1,2,3,4},
    ["chen"] = {1,2,3,4},
    ["cheng"] = {1,2,3,4},
    ["chi"] = {1,2,3,4},
    ["chong"] = {1,2,3,4},
    ["chou"] = {1,2,3,4},
    ["chu"] = {1,2,3,4},
    ["chua"] = {1,3,4},
    ["chuai"] = {1,2,3,4},
    ["chuan"] = {1,2,3,4},
    ["chuang"] = {1,2,3,4},
    ["chui"] = {1,2,4},
    ["chun"] = {1,2,3},
    ["chuo"] = {1,4},
    ["ci"] = {1,2,3,4},
    ["cong"] = {1,2,3,4},
    ["cou"] = {1,2,3,4},
    ["cu"] = {1,2,3,4},
    ["cuan"] = {1,2,4},
    ["cui"] = {1,3,4},
    ["cun"] = {1,2,3,4},
    ["cuo"] = {1,2,3,4},
    ["da"] = {1,2,3,4},
    ["dai"] = {1,3,4},
    ["dan"] = {1,3,4},
    ["dang"] = {1,3,4},
    ["dao"] = {1,2,3,4},
    ["de"] = {1,2},
    ["dei"] = {1,3},
    ["den"] = {4},
    ["deng"] = {1,3,4},
    ["di"] = {1,2,3,4},
    ["dia"] = {3},
    ["dian"] = {1,2,3,4},
    ["diao"] = {1,3,4},
    ["die"] = {1,2,3,4},
    ["dim"] = {2},
    ["din"] = {4},
    ["ding"] = {1,3,4},
    ["diu"] = {1},
    ["dong"] = {1,3,4},
    ["dou"] = {1,2,3,4},
    ["du"] = {1,2,3,4},
    ["duan"] = {1,3,4},
    ["dui"] = {1,3,4},
    ["dun"] = {1,3,4},
    ["duo"] = {1,2,3,4},
    ["e"] = {1,2,3,4},
    ["ei"] = {1,2,3,4},
    ["en"] = {1,3,4},
    ["eng"] = {1},
    ["er"] = {2,3,4},
    ["fa"] = {1,2,3,4},
    ["fan"] = {1,2,3,4},
    ["fang"] = {1,2,3,4},
    ["fei"] = {1,2,3,4},
    ["fen"] = {1,2,3,4},
    ["feng"] = {1,2,3,4},
    ["fiao"] = {4},
    ["fo"] = {2},
    ["fou"] = {1,2,3},
    ["fu"] = {1,2,3,4},
    ["ga"] = {1,2,3,4},
    ["gai"] = {1,3,4},
    ["gan"] = {1,3,4},
    ["gang"] = {1,3,4},
    ["gao"] = {1,3,4},
    ["ge"] = {1,2,3,4},
    ["gei"] = {3},
    ["gen"] = {1,2,3,4},
    ["geng"] = {1,3,4},
    ["gong"] = {1,3,4},
    ["gou"] = {1,3,4},
    ["gu"] = {1,2,3,4},
    ["gua"] = {1,2,3,4},
    ["guai"] = {1,3,4},
    ["guan"] = {1,3,4},
    ["guang"] = {1,3,4},
    ["gui"] = {1,3,4},
    ["gun"] = {3,4},
    ["guo"] = {1,2,3,4},
    ["ha"] = {1,2,3,4},
    ["hai"] = {1,2,3,4},
    ["han"] = {1,2,3,4},
    ["hang"] = {1,2,4},
    ["hao"] = {1,2,3,4},
    ["he"] = {1,2,3,4},
    ["hei"] = {1},
    ["hen"] = {2,3,4},
    ["heng"] = {1,2,4},
    ["hong"] = {1,2,3,4},
    ["hou"] = {1,2,3,4},
    ["hu"] = {1,2,3,4},
    ["hua"] = {1,2,4},
    ["huai"] = {2,4},
    ["huan"] = {1,2,3,4},
    ["huang"] = {1,2,3,4},
    ["hui"] = {1,2,3,4},
    ["hun"] = {1,2,3,4},
    ["huo"] = {1,2,3,4},
    ["ji"] = {1,2,3,4},
    ["jia"] = {1,2,3,4},
    ["jian"] = {1,3,4},
    ["jiang"] = {1,3,4},
    ["jiao"] = {1,2,3,4},
    ["jie"] = {1,2,3,4},
    ["jin"] = {1,3,4},
    ["jing"] = {1,3,4},
    ["jiong"] = {1,3,4},
    ["jiu"] = {1,2,3,4},
    ["ju"] = {1,2,3,4},
    ["juan"] = {1,3,4},
    ["jue"] = {1,2,3,4},
    ["jun"] = {1,3,4},
    ["ka"] = {1,3},
    ["kai"] = {1,3,4},
    ["kan"] = {1,3,4},
    ["kang"] = {1,2,3,4},
    ["kao"] = {1,3,4},
    ["ke"] = {1,2,3,4},
    ["kei"] = {1},
    ["ken"] = {1,3,4},
    ["keng"] = {1,3},
    ["kong"] = {1,3,4},
    ["kou"] = {1,3,4},
    ["ku"] = {1,2,3,4},
    ["kua"] = {1,3,4},
    ["kuai"] = {2,3,4},
    ["kuan"] = {1,3,4},
    ["kuang"] = {1,2,3,4},
    ["kui"] = {1,2,3,4},
    ["kun"] = {1,3,4},
    ["kuo"] = {4},
    ["la"] = {1,2,3,4},
    ["lai"] = {2,3,4},
    ["lan"] = {2,3,4},
    ["lang"] = {1,2,3,4},
    ["lao"] = {1,2,3,4},
    ["le"] = {1,4},
    ["lei"] = {1,2,3,4},
    ["leng"] = {1,2,3,4},
    ["li"] = {1,2,3,4},
    ["lia"] = {3},
    ["lian"] = {2,3,4},
    ["liang"] = {1,2,3,4},
    ["liao"] = {1,2,3,4},
    ["lie"] = {1,2,3,4},
    ["lin"] = {1,2,3,4},
    ["ling"] = {2,3,4},
    ["liu"] = {1,2,3,4},
    ["lo"] = {},
    ["long"] = {1,2,3,4},
    ["lou"] = {1,2,3,4},
    ["lu"] = {1,2,3,4},
    ["luan"] = {2,3,4},
    ["lun"] = {1,2,3,4},
    ["luo"] = {1,2,3,4},
    ["lv"] = {2,3,4},
    ["lve"] = {4},
    ["ma"] = {1,2,3,4},
    ["mai"] = {2,3,4},
    ["man"] = {1,2,3,4},
    ["mang"] = {1,2,3,4},
    ["mao"] = {1,2,3,4},
    ["me"] = {1,4},
    ["mei"] = {2,3,4},
    ["men"] = {1,2,4},
    ["meng"] = {1,2,3,4},
    ["mi"] = {1,2,3,4},
    ["mian"] = {2,3,4},
    ["miao"] = {1,2,3,4},
    ["mie"] = {1,2,4},
    ["min"] = {2,3},
    ["ming"] = {2,3,4},
    ["miu"] = {3,4},
    ["mo"] = {1,2,3,4},
    ["mou"] = {1,2,3,4},
    ["mu"] = {2,3,4},
    ["m̀"] = {},
    ["n"] = {2,3,4},
    ["na"] = {1,2,3,4},
    ["nai"] = {2,3,4},
    ["nan"] = {1,2,3,4},
    ["nang"] = {1,2,3,4},
    ["nao"] = {1,2,3,4},
    ["ne"] = {2,4},
    ["nei"] = {2,3,4},
    ["nen"] = {4},
    ["neng"] = {2,3,4},
    ["ng"] = {2,3,4},
    ["ni"] = {1,2,3,4},
    ["nian"] = {1,2,3,4},
    ["niang"] = {2,3,4},
    ["niao"] = {3,4},
    ["nie"] = {1,2,3,4},
    ["nin"] = {2,3},
    ["ning"] = {2,3,4},
    ["niu"] = {1,2,3,4},
    ["nong"] = {2,3,4},
    ["nou"] = {2,3,4},
    ["nu"] = {2,3,4},
    ["nuan"] = {2,3,4},
    ["nun"] = {2},
    ["nuo"] = {2,3,4},
    ["nv"] = {2,3,4},
    ["nve"] = {4},
    ["o"] = {1,2,3,4},
    ["ou"] = {1,2,3,4},
    ["pa"] = {1,2,3,4},
    ["pai"] = {1,2,3,4},
    ["pan"] = {1,2,3,4},
    ["pang"] = {1,2,3,4},
    ["pao"] = {1,2,3,4},
    ["pei"] = {1,2,3,4},
    ["pen"] = {1,2,3,4},
    ["peng"] = {1,2,3,4},
    ["pi"] = {1,2,3,4},
    ["pian"] = {1,2,3,4},
    ["piao"] = {1,2,3,4},
    ["pie"] = {1,3,4},
    ["pin"] = {1,2,3,4},
    ["ping"] = {1,2,4},
    ["po"] = {1,2,3,4},
    ["pou"] = {1,2,3},
    ["pu"] = {1,2,3,4},
    ["qi"] = {1,2,3,4},
    ["qia"] = {1,2,3,4},
    ["qian"] = {1,2,3,4},
    ["qiang"] = {1,2,3,4},
    ["qiao"] = {1,2,3,4},
    ["qie"] = {1,2,3,4},
    ["qin"] = {1,2,3,4},
    ["qing"] = {1,2,3,4},
    ["qiong"] = {1,2,4},
    ["qiu"] = {1,2,3,4},
    ["qu"] = {1,2,3,4},
    ["quan"] = {1,2,3,4},
    ["que"] = {1,2,4},
    ["qun"] = {1,2,3},
    ["ran"] = {2,3,4},
    ["rang"] = {1,2,3,4},
    ["rao"] = {2,3,4},
    ["re"] = {2,3,4},
    ["ren"] = {2,3,4},
    ["reng"] = {1,2},
    ["ri"] = {4},
    ["rong"] = {2,3,4},
    ["rou"] = {2,3,4},
    ["ru"] = {1,2,3,4},
    ["rua"] = {2},
    ["ruan"] = {2,3,4},
    ["rui"] = {2,3,4},
    ["run"] = {2,3,4},
    ["ruo"] = {2,4},
    ["sa"] = {1,2,3,4},
    ["sai"] = {1,3,4},
    ["san"] = {1,3,4},
    ["sang"] = {1,3,4},
    ["sao"] = {1,3,4},
    ["se"] = {1,4},
    ["sen"] = {1,3},
    ["seng"] = {1,4},
    ["sha"] = {1,2,3,4},
    ["shai"] = {1,3,4},
    ["shan"] = {1,2,3,4},
    ["shang"] = {1,3,4},
    ["shao"] = {1,2,3,4},
    ["she"] = {1,2,3,4},
    ["shei"] = {2},
    ["shen"] = {1,2,3,4},
    ["sheng"] = {1,2,3,4},
    ["shi"] = {1,2,3,4},
    ["shou"] = {1,2,3,4},
    ["shu"] = {1,2,3,4},
    ["shua"] = {1,3,4},
    ["shuai"] = {1,3,4},
    ["shuan"] = {1,4},
    ["shuang"] = {1,3,4},
    ["shui"] = {2,3,4},
    ["shun"] = {3,4},
    ["shuo"] = {1,4},
    ["si"] = {1,2,3,4},
    ["song"] = {1,2,3,4},
    ["sou"] = {1,3,4},
    ["su"] = {1,2,3,4},
    ["suan"] = {1,3,4},
    ["sui"] = {1,2,3,4},
    ["sun"] = {1,3,4},
    ["suo"] = {1,2,3,4},
    ["ta"] = {1,2,3,4},
    ["tai"] = {1,2,3,4},
    ["tan"] = {1,2,3,4},
    ["tang"] = {1,2,3,4},
    ["tao"] = {1,2,3,4},
    ["te"] = {4},
    ["tei"] = {1},
    ["teng"] = {1,2,4},
    ["ti"] = {1,2,3,4},
    ["tian"] = {1,2,3,4},
    ["tiao"] = {1,2,3,4},
    ["tie"] = {1,2,3,4},
    ["tii"] = {2},
    ["ting"] = {1,2,3,4},
    ["tong"] = {1,2,3,4},
    ["tou"] = {1,2,3,4},
    ["tu"] = {1,2,3,4},
    ["tuan"] = {1,2,3,4},
    ["tui"] = {1,2,3,4},
    ["tun"] = {1,2,3,4},
    ["tuo"] = {1,2,3,4},
    ["wa"] = {1,2,3,4},
    ["wai"] = {1,3,4},
    ["wan"] = {1,2,3,4},
    ["wang"] = {1,2,3,4},
    ["wei"] = {1,2,3,4},
    ["wen"] = {1,2,3,4},
    ["weng"] = {1,3,4},
    ["wo"] = {1,3,4},
    ["wu"] = {1,2,3,4},
    ["xi"] = {1,2,3,4},
    ["xia"] = {1,2,3,4},
    ["xian"] = {1,2,3,4},
    ["xiang"] = {1,2,3,4},
    ["xiao"] = {1,2,3,4},
    ["xie"] = {1,2,3,4},
    ["xin"] = {1,2,3,4},
    ["xing"] = {1,2,3,4},
    ["xiong"] = {1,2,4},
    ["xiu"] = {1,2,3,4},
    ["xu"] = {1,2,3,4},
    ["xuan"] = {1,2,3,4},
    ["xue"] = {1,2,3,4},
    ["xun"] = {1,2,4},
    ["ya"] = {1,2,3,4},
    ["yan"] = {1,2,3,4},
    ["yang"] = {1,2,3,4},
    ["yao"] = {1,2,3,4},
    ["ye"] = {1,2,3,4},
    ["yi"] = {1,2,3,4},
    ["yin"] = {1,2,3,4},
    ["ying"] = {1,2,3,4},
    ["yo"] = {1},
    ["yong"] = {1,2,3,4},
    ["you"] = {1,2,3,4},
    ["yu"] = {1,2,3,4},
    ["yuan"] = {1,2,3,4},
    ["yue"] = {1,3,4},
    ["yun"] = {1,2,3,4},
    ["za"] = {1,2,3},
    ["zai"] = {1,3,4},
    ["zan"] = {1,2,3,4},
    ["zang"] = {1,3,4},
    ["zao"] = {1,2,3,4},
    ["ze"] = {2,4},
    ["zei"] = {2},
    ["zen"] = {1,3,4},
    ["zeng"] = {1,3,4},
    ["zha"] = {1,2,3,4},
    ["zhai"] = {1,2,3,4},
    ["zhan"] = {1,3,4},
    ["zhang"] = {1,3,4},
    ["zhao"] = {1,2,3,4},
    ["zhe"] = {1,2,3,4},
    ["zhei"] = {4},
    ["zhen"] = {1,2,3,4},
    ["zheng"] = {1,3,4},
    ["zhi"] = {1,2,3,4},
    ["zhong"] = {1,3,4},
    ["zhou"] = {1,2,3,4},
    ["zhu"] = {1,2,3,4},
    ["zhua"] = {1,3},
    ["zhuai"] = {1,3,4},
    ["zhuan"] = {1,3,4},
    ["zhuang"] = {1,3,4},
    ["zhui"] = {1,3,4},
    ["zhun"] = {1,3,4},
    ["zhuo"] = {1,2,4},
    ["zi"] = {1,2,3,4},
    ["zong"] = {1,3,4},
    ["zou"] = {1,3,4},
    ["zu"] = {1,2,3,4},
    ["zuan"] = {1,3,4},
    ["zui"] = {1,2,3,4},
    ["zun"] = {1,3,4},
    ["zuo"] = {1,2,3,4},
    ["ḿ"] = {2},
}
return wanxiang
