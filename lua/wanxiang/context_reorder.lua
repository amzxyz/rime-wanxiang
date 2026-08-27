-- context_reorder.lua
-- https://github.com/amzxyz/rime-wanxiang

-- 1-Gram：上一个真实上屏词 -> 当前真实上屏词
-- 2-Gram：前两个真实上屏词 -> 当前真实上屏词
-- 数字后量词轻量调频：P 只捕获数字状态，F 负责候选置前
-- 回头码掉头：编码中退格后重新输入原码时交换前两个合法候选
-- 上屏后立即退格：回滚刚写入的 1/2-Gram 记录

local sort     = table.sort
local s_match  = string.match
local s_sub    = string.sub
local s_find   = string.find
local s_format = string.format
local tonumber = tonumber
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local os_time  = os.time
local wanxiang = require("wanxiang/wanxiang")
local userdb   = require("wanxiang/userdb")

local KEY_SEP = ";"
local ONE_PREFIX = "1" .. KEY_SEP
local TWO_PREFIX = "2" .. KEY_SEP
local RECORD_SEPARATOR = " \t"
local C_MAX = 2147483000
local FILTER_SCAN_LIMIT = 100
local MEMORY_GROUP_LIMIT = 10
local NUMBER_CONTEXT = "#NUM"
local DEFAULT_CLASSIFIERS = "百千万亿个多只名位口头匹条群批伙张把件台部块根颗粒滴片朵面扇顶栋座所辆艘架盏支枝杆双对副套打串束排阵堆叠摞扎杯瓶盒包份碗锅盆桶袋罐盘次场局回趟顿番遍声项宗桩款步招年月天周岁秒分刻代期届任夜季本册篇首句段卷幅节堂门帖字行米寸尺里斤两吨克升元角毛笔"
local CLASSIFIER_LOOKUP = {}
local CONFIG = {
    CONTEXT_TIMEOUT_MS = 5000,
    ENABLE_FALLBACK_REORDER = true,
}
local context_state = {
    prev2 = nil,
    prev1 = nil,
    last_commit_time = 0,
    after_number = false,
    reverted_code = "",
    is_backspacing = false,
    learn_known = {},
    learn_seen = {},
    learn_match_count = 0,
    learn_allow_new = false,
    learn_context1 = nil,
    learn_context2 = nil,
    learn_ready = false,
}

local REORDER_TYPE_WHITELIST = {
    user_phrase = true,
    phrase = true,
}

local function now_ms()
    if rime_api and rime_api.get_time_ms then return rime_api.get_time_ms() end
    return os_time() * 1000
end

local function clear_table(t)
    if not t then return end
    for k in pairs(t) do t[k] = nil end
end

local function clear_learning_snapshot()
    clear_table(context_state.learn_known)
    clear_table(context_state.learn_seen)
    context_state.learn_match_count = 0
    context_state.learn_allow_new = false
    context_state.learn_context1 = nil
    context_state.learn_context2 = nil
    context_state.learn_ready = false
end

local function reset_context()
    context_state.prev2 = nil
    context_state.prev1 = nil
    context_state.last_commit_time = 0
    clear_learning_snapshot()
end

local function build_classifier_lookup(text)
    clear_table(CLASSIFIER_LOOKUP)
    if not text or text == "" then return end
    for ch in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
        if not s_match(ch, "%s") then CLASSIFIER_LOOKUP[ch] = true end
    end
end

local function get_digit_key(repr)
    local len = #repr
    if len == 1 then
        local code = string.byte(repr, 1)
        if code >= 48 and code <= 57 then return repr end
    elseif len == 4 and s_sub(repr, 1, 3) == "KP_" then
        local code = string.byte(repr, 4)
        if code >= 48 and code <= 57 then return s_sub(repr, 4, 4) end
    end
    return nil
end

local function is_ascii_digits(text)
    return text and s_match(text, "^%d+$") ~= nil
end

local function load_config(env)
    local config = env.engine and env.engine.schema and env.engine.schema.config
    if not config then return end

    local timeout = config:get_int("context_reorder/context_timeout")
    local fallback = config:get_bool("context_reorder/enable_fallback_reorder")

    if timeout ~= nil and timeout >= 0 then CONFIG.CONTEXT_TIMEOUT_MS = timeout end
    if fallback ~= nil then CONFIG.ENABLE_FALLBACK_REORDER = fallback end

    -- 未配置 custom_classifiers 时使用默认量词；显式配置空列表 [] 时关闭量词调频。
    local classifier_node = config:get_item("context_reorder/custom_classifiers")
    if not classifier_node then
        build_classifier_lookup(DEFAULT_CLASSIFIERS)
    else
        local classifier_text = ""
        local classifier_list = config:get_list("context_reorder/custom_classifiers")
        if classifier_list then
            for i = 0, classifier_list.size - 1 do
                local value = classifier_list:get_value_at(i)
                if value then classifier_text = classifier_text .. (value:get_string() or "") end
            end
        else
            classifier_text = config:get_string("context_reorder/custom_classifiers") or ""
        end
        build_classifier_lookup(classifier_text)
    end
end

-- 稳定记录：code<TAB>word -> c=N d=0 t=0
local function parse_record_tail(tail)
    if type(tail) ~= "string" then return 0 end
    return tonumber(s_match(tail, "c=([^%s\t]+)")) or 0
end

local function make_record_tail(commits)
    commits = math_max(-C_MAX, math_min(C_MAX, commits or 0))
    return s_format("c=%d d=0 t=0", commits)
end

local function make_raw_key(code, word)
    if not code or code == "" or not word or word == "" then return nil end
    return code .. RECORD_SEPARATOR .. word
end

local function fetch_record(db, code, word)
    local raw_key = make_raw_key(code, word)
    if not raw_key then return 0, nil, nil end
    local tail = db:fetch(raw_key)
    return parse_record_tail(tail), tail, raw_key
end

local function next_active_commits(commits)
    commits = commits or 0

    -- 负 c 是删除墓碑，不继承删除前的历史强度。
    -- 用户重新选择该词时视为一次全新的学习，从 c=1 重新开始；
    -- 否则 -9 -> abs(-9)+1 -> 10 会让刚复活的词直接冲到前列。
    if commits < 0 then return 1 end
    if commits >= C_MAX then return C_MAX end
    return commits + 1
end

-- transaction_before / transaction_after 都只保存字符串，不保存 userdata。
local function update_memory_record(db, before, after, code, word)
    local commits, tail, raw_key = fetch_record(db, code, word)
    if not raw_key then return false end

    local next_tail = make_record_tail(next_active_commits(commits))
    if before[raw_key] == nil then before[raw_key] = tail or "" end
    after[raw_key] = next_tail
    db:update(raw_key, next_tail)
    return true
end

-- 原生删词事件同步到上下文数据库。
-- 不监听 Ctrl+Del / Shift+Del；PC 快捷键和移动端 UI 都由 delete_notifier 统一触发。
-- 使用负 c 墓碑而不是 erase，保留 UserDb 同步时的删除语义。
local function mark_record_deleted(db, code, word)
    if not db or not code or code == "" or not word or word == "" then return false end
    local commits, tail, raw_key = fetch_record(db, code, word)
    if not raw_key or not tail then return false end

    local magnitude = math_abs(commits or 0)
    if magnitude < C_MAX then magnitude = magnitude + 1 end
    if magnitude == 0 then magnitude = 1 end
    return db:update(raw_key, make_record_tail(-magnitude))
end

local function get_db(env)
    if env.context_reorder_db then return env.context_reorder_db end

    local config = env.engine.schema.config
    local db_name = config:get_string("context_reorder/db_name") or "context_reorder"
    local db = userdb.LevelDb(db_name)
    if not db or (not db:loaded() and not db:open()) then return nil end

    env.context_reorder_db = db
    env.context_reorder_db_name = db_name
    return db
end

local function release_db(env)
    env.context_reorder_db = nil
    env.context_reorder_db_name = nil
    collectgarbage()
end

local function is_chinese_codepoint(cp)
    if not cp or cp == 0 then return false end
    return (cp >= 0x4E00 and cp <= 0x9FFF)
        or (cp >= 0x3400 and cp <= 0x4DBF)
        or (cp >= 0x20000 and cp <= 0x2A6DF)
        or (cp >= 0x2A700 and cp <= 0x2B73F)
        or (cp >= 0x2B740 and cp <= 0x2B81F)
        or (cp >= 0x2B820 and cp <= 0x2CEAF)
        or (cp >= 0x2CEB0 and cp <= 0x2EBEF)
        or (cp >= 0x30000 and cp <= 0x3134F)
        or (cp >= 0x31350 and cp <= 0x323AF)
        or (cp >= 0x2EBF0 and cp <= 0x2EE5F)
        or (cp >= 0xF900 and cp <= 0xFAFF)
        or (cp >= 0x2F800 and cp <= 0x2FA1F)
end

-- 只学习真实上屏的纯中文词/短语；不按字数截断，不自动拆分，也不生成静态/虚拟下文。
local function is_valid_token(text)
    if not text or text == "" then return false end
    if not (utf8 and utf8.codes) then return false end

    local count = 0
    for _, cp in utf8.codes(text) do
        if not is_chinese_codepoint(cp) then return false end
        count = count + 1
    end
    return count > 0
end

-- 读取某个候选在当前上下文中的 2-Gram / 1-Gram 次数。
-- 只做精确 fetch，不再扫描某个上文的全部历史分支。
local function get_context_counts(db, text, context2, context1)
    if not db or not text or text == "" or not context1 then return 0, 0 end

    local c1 = select(1, fetch_record(db, ONE_PREFIX .. context1, text))
    local c2 = 0
    if context2 then c2 = select(1, fetch_record(db, TWO_PREFIX .. context2 .. KEY_SEP .. context1, text)) end
    if c1 < 0 then c1 = 0 end
    if c2 < 0 then c2 = 0 end
    return c2, c1
end

-- F 每轮只保存“当前同编码候选组”中已经存在记忆的词。
-- 达到 10 个后只禁止新增第 11 个；已有词仍允许继续 c+1。
local function begin_learning_snapshot(context2, context1)
    clear_learning_snapshot()
    context_state.learn_context2 = context2
    context_state.learn_context1 = context1
    context_state.learn_ready = context1 ~= nil
    context_state.learn_allow_new = context_state.learn_ready
end

local function remember_snapshot_candidate(text, is_known)
    if not text or text == "" then return end
    context_state.learn_seen[text] = true
    if is_known and not context_state.learn_known[text] then
        context_state.learn_known[text] = true
        context_state.learn_match_count = context_state.learn_match_count + 1
        context_state.learn_allow_new = context_state.learn_match_count < MEMORY_GROUP_LIMIT
    end
end

local function clear_undo(env)
    env.just_committed = false
    env.undo_prev2 = nil
    env.undo_prev1 = nil
    env.undo_prev_time = nil
    env.undo_after_number = nil
    if env.undo_before then clear_table(env.undo_before) end
    if env.undo_after then clear_table(env.undo_after) end
end

local function rollback_last_commit(env)
    if not env.just_committed then return false end
    if CONFIG.CONTEXT_TIMEOUT_MS > 0
        and (now_ms() - (env.last_action_time or 0)) > CONFIG.CONTEXT_TIMEOUT_MS
    then
        clear_undo(env)
        return false
    end

    local db = get_db(env)
    if db and env.undo_after and env.undo_before then
        for raw_key, expected_after in pairs(env.undo_after) do
            if db:fetch(raw_key) == expected_after then
                local before = env.undo_before[raw_key]
                if before == "" or before == nil then db:erase(raw_key) else db:update(raw_key, before) end
            end
        end
    end

    context_state.prev2 = env.undo_prev2
    context_state.prev1 = env.undo_prev1
    context_state.last_commit_time = env.undo_prev_time or 0
    context_state.after_number = env.undo_after_number == true
    clear_learning_snapshot()
    clear_undo(env)
    return true
end

-- Processor：只负责真实上屏学习、维护两级上下文和立即退格回滚。
local P = {}

function P.init(env)
    load_config(env)
    env.delete_refreshing = nil
    if not get_db(env) then return end

    env.is_t9 = wanxiang.get_input_method_type and wanxiang.get_input_method_type(env) == "t9" or false
    env.undo_before = {}
    env.undo_after = {}
    clear_undo(env)

    env.commit_cb = function(ctx)
            local text = ctx:get_commit_text()
        local current_time = now_ms()

        context_state.reverted_code = ""

        if is_ascii_digits(text) then
            reset_context()
            context_state.after_number = true
            clear_undo(env)
            return
        end

        local was_after_number = context_state.after_number
        context_state.after_number = false
        if context_state.prev1 and CONFIG.CONTEXT_TIMEOUT_MS > 0 and (current_time - context_state.last_commit_time) > CONFIG.CONTEXT_TIMEOUT_MS then reset_context() end
        if not is_valid_token(text) then
            reset_context()
            clear_undo(env)
            return
        end

        env.undo_prev2 = context_state.prev2
        env.undo_prev1 = context_state.prev1
        env.undo_prev_time = context_state.last_commit_time
        env.undo_after_number = was_after_number
        clear_table(env.undo_before)
        clear_table(env.undo_after)

        local db = get_db(env)
        if db then
            local context1 = was_after_number and (CLASSIFIER_LOOKUP[text] and NUMBER_CONTEXT or nil) or context_state.prev1
            local context2 = was_after_number and nil or context_state.prev2

            if context1 then
                local snapshot_matches = context_state.learn_ready
                    and context_state.learn_context1 == context1
                    and context_state.learn_context2 == context2
                local already_known = snapshot_matches and context_state.learn_known[text] or false

                -- 即使候选位于本轮 100 项预读之外，已有记忆也必须继续 c+1。
                if not already_known then
                    local c2, c1 = get_context_counts(db, text, context2, context1)
                    already_known = c2 > 0 or c1 > 0
                end

                -- “10”只限制当前同编码候选组新增第 11 个分支；
                -- 新词必须确实出现在本轮 F 扫描的同码组里，避免旁路提交误写。
                local can_add = snapshot_matches
                    and context_state.learn_allow_new
                    and context_state.learn_seen[text] == true
                if already_known or can_add then
                    update_memory_record(db, env.undo_before, env.undo_after, ONE_PREFIX .. context1, text)
                    if context2 then update_memory_record(db, env.undo_before, env.undo_after, TWO_PREFIX .. context2 .. KEY_SEP .. context1, text) end
                end
            end
        end

        context_state.prev2 = context_state.prev1
        context_state.prev1 = text
        context_state.last_commit_time = current_time
        env.last_action_time = current_time
        env.just_committed = true
        clear_learning_snapshot()
    end

    -- 原生候选删除回调：前端 UI“删除/忘记”和 PC 原生删词快捷键共用此事件。
    --这里只清理 context_reorder 自己的记忆，不主动执行删词，也不捕获任何删除快捷键。
    env.delete_cb = function(ctx)
        local comp = ctx.composition
        if not comp or comp:empty() then return end

        local seg = comp:back()
        if not seg then return end
        local cand = seg:get_candidate_at(seg.selected_index)
        if not cand or not REORDER_TYPE_WHITELIST[cand.type or ""] then return end

        local word = cand.text or ""
        if word == "" then return end

        local db = get_db(env)
        if not db then return end

        if context_state.after_number then
            -- 数字后的量词记忆只有 1-Gram 数字上下文。
            mark_record_deleted(db, ONE_PREFIX .. NUMBER_CONTEXT, word)
        else
            local context1 = context_state.prev1
            local context2 = context_state.prev2
            if context1 then
                mark_record_deleted(db, ONE_PREFIX .. context1, word)
                if context2 then mark_record_deleted(db, TWO_PREFIX .. context2 .. KEY_SEP .. context1, word) end
            end
        end

        -- 删除只撤销 context_reorder 对当前词的上下文加权，不清空上文。
        -- 丢弃本轮扫描快照后立即刷新未确认 composition：F 会沿用同一个
        -- prev2 / prev1（或数字量词上下文）重新读取 c。被删除词因 c<=0
        -- 回到原生候选相对位置，其余仍有记忆的候选继续保持上下文调频。
        clear_learning_snapshot()

        -- delete_notifier 可能由 PC 原生快捷键或移动端 UI 触发。这里不模拟按键，
        -- 只请求 Rime 重建当前未确认候选菜单。用 guard 防止前端/插件异常重入。
        if not env.delete_refreshing and ctx:is_composing() then
            env.delete_refreshing = true
            pcall(function() ctx:refresh_non_confirmed_composition() end)
            env.delete_refreshing = nil
        end
    end

    env.commit_connection = env.engine.context.commit_notifier:connect(env.commit_cb)
    env.delete_connection = env.engine.context.delete_notifier:connect(env.delete_cb)
end

function P.func(key, env)
    if key:release() then return 2 end

    local repr = key:repr()
    local ctx = env.engine.context
    local is_composing = ctx:is_composing()
    local is_backspace = repr == "BackSpace"
    local has_modifier = not is_backspace and (s_find(repr, "Shift", 1, true) or s_find(repr, "Control", 1, true) or s_find(repr, "Alt", 1, true))
    local digit = not is_composing and not env.is_t9 and get_digit_key(repr) or nil

    -- 回头码：只记录一轮连续退格开始前的完整编码；重新打回该编码时由 F 交换前两候选。
    if is_backspace then
        if not context_state.is_backspacing and is_composing then
            local current_input = ctx.input or ""
            if current_input ~= "" then context_state.reverted_code = context_state.reverted_code == current_input and "" or current_input end
        end
        context_state.is_backspacing = true
    elseif not has_modifier then
        context_state.is_backspacing = false
    end

    -- 非组词状态的数字只做状态捕获；数字实际如何上屏仍交给 Rime/前端。
    if digit then context_state.after_number = true elseif is_backspace and not is_composing then context_state.after_number = false end

    -- 上屏后立即退格：撤销本次 1/2-Gram 数据库写入。
    if is_backspace and not is_composing then
        rollback_last_commit(env)
        return 2
    end

    -- 一旦开始下一次实际输入，上一笔提交就不再允许回滚数据库。
    if env.just_committed and not is_backspace and not has_modifier then clear_undo(env) end
    return 2
end

function P.fini(env)
    if env.commit_connection then env.commit_connection:disconnect(); env.commit_connection = nil end
    if env.delete_connection then env.delete_connection:disconnect(); env.delete_connection = nil end

    env.commit_cb = nil
    env.delete_cb = nil
    env.delete_refreshing = nil
    env.undo_before = nil
    env.undo_after = nil
    env.undo_prev2 = nil
    env.undo_prev1 = nil
    env.undo_prev_time = nil
    env.undo_after_number = nil
    env.just_committed = nil
    env.last_action_time = nil
    env.is_t9 = nil

    context_state.after_number = false
    context_state.reverted_code = ""
    context_state.is_backspacing = false
    reset_context()
    release_db(env)
end

-- Filter：只调整原生候选，不生成预测 Candidate。
local F = {}

function F.init(env)
    load_config(env)
end

-- 从同一个 Translation 预读当前同编码候选组。
-- Candidate 只保存在本次 Filter 调用内的局部表中，最多 100 项。
-- 即使已命中 10 个也继续排序，10 只控制是否允许新增。
local function collect_scored_prefix(next_candidate, db, context2, context1, classifier_mode, limit)
    local entries = {}
    local boundary_cand = nil
    local target_end = nil

    while #entries < limit do
        local cand = next_candidate()
        if not cand then break end

        local cand_type = cand.type or ""
        if #entries == 0 then
            if not REORDER_TYPE_WHITELIST[cand_type] then
                boundary_cand = cand
                break
            end
            target_end = cand._end
        elseif not REORDER_TYPE_WHITELIST[cand_type] or cand._end ~= target_end then
            boundary_cand = cand
            break
        end

        local text = cand.text or ""
        local c2, c1 = get_context_counts(db, text, context2, context1)
        local index = #entries + 1

        entries[index] = {
            cand = cand,
            c2 = c2,
            c1 = c1,
            classifier = classifier_mode and CLASSIFIER_LOOKUP[text] or false,
            raw_index = index,
        }
        remember_snapshot_candidate(text, c2 > 0 or c1 > 0)
    end

    return entries, boundary_cand
end

local function sort_scored_prefix(entries, classifier_mode)
    sort(entries, function(a, b)
        if classifier_mode and a.classifier ~= b.classifier then
            return a.classifier
        end

        local at = a.c2 > 0 and 2 or (a.c1 > 0 and 1 or 0)
        local bt = b.c2 > 0 and 2 or (b.c1 > 0 and 1 or 0)
        if at ~= bt then return at > bt end
        if a.c2 ~= b.c2 then return a.c2 > b.c2 end
        if a.c1 ~= b.c1 then return a.c1 > b.c1 end
        return a.raw_index < b.raw_index
    end)
end

function F.func(input, env)
    local ctx = env.engine.context
    local current_input = ctx.input or ""
    local do_classifier = context_state.after_number and next(CLASSIFIER_LOOKUP) ~= nil
    local do_fallback = CONFIG.ENABLE_FALLBACK_REORDER and current_input ~= "" and current_input == context_state.reverted_code

    if current_input == "" or wanxiang.is_special_mode(ctx) then
        clear_learning_snapshot()
        for cand in input:iter() do yield(cand) end
        return
    end

    -- 上文状态在“下一次真实 commit”之前必须保持稳定。
    -- Filter 可能因为翻页、选中变化、super_sequence 手动调序等原因被反复刷新；
    -- 这些 refresh 都不是新的语言上下文，不能在这里按墙钟时间 reset_context()。
    -- context_timeout 只在 commit_cb 中比较“前后两次真实 commit”的时间间隔。
    local context1 = do_classifier and NUMBER_CONTEXT or context_state.prev1
    local context2 = do_classifier and nil or context_state.prev2
    local do_context = context1 ~= nil

    local iterator, iterator_state, iterator_control = input:iter()
    local exhausted = false
    local function next_candidate()
        if exhausted then return nil end
        local cand = iterator(iterator_state, iterator_control)
        iterator_control = cand
        if not cand then exhausted = true end
        return cand
    end

    -- 回头码优先级最高：只交换前两个同段合法候选，不建立任何 Candidate 缓存。
    if do_fallback then
        clear_learning_snapshot()
        local c1 = next_candidate()
        if not c1 then return end
        local c2 = next_candidate()
        if c2 and REORDER_TYPE_WHITELIST[c1.type or ""] and REORDER_TYPE_WHITELIST[c2.type or ""] and c1._end == c2._end then yield(c2); yield(c1) else yield(c1); if c2 then yield(c2) end end
        while true do local cand = next_candidate(); if not cand then break end; yield(cand) end
        return
    end

    if not do_context and not do_classifier then
        clear_learning_snapshot()
        for cand in input:iter() do yield(cand) end
        return
    end

    local db = get_db(env)
    if not db then
        clear_learning_snapshot()
        for cand in input:iter() do yield(cand) end
        return
    end

    begin_learning_snapshot(context2, context1)
    local entries, boundary_cand = collect_scored_prefix(
        next_candidate, db, context2, context1, do_classifier, FILTER_SCAN_LIMIT
    )
    sort_scored_prefix(entries, do_classifier)

    for _, entry in ipairs(entries) do yield(entry.cand) end
    if boundary_cand then yield(boundary_cand) end
    while not exhausted do local cand = next_candidate(); if not cand then break end; yield(cand) end
end

function F.fini(env)
    clear_learning_snapshot()
    release_db(env)
end

return { P = P, F = F }