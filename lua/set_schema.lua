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

-- 检查文件是否存在
local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- 替换方案函数
local function replace_schema(file_path, target_schema)
    local f = io.open(file_path, "r")
    if not f then 
        return false 
    end
    local content = f:read("*a")
    f:close()

    -- 根据文件名决定替换模式
    if file_path:find("wanxiang_reverse") then
        content = content:gsub("([%s]*__include:%s*wanxiang_algebra:/reverse/)%S+", "%1" .. target_schema)
    elseif file_path:find("wanxiang_mixedcode") then
        content = content:gsub("([%s]*__patch:%s*wanxiang_algebra:/mixed/)%S+", "%1" .. target_schema)
    elseif file_path:find("wanxiang_english") then
        content = content:gsub("([%s]*__patch:%s*wanxiang_algebra:/english/)%S+", "%1" .. target_schema)
    elseif file_path:find("wanxiang%.custom") or file_path:find("wanxiang_pro%.custom") then
        content = content:gsub("([%s%-]*wanxiang_algebra:/pro/)%S+",  "%1" .. target_schema, 1)
        content = content:gsub("([%s%-]*wanxiang_algebra:/base/)%S+", "%1" .. target_schema, 1)
    end

    f = io.open(file_path, "w")
    if not f then 
        return false 
    end
    f:write(content)
    f:close()
    return true
end

-- translator 主函数
local function translator(input, seg, env)
    -- 处理直接辅助/间接辅助切换
    if input == "/zjf" or input == "/jjf" then
        local target_aux = (input == "/zjf") and "直接辅助" or "间接辅助"
        local user_dir = rime_api.get_user_data_dir()
        local paths = {
            user_dir .. "/wanxiang_pro.custom.yaml",
            user_dir .. "/wanxiang.custom.yaml",
        }

        local total_hits, touched = 0, 0
        for _, p in ipairs(paths) do
            if file_exists(p) then
                local f = io.open(p, "r")
                local content = f:read("*a")
                f:close()

                local n1, n2 = 0, 0
                content, n1 = content:gsub("(%-+%s*wanxiang_algebra:/pro/)直接辅助(%s*#?.*)", "%1" .. target_aux .. "%2")
                content, n2 = content:gsub("(%-+%s*wanxiang_algebra:/pro/)间接辅助(%s*#?.*)", "%1" .. target_aux .. "%2")
                local n = n1 + n2

                if n > 0 then
                    local w = io.open(p, "w")
                    if w then w:write(content); w:close() end
                    total_hits = total_hits + n
                    touched = touched + 1
                end
            end
        end

        local msg = (total_hits > 0)
            and ("已切换到〔" .. target_aux .. "〕，请重新部署")
            or  "未找到可切换的条目"
        yield(Candidate("switch", seg.start, seg._end, msg, ""))
        return
    end

    -- 方案映射表
    local schema_map = {
        ["/flypy"] = "小鹤双拼",
        ["/mspy"] = "微软双拼",
        ["/zrm"] = "自然码",
        ["/sogou"] = "搜狗双拼",
        ["/znabc"] = "智能ABC",
        ["/ziguang"] = "紫光双拼",
        ["/pyjj"] = "拼音加加",
        ["/gbpy"] = "国标双拼",
        ["/lxsq"] = "乱序17",
        ["/zrlong"] = "自然龙",
        ["/hxlong"] = "汉心龙",
        ["/pinyin"] = "全拼",
    }

    local target_schema = schema_map[input]
    if target_schema then
        local user_dir = rime_api.get_user_data_dir()
        -- ★ 新增：获取系统共享目录（安装目录）
        local shared_dir = rime_api.get_shared_data_dir()

        -- 检查根目录是否存在自定义文件
        local pro_file = user_dir .. "/wanxiang_pro.custom.yaml"
        local normal_file = user_dir .. "/wanxiang.custom.yaml"
        local custom_file_exists = file_exists(pro_file) or file_exists(normal_file)

        local files = {
            "wanxiang_mixedcode.custom.yaml",
            "wanxiang_reverse.custom.yaml",
            "wanxiang_english.custom.yaml"
        }

        -- 判断是否为专业版
        local is_pro = wanxiang.is_pro_scheme(env)
        local fourth_file = is_pro and "wanxiang_pro.custom.yaml" or "wanxiang.custom.yaml"
        table.insert(files, fourth_file)

        for _, name in ipairs(files) do
            -- 1. 优先尝试从 系统目录/custom/ 下寻找
            local src = shared_dir .. "/custom/" .. name
            
            -- 2. 如果系统目录没有，尝试从 用户目录/custom/ 下寻找（作为后备）
            if not file_exists(src) then
                src = user_dir .. "/custom/" .. name
            end
            
            local dest = user_dir .. "/" .. name

            if name == fourth_file and custom_file_exists then
                -- 根目录自定义文件已存在，不复制，但依然修改内容
                replace_schema(dest, target_schema)
            else
                -- 其他文件: 只有当源文件存在时才复制
                if file_exists(src) then
                    if copy_file(src, dest) then
                        replace_schema(dest, target_schema)
                    end
                end
            end
        end

        -- 返回提示候选
        local location_tip = "系统"
        if custom_file_exists then
            yield(Candidate("switch", seg.start, seg._end, "检测到已有配置，已切换到〔" .. target_schema .. "〕，请手动重新部署", ""))
        else
            yield(Candidate("switch", seg.start, seg._end, "已从"..location_tip.."目录复制并切换到〔" .. target_schema .. "〕，请手动重新部署", ""))
        end
    end
end
return translator