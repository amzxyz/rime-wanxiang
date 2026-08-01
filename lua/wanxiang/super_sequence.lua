-- 万象拼音 · 手动自由排序
-- 核心规则：向前移动 = "Control+j"，向后移动 = "Control+k"，重置 = "Control+l"，置顶 = "Control+p"
--
-- v2 稳定 UserDb 格式：
-- 1) raw key = 输入编码 + 候选词，同一候选始终使用同一个同步键
-- 2) c 高位保存候选自己的逻辑版本，低位保存最终位置
-- 3) d 固定写 0；t 交给 librime，不参与业务排序
-- 4) 只保存主动操作的候选；普通候选被动让位时不创建记录
-- 5) 已经手动排序过的候选若再次被挤动，只更新它自己的最终位置
-- 6) c<0 为重置墓碑；墓碑版本高于旧状态，可通过原生 UserDb 同步传播
-- 7) 旧数据迁移由独立的 migrate_sequence_v4.py 完成，运行时不扫描旧文件

-- ✨ 是给上一层滤镜传递排序上下文信息的代码，不用时便于删除
local wanxiang = require("wanxiang/wanxiang")
local userdb   = require("wanxiang/userdb")

------------------------------------------------------------
-- 一、常量与键位
------------------------------------------------------------
local DEFAULT_SEQ_KEY = {
    up = "Control+j",
    down = "Control+k",
    reset = "Control+l",
    pin = "Control+p",
}

local MAX_SORT_CANDIDATES = 500
local POSITION_BASE = 512
local TOMBSTONE_SLOT = 511
local C_MAX = 2147483000
local MAX_VERSION = math.floor((C_MAX - TOMBSTONE_SLOT) / POSITION_BASE)

local RECORD_SEPARATOR = " \t"


-- ✨ 全局通信通道
_G.WanxiangSharedState = _G.WanxiangSharedState or {
    sorter_active = false,
    last_input = "",
    page_cache = {},
}

-- ✨ 防崩溃的候选词克隆函数
local function clone_candidate(c)
    local nc = Candidate(c.type, c.start, c._end, c.text, c.comment or "")
    nc.preedit = c.preedit
    return nc
end

------------------------------------------------------------
-- 三、UserDb 记录格式
------------------------------------------------------------
local function to_integer(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        value = 0
    end

    value = value < 0 and math.ceil(value) or math.floor(value)
    if minimum and value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return value
end

local function parse_record_tail(tail)
    if type(tail) ~= "string" then return 0, 0, false end

    local commits, dee, tick = tail:match(
        "^c=([^%s\t]+) d=([^%s\t]+) t=([^%s\t]+)$"
    )
    commits, dee, tick = tonumber(commits), tonumber(dee), tonumber(tick)

    if not commits or commits ~= math.floor(commits)
        or not dee or dee ~= dee
        or not tick or tick < 0 or tick ~= math.floor(tick)
    then
        return 0, 0, false
    end

    return to_integer(commits, -C_MAX, C_MAX), to_integer(tick, 0), true
end

local function make_record_tail(commits, tick)
    commits = to_integer(commits, -C_MAX, C_MAX)
    tick = to_integer(tick, 0)

    -- UserDb 标准尾巴：c、d、t，字段间仅一个空格。
    return string.format("c=%d d=0 t=%d", commits, tick)
end

local function make_raw_key(input, item)
    if not input or input == "" or not item or item == "" then return nil end
    return input .. RECORD_SEPARATOR .. item
end

local function parse_raw_key(raw_key)
    if type(raw_key) ~= "string" then return nil, nil end

    local split_pos = raw_key:find(RECORD_SEPARATOR, 1, true)
    if not split_pos then return nil, nil end

    local input = raw_key:sub(1, split_pos - 1)
    local item = raw_key:sub(split_pos + #RECORD_SEPARATOR)
    if input == "" or item == "" then return nil, nil end
    return input, item
end

local function decode_state(commits)
    commits = tonumber(commits) or 0
    if commits == 0 then return 0, nil, false end

    local magnitude = math.abs(commits)
    local version = math.floor(magnitude / POSITION_BASE)
    local slot = magnitude % POSITION_BASE

    if commits < 0 then return version, nil, false end
    if slot < 1 or slot > MAX_SORT_CANDIDATES then return version, nil, false end

    local position = MAX_SORT_CANDIDATES + 1 - slot
    return version, position, true
end

local function next_version(commits)
    local magnitude = math.abs(tonumber(commits) or 0)
    local version = math.floor(magnitude / POSITION_BASE)

    if version >= MAX_VERSION then return MAX_VERSION end
    return version + 1
end

local function encode_active(version, position)
    version = math.max(1, math.min(MAX_VERSION, tonumber(version) or 1))
    position = math.max(1, math.min(MAX_SORT_CANDIDATES, tonumber(position) or 1))

    local slot = MAX_SORT_CANDIDATES + 1 - position
    return version * POSITION_BASE + slot
end

local function encode_tombstone(version)
    version = math.max(1, math.min(MAX_VERSION, tonumber(version) or 1))
    return -(version * POSITION_BASE + TOMBSTONE_SLOT)
end

------------------------------------------------------------
-- 四、DB、缓存与旧数据迁移
------------------------------------------------------------
local seq_db = nil
local seq_db_refs = 0
local RECORD_CACHE_LIMIT = 128
local record_cache = {}
local record_cache_size = 0
local record_cache_clock = 0

local function resolve_db_name(config)
    local db_name = config and config:get_string("super_sequence/db_name") or nil
    if not db_name or db_name == "" then return "lua/sequence" end

    db_name = db_name:gsub("\\", "/"):gsub("^/+", "")
    while db_name:match("%.%./") do db_name = db_name:gsub("%.%./", "") end
    db_name = db_name:gsub("%./", "")
    return db_name ~= "" and db_name or "lua/sequence"
end

local function ensure_sequence_db(config)
    if not seq_db then
        seq_db = userdb.LevelDb(resolve_db_name(config))
    end

    if not seq_db:loaded() and not seq_db:open() then
        seq_db = nil
        return nil
    end

    return seq_db
end

local function acquire_sequence_db(env, config)
    if env.sequence_db_attached then return seq_db end

    local db = ensure_sequence_db(config)
    if not db then return nil end

    env.sequence_db_attached = true
    seq_db_refs = seq_db_refs + 1
    return db
end

local function release_sequence_db(env)
    if not env or not env.sequence_db_attached then return end

    env.sequence_db_attached = nil
    seq_db_refs = math.max(0, seq_db_refs - 1)
    if seq_db_refs > 0 then return end

    record_cache = {}
    record_cache_size = 0
    record_cache_clock = 0

    local db = seq_db
    seq_db = nil

    collectgarbage()
    if db and db:loaded() then db:close() end
end

local function invalidate_input_cache(input)
    if input then
        if record_cache[input] then
            record_cache[input] = nil
            record_cache_size = math.max(0, record_cache_size - 1)
        end
    else
        record_cache = {}
        record_cache_size = 0
        record_cache_clock = 0
    end
end

local function touch_cached_entry(cached)
    record_cache_clock = record_cache_clock + 1
    cached.last_used = record_cache_clock
end

local function trim_record_cache()
    if record_cache_size <= RECORD_CACHE_LIMIT then return end

    local oldest_input = nil
    local oldest_clock = math.huge

    for input, cached in pairs(record_cache) do
        local last_used = cached.last_used or 0
        if last_used < oldest_clock then
            oldest_input = input
            oldest_clock = last_used
        end
    end

    if oldest_input then
        record_cache[oldest_input] = nil
        record_cache_size = math.max(0, record_cache_size - 1)
    end
end

local function load_input_records(input)
    if not input or input == "" or not seq_db then return {}, false end

    local cached = record_cache[input]
    if cached then
        touch_cached_entry(cached)
        return cached.records, cached.has_active
    end

    local records = {}
    local has_active = false
    local prefix = input .. RECORD_SEPARATOR
    local accessor = seq_db:query(prefix)

    if accessor then
        for raw_key, tail in accessor:iter() do
            if raw_key:sub(1, #prefix) ~= prefix then break end

            local record_input, item = parse_raw_key(raw_key)
            if record_input ~= input then break end

            -- 旧格式 value 会以 i=... 开头；它已经迁移并写成墓碑，
            -- 不再进入新的候选位置表。
            if item and item ~= "" and not item:match("^i=.- p=") then
                local commits, tick = parse_record_tail(tail)
                local version, position, active = decode_state(commits)

                records[item] = {
                    commits = commits,
                    tick = tick,
                    tail = tail,
                    version = version,
                    position = position,
                    active = active,
                }

                if active then has_active = true end
            end
        end

        accessor = nil
    end

    cached = {
        records = records,
        has_active = has_active,
    }
    touch_cached_entry(cached)

    record_cache[input] = cached
    record_cache_size = record_cache_size + 1
    trim_record_cache()

    return records, has_active
end

local function update_cached_record(input, item, commits, tick, tail)
    local cached = record_cache[input]
    if not cached then return end

    touch_cached_entry(cached)
    local version, position, active = decode_state(commits)

    cached.records[item] = {
        commits = commits,
        tick = tick,
        tail = tail,
        version = version,
        position = position,
        active = active,
    }

    cached.has_active = false
    for _, record in pairs(cached.records) do
        if record.active then
            cached.has_active = true
            break
        end
    end
end

local function write_active_position(input, item, position, records)
    local record = records[item]
    local current = record and record.commits or 0
    local tick = record and record.tick or 0
    local version = next_version(current)
    local commits = encode_active(version, position)
    local raw_key = make_raw_key(input, item)

    if not raw_key then return false end

    local tail = make_record_tail(commits, tick)
    if not tail or not seq_db:update(raw_key, tail) then return false end

    update_cached_record(input, item, commits, tick, tail)
    records[item] = record_cache[input]
        and record_cache[input].records[item]
        or {
            commits = commits,
            tick = tick,
            tail = tail,
            version = version,
            position = position,
            active = true,
        }

    return true
end

local function write_reset_tombstone(input, item, records)
    local record = records[item]
    if not record or not record.active then return true end

    local version = next_version(record.commits)
    local commits = encode_tombstone(version)
    local raw_key = make_raw_key(input, item)
    if not raw_key then return false end

    local tail = make_record_tail(commits, record.tick)
    if not tail or not seq_db:update(raw_key, tail) then return false end

    update_cached_record(input, item, commits, record.tick, tail)
    records[item] = record_cache[input]
        and record_cache[input].records[item]
        or {
            commits = commits,
            tick = record.tick,
            tail = tail,
            version = version,
            position = nil,
            active = false,
        }

    return true
end

------------------------------------------------------------
-- 五、排序状态
------------------------------------------------------------
local seq_property = { ADJUST_KEY = "sequence_adjustment_code" }

function seq_property.get(context)
    return context:get_property(seq_property.ADJUST_KEY)
end

function seq_property.reset(context)
    local code = seq_property.get(context)
    if code ~= nil and code ~= "" then
        context:set_property(seq_property.ADJUST_KEY, "")
    end
end

local curr_state = {}
curr_state.ADJUST_MODE = {
    None = -1,
    Reset = 0,
    Pin = 1,
    Adjust = 2,
}

curr_state.default = {
    selected_phrase = nil,
    offset = 0,
    mode = curr_state.ADJUST_MODE.None,
    highlight_index = nil,
    adjust_code = nil,
    adjust_key = nil,
    dirty = false,
}

function curr_state.reset()
    if curr_state.mode == curr_state.ADJUST_MODE.None then return end
    for key, value in pairs(curr_state.default) do curr_state[key] = value end
end

function curr_state.is_pin_mode()
    return curr_state.mode == curr_state.ADJUST_MODE.Pin
end

function curr_state.is_reset_mode()
    return curr_state.mode == curr_state.ADJUST_MODE.Reset
end

function curr_state.is_adjust_mode()
    return curr_state.mode == curr_state.ADJUST_MODE.Adjust
end

function curr_state.has_adjustment()
    return curr_state.mode ~= curr_state.ADJUST_MODE.None
end

------------------------------------------------------------
-- 六、稳定位置重建
------------------------------------------------------------
local function apply_saved_positions(entries, records)
    local count = #entries
    if count == 0 then return entries end

    local fixed = {}
    local placed = {}
    local slots = {}

    for _, entry in ipairs(entries) do
        local record = records[entry.sort_key]

        if record and record.active and record.position then
            fixed[#fixed + 1] = {
                entry = entry,
                position = math.max(1, math.min(count, record.position)),
                version = record.version or 0,
                magnitude = math.abs(record.commits or 0),
            }
        end
    end

    table.sort(fixed, function(a, b)
        if a.position ~= b.position then return a.position < b.position end
        if a.version ~= b.version then return a.version > b.version end
        if a.magnitude ~= b.magnitude then return a.magnitude > b.magnitude end
        return tostring(a.entry.sort_key) < tostring(b.entry.sort_key)
    end)

    local function find_free_slot(target)
        for position = target, count do
            if not slots[position] then return position end
        end

        for position = target - 1, 1, -1 do
            if not slots[position] then return position end
        end

        return nil
    end

    for _, fixed_entry in ipairs(fixed) do
        local slot = find_free_slot(fixed_entry.position)

        if slot then
            slots[slot] = fixed_entry.entry
            placed[fixed_entry.entry] = true
        end
    end

    local raw_index = 1

    for position = 1, count do
        if not slots[position] then
            while entries[raw_index] and placed[entries[raw_index]] do
                raw_index = raw_index + 1
            end

            slots[position] = entries[raw_index]
            if entries[raw_index] then placed[entries[raw_index]] = true end
            raw_index = raw_index + 1
        end
    end

    for position, entry in ipairs(slots) do
        entry.final_position = position
    end

    return slots
end

local function persist_entry_position(input, entry, position, records)
    if position == entry.raw_position then
        return write_reset_tombstone(input, entry.sort_key, records)
    end

    local record = records[entry.sort_key]

    if record and record.active and record.position == position then
        return true
    end

    return write_active_position(input, entry.sort_key, position, records)
end

local function apply_current_adjustment(input, entries, records)
    if not curr_state.has_adjustment() or not curr_state.dirty then return end

    local from_position
    local active_before = {}

    -- 只记住操作前已经存在的手动排序记录。普通候选即使被挤动，
    -- 也不会因此被写入数据库。
    for item, record in pairs(records) do
        if record.active then active_before[item] = true end
    end

    for position, entry in ipairs(entries) do
        if entry.cand.text == curr_state.selected_phrase then
            from_position = position
            curr_state.adjust_code = input
            curr_state.adjust_key = entry.sort_key
            break
        end
    end

    if not from_position then
        curr_state.dirty = false
        return
    end

    local selected = entries[from_position]
    local selected_key = selected.sort_key
    local to_position = from_position

    if curr_state.is_adjust_mode() then
        to_position = math.max(
            1,
            math.min(#entries, from_position + curr_state.offset)
        )
    elseif curr_state.is_pin_mode() then
        to_position = 1
    elseif curr_state.is_reset_mode() then
        to_position = math.max(
            1,
            math.min(#entries, selected.raw_position)
        )
    end

    local moved = from_position ~= to_position

    if moved then
        local candidate = table.remove(entries, from_position)
        table.insert(entries, to_position, candidate)
    end

    for position, entry in ipairs(entries) do
        entry.final_position = position
    end

    if curr_state.is_reset_mode() then
        -- 重置只删除当前候选的手动状态。
        write_reset_tombstone(input, selected_key, records)
    elseif curr_state.is_pin_mode() or moved then
        -- 主动操作的候选必须保存；置顶即使当前已经在第一位，也要
        -- 保存“保持第一位”的明确意图。
        persist_entry_position(
            input,
            selected,
            to_position,
            records
        )
    end

    if moved then
        -- 仅修正此前就有手动记录、这次又被当前操作挤动的候选。
        -- 从未主动排序过的普通候选只在内存中自然让位，不落库。
        for position, entry in ipairs(entries) do
            local key = entry.sort_key

            if key ~= selected_key and active_before[key] then
                persist_entry_position(
                    input,
                    entry,
                    position,
                    records
                )
            end
        end
    end

    curr_state.highlight_index = to_position - 1
    curr_state.dirty = false
end

------------------------------------------------------------
-- 七、Processor（含 Ctrl 标记）
------------------------------------------------------------
local P = {}

function P.init(env)
    local config = env.engine.schema.config
    env.seq_keys = {
        up = config:get_string("super_sequence/up") or DEFAULT_SEQ_KEY.up,
        down = config:get_string("super_sequence/down") or DEFAULT_SEQ_KEY.down,
        reset = config:get_string("super_sequence/reset") or DEFAULT_SEQ_KEY.reset,
        pin = config:get_string("super_sequence/pin") or DEFAULT_SEQ_KEY.pin,
    }

    acquire_sequence_db(env, config)
end

function P.fini(env)
    env.seq_keys = nil
    release_sequence_db(env)
end

local function process_adjustment(context)
    local candidate = context:get_selected_candidate()
    curr_state.selected_phrase = candidate and candidate.text or nil
    context:refresh_non_confirmed_composition()

    if context.highlight
        and curr_state.highlight_index
        and curr_state.highlight_index >= 0
    then
        context:highlight(curr_state.highlight_index)
    end
end

local function is_single_lowercase_letter(text)
    return type(text) == "string"
        and #text == 1
        and text:match("^[a-z]$") ~= nil
end

function P.func(key_event, env)
    local context = env.engine.context
    local code = key_event.keycode
    local key_repr = key_event:repr()
    local seq_keys = env.seq_keys or DEFAULT_SEQ_KEY
    local up = seq_keys.up
    local down = seq_keys.down
    local reset = seq_keys.reset
    local pin = seq_keys.pin
    local is_ctrl_key = code == 0xffe3 or code == 0xffe4

    -- Ctrl 监听，用于开关可视化标记。
    if is_ctrl_key then
        if context.composition:empty() then
            return wanxiang.RIME_PROCESS_RESULTS.kNoop
        end

        local current = context:get_option("_seq_show_markers")
        local target = not key_event:release()

        if current ~= target then
            local segment = context.composition:back()
            curr_state.highlight_index = segment.selected_index
            context:set_option("_seq_show_markers", target)
            process_adjustment(context)
        end

        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    curr_state.reset()

    local selected_candidate = context:get_selected_candidate()

    if not context:has_menu()
        or not selected_candidate
        or not selected_candidate.text
    then
        if context:get_option("_seq_show_markers") then
            context:set_option("_seq_show_markers", false)
        end

        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    local function get_adjust_code()
        if wanxiang.is_function_mode_active(context) then
            local value = seq_property.get(context)
            if value and value ~= "" then return value end
            return nil
        end

        return context.input:sub(1, context.caret_pos)
    end

    local adjust_code = get_adjust_code()

    if not wanxiang.is_function_mode_active(context)
        and is_single_lowercase_letter(adjust_code)
    then
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    if key_repr == up then
        curr_state.offset = -1
        curr_state.mode = curr_state.ADJUST_MODE.Adjust
    elseif key_repr == down then
        curr_state.offset = 1
        curr_state.mode = curr_state.ADJUST_MODE.Adjust
    elseif key_repr == reset then
        curr_state.offset = nil
        curr_state.mode = curr_state.ADJUST_MODE.Reset
    elseif key_repr == pin then
        curr_state.offset = nil
        curr_state.mode = curr_state.ADJUST_MODE.Pin
    else
        if context:get_option("_seq_show_markers") then
            context:set_option("_seq_show_markers", false)
            process_adjustment(context)
        end

        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

    -- 排序动作前刷新当前编码缓存，确保读取到最近一次原生同步结果。
    invalidate_input_cache(adjust_code)
    curr_state.dirty = true
    process_adjustment(context)
    return wanxiang.RIME_PROCESS_RESULTS.kAccepted
end

------------------------------------------------------------
-- 八、Filter（含标记可视化）
------------------------------------------------------------
local F = {}

function F.init(env)
    local config = env.engine.schema.config
    local symbol = config and (
        config:get_string("paired_symbols/symbol")
        or config:get_string("paired_symbols/trigger")
    ) or "\\"

    env.symbol = string.sub(symbol, 1, 1)
    env.page_size = config and config:get_int("menu/page_size") or 5
end

local function extract_adjustment_code(context)
    if wanxiang.is_function_mode_active(context) then
        local code = seq_property.get(context)
        if code and code ~= "" then return code end
        return nil
    end

    return context.input:sub(1, context.caret_pos)
end

function F.func(input, env)
    -- ✨ 宣告：排序脚本活着，包裹脚本不要自行处理。
    _G.WanxiangSharedState.sorter_active = true

    local context = env.engine.context
    local code = context.input
    local symbol = env.symbol or "\\"
    local has_symbol = code
        and string.find(code, symbol, 1, true) ~= nil

    if not has_symbol then
        _G.WanxiangSharedState.last_input = code
        _G.WanxiangSharedState.page_cache = {}
    end

    local cache_limit = (env.page_size or 5) * 2

    local function original_list()
        local top_count = 0

        for candidate in input:iter() do
            if not has_symbol and top_count < cache_limit then
                _G.WanxiangSharedState.page_cache[#_G.WanxiangSharedState.page_cache + 1] =
                    clone_candidate(candidate)
                top_count = top_count + 1
            end

            yield(candidate)
        end
    end

    local adjustment_allowed = not (
        wanxiang.is_function_mode_active(context)
        and seq_property.get(context) == nil
    )

    if not adjustment_allowed then return original_list() end

    local adjust_code = extract_adjustment_code(context)
    if not adjust_code or adjust_code == "" then return original_list() end

    local records, has_active = load_input_records(adjust_code)
    local has_current_action =
        curr_state.has_adjustment() and curr_state.dirty

    if not has_active and not has_current_action then
        return original_list()
    end

    local entries = {}
    local seen = {}
    local is_function_mode = wanxiang.is_function_mode_active(context)
    local show_markers = context:get_option("_seq_show_markers")
    local iterator, iterator_state, iterator_control = input:iter()

    local function next_candidate()
        local candidate = iterator(iterator_state, iterator_control)
        iterator_control = candidate
        return candidate
    end

    local raw_position = 0
    local scanned = 0

    while scanned < MAX_SORT_CANDIDATES do
        local candidate = next_candidate()
        if not candidate then break end

        scanned = scanned + 1

        local phrase =
            candidate.text:match("^%s*(.-)%s*$")
            or candidate.text

        if not seen[phrase] then
            seen[phrase] = true
            raw_position = raw_position + 1

            entries[#entries + 1] = {
                cand = candidate,
                phrase = phrase,
                sort_key = is_function_mode
                    and tostring(raw_position - 1)
                    or phrase,
                raw_position = raw_position,
                final_position = raw_position,
            }
        end
    end

    local ordered = apply_saved_positions(entries, records)
    apply_current_adjustment(adjust_code, ordered, records)

    local bottom_count = 0

    for position, entry in ipairs(ordered) do
        entry.final_position = position
        local candidate = entry.cand

        if show_markers and not is_function_mode then
            local record = records[entry.sort_key]

            if record and record.active then
                local diff = position - entry.raw_position
                local mark

                if diff > 0 then
                    mark = "+" .. diff
                elseif diff < 0 then
                    mark = tostring(diff)
                else
                    mark = " ●"
                end

                candidate.comment = (candidate.comment or "") .. mark
            end
        end

        if not has_symbol and bottom_count < cache_limit then
            _G.WanxiangSharedState.page_cache[
                #_G.WanxiangSharedState.page_cache + 1
            ] = clone_candidate(candidate)
            bottom_count = bottom_count + 1
        end

        yield(candidate)
    end

    -- 第 501 个及之后的候选不参与排序，保持上游顺序继续惰性透传。
    while true do
        local candidate = next_candidate()
        if not candidate then break end

        local phrase =
            candidate.text:match("^%s*(.-)%s*$")
            or candidate.text

        if not seen[phrase] then
            seen[phrase] = true

            if not has_symbol and bottom_count < cache_limit then
                _G.WanxiangSharedState.page_cache[
                    #_G.WanxiangSharedState.page_cache + 1
                ] = clone_candidate(candidate)
                bottom_count = bottom_count + 1
            end

            yield(candidate)
        end
    end
end

return { P = P, F = F }