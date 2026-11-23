local wanxiang = require("wanxiang/wanxiang")

local function read_file(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end

    local content, read_err = f:read("*a")
    local closed, close_err = f:close()
    if not content then return nil, read_err end
    if not closed then return nil, close_err end
    return content
end

local function write_file(path, content)
    local f, err = io.open(path, "wb")
    if not f then return false, err end

    local written, write_err = f:write(content)
    local closed, close_err = f:close()
    if not written or not closed then return false, write_err or close_err end
    return true
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function get_scheme_info(env)
    local schema_id = env.engine.schema.schema_id or ""

    if schema_id == "wanxiang_pro" then
        return "pro", "wanxiang_pro.custom.yaml"
    elseif schema_id == "wanxiang_lite" then
        return "lite", "wanxiang_lite.custom.yaml"
    elseif schema_id == "wanxiang" then
        return "base", "wanxiang.custom.yaml"
    end

    return nil, nil
end

local schema_map = {
    ["/flypy"]   = "小鹤双拼",
    ["/mspy"]    = "微软双拼",
    ["/zrm"]     = "自然码",
    ["/sogou"]   = "搜狗双拼",
    ["/znabc"]   = "智能ABC",
    ["/ziguang"] = "紫光双拼",
    ["/pyjj"]    = "拼音加加",
    ["/gbpy"]    = "国标双拼",
    ["/lxsq"]    = "乱序17",
    ["/ltsp"]    = "蓝天双拼",
    ["/zrlong"]  = "自然龙",
    ["/hxlong"]  = "汉心龙",
    ["/pinyin"]  = "全拼",
    ["/sdpy"]    = "首道双拼",
    ["/dnsp"]    = "大牛双拼",
    ["/wxsp"]    = "万象双拼",
}

local tone_required_schema = {
    ["万象双拼"] = true,
    ["自然龙"] = true,
    ["汉心龙"] = true,
}

local function is_schema_name(name)
    for _, value in pairs(schema_map) do
        if name == value then return true end
    end
    return false
end

-- 在内存中完成替换；不触碰磁盘，也不改动不认识的 algebra 规则。
local function replace_schema_content(content, target_schema)
    local matched = 0
    local updated = content:gsub(
        "(wanxiang_algebra:/[^/]+/)([^%s#]+)",
        function(prefix, name)
            if is_schema_name(name) then
                matched = matched + 1
                return prefix .. target_schema
            end
            return prefix .. name
        end
    )
    return updated, matched
end

-- source_path 为 nil 时修改现有文件；有值时从模板生成新文件。
-- 返回 changed / created / unchanged / no_rule，失败时返回 nil 和原因。
local function update_schema_file(dest, source_path, target_schema, require_rule)
    local content, err = read_file(source_path or dest)
    if not content then return nil, "读取失败：" .. tostring(err) end

    local updated, matched = replace_schema_content(content, target_schema)
    if require_rule and matched == 0 then
        return nil, "主配置未找到可切换的输入方案规则"
    end
    if not source_path and updated == content then
        return matched > 0 and "unchanged" or "no_rule"
    end

    local ok, write_err = write_file(dest, updated)
    if not ok then return nil, "写入失败：" .. tostring(write_err) end
    return source_path and "created" or "changed"
end

local function replace_aux_content(content, target_aux)
    local matched = 0
    local updated = content:gsub(
        "(%-+%s*wanxiang_algebra:/[%w_]+/)([^%s#]+)",
        function(prefix, name)
            if name == "直接辅助" or name == "间接辅助" then
                matched = matched + 1
                return prefix .. target_aux
            end
            return prefix .. name
        end
    )
    return updated, matched
end

local function emit(seg, message)
    yield(Candidate("switch", seg.start, seg._end, message, ""))
end

local function translator(input, seg, env)
    local profile, main_file = get_scheme_info(env)
    if not profile then return end

    if input == "/zjf" or input == "/jjf" then
        if profile == "lite" or profile == "base" then
            emit(seg, "当前方案不支持辅助码")
            return
        end

        local target_aux = input == "/zjf" and "直接辅助" or "间接辅助"
        local p = rime_api.get_user_data_dir() .. "/" .. main_file
        if not file_exists(p) then
            emit(seg, "未找到当前配置，请先切换双拼方案")
            return
        end

        local content, read_err = read_file(p)
        if not content then
            emit(seg, "读取配置失败：" .. tostring(read_err))
            return
        end

        local updated, matched = replace_aux_content(content, target_aux)
        if matched == 0 then
            emit(seg, "当前配置未找到可切换的辅助码条目")
        elseif updated == content then
            emit(seg, "当前已是〔" .. target_aux .. "〕，无需重新部署")
        else
            local ok, write_err = write_file(p, updated)
            if not ok then
                emit(seg, "切换失败，写入配置出错：" .. tostring(write_err))
            else
                emit(seg, "当前方案已切换到〔" .. target_aux .. "〕，请重新部署")
            end
        end
        return
    end

    local target_schema = schema_map[input]
    if not target_schema then return end

    if profile == "lite" and tone_required_schema[target_schema] then
        emit(seg, "Lite 词库不含声调，不支持〔" .. target_schema .. "〕")
        return
    end

    local user_dir = rime_api.get_user_data_dir()
    local shared_dir = rime_api.get_shared_data_dir()

    -- 主文件必须具备可切换规则；先处理主文件，避免主文件有误时先改动关联配置。
    local files = {
        main_file,
        "wanxiang_mixedcode.custom.yaml",
        "wanxiang_reverse.custom.yaml",
        "wanxiang_abbrev.custom.yaml",
        "wanxiang_phrase.custom.yaml",
    }

    local changed = 0
    local errors = {}
    local main_ok = false
    for _, name in ipairs(files) do
        local dest = user_dir .. "/" .. name
        local user_src = user_dir .. "/custom/" .. name
        local shared_src = shared_dir .. "/custom/" .. name
        local source_path = nil
        local status, err

        if file_exists(dest) then
            status, err = update_schema_file(dest, nil, target_schema, name == main_file)
        else
            if file_exists(user_src) then
                source_path = user_src
            elseif file_exists(shared_src) then
                source_path = shared_src
            end
            if source_path then
                status, err = update_schema_file(dest, source_path, target_schema, name == main_file)
            elseif name == main_file then
                err = "未找到主配置及其模板"
            end
        end

        if err then
            errors[#errors + 1] = name .. "（" .. err .. "）"
            if name == main_file then break end
        elseif status then
            if name == main_file then main_ok = true end
            if status == "changed" or status == "created" then
                changed = changed + 1
            end
        end
    end

    if not main_ok then
        emit(seg, "切换失败：" .. table.concat(errors, "；"))
    elseif #errors > 0 then
        emit(seg, "切换未全部完成，已更改 " .. changed .. " 个文件；失败：" .. table.concat(errors, "；"))
    elseif changed == 0 then
        emit(seg, "当前已是〔" .. target_schema .. "〕，配置无需修改或重新部署")
    else
        emit(seg, "已切换到〔" .. target_schema .. "〕，共更新或创建 " .. changed .. " 个文件，请手动重新部署")
    end
end

return translator
