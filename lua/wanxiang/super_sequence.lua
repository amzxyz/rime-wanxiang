-- 万象拼音 · 手动自由排序
-- 核心规则：向前移动 = "Control+j"，向后移动 = "Control+k"，重置 = "Control+l"，置顶 = "Control+p"
--
-- 1) raw key = 输入编码 + 候选词，同一候选始终使用同一个同步键
-- 2) c 高位保存候选自己的逻辑版本，低位保存最终位置
-- 3) d 固定写 0；t 交给 librime，不参与业务排序
-- 4) 只保存主动操作的候选；普通候选被动让位时不创建记录
-- 5) 已经手动排序过的候选若再次被挤动，只更新它自己的最终位置
-- 6) c<0 为重置墓碑；墓碑版本高于旧状态，可通过原生 UserDb 同步传播

local wanxiang = require("wanxiang/wanxiang")
local userdb   = require("wanxiang/userdb")
local byte     = string.byte

------------------------------------------------------------
-- 一、常量与键位
------------------------------------------------------------
local DEFAULT_SEQ_KEY = {
    up = "Control+j",
    down = "Control+k",
    reset = "Control+l",
    pin = "Control+p",
}

local MAX_SORT_CANDIDATES = 100
local DB_POSITION_LIMIT = 500
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

local function clear_array(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function yield_original_list(input, has_symbol, cache_limit, page_cache)
    local top_count = 0

    for candidate in input:iter() do
        if not has_symbol and top_count < cache_limit then
            page_cache[#page_cache + 1] = clone_candidate(candidate)
            top_count = top_count + 1
        end

        yield(candidate)
    end
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

local function decode_state(commits)
    commits = tonumber(commits) or 0
    if commits == 0 then return 0, nil, false end

    local magnitude = math.abs(commits)
    local version = math.floor(magnitude / POSITION_BASE)
    local slot = magnitude % POSITION_BASE

    if commits < 0 then return version, nil, false end
    if slot < 1 or slot > DB_POSITION_LIMIT then return version, nil, false end

    local position = DB_POSITION_LIMIT + 1 - slot
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
    position = math.max(1, math.min(DB_POSITION_LIMIT, tonumber(position) or 1))

    local slot = DB_POSITION_LIMIT + 1 - position
    return version * POSITION_BASE + slot
end

local function encode_tombstone(version)
    version = math.max(1, math.min(MAX_VERSION, tonumber(version) or 1))
    return -(version * POSITION_BASE + TOMBSTONE_SLOT)
end

------------------------------------------------------------
-- 四、DB、缓存与旧数据迁移
------------------------------------------------------------
local RECORD_CACHE_LIMIT = 128
-- 仅共享排序缓存状态；弱引用不会阻止组件退出后的状态与数据库包装器回收。
local SEQUENCE_STATES = setmetatable({}, { __mode = "v" })

local function resolve_db_name(config)
    local db_name = config and config:get_string("super_sequence/db_name") or nil
    if not db_name or db_name == "" then return "lua/sequence" end

    db_name = db_name:gsub("\\", "/"):gsub("^/+", "")
    while db_name:match("%.%./") do db_name = db_name:gsub("%.%./", "") end
    db_name = db_name:gsub("%./", "")
    return db_name ~= "" and db_name or "lua/sequence"
end

-- Processor / Filter 按 db_name 共享同一排序缓存状态。数据库包装器本身不再手工计数或关闭。
local function get_sequence_state(env, config)
    if env.sequence_state then return env.sequence_state end

    config = config or env.engine.schema.config
    local db_name = env.sequence_db_name or resolve_db_name(config)
    local state = SEQUENCE_STATES[db_name]

    if not state then
        local db = userdb.LevelDb(db_name)
        if not db or (not db:loaded() and not db:open()) then return nil end

        state = {
            db = db, cache = {},
            cache_size = 0, cache_clock = 0,
        }
        SEQUENCE_STATES[db_name] = state
    end

    env.sequence_db_name = db_name
    env.sequence_state = state
    return state
end

local function release_sequence_state(env)
    if not env then return end
    env.sequence_state = nil
    env.sequence_db_name = nil

    -- DbAccessor 没有显式析构接口。所有局部访问器先置空，再执行一次
    -- 完整垃圾回收，确保其先于所引用的 LevelDb 释放。
    collectgarbage()
end

local function invalidate_input_cache(state, input)
    if not state then return end

    if input then
        if state.cache[input] then
            state.cache[input] = nil
            state.cache_size = math.max(0, state.cache_size - 1)
        end
    else
        state.cache = {}
        state.cache_size = 0
        state.cache_clock = 0
    end
end

local function touch_cached_entry(state, cached)
    state.cache_clock = state.cache_clock + 1
    cached.last_used = state.cache_clock
end

local function trim_record_cache(state)
    if state.cache_size <= RECORD_CACHE_LIMIT then return end

    local oldest_input = nil
    local oldest_clock = math.huge

    for input, cached in pairs(state.cache) do
        local last_used = cached.last_used or 0
        if last_used < oldest_clock then
            oldest_input = input
            oldest_clock = last_used
        end
    end

    if oldest_input then
        state.cache[oldest_input] = nil
        state.cache_size = math.max(0, state.cache_size - 1)
    end
end

local function load_input_records(state, input)
    if not state or not input or input == "" then return {}, false end

    local cached = state.cache[input]
    if cached then
        touch_cached_entry(state, cached)
        return cached.records, cached.has_active
    end

    local records = {}
    local active_count = 0
    local prefix = input .. RECORD_SEPARATOR
    local prefix_len = #prefix
    local accessor = state.db:query(prefix)

    if accessor then
        for raw_key, tail in accessor:iter() do
            if raw_key:find(prefix, 1, true) ~= 1 then break end

            local item = raw_key:sub(prefix_len + 1)

            -- 旧格式 value 会以 i=... 开头；它已经迁移并写成墓碑，
            -- 不再进入新的候选位置表。
            if item and item ~= "" and not item:match("^i=.- p=") then
                local commits, tick = parse_record_tail(tail)
                local version, position, active = decode_state(commits)

                records[item] = {
                    commits = commits,
                    tick = tick,
                    version = version,
                    position = position,
                    active = active,
                }

                if active then active_count = active_count + 1 end
            end
        end

        accessor = nil
    end

    cached = {
        records = records,
        active_count = active_count,
        has_active = active_count > 0,
    }
    touch_cached_entry(state, cached)

    state.cache[input] = cached
    state.cache_size = state.cache_size + 1
    trim_record_cache(state)

    return records, active_count > 0
end

local function update_cached_record(state, input, item, commits, tick)
    local cached = state.cache[input]
    if not cached then return end

    touch_cached_entry(state, cached)
    local old_record = cached.records[item]
    local old_active = old_record and old_record.active or false
    local version, position, active = decode_state(commits)

    cached.records[item] = {
        commits = commits,
        tick = tick,
        version = version,
        position = position,
        active = active,
    }

    if old_active ~= active then
        if active then
            cached.active_count = cached.active_count + 1
        else
            cached.active_count = math.max(0, cached.active_count - 1)
        end
    end

    cached.has_active = cached.active_count > 0
end

local function write_active_position(state, input, item, position, records)
    local record = records[item]
    local current = record and record.commits or 0
    local tick = record and record.tick or 0
    local version = next_version(current)
    local commits = encode_active(version, position)
    local raw_key = make_raw_key(input, item)

    if not raw_key then return false end

    local tail = make_record_tail(commits, tick)
    if not tail or not state.db:update(raw_key, tail) then return false end

    update_cached_record(state, input, item, commits, tick)
    records[item] = state.cache[input]
        and state.cache[input].records[item]
        or {
            commits = commits,
            tick = tick,
            version = version,
            position = position,
            active = true,
        }

    return true
end

local function write_reset_tombstone(state, input, item, records)
    local record = records[item]
    if not record or not record.active then return true end

    local version = next_version(record.commits)
    local commits = encode_tombstone(version)
    local raw_key = make_raw_key(input, item)
    if not raw_key then return false end

    local tail = make_record_tail(commits, record.tick)
    if not tail or not state.db:update(raw_key, tail) then return false end

    update_cached_record(state, input, item, commits, record.tick)
    records[item] = state.cache[input]
        and state.cache[input].records[item]
        or {
            commits = commits,
            tick = record.tick,
            version = version,
            position = nil,
            active = false,
        }

    return true
end

------------------------------------------------------------
-- 五、排序状态
------------------------------------------------------------

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
        return a.entry.sort_key < b.entry.sort_key
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

local function persist_entry_position(state, input, entry, position, records)
    if position == entry.raw_position then
        return write_reset_tombstone(state, input, entry.sort_key, records)
    end

    local record = records[entry.sort_key]

    if record and record.active and record.position == position then
        return true
    end

    return write_active_position(state, input, entry.sort_key, position, records)
end

local function apply_current_adjustment(state, input, entries, records)
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

    if curr_state.is_reset_mode() then
        -- 重置只删除当前候选的手动状态。
        write_reset_tombstone(state, input, selected_key, records)
    elseif curr_state.is_pin_mode() or moved then
        -- 主动操作的候选必须保存；置顶即使当前已经在第一位，也要
        -- 保存“保持第一位”的明确意图。
        persist_entry_position(
            state,
            input,
            selected,
            to_position,
            records
        )
    end

    -- 同一轮同时更新最终位置，并在发生移动时修正此前已有手排记录的候选，
    -- 避免对 entries 再做一轮完整扫描。普通候选被动让位仍不落库。
    for position, entry in ipairs(entries) do
        entry.final_position = position

        if moved then
            local key = entry.sort_key
            if key ~= selected_key and active_before[key] then
                persist_entry_position(
                    state,
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

    get_sequence_state(env, config)
end

function P.fini(env)
    env.seq_keys = nil
    release_sequence_state(env)
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
    if type(text) ~= "string" or #text ~= 1 then return false end

    local code = byte(text, 1)
    return code >= 97 and code <= 122
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

    if wanxiang.is_function_mode(context) then
        curr_state.reset()
        return wanxiang.RIME_PROCESS_RESULTS.kNoop
    end

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

    local adjust_code = context.input:sub(1, context.caret_pos)

    if is_single_lowercase_letter(adjust_code) then
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
    invalidate_input_cache(get_sequence_state(env), adjust_code)
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
    get_sequence_state(env, config)
end

function F.fini(env)
    local shared = _G.WanxiangSharedState
    if shared then
        shared.sorter_active = false
        shared.last_input = ""
        if shared.page_cache then
            clear_array(shared.page_cache)
        end
    end

    env.symbol = nil
    env.page_size = nil
    release_sequence_state(env)
end


function F.func(input, env)
    -- ✨ 宣告：排序脚本活着，包裹脚本不要自行处理。
    local shared = _G.WanxiangSharedState
    shared.sorter_active = true

    local context = env.engine.context
    local code = context.input
    local symbol = env.symbol or "\\"
    local has_symbol = code
        and string.find(code, symbol, 1, true) ~= nil
    local page_cache = shared.page_cache

    if not has_symbol then
        shared.last_input = code
        clear_array(page_cache)
    end

    local cache_limit = (env.page_size or 5) * 2

    if wanxiang.is_function_mode(context) then
        curr_state.reset()
        return yield_original_list(input, has_symbol, cache_limit, page_cache)
    end

    local adjust_code = context.input:sub(1, context.caret_pos)
    if adjust_code == "" then
        return yield_original_list(input, has_symbol, cache_limit, page_cache)
    end

    local state = get_sequence_state(env)
    if not state then
        return yield_original_list(input, has_symbol, cache_limit, page_cache)
    end

    local records, has_active = load_input_records(state, adjust_code)
    local has_current_action =
        curr_state.has_adjustment() and curr_state.dirty

    if not has_active and not has_current_action then
        return yield_original_list(input, has_symbol, cache_limit, page_cache)
    end

    local entries = {}
    local seen = {}
    local show_markers = context:get_option("_seq_show_markers")
    local iterator, iterator_state, iterator_control = input:iter()
    local raw_position = 0
    local scanned = 0

    while scanned < MAX_SORT_CANDIDATES do
        local candidate = iterator(iterator_state, iterator_control)
        iterator_control = candidate
        if not candidate then break end

        scanned = scanned + 1

        local text = candidate.text

        if not seen[text] then
            seen[text] = true
            raw_position = raw_position + 1

            entries[#entries + 1] = {
                cand = candidate,
                phrase = text,
                sort_key = text,
                raw_position = raw_position,
                final_position = raw_position,
            }
        end
    end

    local ordered = apply_saved_positions(entries, records)
    apply_current_adjustment(state, adjust_code, ordered, records)

    local bottom_count = 0

    for position, entry in ipairs(ordered) do
        entry.final_position = position
        local candidate = entry.cand

        if show_markers then
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
            page_cache[#page_cache + 1] = clone_candidate(candidate)
            bottom_count = bottom_count + 1
        end

        yield(candidate)
    end

    -- 第 101 个及之后的候选不参与排序，保持上游顺序继续惰性透传。
    while true do
        local candidate = iterator(iterator_state, iterator_control)
        iterator_control = candidate
        if not candidate then break end

        local text = candidate.text

        if not seen[text] then
            seen[text] = true

            if not has_symbol and bottom_count < cache_limit then
                page_cache[#page_cache + 1] = clone_candidate(candidate)
                bottom_count = bottom_count + 1
            end

            yield(candidate)
        end
    end
end

return { P = P, F = F }