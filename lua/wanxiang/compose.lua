-- 万象 Compose
-- 触发前缀取自 recognizer/patterns/compose 的第 2 个字符(默认 C)。
-- 进入 Compose: 输入大写 C 后, 依次键入组合字符(取自系统 XCompose 表转换的静态码表 lua/data/compose.txt),
-- 即可得到合成结果候选。
-- 设计要点(本版):
--   * 纯字符模型, 不再使用私有区(PUA)占位字符。
--   * 小键盘数字(KP_0..9)与运算符(+-*/=) 作为普通可键入字符直接参与 Compose,
--     预编辑中显示为正常数码/符号; 数字序列一律由小键盘承担。
--     小键盘按 keycode 识别(而非 repr 键名): NumLock 开启时小键盘数字键的 repr
--     会变成普通数字名(如 "1"), 但 keycode 恒定, 故必须用 keycode 才能稳定命中。
--   * 所有可键入标点(主键盘 !"#%&'()*+,-./:;<=>?@[\]^_`{|}~ 等, 含小键盘 KP_Decimal/KP_Separator/KP_Add/KP_Subtract/KP_Multiply/KP_Divide/KP_Equal)
--     统一采用"命中制"门控: 仅当接入后新序列能够命中 Compose 编码(或为其真前缀)时才进入序列参与合成;
--     否则视为死路, 直接上屏「前面的所有内容 + 该标点对应的中文全角标点」并退出 Compose(类比逗号->，、句号->。)。
--     例: Cw, -> 上屏 "Cw，"(w 为死路, 字面 Cw 随中文逗号一起上屏);
--          已命中 Ca, 后再按 , -> 上屏 "Ca，"(Ca, 已命中、再按逗号不成新序列)。
--     这样既保留 C, 类序列(如 C,A -> Ą)、C! 类序列(如 C! -> ¡), 又让无效序列里的标点照常上屏为中文标点。
--   * 主键区数字(主键盘 1..9,0)不参与 Compose: 在 Compose 模式下也正常用于选词(候选选择),
--     因此 Compose 不再提供 qwerty 选词, 命中结果一律强制为第一候选。
--   * 功能键(F1..F12)在 RIME 中无法作为普通字符键入, 在 Compose 模式下被吞键(不进入序列);
--     小键盘 Enter 等无法作为普通字符键入的按键则透传交由 RIME 默认处理(不吞键)。
--   * dead 死键(如 dead_acute)现在当作普通字符(如 ' ^ ` 等)直接参与 Compose, 显示为原字符。
-- 注释: 命中时显示 "[Compose] <序列>"; 仅命中前缀(未完整命中)时显示 "[Compose] <序列> ~" 且候选正文为字面 "C<序列>", 放在首位; 死路(不匹配任何前缀)则不显示 Compose 候选。注释强制显示。
-- 候选 type 固定为 "compose", 注释/预编辑由本模块设好;
-- super_comment_preedit 在遍历时对 type 为 "compose" 的候选直接放行(不改动其注释与预编辑)。
-- 注: 自定义路径可用 compose/data_file 覆盖默认，建议始终填写相对 RIME 数据目录的路径。
-- 默认数据文件为 lua/data/compose.txt，加载顺序为用户目录优先、系统目录兜底。
local wanxiang = require("wanxiang/wanxiang")

local M = {}

-- 主键区数字(主键盘 1..9,0): 不参与 Compose, 用于选词。
local MAIN_DIGITS = {
    ["1"] = true,
    ["2"] = true,
    ["3"] = true,
    ["4"] = true,
    ["5"] = true,
    ["6"] = true,
    ["7"] = true,
    ["8"] = true,
    ["9"] = true,
    ["0"] = true
}

-- 小键盘键码 -> 可键入字符(普通字符, 无条件直接参与 Compose, 显示为正常数码/符号)。
-- 注意: 小键盘键名(repr)会随 NumLock 状态变化(开启时为普通数字名 "1", 关闭时为 "KP_1"),
-- 而 keycode 恒定, 故一律按 keycode 识别, 确保 Compose 模式下小键盘始终参与合成。
-- 小键盘所有按键(含 Enter)均参与 Compose, 不吞键: 可字符合成则写入序列,
-- Enter 等无法作为普通字符的按键按对应键名透传给 RIME 默认处理。
local KP_BY_CODE = {
    [0xFFB0] = "0",
    [0xFFB1] = "1",
    [0xFFB2] = "2",
    [0xFFB3] = "3",
    [0xFFB4] = "4",
    [0xFFB5] = "5",
    [0xFFB6] = "6",
    [0xFFB7] = "7",
    [0xFFB8] = "8",
    [0xFFB9] = "9",
    [0xFFAB] = "+",
    [0xFFAD] = "-",
    [0xFFAA] = "*",
    [0xFFAF] = "/",
    [0xFFAE] = ".",
    [0xFFAC] = ",",
    [0xFFBD] = "="
}
-- 小键盘 Enter 等无法作为普通字符键入的按键: 直接透传(不吞键, 不进入序列)。
local KP_PASSTHRU = {
    [0xFF8D] = true -- KP_Enter
}

-- 可键入标点集合(ASCII 标点, 不含数字字母与空格):
--   33-47 (!"#$%&'()*+,-./), 58-64 (:;<=>?@), 91-96 ([\\]^_), 123-126 ({|}~)。
-- 全部纳入"命中制"门控: 仅当接入后能命中 Compose 编码(或为其真前缀)时才参与合成,
-- 否则视为死路, 直接上屏「当前字面序列 + 该标点本身」并退出 Compose。
-- 这样所有标点行为统一, 既保留含标点的 Compose 序列(如 C! -> ¡, C: -> ÷),
-- 又让无效序列里的标点照常原样上屏。
local PUNCT = {}
for i = 33, 47 do
    PUNCT[string.char(i)] = true
end
for i = 58, 64 do
    PUNCT[string.char(i)] = true
end
for i = 91, 96 do
    PUNCT[string.char(i)] = true
end
for i = 123, 126 do
    PUNCT[string.char(i)] = true
end

-- 标点门控死路退出时, 该标点对应的中文全角标点(类比逗号->，、句号->。)。
-- 覆盖 PUNCT 全部成员; 映射表未列出的标点回退上屏原字符本身。
local CN_PUNCT = {
    ["!"] = "！",
    ["\""] = "“",
    ["#"] = "＃",
    ["$"] = "＄",
    ["%"] = "％",
    ["&"] = "＆",
    ["'"] = "‘",
    ["("] = "（",
    [")"] = "）",
    ["*"] = "＊",
    ["+"] = "＋",
    [","] = "，",
    ["-"] = "－",
    ["."] = "。",
    ["/"] = "／",
    [":"] = "：",
    [";"] = "；",
    ["<"] = "《",
    ["="] = "＝",
    [">"] = "》",
    ["?"] = "？",
    ["@"] = "＠",
    ["["] = "【",
    ["\\"] = "＼",
    ["]"] = "】",
    ["^"] = "＾",
    ["_"] = "＿",
    ["`"] = "｀",
    ["{"] = "｛",
    ["|"] = "｜",
    ["}"] = "｝",
    ["~"] = "～"
}

-- 功能键 F1..F12: 无法作为普通字符键入, 直接不支持(吞键)。
local FKEYS = {}
for i = 1, 12 do
    FKEYS["F" .. i] = true
end

local function prefix(env)
    if env._compose_prefix then
        return env._compose_prefix
    end
    local pat = env.engine.schema.config:get_string('recognizer/patterns/compose') or "^C.*"
    env._compose_prefix = pat:sub(2, 2)
    return env._compose_prefix
end

local function in_compose(ctx, env)
    local input = ctx.input or ""
    return #input > 0 and input:sub(1, 1) == prefix(env)
end

local function base_name(repr)
    -- 去掉 Shift+/Control+/Alt+/Super+/Meta+ 等修饰前缀, 取基础键名
    return repr:match("([^%+]+)$") or repr
end

-- 处理器: 在 Compose 模式下拦截特殊键, 分发顺序如下:
--   * 左 Alt(Alt_L) + 任意主键盘可打印键: 直接将对应字符插入 Compose 序列(吞键);
--     便于无小键盘用户也能输入任意字符(如 Alt+1 把 "1" 加入序列), 不被数字选词/翻页/标点门控/功能键拦截。
--     可用 compose/alt_send_char 关闭(默认开启); 仅作用于左 Alt(右 Alt 为 AltGr 不命中)。
--   * 小键盘(数字/运算符): 写入对应普通字符并吞键(不二次上屏)。
--   * 小键盘 Enter 等无法键入的按键: 透传, 交由 RIME 默认处理。
--   * 主键区翻页键(-/=): 直接驱动引擎翻页(Page_Up/Page_Down)并吞键, 不进入序列。
--   * 主键区数字(1-9,0): 不参与 Compose, 透传交由 RIME 正常选词。
--   * 标点: 走命中制门控——能命中/发展为目标序列才进入, 否则退 Compose 上屏原标点。
--   * 功能键(F1-F12 等): 不支持, 吞键(不进入序列, 也不上屏)。
--   * 其余键(字母/dead 死键等): 透传, 由默认处理转写为对应字符进入序列。
local load_data -- 前向声明: 实际定义在文件下方; 本处理器与 compose 翻译器均会调用(详见下方说明)
local function compose_key(key, env)
    -- 释放事件(RIME 会向 processor 传递 key-up):
    -- 必须放行, 否则一次物理击键的「按下+抬起」会被当成两次按键,
    -- 造成小键盘单次击键被识别为重复击键(一次轻按写入两个字符)。
    if key:release() then
        return 2
    end
    local ctx = env.engine.context
    if not in_compose(ctx, env) then
        return 2
    end
    -- 确保 Compose 码表(含前缀集合)已加载: 下面的命中制门控需要查它。
    load_data(env)
    local name = base_name(key:repr() or "")
    local kc = key.keycode

    -- 左 Alt(Alt_L, 即 kAlt) + 任意主键盘可打印键: 直接将对应字符塞进 Compose 序列(吞键)。
    -- 用途: 仅主键盘的用户在 Compose 模式下也能输入任意字符(如 Alt+1 把字符 "1" 加入序列),
    --   不被数字选词 / 翻页 / 标点门控 / 功能键吞键等逻辑拦截。
    -- 用 key:alt() 判定: 它对应 kAlt(Alt_L); Linux 下右 Alt 通常是 AltGr(kAltGr, 独立修饰位),
    --   不会被命中, 故本分支天然只作用于左 Alt, 不与 AltGr 输入特殊符号冲突。
    --   额外排除 Ctrl 组合(Ctrl+Alt 在部分环境被当作 AltGr), 避免误触发。
    -- 配置开关 compose/alt_send_char(默认 true) 可关闭此行为; 仅在 Compose 模式(上方已 gate)生效。
    local alt_ch = (kc >= 0x20 and kc <= 0x7E) and string.char(kc) or nil
    if env._alt_send_char ~= false and key:alt() and not key:ctrl() and alt_ch then
        if ctx.push_input then
            ctx:push_input(alt_ch)
        else
            ctx.input = (ctx.input or "") .. alt_ch
        end
        return 1
    end

    -- 小键盘: 按恒定 keycode 识别(NumLock 开关不改变 keycode, 仅改变 repr 名)。
    -- 可键入字符(数字/运算符/标点)一律无条件写入对应字符并参与 Compose(吞键, 不二次上屏)。
    -- 小键盘区整体承担"数字序列与符号序列"的输入, 不与主键区翻页/选词功能冲突。
    local kpch = KP_BY_CODE[kc]
    if kpch then
        if ctx.push_input then
            ctx:push_input(kpch)
        else
            ctx.input = (ctx.input or "") .. kpch
        end
        return 1
    end
    -- 小键盘 Enter 等无法作为普通字符键入的按键: 透传(不吞键, 不进入序列), 交由 RIME 默认处理。
    if KP_PASSTHRU[kc] then
        return 2
    end

    -- 主键区翻页键(- / =, keycode 0x2D/0x3D): 在 Compose 模式下一律作为翻页键使用。
    -- 直接驱动引擎翻页并消费原键(return 1), 绝不透传给默认处理器,
    -- 否则 -/= 会被当成字符追加进 compose 序列(即"进 Compose 了")。
    -- 不依赖 key_binder 的 when:has_menu: Compose 翻译器每次只产出 1 个候选,
    -- 在首字符(C 后尚未出候选)或死路时 has_menu 为假, 会导致 key_binder 的 minus/equal 绑定漏网、
    -- 按键下沉到默认处理器被吞进序列。这里由本处理器直接发送 Page_Up/Page_Down 翻页(单候选时为无操作)。
    -- 注意: 此豁免会令含 -/= 的 compose 序列(如 en-dash 的 C--、C-> 等)在 Compose 模式下不可用,
    -- 这是"保留翻页而非进入合成"的取舍; 如更需要这类序列, 可改为仅 has_menu 时翻页。
    if kc == 0x2D or kc == 0x3D or name == "minus" or name == "equal" then
        local page_key = (kc == 0x2D or name == "minus") and "Page_Up" or "Page_Down"
        pcall(function()
            env.engine:process_key(KeyEvent(page_key))
        end)
        return 1
    end

    -- 主键区数字(1..9,0): 不参与 Compose, 透传交由 RIME 正常选词。
    if MAIN_DIGITS[string.char(kc)] then
        return 2
    end

    -- 计算该键对应的可键入字符(主键盘可打印字符)。
    local ch = nil
    if kc >= 0x20 and kc <= 0x7E then
        ch = string.char(kc)
    end

    -- 标点门控(命中制): 适用于所有可键入标点(PUNCT 集合, 见上方定义, 不含已豁免的主键区 -/=)。
    -- 仅当接入该字符后"能够命中"Compose 时才参与合成, 否则发挥原有上屏功能。
    -- "能够命中" = 新序列是已有编码(完整命中)或某编码的真前缀(可发展为目标序列)。
    -- 例: C 后按 "," -> 新序列 "," 是 ",A"/",C"/",," 等的真前缀 -> 参与(C,A -> Ą);
    --      已命中 C,A 后再按 "," -> 新序列 ",A," 无任何编码/前缀 -> 退出 Compose 并上屏 "C,A,"。
    --      已命中 C! 后再按 "?" -> "C!?" 无编码/前缀 -> 退出并上屏 "C!?"。
    if ch and PUNCT[ch] then
        local input = ctx.input or ""
        local after = input:sub(2) .. ch -- 去掉触发前缀 C 后的新序列
        if (env._compose_data and env._compose_data[after]) or (env._compose_prefixes and env._compose_prefixes[after]) then
            if ctx.push_input then
                ctx:push_input(ch)
            else
                ctx.input = input .. ch
            end
            return 1
        end
        -- 死路: 接入该标点后既不能命中编码, 也不是任何编码的真前缀。
        -- 上屏「前面的所有内容(剥掉末尾连续标点) + 该标点对应的中文全角标点」并退出 Compose:
        --   例: Cw, -> "Cw" 去尾标点(无) + "，" = "Cw，";
        --       Ca,, -> "Ca," 去尾标点(,) = "Ca" + "，" = "Ca，";
        --       C!? -> "C!" 去尾标点(无, ? 非尾) ... 实际 C!? 整体无编码/前缀 -> 上屏 "C!？"。
        local body = (ctx.input or ""):gsub("%p+$", "")
        env.engine:commit_text(body .. (CN_PUNCT[ch] or ch))
        ctx:clear()
        return 1
    end

    if FKEYS[name] then
        -- 功能键: 无法作为普通字符键入, 直接不支持(吞键, 不进入序列, 也不上屏)。
        return 1
    end
    -- 其余键(字母/dead 死键等): 透传, 由 RIME 默认转写为对应字符进入序列。
    return 2
end

-- 将序列中的字符还原为可读键名用于注释(小键盘数字/运算符显示为正常数码/符号)。
local function display_seq(seq)
    local out = {}
    for _, cp in utf8.codes(seq) do
        local c = utf8.char(cp)
        out[#out + 1] = c
    end
    return table.concat(out)
end

load_data = function(env)
    if env._compose_loaded then
        return true
    end
    env._compose_data = {}
    -- 前缀集合: 记录所有编码的"真前缀"(不含编码本身), 供门控判断"前缀匹配"。
    env._compose_prefixes = {}
    local config = env.engine.schema.config
    -- 左 Alt 送字符开关(默认开启): 读一次并缓存, 供 compose_key 的 Alt 分支使用;
    -- 仅当配置显式 false 时关闭, 其余(未配置/true)一律开启。
    local ok_alt, alt_val = pcall(function() return config:get_bool("compose/alt_send_char") end)
    env._alt_send_char = (ok_alt and alt_val == false) and false or true
    -- 配置和默认值均保留相对路径，统一按“用户目录 > 系统目录”查找并打开。
    local path = config:get_string("compose/data_file") or "lua/data/compose.txt"
    local f, close = wanxiang.load_file_with_fallback(path, "r")
    if not f then return false end
    for line in f:lines() do
        if line ~= "" and not line:match("^#") then
            -- 制表符分割: 编码 \t 合成结果
            local code, value = line:match("^([^\t]+)\t(.+)$")
            if code and value then
                -- 反转义: \\ -> \, \t -> 制表符
                code = code:gsub("\\t", "\t"):gsub("\\\\", "\\")
                value = value:gsub("\\t", "\t"):gsub("\\\\", "\\")
                env._compose_data[code] = value
                -- 登记该编码的所有真前缀(按 utf8 字符切分), 供前缀匹配门控使用。
                local n = utf8.len(code)
                if n and n > 1 then
                    for i = 1, n - 1 do
                        env._compose_prefixes[code:sub(1, utf8.offset(code, i + 1) - 1)] = true
                    end
                end
            end
        end
    end
    close()
    env._compose_loaded = true
    return true
end

local function compose(input, seg, env)
    -- 获取 recognizer/patterns/compose 的第 2 个字符作为触发前缀(默认 C)
    env.compose_keyword = env.compose_keyword or
                              env.engine.schema.config:get_string('recognizer/patterns/compose'):sub(2, 2)
    if seg:has_tag("compose") and env.compose_keyword ~= '' and input:sub(1, 1) == env.compose_keyword then
        if not load_data(env) then
            return
        end
        -- 剥掉触发前缀, 得到用户实际键入的组合序列
        local seq = input:sub(2)
        if #seq > 0 then
            -- 注意: seq 只剥掉了"一个"触发前缀字符(首字符 C)。
            -- 若组合序列本身以 C 开头(如系统表的 <C><O>→©), 正确打法是 CCO,
            -- 剥首字符后得到 "CO" 查表命中。切勿改成 ^C+ 之类剥掉多个 C 的写法。
            local result = env._compose_data[seq]
            local is_prefix = env._compose_prefixes and env._compose_prefixes[seq]
            if result then
                -- 命中: 直接给出合成结果候选, 强制为第一候选。
                local cand = Candidate("compose", seg.start, seg._end, result, "[Compose] " .. display_seq(seq))
                cand.quality = 1000000
                yield(cand)
            elseif is_prefix then
                -- 仅命中前缀(未完整命中): 候选正文为字面序列 "C<序列>", 注释 "[Compose] <序列> ~",
                -- 强制为第一候选; 提示用户仍在序列途中(可继续键入或按标点退出 Compose)。
                local seq_disp = display_seq(seq)
                local cand =
                    Candidate("compose", seg.start, seg._end, "C" .. seq_disp, "[Compose] " .. seq_disp .. " ~")
                cand.quality = 1000000
                yield(cand)
            end
            -- 其余(既非命中也非任何编码前缀的死路): 不显示 Compose 候选(用户可按标点退出上屏字面序列)。
        end
    end
end

return {
    processor = compose_key,
    translator = compose
}