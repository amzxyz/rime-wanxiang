-- user_predict.lua
-- https://github.com/amzxyz/rime-wanxiang
-- by amzxyz
-- 架构层: Processor (物理按键截取与逻辑分发) + Translator (候选词生成与上屏) + Filter (输入调频)
-- 算法层:
-- 1. 瀑布流查询模型 (S-Gram -> 2-Gram 精确 -> 1-Gram 断崖回退 -> P-Gram 模糊抗抖动)
-- 2. c 值直接排名 (稳定 raw key，同步时同键去重)
-- 3. 负 c 墓碑删除 (删除与恢复均递增绝对值，避免同值折返)
-- 4. 事务级回滚机制 (拦截上屏立即退格，复原上次数据库操作)
-- 5. c 值合并 (导入与同步均按绝对值较大的状态优先)
-- 6. ABA 防折返输入 (拦截如"你好"->"你好"的自我循环，减少数据库无效记录)
-- 7. 继承原生主动删除 (Ctrl+Del / Shift+Del 物理销毁当前候选词的多维关联)
-- 8. 语境隔离与时效防御 (精准识别标点断句，外加 5秒 语境超时自动熔断防穿透)
-- 9. 语气助词智能白名单 (特许“吧呢吗”等助词接标点的合法性，实现终结符平滑解耦)
-- 10. 跨平台双层按键防线 (针对移动端软键盘强删字节的底层特性，彻底免疫退格乱码)
-- 11. 融合前端联动删除机制 (捕获前端发送的 delete_notifier，实现点击/手势删词同步清除数据库)

local insert   = table.insert
local remove   = table.remove
local sort     = table.sort
local s_match  = string.match
local s_sub    = string.sub
local s_len    = string.len
local s_find   = string.find
local s_format = string.format
local tonumber = tonumber
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local os_time  = os.time
local wanxiang = require("wanxiang/wanxiang")
local userdb = require("wanxiang/userdb")
local shared_reverted_code = ""
local shared_is_backspacing = false
-- 旧格式迁移由外部 migrate_predict_v3.py 完成。
-- 运行时使用稳定的 code<TAB>phrase / c-d-t 记录，保证同步同键合并。
local KEY_SEP = ";"
local S_PREFIX = "S" .. KEY_SEP
local P_PREFIX = "P" .. KEY_SEP
local ONE_PREFIX = "1" .. KEY_SEP
local TWO_PREFIX = "2" .. KEY_SEP
local RECORD_SEPARATOR = " \t"
local C_MAX = 2147483000
-- 内部运行参数默认值 (会被外部 YAML 配置覆盖)
local CONFIG = {
    MAX_CANDIDATES      = 5,             
    MAX_PREDICTIONS     = 3,             
    MAX_MEMORY_BRANCHES = 15,            
    SCAN_LIMIT          = 80,            
    CONTEXT_TIMEOUT_MS  = 5000,
    PREDICT_STYLE       = "off",
    ENABLE_FALLBACK_REORDER = true,
}
local is_after_number = false  --量词调频状态
-- 量词动态查找表与构建函数
local CLASSIFIER_LOOKUP = {}
-- 量词兜底字符串
local default_classifiers = "百千万亿个多只名位口头匹条群批伙张把件台部块根颗粒滴片朵面扇顶栋座所辆艘架盏支枝杆双对副套打串束排阵堆叠摞扎杯瓶盒包份碗锅盆桶袋罐盘次场局回趟顿番遍声项宗桩款步招年月天周岁秒分刻代期届任夜季本册篇首句段卷幅节堂门帖字行米寸尺里斤两吨克升元角毛笔"

-- 根据配置字符串构建量词快速查找表。
local function build_classifier_lookup(str)
    CLASSIFIER_LOOKUP = {}
    if not str or str == "" then return end 
    for c in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
        if not s_match(c, "%s") then 
            CLASSIFIER_LOOKUP[c] = true
        end
    end
end
-- 语气助词白名单与高频句末白名单
local PARTICLE_WHITELIST = {
    ["吧"]=true, ["呢"]=true, ["吗"]=true, ["啦"]=true,
    ["嘛"]=true, ["呀"]=true, ["恩"]=true, ["欸"]=true,
    ["哒"]=true, ["哈"]=true, ["哇"]=true, ["啊"]=true,
    ["哦"]=true, ["噢"]=true, ["咯"]=true, ["呗"]=true,
    ["哟"]=true, ["呦"]=true, ["哎"]=true, ["嗯"]=true,
    ["么"]=true, ["啥"]=true, ["谁"]=true, ["哪"]=true,
    ["里"]=true, ["儿"]=true, ["了"]=true, ["的"]=true,
    ["过"]=true, ["好"]=true, ["行"]=true, ["对"]=true, ["成"]=true
}

-- 判断文本是否为允许参与语境处理的语气标点。
local function is_tone_symbol(text) 
    return s_match(text, "^[！？，。～]+$") ~= nil 
end

-- 在缺少原生 utf8.len 时提供兼容的字符数统计。
local utf8_len = utf8 and utf8.len or function(str)
    local _, count = string.gsub(str, "[^\128-\191]", "")
    return count
end
-- 动态加载 YAML 方案配置
local function load_config(env)
    local config = env.engine.schema.config
    if config then
        CONFIG.MAX_CANDIDATES      = config:get_int("user_predict/max_candidates") or 5
        CONFIG.MAX_PREDICTIONS     = config:get_int("user_predict/max_predictions") or 3
        CONFIG.MAX_MEMORY_BRANCHES = config:get_int("user_predict/max_memory_branches") or 15
        local timeout_val = config:get_int("user_predict/context_timeout")
        if timeout_val ~= nil then CONFIG.CONTEXT_TIMEOUT_MS = timeout_val end
        -- 移动端用 mobile_predict_style，PC端默认 reorder 调频
        if wanxiang.is_mobile_device() then
            local mobile_style = config:get_string("user_predict/mobile_predict_style")
            if mobile_style ~= nil then CONFIG.PREDICT_STYLE = mobile_style end
        else
            CONFIG.PREDICT_STYLE = "reorder"
        end
        local fallback_val = config:get_bool("user_predict/enable_fallback_reorder")
        if fallback_val ~= nil then CONFIG.ENABLE_FALLBACK_REORDER = fallback_val end
        local custom_node = config:get_item("user_predict/custom_classifiers")
        if custom_node then
            local custom_str = ""
            local list = config:get_list("user_predict/custom_classifiers")
            if list then
                for i = 0, list.size - 1 do
                    local val = list:get_value_at(i)
                    if val then 
                        custom_str = custom_str .. val:get_string() 
                    end
                end
            else
                custom_str = config:get_string("user_predict/custom_classifiers") or ""
            end
            build_classifier_lookup(custom_str)
        else
            build_classifier_lookup(default_classifiers)
        end
    end
end

local PH_CHAR = "›"

local history = {}
local last_commit = ""
local last_commit_time = 0
local predict_count = 0
local is_predicting = false
local pending_cands = nil

-- 内存阻断模块：打断语境后洗白临时记忆链，防止长距离上下文穿透
local function reset_memory_chain(env, reason)
    for i = 1, #history do history[i] = nil end
    last_commit = ""
    last_commit_time = 0
    predict_count = 0
    is_predicting = false
    pending_cands = nil
    env.need_push = false
end

-- 解析稳定记录尾部中的 c 字段。
local function parse_record_tail(tail)
    if type(tail) ~= "string" then return 0 end
    return tonumber(s_match(tail, "c=([^%s\t]+)")) or 0
end

-- 生成经过范围保护的预测记录尾部；d/t 仅作 UserDb 格式占位。
local function make_record_tail(commits)
    commits = math_max(-C_MAX, math_min(C_MAX, commits or 0))
    return s_format("c=%d d=0 t=0", commits)
end

-- 判断文本是否为完整的 c/d/t 记录尾部。
local function is_record_tail(tail)
    if type(tail) ~= "string" then return false end

    local commits, deletes, tick = s_match(
        tail,
        "^c=([^%s\t]+)%s+d=([^%s\t]+)%s+t=([^%s\t]+)$"
    )

    return tonumber(commits) ~= nil
        and tonumber(deletes) ~= nil
        and tonumber(tick) ~= nil
end


-- 在预测业务层生成完整 raw key。
local function make_raw_key(code, word)
    if not code or code == "" or not word or word == "" then return nil end
    return code .. RECORD_SEPARATOR .. word
end

-- 将完整 raw key 拆分为预测 code 和候选词。
local function parse_raw_key(raw_key)
    if type(raw_key) ~= "string" then return nil, nil end

    local split_pos = s_find(raw_key, RECORD_SEPARATOR, 1, true)
    if not split_pos then return nil, nil end

    local code = s_sub(raw_key, 1, split_pos - 1)
    local word = s_sub(raw_key, split_pos + s_len(RECORD_SEPARATOR))
    if code == "" or word == "" then return nil, nil end
    return code, word
end

-- 精确读取预测记录及其完整 raw key。
local function fetch_record(db, code, word)
    local raw_key = make_raw_key(code, word)
    if not raw_key then return 0, nil, nil end

    local tail = db:fetch(raw_key)
    return parse_record_tail(tail), tail, raw_key
end

-- 精确写入预测记录的 c 值。
local function update_record(db, code, word, commits)
    local raw_key = make_raw_key(code, word)
    if not raw_key then return false end
    return db:update(raw_key, make_record_tail(commits))
end

-- 根据当前状态生成下一次有效学习计数。
local function next_active_commits(commits)
    local magnitude = math_abs(commits or 0)

    if magnitude >= C_MAX then return C_MAX end
    return magnitude + 1
end

-- 使用递增绝对值的负 c 墓碑标记预测记录已删除。
local function mark_record_deleted(db, code, word)
    local commits, tail, raw_key = fetch_record(db, code, word)
    if not raw_key then return false end
    if not tail then return true end

    local magnitude = math_abs(commits)
    if magnitude < C_MAX then magnitude = magnitude + 1 end
    if magnitude == 0 then magnitude = 1 end

    return db:update(raw_key, make_record_tail(-magnitude))
end

-- 解析预测导入文件中的稳定记录行。
local function split_predict_line(line)
    if not line or line == "" then return nil, nil, nil end

    line = line:gsub("\r$", "")
    local code, word, tail = line:match("^(.-)\t(.-)\t(.+)$")
    if not code or code == "" or not word or word == "" then
        return nil, nil, nil
    end

    if not is_record_tail(tail) then
        local commits = tonumber(tail)
        if not commits then return nil, nil, nil end
        tail = make_record_tail(commits)
    end

    return code, word, tail
end

local _db_pool, _db_refs = {}, {}

-- 获取并引用当前方案共用的预测数据库。
local function get_db(env)
    if env.predict_db then return env.predict_db end

    local config = env.engine.schema.config
    local db_name = config:get_string("user_predict/db_name") or "lua/predict"
    local db = _db_pool[db_name]

    if not db then
        db = userdb.LevelDb(db_name)
        if not db then return nil end
        _db_pool[db_name] = db
    end

    if not db:loaded() and not db:open() then
        _db_pool[db_name] = nil
        return nil
    end

    _db_refs[db_name] = (_db_refs[db_name] or 0) + 1
    env.predict_db, env.predict_db_name = db, db_name
    return db
end

-- 释放当前组件的数据库引用并在最后关闭数据库。
local function release_db(env)
    local db, db_name = env.predict_db, env.predict_db_name
    if not db or not db_name then return end

    env.predict_db, env.predict_db_name = nil, nil

    local refs = (_db_refs[db_name] or 1) - 1
    if refs > 0 then
        _db_refs[db_name] = refs
        return
    end

    _db_refs[db_name] = nil
    _db_pool[db_name] = nil

    -- db 仍由局部变量持有；先回收此前已失去引用的查询访问器，再关闭数据库。
    collectgarbage("collect")
    db:close()
end


-- 语境分割算法 (纯汉字白名单)
local function is_chinese_char(char)
    local cp = utf8 and utf8.codepoint(char) or 0
    if not cp or cp == 0 then return false end
    return (cp >= 0x4E00 and cp <= 0x9FFF)   -- Basic
        or (cp >= 0x3400 and cp <= 0x4DBF)  -- Ext A
        or (cp >= 0x20000 and cp <= 0x2A6DF) -- Ext B
        or (cp >= 0x2A700 and cp <= 0x2B73F) -- Ext C
        or (cp >= 0x2B740 and cp <= 0x2B81F) -- Ext D
        or (cp >= 0x2B820 and cp <= 0x2CEAF) -- Ext E
        or (cp >= 0x2CEB0 and cp <= 0x2EBEF) -- Ext F
        or (cp >= 0x30000 and cp <= 0x3134F) -- Ext G
        or (cp >= 0x31350 and cp <= 0x323AF) -- Ext H
        or (cp >= 0x2EBF0 and cp <= 0x2EE5F) -- Ext I
        or (cp >= 0xF900  and cp <= 0xFAFF)  -- Compatibility
        or (cp >= 0x2F800 and cp <= 0x2FA1F) -- Compatibility Supplement
        or (cp >= 0x2E80  and cp <= 0x2EFF)  -- Radicals Supplement
        or (cp >= 0x2F00  and cp <= 0x2FDF)  -- Kangxi Radicals
end

-- 判断上屏文本是否允许进入预测语境。
local function is_valid_commit_text(text)
    if not text or text == "" then return false end
    if is_tone_symbol(text) then return true end -- 特许白名单语气标点通行
    for c in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
        if not is_chinese_char(c) then return false end
    end
    return true
end

-- 分词聚集算法
local function get_utf8_chars(str)
    if not str or str == "" then return {} end
    if s_match(str, "^[a-zA-Z0-9]+$") or is_tone_symbol(str) then return { str } end
    local chars = {}
    if utf8 and utf8.codes then
        for _, c in utf8.codes(str) do
            insert(chars, utf8.char(c))
        end
    else
        for c in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
            insert(chars, c)
        end
    end
    return chars
end

-- 模糊查询降级参数 (现在统一供 1 和 P 使用)
local function get_suffix_lengths(len)
    if len >= 4 then return {4, 3, 2} 
    elseif len == 3 then return {3, 2}    
    elseif len == 2 then return {2}       
    elseif len == 1 then return {1} end
    return {}
end

-- 读取层预测核心
local function get_predictions(env, prev_commit)
    if not prev_commit or prev_commit == "" then return nil end

    local db = get_db(env)
    if not db then return nil end

    local cands = {}
    local seen = {}
    local scan_limit = CONFIG.SCAN_LIMIT

    -- 查询单个预测层级并按权重收集候选。
    local function fetch_candidates(code, multiplier)
        local prefix = code .. RECORD_SEPARATOR
        local accessor = db:query(prefix)
        if not accessor then return end

        local prefix_cands = {}
        local scan_count = 0

        for raw_key, tail in accessor:iter() do
            if scan_count >= scan_limit
                or s_sub(raw_key, 1, s_len(prefix)) ~= prefix
            then
                break
            end

            local record_code, word = parse_raw_key(raw_key)
            local commits = parse_record_tail(tail)

            if record_code == code and commits > 0 and word ~= "" then
                insert(prefix_cands, {
                    word = word,
                    weight = commits * multiplier,
                    db_code = record_code,
                    db_word = word,
                })
            end

            scan_count = scan_count + 1
        end

        accessor = nil

        if #prefix_cands == 0 then return end

        -- 按当前层级计算后的权重降序排列。
        sort(prefix_cands, function(a, b) return a.weight > b.weight end)

        for i, cand in ipairs(prefix_cands) do
            if i <= CONFIG.MAX_MEMORY_BRANCHES then
                if not seen[cand.word] then
                    insert(cands, cand)
                    seen[cand.word] = true
                end
            else
                mark_record_deleted(db, cand.db_code, cand.db_word)
            end
        end
    end

    -- S先读
    if #history >= 1 then
        fetch_candidates(S_PREFIX .. history[#history], 1000000)
    end

    -- 小于等于2先找上文组合查 2-Gram
    if #history >= 2 then
        local u0 = history[#history - 1]
        local u1 = history[#history]
        local len_u0 = u0 and utf8_len(u0) or 0
        local len_u1 = u1 and utf8_len(u1) or 0

        if len_u1 <= 4 and (len_u0 + len_u1) <= 5 then
            fetch_candidates(
                TWO_PREFIX .. u0 .. KEY_SEP .. u1,
                10000
            )
        end
    end

    -- 查 1-Gram
    if #cands < CONFIG.MAX_CANDIDATES and #history >= 1 then
        local u1 = history[#history]
        local chars = get_utf8_chars(u1)
        local len_u1 = #chars
        local max_len = math_min(len_u1, 4)
        local min_len = len_u1 >= 2 and 2 or 1

        for l = max_len, min_len, -1 do
            local lookup_u1 =
                table.concat(chars, "", len_u1 - l + 1, len_u1)

            fetch_candidates(ONE_PREFIX .. lookup_u1, 100)
            if #cands > 0 then break end
        end
    end

    -- 查不到再去拿 P 去匹配
    if #cands < CONFIG.MAX_CANDIDATES then
        local chars = get_utf8_chars(prev_commit)
        local lengths_to_query = get_suffix_lengths(#chars)

        for _, l in ipairs(lengths_to_query) do
            local suffix = table.concat(chars, "", #chars - l + 1, #chars)
            fetch_candidates(P_PREFIX .. suffix, 1)
            if #cands > 0 then break end
        end
    end

    if #cands == 0 then return nil end

    -- 汇总所有层级后按最终权重降序排列。
    sort(cands, function(a, b) return a.weight > b.weight end)
    return cands
end


-- 物理按键与前端通用的删除逻辑
local function remove_predict_candidate(env, word)
    local db = get_db(env)

    if pending_cands then
        for _, cand in ipairs(pending_cands) do
            if cand.word == word then
                mark_record_deleted(db, cand.db_code, cand.db_word)
                break
            end
        end
    end

    local chars = get_utf8_chars(last_commit)
    local lengths = get_suffix_lengths(#chars)

    for _, l in ipairs(lengths) do
        local suffix = table.concat(chars, "", #chars - l + 1, #chars)
        mark_record_deleted(db, P_PREFIX .. suffix, word)
    end
end


local P = {}
-- 初始化按键处理器、数据库及上下文通知器。
function P.init(env)
    load_config(env) 
    env.is_t9 = false
    if wanxiang.get_input_method_type then
        env.is_t9 = (wanxiang.get_input_method_type(env) == "t9")
    end
    local db = get_db(env)
    if not db then return end

    env.need_push = false 
    env.last_written_keys = {}
    env.undo_transaction = nil
    env.just_committed = false
    
    -- 处理上屏事件并学习当前预测语境。
    env.commit_cb = function(ctx)
        shared_reverted_code = ""
        env.undo_transaction = nil
        env.just_committed = false

        local text = ctx:get_commit_text()
        if not s_match(text, "^[0-9]+$") then
            is_after_number = false
        end
        if not is_valid_commit_text(text) then
            reset_memory_chain(env, "非纯汉字阻断")
            return
        end

        local current_time = (rime_api and rime_api.get_time_ms) and rime_api.get_time_ms() or (os_time() * 1000)
        if last_commit ~= "" and (current_time - last_commit_time) > CONFIG.CONTEXT_TIMEOUT_MS then
            reset_memory_chain(env, "输入超时") 
        end

        if not is_predicting then 
            is_predicting = true 
            predict_count = 1
        else
            predict_count = predict_count + 1
        end
        
        if predict_count > CONFIG.MAX_PREDICTIONS then
            is_predicting = false
            predict_count = 0
            pending_cands = nil
            return
        end

        env.last_written_keys = {} 
        -- 更新单条记忆关联，并保存本次事务写入前后的完整状态。
        local function update_memory(code, word)
            if not code or code == "" or not word or word == "" then return end

            local commits, tail, raw_key = fetch_record(db, code, word)
            local next_tail = make_record_tail(next_active_commits(commits))
            local state = env.last_written_keys[raw_key]

            if state then
                state.after = next_tail
            else
                env.last_written_keys[raw_key] = {
                    before = tail or "",
                    after = next_tail,
                }
            end

            db:update(raw_key, next_tail)
        end

        current_time = (rime_api and rime_api.get_time_ms) and rime_api.get_time_ms() or (os_time() * 1000)
        
        local should_record = true
        local is_terminal_symbol = false
        local is_aba_return = false
        local text_chars = get_utf8_chars(text)
        local len_text = #text_chars

        -- 基础规则：单次上屏超过 4 个字不记录
        if len_text > 4 then should_record = false end
        
        -- 基础规则：标点与助词白名单隔离
        if should_record and is_tone_symbol(text) then
            local prev_chars = get_utf8_chars(last_commit)
            local last_char = prev_chars[#prev_chars] or "" 
            
            if not PARTICLE_WHITELIST[last_char] then
                should_record = false
                reset_memory_chain(env, "非助词接标点") 
            else
                is_terminal_symbol = true 
            end
        end

        -- 基础规则：防重复与 ABA 折返输入。
        if should_record and last_commit == text then should_record = false end
        if should_record and #history >= 2
            and text == history[#history - 1]
        then
            should_record = false
            is_aba_return = true
        end

        -- 核心录入逻辑区
        if should_record then
            -- 常规上文级联录入
            if last_commit ~= "" then
                local u1_chars = get_utf8_chars(last_commit)
                local len_u1 = #u1_chars
                
                -- P-Gram
                local lengths_to_learn = get_suffix_lengths(len_u1)
                for _, l in ipairs(lengths_to_learn) do
                    if l < len_u1 or len_u1 >= 4 then
                        local suffix = table.concat(u1_chars, "", len_u1 - l + 1, len_u1)
                        update_memory(P_PREFIX .. suffix, text)
                    end
                end
                
                -- 1-Gram
                if len_u1 <= 4 and #history >= 1 then 
                    update_memory(ONE_PREFIX .. last_commit, text)
                end
                
                -- 2-Gram
                if len_u1 <= 4 and #history >= 2 then
                    local u0 = history[#history - 1]
                    local len_u0 = u0 and #get_utf8_chars(u0) or 0
                    if (len_u0 + len_u1) <= 5 then
                        update_memory(TWO_PREFIX .. u0 .. KEY_SEP .. last_commit, text)
                    end
                end
            end
            -- 四字纯中文整句按 2+2 自动拆分学习。
            -- 无论候选原始排名如何，只要最终上屏文本为四个汉字，
            -- 都直接记录“前两字 -> 后两字”，支持首次输入即建立关联。
            if len_text == 4 then
                local part1 = text_chars[1] .. text_chars[2]
                local part2 = text_chars[3] .. text_chars[4]
                update_memory(ONE_PREFIX .. part1, part2)
            end
        end
        
        -- 调用逻辑解耦
        if should_record then
            if is_terminal_symbol then
                reset_memory_chain(env, "终结符上屏完毕") 
            else
                insert(history, text)
                if #history > 2 then remove(history, 1) end
                last_commit = text
            end
        elseif is_aba_return then
            for i = #history, 1, -1 do history[i] = nil end
            insert(history, text)
            last_commit = text
        end

        -- 回滚只绑定当前这次上屏；本次没有写库时不得继承旧事务。
        if next(env.last_written_keys) then
            env.undo_transaction = env.last_written_keys
        else
            env.undo_transaction = nil
        end

        last_commit_time = current_time
        env.last_action_time = current_time
        env.just_committed = true
        
        -- 如果两个开关都没开，绝对不去查库！绝对不建缓存
        if predict_count <= CONFIG.MAX_PREDICTIONS and ctx:get_option("prediction") then
            if CONFIG.PREDICT_STYLE ~= "off" then
                pending_cands = get_predictions(env, last_commit)
                if pending_cands then 
                    if CONFIG.PREDICT_STYLE == "post" then
                        env.need_push = true 
                    else
                        predict_count = 0; is_predicting = false
                    end
                else
                    predict_count = 0; is_predicting = false; pending_cands = nil
                end
            else
                predict_count = 0; is_predicting = false; pending_cands = nil
            end
        else
            predict_count = 0; is_predicting = false; pending_cands = nil
        end
    end
    
    -- 处理输入框变化以及预测数据导入导出命令。
    env.update_cb = function(ctx)
        local input = ctx.input or ""
        if is_predicting and not s_find(input, PH_CHAR) and not env.need_push then
            -- 软键盘输入、候选切换或前端清空占位符时，只关闭联想界面。
            -- 保留 history / last_commit，确保随后上屏的任意候选都能继续学习。
            predict_count = 0
            is_predicting = false
            pending_cands = nil
        end

        if input == "/outpredict" then
            ctx:clear()

            local export_path =
                rime_api.get_user_data_dir() .. "/predict_export.txt"
            local file = io.open(export_path, "w")

            if file then
                local accessor = db:query("")

                if accessor then
                    for raw_key, tail in accessor:iter() do
                        local code, word = parse_raw_key(raw_key)

                        if code and word
                            and s_sub(code, 1, 1) ~= "\1"
                            and s_sub(code, 1, 1) ~= "\0"
                            and not s_find(word, "|", 1, true)
                            and is_record_tail(tail)
                        then
                            file:write(code, "\t", word, "\t", tail, "\n")
                        end
                    end

                    accessor = nil
                end

                file:close()
            end

            reset_memory_chain(env, "导出结束")
            return
        end

        if input == "/inpredict" then
            ctx:clear()

            local import_path =
                rime_api.get_user_data_dir() .. "/predict_import.txt"
            local file = io.open(import_path, "r")

            if file then
                for line in file:lines() do
                    local code, word, tail = split_predict_line(line)

                    if code and word and tail
                        and not s_find(word, "|", 1, true)
                    then
                        local incoming = parse_record_tail(tail)
                        local current = fetch_record(db, code, word)

                        local incoming_abs = math_abs(incoming)
                        local current_abs = math_abs(current)
                        local should_update =
                            incoming_abs > current_abs
                            or incoming_abs == current_abs
                                and incoming < 0 and current >= 0

                        if should_update then
                            update_record(db, code, word, incoming)
                        end
                    end
                end

                file:close()
            end

            reset_memory_chain(env, "导入结束")
            return
        end

        local expected_ph = string.rep(PH_CHAR, predict_count)
        local expected_len = string.len(expected_ph)

        if env.need_push and input == "" then
            env.need_push = false
            ctx:push_input(expected_ph)
            ctx.caret_pos = expected_len
            return
        end
        
        if s_find(input, PH_CHAR) then
            if input ~= expected_ph then
                local clean_text = string.gsub(input, PH_CHAR, "")
                ctx:clear()
                predict_count = 0
                is_predicting = false
                pending_cands = nil
                if clean_text ~= "" then ctx:push_input(clean_text) end
                return
            else
                if ctx.caret_pos < expected_len then 
                    ctx:clear()
                    predict_count = 0
                    is_predicting = false
                    pending_cands = nil
                    return 
                end
            end
        end
    end

    -- 处理前端候选删除通知并同步写入墓碑。
    env.delete_cb = function(ctx)
        local comp = ctx.composition
        if not comp or comp:empty() then return end
        
        local seg = comp:back()
        local idx = seg.selected_index
        local cand = seg:get_candidate_at(idx)
        
        if cand and cand.type == "predict" then
            remove_predict_candidate(env, cand.text)
            ctx:clear()
            -- 考虑到此时前端已经自行操作 UI 销毁了词汇，为保持一致打断记忆链
            reset_memory_chain(env, "前端主动销毁词条")
        end
    end

    env.commit_connection = env.engine.context.commit_notifier:connect(env.commit_cb)
    env.update_connection = env.engine.context.update_notifier:connect(env.update_cb)
    env.delete_connection = env.engine.context.delete_notifier:connect(env.delete_cb)
end

-- 处理物理按键、预测打断、删除和事务回滚。
function P.func(key, env)
    local ctx = env.engine.context
    local input = ctx.input
    if not input then return 2 end
    if key:release() then return 2 end
    local repr = key:repr()
    if repr == "BackSpace" then
        if not shared_is_backspacing and ctx:is_composing() then
            local current_input = ctx.input or ""
            if current_input ~= "" then
                if shared_reverted_code == current_input then
                    shared_reverted_code = "" 
                else
                    shared_reverted_code = current_input
                end
            end
        end
        shared_is_backspacing = true
    elseif not s_find(repr, "Shift", 1, true) and not s_find(repr, "Control", 1, true) and not s_find(repr, "Alt", 1, true) then
        shared_is_backspacing = false
    end

    if env.just_committed and repr ~= "BackSpace"
        and not s_find(repr, "Shift", 1, true)
        and not s_find(repr, "Control", 1, true)
        and not s_find(repr, "Alt", 1, true)
    then
        env.just_committed = false
        env.undo_transaction = nil
    end
    
    if repr == "BackSpace" then
        local current_time = (rime_api and rime_api.get_time_ms)
            and rime_api.get_time_ms() or (os_time() * 1000)
        local is_safe_to_undo = env.just_committed
            and env.undo_transaction
            and (not ctx:is_composing() or is_predicting)

        if is_safe_to_undo
            and (current_time - (env.last_action_time or 0))
                <= CONFIG.CONTEXT_TIMEOUT_MS
        then
            local db = get_db(env)

            for raw_key, state in pairs(env.undo_transaction) do
                local current_tail = db:fetch(raw_key)

                if current_tail == state.after then
                    if state.before == "" then
                        db:erase(raw_key)
                    else
                        db:update(raw_key, state.before)
                    end
                end
            end

            env.last_action_time = current_time
        end

        env.undo_transaction = nil
        env.just_committed = false
        if is_predicting then
            ctx:clear()
            reset_memory_chain(env, "退格强清联想")
            return 1 
        end
    end
    
    if is_predicting then
        -- 数字键打断联想并上屏数字
        if s_match(repr, "^[0-9]$") or s_match(repr, "^KP_[0-9]$") then
            if env.is_t9 then
                -- T9: 数字键是编码，放行
                env.engine.context:clear()
                reset_memory_chain(env, "T9数字放行起音节")
                return 2
            end
            local digit = s_match(repr, "%d")
            ctx:clear()
            reset_memory_chain(env, "数字打断联想并上屏")
            env.engine:commit_text(digit)
            return 1
        end
        
        -- 普通输入只关闭联想界面，保留上文供下一次上屏继续学习
        predict_count = 0
        is_predicting = false
        pending_cands = nil
        env.need_push = false
        ctx:clear()
        return 2
    end

    if not ctx:is_composing() then
        if s_match(repr, "^[0-9]$") or s_match(repr, "^KP_[0-9]$") then
            is_after_number = true
        elseif repr == "BackSpace" then
            is_after_number = false
        end
        if repr == "Return" or repr == "KP_Enter" or key.keycode == 0x20 then
            reset_memory_chain(env, "非输入状态排版打断")
            return 2 
        end
        local symbol_map = { ["?"] = "？", ["!"] = "！", [","] = "，", ["."] = "。" }
        if symbol_map[repr] then
            env.engine:commit_text(symbol_map[repr])
            return 1
        end
    end

    if ctx:has_menu() and (s_find(repr, "Shift") or s_find(repr, "Control")) and (s_find(repr, "Delete") or s_find(repr, "BackSpace")) then
        local cand = ctx:get_selected_candidate()
        if cand and cand.type == "predict" then
            remove_predict_candidate(env, cand.text)
            ctx:clear()
            reset_memory_chain(env, "物理按键销毁词条")
            return 1
        end
    end
    return 2 
end

-- 断开按键处理器通知器并释放数据库。
function P.fini(env)
    if env.commit_connection then
        env.commit_connection:disconnect()
        env.commit_connection = nil
    end

    if env.update_connection then
        env.update_connection:disconnect()
        env.update_connection = nil
    end

    if env.delete_connection then
        env.delete_connection:disconnect()
        env.delete_connection = nil
    end

    env.commit_cb = nil
    env.update_cb = nil
    env.delete_cb = nil
    env.last_written_keys = nil
    env.undo_transaction = nil

    reset_memory_chain(env, "方案切换")
    shared_reverted_code = ""
    shared_is_backspacing = false
    is_after_number = false

    release_db(env)
end

local T = {}
function T.init(env)
    load_config(env)
end

-- 在后置联想模式下生成预测候选。
function T.func(input, seg, env)
    -- 受总开关与联想开关联合控制
    if not env.engine.context:get_option("prediction") or CONFIG.PREDICT_STYLE ~= "post" then return end
    
    if s_match(input, "^[›]+$") and pending_cands then
        local count = 0
        for _, c in ipairs(pending_cands) do
            if count >= CONFIG.MAX_CANDIDATES then break end
            local cand = Candidate("predict", seg.start, seg._end, c.word, "")
            yield(cand)
            count = count + 1
        end
    end
end

function T.fini(env) end

-- Filter (F): 负责输入生命周期内的极速实时调频
local F = {}

-- 快速检测纯英文字母文本（替代 s_find 正则，结果完全等价）
local function is_alpha_fast(s)
  if not s or s == "" then return false end
  local b = string.byte(s, 1)
  if not ((b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A)) then return false end
  for i = 2, #s do
    b = string.byte(s, i)
    if not ((b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A)) then return false end
  end
  return true
end

function F.init(env)
    env.f_last_pending_cands = nil
    env.f_reorder_map = nil
    env.shared_boosted = {}
    env.shared_normal = {}
end

-- 按预测排名排序，并用原始序号保持稳定性。
local function stable_sort(a, b)
    if a.rank == b.rank then return a.index < b.index end
    return a.rank < b.rank
end

-- 按正常或回头码兜底顺序输出候选。
local function flush_yield(b_list, b_cnt, n_list, n_cnt, fallback)
    if not fallback then
        for i = 1, b_cnt do yield(b_list[i].cand) end
        for i = 1, n_cnt do yield(n_list[i]) end
    else
        if b_cnt >= 2 then
            yield(b_list[2].cand); yield(b_list[1].cand)
            for i = 3, b_cnt do yield(b_list[i].cand) end
            for i = 1, n_cnt do yield(n_list[i]) end
        elseif b_cnt == 1 and n_cnt >= 1 then
            yield(n_list[1]); yield(b_list[1].cand)
            for i = 2, n_cnt do yield(n_list[i]) end
        elseif b_cnt == 0 and n_cnt >= 2 then
            yield(n_list[2]); yield(n_list[1])
            for i = 3, n_cnt do yield(n_list[i]) end
        else
            if b_cnt == 1 then yield(b_list[1].cand) end
            if n_cnt == 1 then yield(n_list[1]) end
        end
    end
end

-- 根据预测记录和量词状态实时调整候选顺序。
function F.func(input, env)
    local ctx = env.engine.context
    local shared_boosted = env.shared_boosted or {}
    local shared_normal = env.shared_normal or {}
    env.shared_boosted = shared_boosted
    env.shared_normal = shared_normal

    if not ctx:get_option("prediction") or s_match(ctx.input or "", "^[›]+$") then
        for cand in input:iter() do yield(cand) end
        return
    end

    if CONFIG.PREDICT_STYLE ~= "reorder" and not CONFIG.ENABLE_FALLBACK_REORDER then
        for cand in input:iter() do yield(cand) end
        return
    end

    if env.f_last_pending_cands ~= pending_cands then
        env.f_last_pending_cands = pending_cands
        env.f_reorder_map = nil

        if CONFIG.PREDICT_STYLE == "reorder" and pending_cands then
            env.f_reorder_map = {}
            for rank, cand in ipairs(pending_cands) do
                env.f_reorder_map[cand.word] = rank
            end
        end
    end

    local do_reorder = env.f_reorder_map and next(env.f_reorder_map)
    local do_classifier = is_after_number and CLASSIFIER_LOOKUP and next(CLASSIFIER_LOOKUP)
    
    local current_input = ctx.input or ""
    local do_fallback = CONFIG.ENABLE_FALLBACK_REORDER and current_input == shared_reverted_code and shared_reverted_code ~= ""

    if do_fallback then
        do_reorder = false
        do_classifier = false
    end
    
    if (not do_reorder and not do_classifier and not do_fallback) or current_input == "" then
        for cand in input:iter() do yield(cand) end
        return
    end

    -- 极速旁路通道 (0 运算，0 分配，专供回头码使用)
    if do_fallback then
        local idx = 0
        local c1 = nil
        for cand in input:iter() do
            idx = idx + 1
            if idx == 1 then
                c1 = cand
            elseif idx == 2 then
                local ct = cand.type
                local is_cand_valid = ct ~= "raw" and ct ~= "english" and not is_alpha_fast(cand.text)
                if c1.type ~= "sentence" and is_cand_valid and c1._end == cand._end then
                    yield(cand)
                    yield(c1)
                else
                    yield(c1)
                    yield(cand)
                end
            else
                yield(cand)
            end
        end
        if idx == 1 and c1 then yield(c1) end
        return
    end

    local b_cnt = 0
    local n_cnt = 0
    
    local count = 0
    local max_scan = 20
    local target_len = 0
    local target_end = 0

    for cand in input:iter() do
        count = count + 1
        local text = cand.text or ""
        local ct = cand.type
        local current_len = utf8_len(text) or 0
        
        if count == 1 then 
            target_len = current_len 
            target_end = cand._end
            if ct == "sentence" then
                do_fallback = false
            end
        end
        
        local length_mismatch_stop = false
        if cand._end ~= target_end then
            length_mismatch_stop = true
        end

        if do_classifier then
            if count > 1 and current_len < target_len then length_mismatch_stop = true end
        else
            if count > 1 and current_len ~= target_len then length_mismatch_stop = true end
        end

        if ct == "raw" or ct == "english" or is_alpha_fast(text) or length_mismatch_stop or count > max_scan then
            for i = b_cnt + 1, #shared_boosted do shared_boosted[i] = nil end
            for i = n_cnt + 1, #shared_normal do shared_normal[i] = nil end
            sort(shared_boosted, stable_sort)
            flush_yield(shared_boosted, b_cnt, shared_normal, n_cnt, do_fallback)
            yield(cand)
            for rest_cand in input:iter() do yield(rest_cand) end
            return
        end

        -- 分类与排名逻辑
        local rank = env.f_reorder_map and env.f_reorder_map[text]
        local is_classifier = do_classifier and CLASSIFIER_LOOKUP[text]
        
        if (rank or is_classifier) and current_len == target_len then
            local final_rank = rank or 0
            if is_classifier then final_rank = -1 end 
            b_cnt = b_cnt + 1
            if not shared_boosted[b_cnt] then
                shared_boosted[b_cnt] = {}
            end
            local b_obj = shared_boosted[b_cnt]
            b_obj.cand = cand
            b_obj.rank = final_rank
            b_obj.index = count
        else
            n_cnt = n_cnt + 1
            shared_normal[n_cnt] = cand
        end
    end

    for i = b_cnt + 1, #shared_boosted do shared_boosted[i] = nil end
    for i = n_cnt + 1, #shared_normal do shared_normal[i] = nil end
    
    sort(shared_boosted, stable_sort)
    flush_yield(shared_boosted, b_cnt, shared_normal, n_cnt, do_fallback)
end

function F.fini(env)
    if env.shared_boosted then
        for i = #env.shared_boosted, 1, -1 do
            local item = env.shared_boosted[i]
            if item then
                item.cand = nil
                item.rank = nil
                item.index = nil
            end
            env.shared_boosted[i] = nil
        end
    end

    if env.shared_normal then
        for i = #env.shared_normal, 1, -1 do
            env.shared_normal[i] = nil
        end
    end

    env.f_last_pending_cands = nil
    env.f_reorder_map = nil
    env.shared_boosted = nil
    env.shared_normal = nil
end
return { P = P, T = T, F = F }
