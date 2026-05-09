-- user_predict.lua
-- https://github.com/amzxyz/rime_wanxiang
-- by amzxyz
-- 架构层: Processor (物理按键截取与逻辑分发) + Translator (候选词生成与上屏) + Filter (输入调频)
-- 算法层:
-- v1.1.0 (深度定制版：存得严，查得准，清得快)
-- 1. 瀑布流查询模型 (S-Gram -> 2-Gram 精确 -> 1-Gram 断崖回退 -> P-Gram 模糊抗抖动)
-- 2. 双重衰减排名 (时间指数衰减 + 频次基础权重)
-- 3. 数据淘汰系统 (P记录30天清理 + 1/2记录90天生命周期)
-- 4. 事务级回滚机制 (拦截上屏立即退格，复原上次数据库操作)
-- 5. LWW 智能合并 (导入数据时采用 Last Write Wins 策略，保留最新时间戳数据)
-- 6. ABA 防折返输入 (拦截如"你好"->"你好"的自我循环，减少数据库无效记录)
-- 7. 继承原生主动删除 (Ctrl+Del / Shift+Del 物理销毁当前候选词的多维关联)
-- 8. 语境隔离与时效防御 (精准识别标点断句，外加 5秒 语境超时自动熔断防穿透)
-- 9. 语气助词智能白名单 (特许“吧呢吗”等助词接标点的合法性，实现终结符平滑解耦)
-- 10. 跨平台双层按键防线 (针对移动端软键盘强删字节的底层特性，彻底免疫退格乱码)

local insert   = table.insert
local remove   = table.remove
local sort     = table.sort
local s_match  = string.match
local s_sub    = string.sub
local s_len    = string.len
local s_find   = string.find
local s_format = string.format
local tonumber = tonumber
local math_max = math.max
local math_min = math.min
local os_time  = os.time
local shared_reverted_code = ""
local shared_is_backspacing = false
-- 内部运行参数默认值 (会被外部 YAML 配置覆盖)
local CONFIG = {
    MAX_CANDIDATES      = 5,             
    MAX_PREDICTIONS     = 3,             
    EXPIRY_SECONDS      = 90 * 24 * 3600,
    P_EXPIRY_SECONDS    = 30 * 24 * 3600,
    ACTIVATION_SECONDS  = 7 * 24 * 3600, 
    MAX_MEMORY_BRANCHES = 15,            
    DECAY_RATE          = 0.85,          
    SCAN_LIMIT          = 80,            
    ENABLE_PREDICT_SPACE = false,  
    CONTEXT_TIMEOUT_MS  = 5000,
    ENABLE_POST_PREDICT = true,
    ENABLE_CONTEXT_REORDER = true,
    ENABLE_FALLBACK_REORDER = true,
}
local is_after_number = false  --量词调频状态
-- 量词动态查找表与构建函数
local CLASSIFIER_LOOKUP = {}
-- 量词兜底字符串
local default_classifiers = "百千万亿个多只名位口头匹条群批伙张把件台部块根颗粒滴片朵面扇顶栋座所辆艘架盏支枝杆双对副套打串束排阵堆叠摞扎杯瓶盒包份碗锅盆桶袋罐盘次场局回趟顿番遍声项宗桩款步招年月天周岁秒分刻代期届任夜季本册篇首句段卷幅节堂门帖字行米寸尺里斤两吨克升元角毛笔"

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

local function is_tone_symbol(text) 
    return s_match(text, "^[！？，。～]+$") ~= nil 
end

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
        CONFIG.EXPIRY_SECONDS      = (config:get_int("user_predict/expiry_days") or 90) * 86400
        CONFIG.ACTIVATION_SECONDS  = (config:get_int("user_predict/activation_days") or 7) * 86400
        CONFIG.MAX_MEMORY_BRANCHES = config:get_int("user_predict/max_memory_branches") or 15
        CONFIG.DECAY_RATE          = config:get_double("user_predict/decay_rate") or 0.85
        local ps_val = config:get_bool("user_predict/enable_predict_space")
        if ps_val ~= nil then CONFIG.ENABLE_PREDICT_SPACE = ps_val end
        local timeout_val = config:get_int("user_predict/context_timeout")
        if timeout_val ~= nil then CONFIG.CONTEXT_TIMEOUT_MS = timeout_val end
        local post_val = config:get_bool("user_predict/enable_post_predict")
        if post_val ~= nil then CONFIG.ENABLE_POST_PREDICT = post_val end
        local reorder_val = config:get_bool("user_predict/enable_context_reorder")
        if reorder_val ~= nil then CONFIG.ENABLE_CONTEXT_REORDER = reorder_val end
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

local _db_pool = {}
local function get_db(env)
    local config = env.engine.schema.config
    local db_name = config:get_string("user_predict/db_name") or "lua/predict"
    if not _db_pool[db_name] then _db_pool[db_name] = LevelDb(db_name) end
    local db = _db_pool[db_name]
    if db and not db:loaded() then db:open() end
    return db
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
    
    local function fetch_and_clean(query_key, multiplier)
        local da = db:query(query_key)
        if not da then return end
        local scan_count = 0
        local now = os_time()
        local prefix_cands = {} 
        
        for k, v in da:iter() do
            if scan_count >= scan_limit or not s_find(k, query_key, 1, true) then break end
            if s_sub(k, 1, 1) ~= "\1" then
                local word = s_sub(k, s_len(query_key) + 1)
                local c_str, ts_str = s_match(v, "^([^|]+)|?(.*)$")
                local count = tonumber(c_str) or 0
                local ts = tonumber(ts_str) or 0
                
                local is_p_gram = (s_sub(k, 1, 2) == "P\t")
                local limit = is_p_gram and CONFIG.P_EXPIRY_SECONDS or CONFIG.EXPIRY_SECONDS
                
                if ts == 0 then ts = now - limit - 1 end
                
                if (now - ts) > limit then
                    if db.erase then db:erase(k) else db:update(k, "") end
                else
                    if count > 0 then
                        local age_days = (now - ts) / 86400.0
                        local score = count * (CONFIG.DECAY_RATE ^ age_days) * multiplier
                        if score > 0.05 and word ~= "" then
                            insert(prefix_cands, { word = word, weight = score, db_key = k })
                        end
                    end
                end
            end
            scan_count = scan_count + 1
        end
        da = nil
        
        if #prefix_cands > 0 then
            sort(prefix_cands, function(a, b) return a.weight > b.weight end)
            for i, c in ipairs(prefix_cands) do
                if i <= CONFIG.MAX_MEMORY_BRANCHES then
                    if not seen[c.word] then insert(cands, c); seen[c.word] = true end
                else
                    db:update(c.db_key, "0|" .. tostring(now))
                end
            end
        end
    end

    -- S先读
    if #history >= 1 then fetch_and_clean("S\t" .. history[#history] .. "\t", 1000000) end

    -- 小于等于2先找上文组合查 2-Gram
    if #history >= 2 then 
        local u0 = history[#history - 1]
        local u1 = history[#history]
        local len_u0 = u0 and utf8_len(u0) or 0
        local len_u1 = u1 and utf8_len(u1) or 0
        
        -- 对齐写入时的条件：u1不超过4，且总和不超过5
        if len_u1 <= 4 and (len_u0 + len_u1) <= 5 then
            fetch_and_clean("2\t" .. u0 .. "\t" .. u1 .. "\t", 10000) 
        end
    end

    -- 查 1-Gram
    if #cands < CONFIG.MAX_CANDIDATES and #history >= 1 then 
        local u1 = history[#history]
        local chars = get_utf8_chars(u1)
        local len_u1 = #chars
        
        local max_len = math_min(len_u1, 4)
        local min_len = (len_u1 >= 2) and 2 or 1
        
        for l = max_len, min_len, -1 do
            local lookup_u1 = table.concat(chars, "", len_u1 - l + 1, len_u1)
            fetch_and_clean("1\t" .. lookup_u1 .. "\t", 100) 
            if #cands > 0 then break end
        end
    end

    -- 查不到再去拿 P 去匹配
    if #cands < CONFIG.MAX_CANDIDATES then
        local chars = get_utf8_chars(prev_commit)
        local lengths_to_query = get_suffix_lengths(#chars)
        for _, l in ipairs(lengths_to_query) do
            fetch_and_clean("P\t" .. table.concat(chars, "", #chars - l + 1, #chars) .. "\t", 1)
            if #cands > 0 then break end
        end
    end

    if #cands > 0 then
        sort(cands, function(a, b) return a.weight > b.weight end)
        return cands
    end
    return nil
end

local P = {}
function P.init(env)
    load_config(env) 
    local db = get_db(env)

    env.need_push = false 
    env.last_written_keys = {}
    env.just_committed = false
    
    env.commit_cb = function(ctx)
        shared_reverted_code = ""
        shared_max_input_code = ""
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
        local function update_memory(key, is_tone)
            local val = db:fetch(key)
            local now = os_time()
            env.last_written_keys[key] = val or ""
            
            if not val or val == "" then
                if is_tone then db:update(key, "1|" .. tostring(now)) else db:update(key, "0|" .. tostring(now)) end
            else
                local c_str, ts_str = s_match(val, "^([^|]+)|?(.*)$")
                local count = tonumber(c_str) or 0
                local ts = tonumber(ts_str) or 0
                local age = now - ts
                if age > CONFIG.EXPIRY_SECONDS then
                    db:update(key, "0|" .. tostring(now))
                elseif count == 0 then
                    if age <= CONFIG.ACTIVATION_SECONDS then db:update(key, "1|" .. tostring(now)) else db:update(key, "0|" .. tostring(now)) end
                else
                    db:update(key, tostring(count + 1) .. "|" .. tostring(now))
                end
            end
        end

        current_time = (rime_api and rime_api.get_time_ms) and rime_api.get_time_ms() or (os_time() * 1000)
        
        local should_record = true
        local is_terminal_symbol = false 
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

        -- 基础规则：防折返输入
        if should_record and last_commit == text then should_record = false end
        if should_record and #history >= 2 then
            if text == history[#history - 1] then
                should_record = false
                remove(history, #history)
                last_commit = history[#history] or ""
            end
        end

        -- 核心录入逻辑区
        if should_record then
            local text_is_tone = is_tone_symbol(text)

            -- 常规上文级联录入
            if last_commit ~= "" then
                local u1_chars = get_utf8_chars(last_commit)
                local len_u1 = #u1_chars
                
                -- P-Gram
                local lengths_to_learn = get_suffix_lengths(len_u1)
                for _, l in ipairs(lengths_to_learn) do
                    if l < len_u1 or len_u1 >= 4 then
                        update_memory("P\t" .. table.concat(u1_chars, "", len_u1 - l + 1, len_u1) .. "\t" .. text, text_is_tone)
                    end
                end
                
                -- 1-Gram
                if len_u1 <= 4 and #history >= 1 then 
                    update_memory("1\t" .. last_commit .. "\t" .. text, text_is_tone) 
                end
                
                -- 2-Gram
                if len_u1 <= 4 and #history >= 2 then
                    local u0 = history[#history - 1]
                    local len_u0 = u0 and #get_utf8_chars(u0) or 0
                    if (len_u0 + len_u1) <= 5 then
                        update_memory("2\t" .. u0 .. "\t" .. last_commit .. "\t" .. text, text_is_tone)
                    end
                end
            end
            -- 四字成语的 2+2 自我拆分学习
            if len_text == 4 then
                local part1 = text_chars[1] .. text_chars[2]
                local part2 = text_chars[3] .. text_chars[4]
                
                local is_known_prefix = false
                for _, prefix in ipairs({"1", "P"}) do
                    local query_key = prefix .. "\t" .. part1 .. "\t"
                    local da = db:query(query_key)
                    if da then
                        for k, _ in da:iter() do
                            if s_find(k, query_key, 1, true) then
                                is_known_prefix = true
                                break
                            end
                        end
                    end
                    if is_known_prefix then break end
                end
                if is_known_prefix then
                    update_memory("1\t" .. part1 .. "\t" .. part2, false)
                end
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
        end
        
        -- 事务入栈：把本次写库的记录推入回滚栈（最大保留 3 级）
        env.undo_stack = env.undo_stack or {}
        if next(env.last_written_keys) then
            insert(env.undo_stack, env.last_written_keys)
            if #env.undo_stack > 3 then remove(env.undo_stack, 1) end
        end

        last_commit_time = current_time
        env.last_action_time = current_time
        env.just_committed = true
        
        -- 如果两个开关都没开，绝对不去查库！绝对不建缓存
        if predict_count <= CONFIG.MAX_PREDICTIONS and ctx:get_option("prediction") then
            if CONFIG.ENABLE_POST_PREDICT or CONFIG.ENABLE_CONTEXT_REORDER then
                pending_cands = get_predictions(env, last_commit)
                if pending_cands then 
                    if CONFIG.ENABLE_POST_PREDICT then
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
    
    env.update_cb = function(ctx)
        local input = ctx.input or ""
        if input == "/clean" then
            ctx:clear()
            local now = os_time()
            local deleted_count = 0
            for k, v in db:query(""):iter() do
                if s_sub(k, 1, 1) ~= "\1" and s_sub(k, 1, 1) ~= "\0" then
                    local _, ts_str = s_match(v, "^([^|]+)|?(.*)$")
                    local ts = tonumber(ts_str) or 0
                    local is_p_gram = (s_sub(k, 1, 2) == "P\t")
                    local limit = is_p_gram and CONFIG.P_EXPIRY_SECONDS or CONFIG.EXPIRY_SECONDS
                    
                    if ts == 0 then ts = now - limit - 1 end
                    
                    if (now - ts) > limit then
                        if db.erase then db:erase(k) else db:update(k, "") end
                        deleted_count = deleted_count + 1
                    end
                end
            end
            
            reset_memory_chain(env, "手动清理结束")
            -- 上屏提示信息，让用户知道清理了多少条垃圾
            env.engine:commit_text("【预测数据库清理完成：共清除 " .. deleted_count .. " 条过期记忆】")
            return
        end
        if input == "/outpredict" then
            ctx:clear()
            local sync_path = rime_api.get_user_data_dir() .. "/predict_export.txt"
            local f = io.open(sync_path, "w")
            if f then
                for k, v in db:query(""):iter() do
                    if s_sub(k, 1, 1) ~= "\1" and s_sub(k, 1, 1) ~= "\0" then
                        f:write(k .. "\t" .. v .. "\n")
                    end
                end
                f:close()
            end
            reset_memory_chain(env, "导出结束")
            return
        end

        if input == "/inpredict" then
            ctx:clear()
            local sync_path = rime_api.get_user_data_dir() .. "/predict_import.txt"
            local f = io.open(sync_path, "r")
            if f then
                for line in f:lines() do
                    local k, v = s_match(line, "^(.*)\t([^\t]+)$")
                    if k and v then
                        local old_v = db:fetch(k)
                        if old_v and old_v ~= "" then
                            local _, old_ts = s_match(old_v, "^([^|]+)|?(.*)$")
                            local _, new_ts = s_match(v, "^([^|]+)|?(.*)$")
                            local o_ts = tonumber(old_ts) or 0
                            local n_ts = tonumber(new_ts) or 0
                            
                            if n_ts > o_ts then db:update(k, v) end
                        else
                            db:update(k, v)
                        end
                    end
                end
                f:close()
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

    env.commit_connection = env.engine.context.commit_notifier:connect(env.commit_cb)
    env.update_connection = env.engine.context.update_notifier:connect(env.update_cb)
end

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

    if env.just_committed and repr ~= "BackSpace" and not s_find(repr, "Shift", 1, true) and not s_find(repr, "Control", 1, true) and not s_find(repr, "Alt", 1, true) then
        env.just_committed = false
    end
    
    if repr == "BackSpace" then
        local current_time = (rime_api and rime_api.get_time_ms) and rime_api.get_time_ms() or (os_time() * 1000)
        local is_safe_to_undo = (not ctx:is_composing() or is_predicting)
        
        if is_safe_to_undo and env.undo_stack and #env.undo_stack > 0 then
            -- 延时策略：如果在规定时间内连按退格
            if (current_time - (env.last_action_time or 0)) <= CONFIG.CONTEXT_TIMEOUT_MS then
                local keys_to_undo = remove(env.undo_stack)
                local db = get_db(env)
                for k, v in pairs(keys_to_undo) do
                    if v == "" then 
                        if db.erase then db:erase(k) else db:update(k, "") end
                    else 
                        db:update(k, v) 
                    end
                end
                env.last_action_time = current_time
            else
                env.undo_stack = {}
            end
        end
        env.just_committed = false
        if is_predicting then
            ctx:clear()
            reset_memory_chain(env, "退格强清联想")
            return 1 
        end
    end
    
    if is_predicting then
        local is_alt_key = (repr == "Tab" or repr == "Alt" or repr == "Alt_L" or repr == "Alt_R")

        -- 根据选词范围分流数字键
        if s_match(repr, "^[0-9]$") or s_match(repr, "^KP_[0-9]$") then
            local digit = s_match(repr, "%d")
            local d = tonumber(digit)
            if d == 0 then d = 10 end
            local config = env.engine.schema.config
            local page_size = config:get_int("menu/page_size")
            
            local ctx = env.engine.context
            local comp = ctx.composition
            local seg = (comp and not comp:empty()) and comp:back() or nil
            
            local is_valid_candidate = false
            
            if seg then
                local current_page = math.floor(seg.selected_index / page_size)
                local target_index = current_page * page_size + (d - 1)
                if seg:get_candidate_at(target_index) then
                    is_valid_candidate = true
                end
            end
            if d > page_size or not is_valid_candidate then
                ctx:clear()
                if reset_memory_chain then
                    reset_memory_chain(env, "非选词数字打断联想并上屏")
                end
                env.engine:commit_text(digit)
                return 1
            else
                return 2
            end
        end

        if CONFIG.ENABLE_PREDICT_SPACE then
            -- enable_predict_space: true
            if key.keycode == 0x20 then
                local current_input = ctx.input or ""
                local is_predict_placeholder = (current_input ~= "") and s_find(current_input, "^" .. PH_CHAR .. "+$")

                if is_predicting and is_predict_placeholder then
                    ctx:clear()
                    reset_memory_chain(env, "空格打断联想并上屏")
                    env.engine:commit_text(" ")
                    return 1
                else
                    is_predicting = false
                    predict_count = 0
                    pending_cands = nil
                    return 2 -- 放行空格，让原生处理
                end
            elseif is_alt_key then
                ctx:clear()
                reset_memory_chain(env, "替身键打断联想")
                return 1
            end
        else
            -- enable_predict_space: false
            if is_alt_key then
                ctx:clear()
                reset_memory_chain(env, "替身键打断联想并上屏空格")
                env.engine:commit_text(" ")
                return 1
            end
        end
        
        if repr == "Return" then
            ctx:clear()
            reset_memory_chain(env, "打断键清除预测") 
            return 1
        end
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
            local word = cand.text
            local db = get_db(env)

            local exact_key = nil
            if pending_cands then
                for _, c in ipairs(pending_cands) do
                    if c.word == word then exact_key = c.db_key; break end
                end
            end
            
            if exact_key then
                if db.erase then db:erase(exact_key) else db:update(exact_key, "") end
            end
            local chars = get_utf8_chars(last_commit)
            local lengths = get_suffix_lengths(#chars)
            for _, l in ipairs(lengths) do
                local p_key = "P\t" .. table.concat(chars, "", #chars - l + 1, #chars) .. "\t" .. word
                if db.erase then db:erase(p_key) else db:update(p_key, "") end
            end
            ctx:clear()
            reset_memory_chain(env, "物理销毁词条")
            return 1 
        end
    end
    return 2 
end

function P.fini(env)
    if env.commit_connection then env.commit_connection:disconnect(); env.commit_connection = nil end
    if env.update_connection then env.update_connection:disconnect(); env.update_connection = nil end
end

local T = {}
function T.init(env)
    load_config(env) 
    get_db(env)
end

function T.func(input, seg, env)
    -- 受总开关与联想开关联合控制
    if not env.engine.context:get_option("prediction") or not CONFIG.ENABLE_POST_PREDICT then return end
    
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

local f_last_commit = ""
local f_reorder_map = nil
local shared_boosted = {}
local shared_normal = {}
local boosted_obj_pool = {}
local boosted_pool_idx = 0

function F.init(env) end

local function stable_sort(a, b)
    if a.rank == b.rank then return a.index < b.index end
    return a.rank < b.rank
end

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

function F.func(input, env)
    local ctx = env.engine.context
    
    if not ctx:get_option("prediction") or s_match(ctx.input or "", "^[›]+$") then
        for cand in input:iter() do yield(cand) end
        return
    end

    if not CONFIG.ENABLE_CONTEXT_REORDER and not CONFIG.ENABLE_FALLBACK_REORDER then
        for cand in input:iter() do yield(cand) end
        return
    end

    if f_last_commit ~= last_commit then
        f_last_commit = last_commit
        f_reorder_map = nil
        
        local is_context_valid = false
        local u1_len = utf8_len(last_commit) or 0
        
        if #history >= 2 then
            local u0_len = utf8_len(history[#history - 1]) or 0
            if (u0_len + u1_len) >= 3 then
                is_context_valid = true
            end
        else
            if u1_len >= 2 then
                is_context_valid = true
            end
        end

        if is_context_valid and CONFIG.ENABLE_CONTEXT_REORDER then
            local preds = pending_cands or get_predictions(env, last_commit)
            if preds then
                f_reorder_map = {}
                for rank, p in ipairs(preds) do
                    f_reorder_map[p.word] = rank
                end
            end
        end
    end

    local do_reorder = f_reorder_map and next(f_reorder_map)
    local do_classifier = is_after_number and CLASSIFIER_LOOKUP and next(CLASSIFIER_LOOKUP)
    
    local current_input = ctx.input or ""
    local do_fallback = CONFIG.ENABLE_FALLBACK_REORDER and current_input == shared_reverted_code and shared_reverted_code ~= ""
    
    if (not do_reorder and not do_classifier and not do_fallback) or current_input == "" then
        for cand in input:iter() do yield(cand) end
        return
    end

    -- 极速旁路通道 (0 运算，0 分配)
    if not do_reorder and not do_classifier and do_fallback then
        local idx = 0
        local c1 = nil
        for cand in input:iter() do
            idx = idx + 1
            if idx == 1 then
                c1 = cand
            elseif idx == 2 then
                if c1.type ~= "sentence" and c1._end == cand._end then
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

    boosted_pool_idx = 0
    local b_cnt = 0
    local n_cnt = 0
    
    local count = 0
    local max_scan = 20
    local target_len = 0
    local target_end = 0

    for cand in input:iter() do
        count = count + 1
        local text = cand.text or ""
        local current_len = utf8_len(text) or 0
        
        if count == 1 then 
            target_len = current_len 
            target_end = cand._end
            if cand.type == "sentence" then
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

        if cand.type == "raw" or cand.type == "english" or s_find(text, "^[a-zA-Z]+$") or length_mismatch_stop or count > max_scan then
            for i = b_cnt + 1, #shared_boosted do shared_boosted[i] = nil end
            for i = n_cnt + 1, #shared_normal do shared_normal[i] = nil end
            sort(shared_boosted, stable_sort)
            flush_yield(shared_boosted, b_cnt, shared_normal, n_cnt, do_fallback)
            yield(cand)
            for rest_cand in input:iter() do yield(rest_cand) end
            return
        end

        -- 分类与排名逻辑
        local rank = f_reorder_map and f_reorder_map[text]
        local is_classifier = do_classifier and CLASSIFIER_LOOKUP[text]
        
        if (rank or is_classifier) and current_len == target_len then
            local final_rank = rank or 0
            if is_classifier then final_rank = -1 end 
            boosted_pool_idx = boosted_pool_idx + 1
            if not boosted_obj_pool[boosted_pool_idx] then
                boosted_obj_pool[boosted_pool_idx] = {}
            end
            local b_obj = boosted_obj_pool[boosted_pool_idx]
            b_obj.cand = cand
            b_obj.rank = final_rank
            b_obj.index = count
            b_cnt = b_cnt + 1
            shared_boosted[b_cnt] = b_obj
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

function F.fini(env) end
return { P = P, T = T, F = F }
