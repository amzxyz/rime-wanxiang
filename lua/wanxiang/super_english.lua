-- lua/super_english.lua
-- https://github.com/amzxyz/rime-wanxiang
-- @description: 英文全能处理器 (Filter Only: 锚点切分 + 动态分隔符 + 超时销毁 + 性能极速优化)
-- @author: amzxyz

-- 核心功能清单:
-- 1. [Format] 语句级英文大写格式化,逐词大小写对应 (look HELLO -> look HELLO)
-- 2. [Spacing] 智能语句空格切分，智能单词上屏加空格 (Smart Spacing) 与无损分词还原
-- 3. [Memory] 全量历史缓存，完美解决回删乱码问题
-- 4. [Construct] 原生优先构造策略 (短词无分词则重置为原生输入)
-- 5. [Order] 单字母(a/A) 智能插队排序,补齐单字母候选
-- 6. [Limit & Perf] 纯英文数量限制，并增加极速防卡顿熔断机制
-- 7. [Mixed] 中英混合候选智能决策，过滤双拼硬凑的假中文,中文状态也能输入英文句子了
-- 8. [Lock] 编码达到阈值且英文句子胜出后锁定，并持续使用历史锚点兜底
-- 9. [Fix] 中英决策前先恢复英文空格，保证 phrase 等长判定与原分词输出一致

local byte = string.byte
local find = string.find
local gsub = string.gsub
local upper = string.upper
local lower = string.lower
local sub = string.sub
local match = string.match

local function get_now()
    if rime_api and rime_api.get_time_ms then
        return rime_api.get_time_ms() / 1000
    end
    return os.time()
end

local function pure(s)
    return gsub(s, "[^a-zA-Z]", ""):lower()
end

local no_spacing_words = {
    ["http"]  = true, ["https"] = true, ["www"]   = true, ["ftp"]   = true,
    ["ssh"]   = true, ["mailto"]= true, ["file"]  = true, ["tel"]   = true,
}

local allowed_ascii_symbols = {
    [32] = true,  -- space
    [33] = true,  -- !
    [39] = true,  -- ' 
    [44] = true,  -- ,
    [45] = true,  -- -
    [43] = true,  -- +
    [46] = true,  -- .
    [48]=true, [49]=true, [50]=true, [51]=true, [52]=true,
    [53]=true, [54]=true, [55]=true, [56]=true, [57]=true,
}

local function is_ascii_phrase_fast(s)
    if not s or s == "" then return false end
    local len = #s
    local has_alpha = false
    for i = 1, len do
        local b = byte(s, i)
        local is_upper = (b >= 65 and b <= 90)
        local is_lower = (b >= 97 and b <= 122)
        local is_allowed_sym = allowed_ascii_symbols[b]
        
        if is_upper or is_lower then
            has_alpha = true
        elseif not is_allowed_sym then
            return false
        end
    end
    return has_alpha
end

local function has_letters(s)
    return find(s, "[a-zA-Z]")
end

local apply_segment_formatting

local function word_count_fast(s)
    if not s or s == "" then return 0 end
    local count = 0
    local in_word = false
    for i = 1, #s do
        local b = byte(s, i)
        local is_space = (b == 32 or b == 9 or b == 10 or b == 13)
        if is_space then
            in_word = false
        elseif not in_word then
            count = count + 1
            in_word = true
        end
    end
    return count
end

local function utf8_chars(s)
    local chars = {}
    local i = 1
    while i <= #s do
        local b = byte(s, i)
        local width
        if b < 0x80 then
            width = 1
        elseif b < 0xE0 then
            width = 2
        elseif b < 0xF0 then
            width = 3
        else
            width = 4
        end
        chars[#chars + 1] = sub(s, i, i + width - 1)
        i = i + width
    end
    return chars
end

local function utf8_length(s)
    return #utf8_chars(s or "")
end

local function chars_match_at(sentence_chars, start_index, word_chars)
    if start_index + #word_chars - 1 > #sentence_chars then return false end
    for i = 1, #word_chars do
        if sentence_chars[start_index + i - 1] ~= word_chars[i] then
            return false
        end
    end
    return true
end

local function cache_context_words(ctx, env, curr_input)
    local code_len = #curr_input
    if code_len < 4 or code_len > 6 then return end

    local comp = ctx and ctx.composition
    local seg = comp and not comp:empty() and comp:back() or nil
    if not seg then return end

    local words = {}
    local seen = {}
    for index = 0, 2 do
        local ok, cand = pcall(function()
            return seg:get_candidate_at(index)
        end)
        if not ok or not cand then break end

        local candidate_text = cand.text or ""
        if cand.type == "phrase"
           and candidate_text ~= ""
           and not is_ascii_phrase_fast(candidate_text)
           and utf8_length(candidate_text) >= 2
           and not seen[candidate_text] then
            seen[candidate_text] = true
            words[#words + 1] = candidate_text
        end
    end

    if #words > 0 then
        env.mixed_word_cache[curr_input] = words
    else
        env.mixed_word_cache[curr_input] = nil
    end
end

local function prune_prefix_cache(cache, curr_input)
    if not cache then return end

    local curr_len = #curr_input
    for key in pairs(cache) do
        local key_len = #key
        if key_len > curr_len or sub(curr_input, 1, key_len) ~= key then
            cache[key] = nil
        end
    end
end

local function collect_cached_words(env, curr_input, sentence_text)
    local target_len = utf8_length(sentence_text)
    local result = {}
    local seen = {}
    local max_prefix_len = #curr_input - 1
    if max_prefix_len > 6 then max_prefix_len = 6 end

    for code_len = 4, max_prefix_len do
        local prefix = sub(curr_input, 1, code_len)
        local cached = env.mixed_word_cache[prefix]
        if cached then
            for i = 1, #cached do
                local word = cached[i]
                local word_len = utf8_length(word)
                if word_len >= 2
                   and word_len < target_len
                   and find(sentence_text, word, 1, true)
                   and not seen[word] then
                    seen[word] = true
                    result[#result + 1] = {
                        text = word,
                        chars = utf8_chars(word),
                        length = word_len
                    }
                end
            end
        end
    end

    table.sort(result, function(a, b)
        if a.length ~= b.length then return a.length > b.length end
        return a.text < b.text
    end)
    return result
end

local function segment_chinese_sentence(sentence_text, cached_words)
    local chars = utf8_chars(sentence_text)
    local n = #chars
    if n == 0 then return nil, {} end

    local dp = {}
    local choice = {}
    dp[n + 1] = 0

    for i = n, 1, -1 do
        dp[i] = 1 + dp[i + 1]
        choice[i] = {
            length = 1,
            text = chars[i],
            cached = false
        }

        for j = 1, #cached_words do
            local word = cached_words[j]
            local next_index = i + word.length
            if chars_match_at(chars, i, word.chars) then
                local cost = 1 + dp[next_index]
                if cost < dp[i]
                   or (cost == dp[i] and word.length > choice[i].length) then
                    dp[i] = cost
                    choice[i] = {
                        length = word.length,
                        text = word.text,
                        cached = true
                    }
                end
            end
        end
    end

    local parts = {}
    local i = 1
    while i <= n do
        local selected = choice[i]
        parts[#parts + 1] = selected.cached
            and ("[词:" .. selected.text .. "]")
            or ("[单:" .. selected.text .. "]")
        i = i + selected.length
    end

    return dp[1], parts
end

local function reset_mixed_locks(env)
    env.decision_locked = false
    env.lock_prefix = nil
    env.lock_length = 0

    env.chinese_decision_locked = false
    env.chinese_lock_prefix = nil
    env.chinese_lock_length = 0
end

local function find_english_anchor(env, curr_input)
    local memory = env.memory
    if not memory then return nil, "" end

    if env.decision_locked then
        local lock_prefix = env.lock_prefix
        local lock_len = env.lock_length or 0
        if lock_prefix and lock_len > 0
           and #curr_input > lock_len
           and sub(curr_input, 1, lock_len) == lock_prefix then
            local anchor = memory[lock_prefix]
            if anchor and is_ascii_phrase_fast(anchor.text) then
                return anchor, sub(curr_input, lock_len + 1)
            end
        end
    end

    for i = #curr_input - 1, 1, -1 do
        local prefix = sub(curr_input, 1, i)
        local anchor = memory[prefix]
        if anchor and is_ascii_phrase_fast(anchor.text) then
            return anchor, sub(curr_input, i + 1)
        end
    end
    return nil, ""
end

local function build_fallback_candidate(env, curr_input)
    if env.block_derivation or not has_letters(curr_input) then return nil end

    local anchor, diff = find_english_anchor(env, curr_input)
    if not anchor or diff == "" then return nil end

    local has_spacing = find(anchor.text, " ", 1, true) ~= nil
    local last_word = match(anchor.text, "(%S+)%s*$") or ""
    local spacer = sub(anchor.text, -1) == " " and "" or " "
    local output_text

    if has_spacing or #last_word > 3 then
        output_text = anchor.text .. spacer .. diff
    else
        output_text = curr_input
    end

    output_text = apply_segment_formatting(output_text, curr_input)
    local cand = Candidate("fallback", 0, #curr_input, output_text, "~")
    cand.preedit = output_text
    cand.quality = 999
    return cand
end

local function find_target_in_text(text, start_pos, target_fp)
    local text_len = #text
    local target_len = #target_fp
    if target_len == 0 then return nil, nil end
    local t_idx = 1       
    local scan_p = start_pos 
    local s_index = nil   
    while scan_p <= text_len and t_idx <= target_len do
        local char_txt = sub(text, scan_p, scan_p)
        if lower(char_txt) == sub(target_fp, t_idx, t_idx) then
            if t_idx == 1 then s_index = scan_p end 
            t_idx = t_idx + 1
        end
        scan_p = scan_p + 1
    end
    if t_idx > target_len then
        return s_index, scan_p - 1
    end
    return nil, nil
end

local function restore_sentence_spacing(cand, split_pattern, check_pattern)
    local guide = cand.preedit or ""
    if not find(guide, check_pattern) then return cand end
    local text = cand.text
    local targets = {}
    for seg in string.gmatch(guide, split_pattern) do
        local t = pure(seg)
        if #t > 0 then table.insert(targets, t) end
    end
    if #targets == 0 then return cand end
    local starts = {}
    local p = 1
    for _, target in ipairs(targets) do
        local s, e = find_target_in_text(text, p, target)
        if not s then return cand end
        table.insert(starts, s)
        p = e + 1 
    end
    local parts = {}
    if starts[1] > 1 then
        table.insert(parts, sub(text, 1, starts[1] - 1))
    end
    for i = 1, #starts do
        local current_s = starts[i]
        local next_s = starts[i+1]
        local chunk_end = next_s and (next_s - 1) or #text
        table.insert(parts, sub(text, current_s, chunk_end))
    end
    local new_text = ""
    for i, part in ipairs(parts) do
        if i == 1 then
            new_text = part
        else
            local last_char = sub(new_text, -1)
            if last_char == "'" or last_char == "-" then
                new_text = new_text .. part
            else
                new_text = new_text .. " " .. part
            end
        end
    end
    new_text = gsub(new_text, "%s%s+", " ") 
    if new_text == "" then return cand end
    local nc = Candidate(cand.type, cand.start, cand._end, new_text, cand.comment)
    nc.preedit = cand.preedit
    return nc
end

local NBSP = string.char(0xC2, 0xA0)

apply_segment_formatting = function(text, input_code)
    if not input_code or input_code == "" then return text end
    local parts = {}
    local p_code = 1 
    for word in string.gmatch(text, "%S+") do
        local out_word = word
        local clean_word = pure(word)
        local w_len = #clean_word
        if w_len > 0 then
            if find(word, "[\128-\255]") then
                local input_remain = #input_code - p_code + 1
                if input_remain > 0 then
                     local check_len = (w_len < input_remain) and w_len or input_remain
                     p_code = p_code + check_len
                end
            else
                local input_remain = #input_code - p_code + 1
                if input_remain > 0 then
                    local check_len = (w_len < input_remain) and w_len or input_remain
                    local segment = sub(input_code, p_code, p_code + check_len - 1)
                    local is_pure_alpha = not find(word, "[^a-zA-Z]")
                    if find(segment, "^%u%u") and is_pure_alpha then
                        out_word = upper(word)
                    elseif find(segment, "^%u") then
                        out_word = gsub(word, "^%a", upper)
                    end
                    p_code = p_code + check_len
                end
            end
        end
        table.insert(parts, out_word)
    end
    return table.concat(parts, " ")
end

local function apply_formatting(cand, code_ctx)
    local text = cand.text
    if not text or text == "" then return cand end
    local changed = false
    local norm = gsub(text, NBSP, " ")
    if norm ~= text then text = norm; changed = true end
    if is_ascii_phrase_fast(text) then
        if code_ctx.raw_input then
            local new_text = apply_segment_formatting(text, code_ctx.raw_input)
            if new_text ~= text then text = new_text; changed = true end
        end
        if code_ctx.spacing_mode and code_ctx.spacing_mode ~= "off" then
            local mode = code_ctx.spacing_mode
            if mode == "smart" then
                if code_ctx.prev_is_eng then 
                    if not find(text, "^%s") then text = " " .. text; changed = true end
                end
            elseif mode == "before" then 
                if not find(text, "^%s") then text = " " .. text; changed = true end
            elseif mode == "after" then 
                if not find(text, "%s$") then text = text .. " "; changed = true end
            end
        end
    end
    if not changed then return cand end
    local nc = Candidate(cand.type, cand.start, cand._end, text, cand.comment)
    nc.preedit = cand.preedit
    return nc
end
local P = {}
function P.init(env)
    local ctx = env.engine.context
    env.last_ascii_mode = ctx:get_option("ascii_mode") or false
    env.typed_in_ascii = false

    if ctx.option_update_notifier then
        env.option_conn = ctx.option_update_notifier:connect(function(ctx, option_name)
            if option_name == "ascii_mode" then
                local current_ascii = ctx:get_option("ascii_mode")
                if env.last_ascii_mode and not current_ascii then
                    if env.typed_in_ascii then
                        _G.english_spacing_break = true
                    end
                    env.typed_in_ascii = false
                elseif not env.last_ascii_mode and current_ascii then
                    env.typed_in_ascii = false
                end
                env.last_ascii_mode = current_ascii
            end
        end)
    end
end

function P.fini(env)
    if env.option_conn then
        env.option_conn:disconnect()
        env.option_conn = nil
    end
end

function P.func(key, env)
    if key:release() then return 2 end

    local ctx = env.engine.context
    local ascii_mode = ctx:get_option("ascii_mode")
    local kc = key.keycode

    -- 符号和回车打断检测（composition 为空时）
    if ctx.composition:empty() then
        local is_letter = (kc >= 0x41 and kc <= 0x5a) or (kc >= 0x61 and kc <= 0x7a)
        local is_digit = (kc >= 0x30 and kc <= 0x39)
        local is_symbol = (kc >= 0x20 and kc <= 0x7e) and not is_letter and not is_digit
        local is_enter = (kc == 0xff0d or kc == 0xff8d)
        if is_symbol or is_enter then
            _G.english_spacing_break = true
        end
    end

    -- 英文模式下记录字符输入
    if ascii_mode then
        env.typed_in_ascii = true
    end

    return 2
end
local F = {}
function F.init(env)
    local cfg = env.engine.schema.config
    env.memory = {}
    env.english_spacing_mode = "off"
    env.spacing_timeout = 0
    env.lookup_key = "`"
    env.max_eng_cands = 0
    env.pair_symbol = "\\"
    env.span_clean_threshold = 1
    env.mixed_lock_min_length = 6
    env.span_scan_limit = 3
    env.last_input = ""
    env.mixed_word_cache = {}
    local delimiter_str = " '" 
    if cfg then
        local str = cfg:get_string("wanxiang_english/english_spacing")
        if str then env.english_spacing_mode = str end
        local timeout = cfg:get_double("wanxiang_english/spacing_timeout")
        if timeout then env.spacing_timeout = timeout end
        local key = cfg:get_string("wanxiang_lookup/key")
        if key and key ~= "" then env.lookup_key = key end
        local max_cands = cfg:get_int("wanxiang_english/max_candidates")
        if max_cands then env.max_eng_cands = max_cands end
        local clean_threshold = cfg:get_int("wanxiang_english/span_clean_threshold")
        if clean_threshold then env.span_clean_threshold = clean_threshold end
        local lock_min_length = cfg:get_int("wanxiang_english/mixed_lock_min_length")
        if lock_min_length then env.mixed_lock_min_length = lock_min_length end
        local scan_limit = cfg:get_int("wanxiang_english/span_scan_limit")
        if scan_limit and scan_limit > 0 then
            env.span_scan_limit = scan_limit > 3 and 3 or scan_limit
        end
        local sym = cfg:get_string("wanxiang_english/trigger")
        if sym and #sym > 0 then env.pair_symbol = sub(sym, 1, 1) end
        delimiter_str = cfg:get_string('speller/delimiter') or delimiter_str
    end
    env.lookup_key_esc = gsub(env.lookup_key, "([%%%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    env.delimiter_char = sub(delimiter_str, 1, 1)
    local escaped_delims = gsub(delimiter_str, "([%%%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    env.split_pattern = "[^" .. escaped_delims .. "]+"     
    env.delim_check_pattern = "[" .. escaped_delims .. "]" 
    env.prev_commit_is_eng = false
    env.last_commit_time = 0
    env.comp_start_time = nil
    env.spacing_active = false
    reset_mixed_locks(env)
    if env.engine.context then
        env.update_notifier = env.engine.context.update_notifier:connect(function(ctx)
            local curr_input = ctx.input or ""
            if curr_input ~= "" then
                prune_prefix_cache(env.memory, curr_input)
                prune_prefix_cache(env.mixed_word_cache, curr_input)
                cache_context_words(ctx, env, curr_input)
            end

            if env.lookup_key and find(curr_input, env.lookup_key, 1, true) then
                env.block_derivation = true
            else
                env.block_derivation = false
            end

            if curr_input == "" then
                if env.last_input ~= "" then
                    env.comp_start_time = nil
                    env.memory = {}
                    env.mixed_word_cache = {}
                    reset_mixed_locks(env)
                    collectgarbage("step", 20)
                end
            elseif env.comp_start_time == nil then
                env.comp_start_time = get_now()
            end
            env.last_input = curr_input
        end)
        env.commit_notifier = env.engine.context.commit_notifier:connect(function(ctx)
            local commit_text = ctx:get_commit_text()
            local text_no_space = gsub(commit_text, "%s", "")
            local is_eng = is_ascii_phrase_fast(text_no_space)
            
            if is_eng then
                local clean = gsub(commit_text, "%s+$", ""):lower()
                if no_spacing_words[clean] then
                    is_eng = false
                end
            end
            
            env.prev_commit_is_eng = is_eng
            if is_eng then
                env.last_commit_time = get_now()
            else
                env.last_commit_time = 0
            end
            _G.english_spacing_break = false
            env.block_derivation = false
            env.memory = {}
            env.mixed_word_cache = {}
            reset_mixed_locks(env)
        end)
    end
end

function F.fini(env)
    if env.update_notifier then env.update_notifier:disconnect(); env.update_notifier = nil end
    if env.commit_notifier then env.commit_notifier:disconnect(); env.commit_notifier = nil end
    env.memory = nil
    env.mixed_word_cache = nil
    reset_mixed_locks(env)
end

local function sync_lock_with_input(env, curr_input)
    if not env.decision_locked and not env.chinese_decision_locked then return end

    local lock_len
    local lock_prefix
    if env.decision_locked then
        lock_len = env.lock_length or 0
        lock_prefix = env.lock_prefix or ""
    else
        lock_len = env.chinese_lock_length or 0
        lock_prefix = env.chinese_lock_prefix or ""
    end

    if #curr_input < lock_len or sub(curr_input, 1, lock_len) ~= lock_prefix then
        reset_mixed_locks(env)
    end
end

local function yield_passthrough(input)
    for cand in input:iter() do
        yield(cand)
    end
end

local function try_yield_forced_english(ctx, curr_input, symbol)
    local code_len = #curr_input
    if code_len <= 2 or sub(curr_input, -2) ~= symbol .. symbol then
        return false
    end

    local raw_text = sub(curr_input, 1, code_len - 2)
    if not is_ascii_phrase_fast(raw_text) then
        return false
    end

    if ctx.composition and not ctx.composition:empty() then
        ctx.composition:back().prompt = "〔英文造词〕"
    end

    local cand = Candidate("english", 0, code_len, raw_text, "")
    cand.preedit = raw_text
    yield(cand)
    return true
end

local function build_code_context(env, curr_input)
    local effective_prev_is_eng = env.prev_commit_is_eng

    if _G.english_spacing_break == true then
        effective_prev_is_eng = false
        env.prev_commit_is_eng = false
    elseif effective_prev_is_eng and env.spacing_timeout > 0 then
        local check_time = env.comp_start_time or get_now()
        if (check_time - env.last_commit_time) > env.spacing_timeout then
            effective_prev_is_eng = false
            env.prev_commit_is_eng = false
        end
    end

    return {
        raw_input = curr_input,
        spacing_mode = env.english_spacing_mode,
        prev_is_eng = effective_prev_is_eng
    }
end

local function build_single_char_candidates(curr_input)
    if #curr_input ~= 1 then
        return nil, false, true
    end

    local b = byte(curr_input)
    local is_upper = (b >= 65 and b <= 90)
    local is_lower = (b >= 97 and b <= 122)
    if not is_upper and not is_lower then
        return nil, false, false
    end

    local alternate = is_upper and lower(curr_input) or upper(curr_input)
    return {
        Candidate("completion", 0, 1, curr_input, ""),
        Candidate("completion", 0, 1, alternate, "")
    }, true, false
end

local function new_filter_state(env, curr_input, code_ctx)
    local single_chars, has_single_chars, single_char_injected =
        build_single_char_candidates(curr_input)
    local initial_eng_count = has_single_chars and 2 or 0

    return {
        env = env,
        curr_input = curr_input,
        code_len = #curr_input,
        code_ctx = code_ctx,

        single_chars = single_chars,
        has_single_chars = has_single_chars,
        single_char_injected = single_char_injected,

        safe_max_cands = env.max_eng_cands or 0,
        clean_threshold = env.span_clean_threshold or 1,
        scan_limit = 3,
        lock_min_length = env.mixed_lock_min_length or 6,
        has_explicit_delimiter = find(curr_input, env.delim_check_pattern) ~= nil,

        has_valid_candidate = false,
        has_retained_sentence = false,
        best_candidate_saved = false,
        lock_anchor_refreshed = false,
        eng_yield_count = initial_eng_count,
        consecutive_quota_skips = 0,
        stop_processing = false,
        stop_after_buffer = false,

        retained_sentence_in_buffer = false,
        deleted_fake_cn_in_buffer = false,
        first_survivor_is_sentence = false,
        first_survivor_text = nil,
        decision_ready = false,
        pending_lock = false,
        pending_chinese_lock = false,

        buffered = {},
        scanned = 0,
        english_sentence_index = nil,
        english_sentence_words = 0,
        chinese_sentence_index = nil,
        chinese_segments = nil,
        chinese_parts = nil,
        mixed_delete_candidates = {},
        scan_prospective_eng_count = initial_eng_count
    }
end

local function remember_first_candidate(state, text, ignore_block_derivation)
    if state.best_candidate_saved then return end
    if state.env.block_derivation and not ignore_block_derivation then return end
    if not is_ascii_phrase_fast(text) then return end

    state.env.memory[state.curr_input] = {
        text = text
    }
    state.best_candidate_saved = true
end

local function refresh_locked_anchor(state, text, words, comment)
    local env = state.env
    if not env.decision_locked
       or env.block_derivation
       or state.lock_anchor_refreshed
       or comment == "~"
       or words <= 1 then
        return
    end

    local lock_prefix = env.lock_prefix or ""
    local lock_len = env.lock_length or 0

    if state.code_len <= lock_len
       or sub(state.curr_input, 1, lock_len) ~= lock_prefix then
        return
    end

    env.memory[state.curr_input] = { text = text }
    env.lock_prefix = state.curr_input
    env.lock_length = state.code_len
    state.best_candidate_saved = true
    state.lock_anchor_refreshed = true
end

local function emit_single_char_candidates(state)
    if not state.has_single_chars or state.single_char_injected then return end

    if not state.best_candidate_saved then
        remember_first_candidate(state, state.single_chars[1].text, true)
    end
    for i = 1, #state.single_chars do
        yield(state.single_chars[i])
    end

    state.single_char_injected = true
    state.has_valid_candidate = true
end

local function prepare_buffer_item(cand, env)
    local raw_text = cand.text or ""
    local is_ascii = is_ascii_phrase_fast(raw_text)
    local prepared = cand
    local text = raw_text
    local words = 0

    if is_ascii then
        words = word_count_fast(raw_text)
        if words <= 1 then
            prepared = restore_sentence_spacing(cand, env.split_pattern,
                env.delim_check_pattern)
            text = prepared.text or raw_text
            words = word_count_fast(text)
        end
    end

    return {
        cand = cand,
        prepared = prepared,
        c_type = cand.type,
        text = text,
        is_ascii = is_ascii,
        words = words
    }
end

local function process_candidate(state, cand, prepared, c_type, text, is_ascii, known_words)
    if state.stop_processing then return end

    local env = state.env
    if c_type == "raw"
       or (state.code_len == 1 and lower(text) == lower(state.curr_input)) then
        return
    end

    if state.mixed_delete_candidates[cand] then
        return
    end

    if env.decision_locked and not is_ascii then
        return
    end

    if env.chinese_decision_locked and is_ascii then
        local probe = prepared
            or restore_sentence_spacing(cand, env.split_pattern, env.delim_check_pattern)
        local probe_text = probe.text or text
        local probe_words = known_words
        if not probe_words or probe_words <= 0 then
            probe_words = word_count_fast(probe_text)
        end

        if probe_words > 1 then
            return
        end

        prepared = probe
        text = probe_text
        known_words = probe_words
    end

    if is_ascii
       and c_type ~= "user_phrase"
       and c_type ~= "user_table" then
        if state.safe_max_cands > 0
           and state.eng_yield_count >= state.safe_max_cands then
            emit_single_char_candidates(state)
            state.consecutive_quota_skips = state.consecutive_quota_skips + 1
            if state.consecutive_quota_skips > 50 then
                state.stop_processing = true
            end
            return
        end
        state.eng_yield_count = state.eng_yield_count + 1
    end

    state.consecutive_quota_skips = 0

    local working_cand = prepared
        or restore_sentence_spacing(cand, env.split_pattern, env.delim_check_pattern)
    local formatted = apply_formatting(working_cand, state.code_ctx)

    if is_ascii and formatted.comment
       and find(formatted.comment, "\226\152\175") then
        local clean = Candidate(formatted.type, formatted.start, formatted._end,
            formatted.text, "")
        clean.preedit = formatted.preedit
        formatted = clean
    end

    local final_is_ascii = is_ascii
    if not final_is_ascii then
        final_is_ascii = is_ascii_phrase_fast(formatted.text)
    end

    local words = 0
    if final_is_ascii then
        if known_words and known_words > 0 then
            words = known_words
        else
            words = word_count_fast(formatted.text)
        end
    end

    state.has_valid_candidate = true
    if words > 1 then
        state.has_retained_sentence = true
        if final_is_ascii then
            refresh_locked_anchor(state, formatted.text, words, formatted.comment)
        end
    end

    local final_type = formatted.type
    local is_vip_type = final_type == "user_table"
        or final_type == "fixed"
        or final_type == "phrase"
    local treat_as_vip = is_vip_type or not is_ascii

    if treat_as_vip then
        if formatted.comment ~= "~" then
            remember_first_candidate(state, formatted.text)
        end
        yield(formatted)
        return
    end

    emit_single_char_candidates(state)
    if formatted.comment ~= "~" then
        remember_first_candidate(state, formatted.text)
    end
    yield(formatted)
end

local function buffer_item_survives_mixed(state, item)
    if item.c_type == "raw" then return false end

    if state.env.decision_locked then
        return item.is_ascii
    end

    if state.env.chinese_decision_locked then
        return not (item.is_ascii and item.words > 1)
    end

    return not state.mixed_delete_candidates[item.cand]
end

local function buffer_item_survives_quota(state, item, prospective_eng_count)
    if not item.is_ascii
       or item.c_type == "user_phrase"
       or item.c_type == "user_table" then
        return true, prospective_eng_count
    end

    if state.safe_max_cands > 0
       and prospective_eng_count >= state.safe_max_cands then
        return false, prospective_eng_count
    end

    return true, prospective_eng_count + 1
end

local function analyze_buffer_survivors(state)
    local prospective_eng_count = state.has_single_chars and 2 or 0
    local first_survivor_seen = false

    for i = 1, state.scanned do
        local item = state.buffered[i]
        local survives = buffer_item_survives_mixed(state, item)

        if survives then
            survives, prospective_eng_count =
                buffer_item_survives_quota(state, item, prospective_eng_count)
        end

        if survives then
            if not first_survivor_seen then
                first_survivor_seen = true
                state.first_survivor_is_sentence = item.is_ascii
                    and item.words > 1
                if state.first_survivor_is_sentence then
                    state.first_survivor_text = item.text
                end
            end
            if item.is_ascii and item.words > 1 then
                state.retained_sentence_in_buffer = true
            end
        end
    end
end

local function activate_lock_if_needed(state)
    local env = state.env
    if env.decision_locked
       or env.chinese_decision_locked
       or state.pending_chinese_lock
       or env.block_derivation
       or not state.first_survivor_is_sentence
       or state.code_len < state.lock_min_length then
        return
    end
    state.pending_lock = true
end

local function apply_pending_lock(state)
    if not state.pending_lock
       or state.env.decision_locked
       or state.env.chinese_decision_locked then
        return
    end

    local env = state.env
    local anchor_text = state.first_survivor_text

    if anchor_text and is_ascii_phrase_fast(anchor_text) then
        env.memory[state.curr_input] = { text = anchor_text }
        state.best_candidate_saved = true
    end

    env.decision_locked = true
    env.lock_prefix = state.curr_input
    env.lock_length = state.code_len
end

local function apply_pending_chinese_lock(state)
    if not state.pending_chinese_lock
       or state.env.chinese_decision_locked
       or state.env.decision_locked then
        return
    end

    local env = state.env
    env.chinese_decision_locked = true
    env.chinese_lock_prefix = state.curr_input
    env.chinese_lock_length = state.code_len
end

local function emit_locked_fallback_if_needed(state)
    if not state.env.decision_locked or state.retained_sentence_in_buffer then
        return
    end

    local fallback = build_fallback_candidate(state.env, state.curr_input)
    if not fallback then return end

    yield(fallback)
    state.has_valid_candidate = true
    state.has_retained_sentence = word_count_fast(fallback.text) > 1
    state.stop_after_buffer = state.has_retained_sentence
end

local function flush_buffer(state)
    for i = 1, state.scanned do
        local item = state.buffered[i]
        process_candidate(state, item.cand, item.prepared, item.c_type,
            item.text, item.is_ascii, item.words)
        state.buffered[i] = nil
        if state.stop_processing then break end
    end

    state.buffered = nil
end

local function finalize_mixed_decision(state)
    if state.decision_ready then return end

    state.retained_sentence_in_buffer = false
    state.deleted_fake_cn_in_buffer = false
    state.first_survivor_is_sentence = false

    if state.env.chinese_decision_locked then
        state.decision_ready = true
        flush_buffer(state)
        return
    end

    if state.env.decision_locked then
        analyze_buffer_survivors(state)
        emit_locked_fallback_if_needed(state)
        state.decision_ready = true
        flush_buffer(state)
        return
    end

    local endpoint = state.english_sentence_index
    local english_item = endpoint and state.buffered[endpoint] or nil
    local chinese_item = state.chinese_sentence_index
        and state.buffered[state.chinese_sentence_index] or nil

    if endpoint and english_item and chinese_item
       and state.code_len >= 4 and state.code_len <= 6 then
        local cached_words = collect_cached_words(state.env, state.curr_input,
            chinese_item.text)
        local cn_segments, cn_parts = segment_chinese_sentence(
            chinese_item.text, cached_words)
        local en_segments = english_item.words

        state.chinese_segments = cn_segments
        state.chinese_parts = cn_parts
        state.english_sentence_words = en_segments

        if cn_segments and en_segments > cn_segments
           and (en_segments - cn_segments) >= state.clean_threshold then
            state.mixed_delete_candidates[english_item.cand] = true
            if state.code_len >= state.lock_min_length then
                state.pending_chinese_lock = true
            end
        elseif cn_segments and cn_segments > en_segments
           and (cn_segments - en_segments) >= state.clean_threshold then
            for i = 1, state.scanned do
                local item = state.buffered[i]
                if item and not item.is_ascii and item.c_type ~= "raw" then
                    state.mixed_delete_candidates[item.cand] = true
                end
            end
            state.deleted_fake_cn_in_buffer = true
        end
    end
    analyze_buffer_survivors(state)
    activate_lock_if_needed(state)
    apply_pending_chinese_lock(state)
    apply_pending_lock(state)
    emit_locked_fallback_if_needed(state)
    state.decision_ready = true
    flush_buffer(state)
end

local function buffer_for_decision(state, cand)
    state.scanned = state.scanned + 1
    local item = prepare_buffer_item(cand, state.env)
    state.buffered[state.scanned] = item

    if not item.is_ascii
       and item.c_type ~= "raw"
       and not state.chinese_sentence_index then
        state.chinese_sentence_index = state.scanned
    end

    if item.is_ascii
       and item.words > 1
       and not state.english_sentence_index then
        state.english_sentence_index = state.scanned
        state.english_sentence_words = item.words
    end

    if state.env.decision_locked
       and item.c_type ~= "raw"
       and item.is_ascii
       and item.words > 1 then
        return true
    end

    return state.scanned >= state.scan_limit
end

local function run_candidate_stream(input, state)
    for cand in input:iter() do
        if state.decision_ready then
            local text = cand.text or ""
            process_candidate(state, cand, nil, cand.type, text,
                is_ascii_phrase_fast(text), nil)
        elseif buffer_for_decision(state, cand) then
            finalize_mixed_decision(state)
        end

        if state.stop_processing or state.stop_after_buffer then
            break
        end
    end

    if not state.decision_ready then
        finalize_mixed_decision(state)
    end

    apply_pending_chinese_lock(state)
    apply_pending_lock(state)
end

local function emit_terminal_fallback(state)

    if state.env.chinese_decision_locked then return end

    local need_fallback =
        (not state.env.decision_locked and not state.has_valid_candidate)
        or (state.env.decision_locked and not state.has_retained_sentence)
    if not need_fallback then return end

    local fallback = build_fallback_candidate(state.env, state.curr_input)
    if fallback then
        yield(fallback)
        state.has_valid_candidate = true
        state.has_retained_sentence = word_count_fast(fallback.text) > 1
    end
end

function F.func(input, env)
    local ctx = env.engine.context
    local curr_input = ctx.input or ""

    if _G.english_spacing_break == true then
        env.prev_commit_is_eng = false
    end

    sync_lock_with_input(env, curr_input)

    if not has_letters(curr_input) then
        reset_mixed_locks(env)
        yield_passthrough(input)
        return
    end

    if try_yield_forced_english(ctx, curr_input, env.pair_symbol) then
        return
    end

    local code_ctx = build_code_context(env, curr_input)
    local state = new_filter_state(env, curr_input, code_ctx)

    run_candidate_stream(input, state)
    emit_terminal_fallback(state)
end

return { F = F, P = P }