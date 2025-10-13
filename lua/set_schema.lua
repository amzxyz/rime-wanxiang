--https://github.com/amzxyz/rime_wanxiang
--@amzxyz
--一个快速初始化方案类型的工具,使用方法,方案文件放进用户目录后先部署,再执行相关指令后重新部署完成切换
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
       -- 把 "__include: wanxiang_reverse.schema:/"（含可选后缀）改成 "__include: wanxiang_algebra:/mixed/"
        content = content:gsub("(%-?%s*__include:%s*)wanxiang_reverse%.schema:/[^%s\r\n]*", "%1wanxiang_algebra:/reverse/" .. target_schema)
        -- "__patch: wanxiang_reverse.schema:/hspzn" -> "__patch: wanxiang_algebra:/reverse/hspzn"
        content = content:gsub("(%-?%s*__patch:%s*)wanxiang_reverse%.schema:/([^%s\r\n]+)", "%1wanxiang_algebra:/reverse/%2")

        content = content:gsub("([%s]*__include:%s*wanxiang_algebra:/reverse/)%S+", "%1" .. target_schema)

    elseif file_path:find("wanxiang_mixedcode") then

        -- "__include: wanxiang_mixedcode.schema:/全拼"
        --   -> "__include: wanxiang_algebra:/mixed/通用派生规则"
        --      "__patch:   wanxiang_algebra:/mixed/全拼"
        content = content:gsub(
        "(%-?%s*)__include:%s*wanxiang_mixedcode%.schema:/全拼",
        function(lead)
            return lead .. "__include: wanxiang_algebra:/mixed/通用派生规则\n"
                .. lead .. "__patch:  wanxiang_algebra:/mixed/全拼"
        end
        )
        content = content:gsub("([%s]*__patch:%s*wanxiang_algebra:/mixed/)%S+", "%1" .. target_schema)

    elseif file_path:find("wanxiang%.custom") or file_path:find("wanxiang_pro%.custom") then
        -- 先把旧前缀整体替换为新前缀
        -- "- wanxiang.schema:/"            -> "- wanxiang_algebra:/base/"
        -- "- wanxiang_pro.schema:/"        -> "- wanxiang_algebra:/pro/"
        content = content:gsub("(%-+%s*)wanxiang%.schema:/", "%1wanxiang_algebra:/base/")
        content = content:gsub("(%-+%s*)wanxiang_pro%.schema:/", "%1wanxiang_algebra:/pro/")

        -- 再将 base/pro 后面的 schema 名替换为 target_schema
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
    if input == "/zjf" or input == "/jjf" then
        local target_aux = (input == "/zjf") and "直接辅助" or "间接辅助"
        local user_dir = rime_api.get_user_data_dir()
        local paths = {
            user_dir .. "/wanxiang_pro.custom.yaml",
            user_dir .. "/wanxiang.custom.yaml",
        }

        local total_hits, touched = 0, 0
        for _, p in ipairs(paths) do
            local f = io.open(p, "r")
            if f then
                local content = f:read("*a"); f:close()

                -- 两次 gsub 都要接收“新文本 + 命中次数”
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
            yield(Candidate("switch", seg.start, seg._end, "检测到已有自定义文件，已为您切换到〔" .. target_schema .. "〕，请手动重新部署", ""))
        else
            yield(Candidate("switch", seg.start, seg._end, "已帮您复制并切换到〔" .. target_schema .. "〕，请手动重新部署", ""))
        end
    end
end
return translator