local wanxiang = require("wanxiang/wanxiang")

local function copy_file(src, dest)
    local fi = io.open(src, "rb")
    if not fi then
        return false
    end

    local content = fi:read("*a")
    fi:close()

    local fo = io.open(dest, "wb")
    if not fo then
        return false
    end

    fo:write(content)
    fo:close()
    return true
end

local function file_exists(path)
    local f = io.open(path, "r")
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
    }

local function is_schema_name(name)

    for _, value in pairs(schema_map) do

        if name == value then
            return true
        end

    end

    return false
end

local function replace_schema(file_path, target_schema)
    local f = io.open(file_path, "r")
    if not f then
        return false
    end

    local content = f:read("*a")
    f:close()

    content = content:gsub(
        "(wanxiang_algebra:/[^/]+/)([^%s#]+)",
        function(prefix, name)
            if is_schema_name(name) then
                return prefix .. target_schema
            end

            return prefix .. name
        end
    )

    f = io.open(file_path, "w")
    if not f then
        return false
    end

    f:write(content)
    f:close()
    return true
end

local function translator(input, seg, env)
    local profile, main_file = get_scheme_info(env)
    if not profile then
        return
    end

    if input == "/zjf" or input == "/jjf" then
        if profile == "lite" then
            yield(Candidate("switch", seg.start, seg._end, "Lite 方案不使用辅助码，无需切换", ""))
            return
        end

        local target_aux

        if input == "/zjf" then
            target_aux = "直接辅助"
        else
            target_aux = "间接辅助"
        end

        local user_dir = rime_api.get_user_data_dir()
        local p = user_dir .. "/" .. main_file

        if file_exists(p) then
            local f = io.open(p, "r")
            local content = f:read("*a")
            f:close()

            local n1, n2 = 0, 0
            content, n1 = content:gsub(
                "(%-+%s*wanxiang_algebra:/[%w_]+/)直接辅助(%s*#?.*)",
                "%1" .. target_aux .. "%2"
            )
            content, n2 = content:gsub(
                "(%-+%s*wanxiang_algebra:/[%w_]+/)间接辅助(%s*#?.*)",
                "%1" .. target_aux .. "%2"
            )

            if (n1 + n2) > 0 then
                local w = io.open(p, "w")
                if w then
                    w:write(content)
                    w:close()
                end
                local msg = "当前方案已切换到〔" .. target_aux .. "〕，请重新部署"
                yield(Candidate("switch", seg.start, seg._end, msg, ""))
            else
                yield(Candidate("switch", seg.start, seg._end, "当前配置未找到可切换的条目", ""))
            end
        else
            yield(Candidate("switch", seg.start, seg._end, "未找到当前配置，请先切换双拼方案", ""))
        end
        return
    end

    local target_schema = schema_map[input]
    if not target_schema then
        return
    end

    local user_dir = rime_api.get_user_data_dir()
    local shared_dir = rime_api.get_shared_data_dir()
    local dest_main = user_dir .. "/" .. main_file
    local main_exists = file_exists(dest_main)

    local files = {
        "wanxiang_mixedcode.custom.yaml",
        "wanxiang_reverse.custom.yaml",
        "wanxiang_english.custom.yaml",
        "wanxiang_abbrev.custom.yaml",
        "wanxiang_phrase.custom.yaml",
        main_file,
    }

    for _, name in ipairs(files) do
        local dest       = user_dir .. "/" .. name
        local user_src   = user_dir .. "/custom/" .. name
        local shared_src = shared_dir .. "/custom/" .. name

        if file_exists(dest) then
            -- 1. 外部已存在：只改，绝不复制覆盖
            replace_schema(dest, target_schema)
        elseif file_exists(user_src) then
            -- 2. 用户自己放在 custom 里的模板优先
            if copy_file(user_src, dest) then
                replace_schema(dest, target_schema)
            end
        elseif file_exists(shared_src) then
            -- 3. 系统自带模板兜底
            if copy_file(shared_src, dest) then
                replace_schema(dest, target_schema)
            end
        end
    end

    local msg

    if main_exists then
        msg = "检测到专属配置，已切换到〔" .. target_schema .. "〕，请手动重新部署"
    else
        msg = "已从系统目录构建配置并切换到〔" .. target_schema .. "〕，请手动重新部署"
    end

    yield(Candidate("switch", seg.start, seg._end, msg, ""))
end
return translator