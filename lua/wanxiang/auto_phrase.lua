-- @amzxyz https://github.com/amzxyz/rime-wanxiang
-- 自动造词
local AP = {}

local function clear_comment_cache(env)
    local cache = env.comment_cache
    if not cache then return end
    for key in pairs(cache) do
        cache[key] = nil
    end
end

local function release_runtime(env)
    if env._commit_conn then
        pcall(function() env._commit_conn:disconnect() end)
        env._commit_conn = nil
    end

    if env._delete_conn then
        pcall(function() env._delete_conn:disconnect() end)
        env._delete_conn = nil
    end

    if env.memory then
        pcall(function() env.memory:disconnect() end)
        env.memory = nil
    end

    if env.en_memory then
        pcall(function() env.en_memory:disconnect() end)
        env.en_memory = nil
    end
end

-- 工具：是否纯英文（ASCII 且至少 1 个字母）
local function is_ascii_word(text)
    if not text or text == "" then
        return false
    end
    local has_alpha = false
    for i = 1, #text do
        local b = text:byte(i)
        if b > 127 then
            return false
        end
        if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
            has_alpha = true
        end
    end
    return has_alpha
end

-- 判断字符是否为汉字（原逻辑）
function AP.is_chinese_only(text)
    local non_chinese_pattern = "[%w%p]"

    if not text or text == "" then
        return false
    end

    if text:match(non_chinese_pattern) then
        return false
    end

    for _, cp in utf8.codes(text) do
        -- 常用汉字区 + 扩展 A/B/C/D/E/F/G
        if not (
            (cp >= 0x4E00 and cp <= 0x9FFF) or -- CJK Unified Ideographs
            (cp >= 0x3400 and cp <= 0x4DBF) or -- CJK Ext-A
            (cp >= 0x20000 and cp <= 0x2EBEF)  -- CJK Ext-B~G
        ) then
            return false
        end
    end
    return true
end

function AP.init(env)
    env.comment_cache = {}

    local config = env.engine.schema.config
    local ctx    = env.engine.context

    -- 中文自动造词的开关（只控制 add_user_dict）
    local enable_auto_phrase =
        config:get_bool("add_user_dict/enable_auto_phrase") or false
    local enable_user_dict  =
        config:get_bool("add_user_dict/enable_user_dict") or false

    -- 中文：add_user_dict（受 add_* 开关影响）
    if enable_auto_phrase and enable_user_dict then
        env.memory = Memory(env.engine, env.engine.schema, "add_user_dict")
    else
        env.memory = nil
    end

    -- 英文：enuser（不受 add_* 开关影响，始终尝试启用）
    env.en_memory = Memory(env.engine, env.engine.schema, "wanxiang_english")

    -- 中英文任一造词启用时，都需要监听上屏事件。
    if env.en_memory or env.memory then
        env._commit_conn = ctx.commit_notifier:connect(function(c)
            AP.commit_handler(c, env)
        end)
    end

    -- 删除事件只用于清理中文造词的注释缓存。
    if env.memory then
        env._delete_conn = ctx.delete_notifier:connect(function()
            clear_comment_cache(env)
        end)
    end
end

function AP.fini(env)
    release_runtime(env)
    clear_comment_cache(env)
    env.comment_cache = nil
end

function AP.save_comment_cache(cand, genuine, env)
    local text = cand.text
    local comment = genuine.comment
    local cache = env.comment_cache

    if cache and text and text ~= "" and comment and comment ~= "" then
        cache[text] = comment
    end
end

-- 入口
function AP.func(input, env)
    local use_comment_cache = env.memory ~= nil  -- 只有中文造词才需要缓存注释

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()

        if use_comment_cache then
            AP.save_comment_cache(cand, genuine_cand, env)
        end

        yield(cand)
    end
end

-- 造词
function AP.commit_handler(ctx, env)
    local comment_cache = env.comment_cache

    if not ctx or not ctx.composition then
        clear_comment_cache(env)
        return
    end

    local segments       = ctx.composition:toSegmentation():get_segments()
    local segments_count = #segments
    local commit_text    = ctx:get_commit_text() or ""
    local raw_input      = ctx.input or ""

    ---------------------------------------------------
    -- ① 英文造词（保持原样，仍用硬编码 "\"）
    ---------------------------------------------------
    if raw_input ~= "" and raw_input:sub(-1) == "\\" and is_ascii_word(commit_text) then
        local code_body = raw_input:gsub("\\+$", "")
        code_body = code_body:gsub("%s+$", "")
        local clean_commit_text = commit_text:gsub("\\+$", "")
        if code_body ~= "" and clean_commit_text ~= "" and env.en_memory then
            local function save_entry(code)
                local entry = DictEntry()
                entry.text        = clean_commit_text
                entry.weight      = 1
                entry.custom_code = code .. " "
                env.en_memory:update_userdict(entry, 1, "")
            end
            save_entry(code_body)
            local lower_code = string.lower(code_body)
            if lower_code ~= code_body then
                save_entry(lower_code)
            end
        end

        clear_comment_cache(env)
        return
    end

    ---------------------------------------------------
    -- ② 中文自动造词
    ---------------------------------------------------
    if not env.memory then
        clear_comment_cache(env)
        return
    end

    -- 基础检查
    if segments_count <= 1 or utf8.len(commit_text) <= 1 then
        clear_comment_cache(env)
        return
    end
    if not AP.is_chinese_only(commit_text) or comment_cache[commit_text] then
        clear_comment_cache(env)
        return
    end

    local code_table = {}
    local config = env.engine.schema.config
    local delimiter = config:get_string("speller/delimiter") or " '"
    local escaped_delimiter = utf8.char(utf8.codepoint(delimiter)):gsub("(%W)", "%%%1")

    for i = 1, segments_count do
        local seg  = segments[i]
        local cand = seg:get_selected_candidate()

        -- 无候选：可能是符号段
        if not cand then
            if i == segments_count then
                -- 最后一个 segment 无候选，允许跳过
                goto continue
            else
                clear_comment_cache(env)
                return
            end
        end

        -- 从缓存中取出该候选的注释（编码）
        local comment = comment_cache[cand.text]

        -- 有候选但无编码
        if not comment or comment == "" then
            if i == segments_count then
                -- 最后一个 segment 无编码，允许跳过
                goto continue
            else
                clear_comment_cache(env)
                return
            end
        end

        -- 有编码，分割加入
        for part in comment:gmatch("[^" .. escaped_delimiter .. "]+") do
            table.insert(code_table, part)
        end

        ::continue::
    end

    -- 最终至少需要一个编码片段
    if #code_table == 0 then
        clear_comment_cache(env)
        return
    end

    -- 检查编码片段数量是否与 commit_text 的字数一致
    local total_chars = utf8.len(commit_text)
    if #code_table ~= total_chars then
        clear_comment_cache(env)
        return
    end

    local dictEntry = DictEntry()
    dictEntry.text        = commit_text
    dictEntry.weight      = 1
    dictEntry.custom_code = table.concat(code_table, " ") .. " "
    env.memory:update_userdict(dictEntry, 1, "")
    clear_comment_cache(env)
end

return AP