-- lua/super_english.lua
-- https://github.com/amzxyz/rime_wanxiang
-- @description: 英文全能处理器 (Filter Only: 锚点切分 + 动态分隔符 + 超时销毁)
-- @author: amzxyz

-- 核心功能清单:
-- 1. [Format] 语句级英文大写格式化,逐词大小写对应 (look HELLO -> look HELLO)
-- 2. [Spacing] 智能语句空格切分，智能单词上屏加空格 (Smart Spacing) 与无损分词还原
-- 3. [Memory] 全量历史缓存，完美解决回删乱码问题
-- 4. [Construct] 原生优先构造策略 (短词无分词则重置为原生输入)
-- 5. [Order] 单字母(a/A) 智能插队排序,补齐单字母候选

local F = {}

local byte = string.byte
local find = string.find
local gsub = string.gsub
local upper = string.upper
local lower = string.lower
local sub = string.sub
local match = string.match
local format = string.format
local STICKY_BUFFER_SIZE = 2

local function fast_type(c)
    local t = c.type
    if t then return t end
    local g = c.get_genuine and c:get_genuine() or nil
    return (g and g.type) or ""
end

local function is_table_type(c)
    local t = fast_type(c)
    return t == "user_table" or t == "fixed"
end

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
    [63] = true,  -- ?
    [92] = true,  -- \
    [48]=true, [49]=true, [50]=true, [51]=true, [52]=true,
    [53]=true, [54]=true, [55]=true, [56]=true, [57]=true,
}

local function is_ascii_phrase_fast(s)
    if not s or s == "" then return false end
    local len = #s
    for i = 1, len do
        local b = byte(s, i)
        local is_upper = (b >= 65 and b <= 90)
        local is_lower = (b >= 97 and b <= 122)
        local is_allowed_sym = allowed_ascii_symbols[b]
        if not (is_upper or is_lower or is_allowed_sym) then
            return false
        end
    end
    return true
end

local function has_letters(s)
    return find(s, "[a-zA-Z]")
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

local function apply_segment_formatting(text, input_code)
    if not input_code or input_code == "" then return text end
    local parts = {}
    local p_code = 1 
    for word in string.gmatch(text, "%S+") do
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
                        word = upper(word)
                    elseif find(segment, "^%u") then
                        word = gsub(word, "^%a", upper)
                    end
                    p_code = p_code + check_len
                end
            end
        end
        table.insert(parts, word)
    end
    return table.concat(parts, " ")
end

local function apply_formatting(cand, code_ctx)
    local text = cand.text
    if not text or text == "" then return cand end
    local changed = false
    local norm = gsub(text, NBSP, " ")
    if norm ~= text then text = norm; changed = true end
    if is_ascii_phrase_fast(text) and has_letters(text) then
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

function F.init(env)
    env.memory = {}
    local cfg = env.engine.schema.config
    env.english_spacing_mode = "off"
    env.spacing_timeout = 0 
    env.lookup_key = "`"
    if cfg then
        local str = cfg:get_string("wanxiang_english/english_spacing")
        if str then env.english_spacing_mode = str end
        local timeout = cfg:get_double("wanxiang_english/spacing_timeout")
        if timeout then env.spacing_timeout = timeout end
        local key = cfg:get_string("wanxiang_lookup/key")
        if key and key ~= "" then env.lookup_key = key end
    end
    env.lookup_key_esc = gsub(env.lookup_key, "([%%%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    local delimiter_str = " '" 
    if cfg then
        delimiter_str = cfg:get_string('speller/delimiter') or delimiter_str
    end
    env.delimiter_char = sub(delimiter_str, 1, 1)
    local escaped_delims = gsub(delimiter_str, "([%%%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    env.split_pattern = "[^" .. escaped_delims .. "]+"     
    env.delim_check_pattern = "[" .. escaped_delims .. "]" 
    env.prev_commit_is_eng = false
    env.last_commit_time = 0
    env.comp_start_time = nil
    env.spacing_active = false  
    env.decision_locked = false 
    env.sticky_countdown = 0
    if env.engine.context then
        env.update_notifier = env.engine.context.update_notifier:connect(function(ctx)
            local curr_input = ctx.input
            if env.lookup_key and find(curr_input, env.lookup_key, 1, true) then
                env.block_derivation = true
            else
                env.block_derivation = false
            end
            if curr_input == "" then
                env.comp_start_time = nil
            elseif env.comp_start_time == nil then
                env.comp_start_time = get_now()
            end
        end)
        env.commit_notifier = env.engine.context.commit_notifier:connect(function(ctx)
            local commit_text = ctx:get_commit_text()
            local text_no_space = gsub(commit_text, "%s", "")
            local is_eng = is_ascii_phrase_fast(text_no_space)
            if find(text_no_space, "[/\\\\]$") then
                env.sticky_countdown = STICKY_BUFFER_SIZE
                is_eng = false 
            elseif env.sticky_countdown > 0 then
                if is_eng then
                    env.sticky_countdown = env.sticky_countdown - 1
                    is_eng = false 
                else
                    env.sticky_countdown = 0
                end
            elseif is_eng then
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
            ctx:set_property("english_spacing", "")
            env.block_derivation = false
        end)
    end
end
function F.fini(env)
    if env.update_notifier then env.update_notifier:disconnect(); env.update_notifier = nil end
    if env.commit_notifier then env.commit_notifier:disconnect(); env.commit_notifier = nil end
    env.memory = nil
end

function F.func(input, env)
    local ctx = env.engine.context
    local curr_input = ctx.input
    if not has_letters(curr_input) then
        for cand in input:iter() do
            yield(cand)
        end
        return 
    end
    -- ===
    local has_valid_candidate = false
    local best_candidate_saved = false
    local code_len = #curr_input

    -- [Feature] 强制英文造词
    if code_len > 2 and sub(curr_input, -2) == "\\\\" then
        local raw_text = sub(curr_input, 1, code_len - 2)
        if is_ascii_phrase_fast(raw_text) then
            if ctx.composition and not ctx.composition:empty() then
                ctx.composition:back().prompt = "〔英文造词〕"
            end
            local cand = Candidate("english", 0, code_len, raw_text, "")
            cand.preedit = raw_text 
            yield(cand)
            return 
        end
    end
    
    local break_signal = (ctx:get_property("english_spacing") == "true")
    local effective_prev_is_eng = env.prev_commit_is_eng

    if break_signal then 
        effective_prev_is_eng = false
        env.prev_commit_is_eng = false
    elseif effective_prev_is_eng and env.spacing_timeout > 0 then
        local check_time = env.comp_start_time or get_now()
        if (check_time - env.last_commit_time) > env.spacing_timeout then
            effective_prev_is_eng = false
            env.prev_commit_is_eng = false 
        end
    end

    local code_ctx = {
        raw_input = curr_input, 
        spacing_mode = env.english_spacing_mode,
        prev_is_eng = effective_prev_is_eng
    }

    local single_char_injected = false
    local single_chars = {}
    
    if code_len == 1 then
        local b = byte(curr_input)
        local is_upper = (b >= 65 and b <= 90)
        local is_lower = (b >= 97 and b <= 122)
        if is_upper or is_lower then
            local t1 = curr_input
            local t2 = is_upper and lower(curr_input) or upper(curr_input)
            table.insert(single_chars, Candidate("completion", 0, 1, t1, ""))
            table.insert(single_chars, Candidate("completion", 0, 1, t2, ""))
            has_single_chars = true
        end
    else
        single_char_injected = true 
    end

    for cand in input:iter() do
        local good_cand = restore_sentence_spacing(cand, env.split_pattern, env.delim_check_pattern)
        local fmt_cand = apply_formatting(good_cand, code_ctx)
        
        -- [恢复] 去除注释中的太极符号
        if fmt_cand.comment and find(fmt_cand.comment, "\226\152\175") then
            local nc = Candidate(fmt_cand.type, fmt_cand.start, fmt_cand._end, fmt_cand.text, "")
            nc.preedit = fmt_cand.preedit
            fmt_cand = nc
        end

        local c_type = cand.type
        local is_ascii = is_ascii_phrase_fast(fmt_cand.text) 
        local is_tbl = is_table_type(cand)

        -- [垃圾词判定]：保护符号，只去重单字母
        local is_garbage = (c_type == "raw") 
        if not is_garbage and code_len == 1 and has_letters(curr_input) then
             if lower(fmt_cand.text) == lower(curr_input) then
                 is_garbage = true
             end
        end
        
        if not is_garbage then
            has_valid_candidate = true
            
            -- [VIP 优先逻辑]
            local is_vip_type = (c_type == "user_table" or c_type == "fixed" or c_type == "phrase")
            local is_hidden_vip = (not is_vip_type) and (not is_ascii)
            local treat_as_vip = is_vip_type or is_hidden_vip

            if treat_as_vip then
                -- VIP 通道：不仅是 user_table，包括汉字等，都直接输出，不让单字母插队
                if not best_candidate_saved and cand.comment ~= "~" and not env.block_derivation then
                    env.memory[curr_input] = {
                        text = fmt_cand.text,
                        preedit = fmt_cand.preedit or curr_input
                    }
                    best_candidate_saved = true
                end
                yield(fmt_cand)

            else
                -- 普通通道：允许单字母插队到前面
                if has_single_chars and not single_char_injected then
                    if not best_candidate_saved then
                        env.memory[curr_input] = { text = single_chars[1].text, preedit = curr_input }
                        best_candidate_saved = true
                    end
                    for _, c in ipairs(single_chars) do yield(c) end
                    single_char_injected = true
                    has_valid_candidate = true
                end
                
                if not best_candidate_saved and cand.comment ~= "~" and not env.block_derivation then
                    env.memory[curr_input] = {
                        text = fmt_cand.text,
                        preedit = fmt_cand.preedit or curr_input
                    }
                    best_candidate_saved = true
                end
                yield(fmt_cand)
            end
        end
    end

    -- 3. 兜底逻辑 (补单字母)
    if has_single_chars and not single_char_injected then
        if not best_candidate_saved then
            env.memory[curr_input] = { text = single_chars[1].text, preedit = single_chars[1].text }
            best_candidate_saved = true
        end
        for _, c in ipairs(single_chars) do yield(c) end
        has_valid_candidate = true
    end

    -- [Phase 3] 历史回溯构造 (Strictly fallback)
    if not has_valid_candidate then
        if find(curr_input, "^[/]") then 
            return 
        end
        if not env.block_derivation and has_letters(curr_input) then
            local anchor = nil
            local diff = ""
            for i = #curr_input - 1, 1, -1 do
                local prefix = sub(curr_input, 1, i)
                if env.memory[prefix] then
                    anchor = env.memory[prefix]
                    diff = sub(curr_input, i + 1)
                    break
                end
            end
            
            if anchor and diff ~= "" then
                local has_spacing = find(anchor.text, " ")
                local last_word = match(anchor.text, "(%S+)%s*$") or ""
                local last_len = #last_word
                local output_text = ""
                local output_preedit = ""
                
                local is_code_mode = find(curr_input, "^[/\\]")
                
                if is_ascii_phrase_fast(anchor.text) then
                    local spacer = " "
                    if sub(anchor.text, -1) == " " then spacer = "" end

                    if has_spacing then
                        output_text = anchor.text .. spacer .. diff
                        output_preedit = (anchor.preedit or anchor.text) .. spacer .. diff
                    elseif last_len > 3 then
                        output_text = anchor.text .. spacer .. diff
                        output_preedit = (anchor.preedit or anchor.text) .. spacer .. diff
                    else
                        output_text = curr_input
                        output_preedit = curr_input
                    end
                elseif is_code_mode then
                    output_text = anchor.text .. diff
                    output_preedit = (anchor.preedit or anchor.text) .. diff
                else
                    output_text = anchor.text
                    output_preedit = (anchor.preedit or anchor.text) .. env.delimiter_char .. diff
                end
                
                output_text = apply_segment_formatting(output_text, curr_input)
                
                local cand = Candidate("completion", 0, #curr_input, output_text, "~")
                cand.preedit = output_preedit
                cand.quality = 999
                yield(cand)
            else
                -- [Phase 4] 真正的无解兜底
                local cand = Candidate("completion", 0, #curr_input, curr_input, "~")
                cand.preedit = curr_input
                yield(cand)
            end
        else
             -- 特殊符号或被拦截时的兜底
             local cand = Candidate("completion", 0, #curr_input, curr_input, "~")
             cand.preedit = curr_input
             yield(cand)
        end
    end
end

return F