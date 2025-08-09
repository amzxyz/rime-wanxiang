local wanxiang = require("wanxiang")

-- 文件复制函数
local function copy_file(src, dest)
    local fi = io.open(src, "r")
    if not fi then 
        return false 
    end
    local content = fi:read("*a")
    fi:close()

    local fo = io.open(dest, "w")
    if not fo then 
        return false 
    end
    fo:write(content)
    fo:close()
    return true
end

-- 替换方案函数（根据文件名应用特定替换模式）
local function replace_schema(file_path, target_schema)
    local f = io.open(file_path, "r")
    if not f then 
        return false 
    end
    local content = f:read("*a")
    f:close()

    -- 根据文件名决定替换模式
    if file_path:find("wanxiang_reverse") then
        content = content:gsub("([%s]*__include:%s*wanxiang_reverse%.schema:/)[^%sa-zA-Z\r\n]+", "%1" .. target_schema)

    elseif file_path:find("wanxiang_mixedcode") then
        content = content:gsub("([%s]*__include:%s*wanxiang_mixedcode%.schema:/)[^%sa-zA-Z\r\n]+", "%1" .. target_schema)

    elseif file_path:find("wanxiang%.custom") or file_path:find("wanxiang_pro%.custom") then
        content = content:gsub("([%s%-]*wanxiang[_]pro%.schema:/)[^%sa-zA-Z\r\n]+", "%1" .. target_schema, 1)
        content = content:gsub("([%s%-]*wanxiang%.schema:/)[^%sa-zA-Z\r\n]+", "%1" .. target_schema, 1)
    end
    
    f = io.open(file_path, "w")
    if not f then 
        return false 
    end
    f:write(content)
    f:close()
    return true
end

local function add_schema_to_default(user_dir, new_schema)
    local default_path = user_dir .. "/default.yaml"
    local f = io.open(default_path, "r")
    if not f then return false end

    local lines = {}
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()

    -- 检查是否已经有该 schema
    for _, line in ipairs(lines) do
        if line:match("^%s*%-+%s*schema:%s*" .. new_schema .. "%s*$") then
            return true -- 已存在
        end
    end
    -- 找到 schema_list: 最后一个 schema 条目位置
    local schema_list_found = false
    local insert_pos = nil
    for i, line in ipairs(lines) do
        if not schema_list_found then
            if line:match("^%s*schema_list%s*:%s*$") then
                schema_list_found = true
            end
        else
            if line:match("^%s*%-+%s*schema:%s*[%w_%-]+") then
                insert_pos = i
            elseif not line:match("^%s*#") and not line:match("^%s*$") then
                -- 遇到不是注释/空行的内容，说明 schema_list 结束
                break
            end
        end
    end
    if insert_pos then
        local indent = lines[insert_pos]:match("^(%s*)")
        table.insert(lines, insert_pos + 1, indent .. "- schema: " .. new_schema)
    else
        -- 没找到 schema_list，直接加到末尾
        table.insert(lines, "schema_list:")
        table.insert(lines, "  - schema: " .. new_schema)
    end
    -- 写回文件
    f = io.open(default_path, "w")
    if not f then return false end
    for _, line in ipairs(lines) do
        f:write(line, "\n")
    end
    f:close()
    return true
end

-- translator 主函数（增加/gongcun功能）
local function translator(input, seg, env)
    -- ===== 新增的/gongcun功能 =====
    if input == "/gongcun" then
        local user_dir = rime_api.get_user_data_dir()
        -- 步骤1: 复制文件并重命名
        local src_file = user_dir .. "/custom/wanxiang_quanpin.schema.yaml"
        local dest_file = user_dir .. "/wanxiang_quanpin.schema.yaml"
        
        if not copy_file(src_file, dest_file) then
            yield(Candidate("gongcun", seg.start, seg._end, "错误：wanxiang_quanpin.schema.yaml不存在或无法复制", ""))
            return
        end
        -- 步骤2: 在default.yaml中添加条目
        add_schema_to_default(user_dir, "wanxiang_quanpin")  -- 直接执行，不检查结果
        -- 返回提示
        yield(Candidate("gongcun", seg.start, seg._end, "已添加全拼方案，重新部署后用Ctrl+Shift+Space切换", ""))
        return
    end
    -- ===== 原有的双拼切换功能 =====
    local schema_map = {
        ["/flypy"] = "小鹤双拼",
        ["/mspy"] = "微软双拼",
        ["/zrm"] = "自然码",
        ["/sogou"] = "搜狗双拼",
        ["/abc"] = "智能ABC",
        ["/ziguang"] = "紫光双拼",
        ["/pyjj"] = "拼音加加",
        ["/gbpy"] = "国标双拼",
        ["/lxsq"] = "乱序17",
        ["/pinyin"] = "全拼"
    }

    local target_schema = schema_map[input]
    if target_schema then
        local user_dir = rime_api.get_user_data_dir()

        -- 检查根目录是否存在自定义文件
        local pro_file = user_dir .. "/wanxiang_pro.custom.yaml"
        local normal_file = user_dir .. "/wanxiang.custom.yaml"
        local pro_exists = io.open(pro_file, "r")
        local normal_exists = io.open(normal_file, "r")
        local custom_file_exists = false

        if pro_exists or normal_exists then
            custom_file_exists = true
            if pro_exists then pro_exists:close() end
            if normal_exists then normal_exists:close() end
        end

        local files = {
            "wanxiang_mixedcode.custom.yaml",
            "wanxiang_reverse.custom.yaml"
        }

        -- 判断是否为专业版
        local is_pro = wanxiang.is_pro_scheme(env)
        local fourth_file = is_pro and "wanxiang_pro.custom.yaml" or "wanxiang.custom.yaml"
        table.insert(files, fourth_file)

        for _, name in ipairs(files) do
            local src = user_dir .. "/custom/" .. name
            local dest = user_dir .. "/" .. name

            if name == fourth_file and custom_file_exists then
                -- 根目录自定义文件已存在，不复制，但依然修改
                replace_schema(dest, target_schema)
            else
                -- 其他文件: 若 custom 目录存在文件，则复制到根目录并修改
                local src_file = io.open(src, "r")
                if src_file then
                    src_file:close()
                    if copy_file(src, dest) then
                        replace_schema(dest, target_schema)
                    end
                end
            end
        end

        -- 返回提示候选
        if custom_file_exists then
            yield(Candidate("switch", seg.start, seg._end, "已有自定义文件，已切换到〔" .. target_schema .. "〕，请重新部署", ""))
        else
            yield(Candidate("switch", seg.start, seg._end, "已复制并切换到〔" .. target_schema .. "〕，请重新部署", ""))
        end
    end
end

return translator