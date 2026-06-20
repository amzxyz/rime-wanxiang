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

local function replace_schema(file_path, target_schema)
    local f = io.open(file_path, "r")
    if not f then 
        return false 
    end
    local content = f:read("*a")
    f:close()

    if file_path:find("wanxiang_reverse") then
        content = content:gsub("([%s]*__include:%s*wanxiang_algebra:/reverse/)%S+", "%1" .. target_schema)
    elseif file_path:find("wanxiang_mixedcode") then
        content = content:gsub("([%s]*__patch:%s*wanxiang_algebra:/mixed/)%S+", "%1" .. target_schema)
    elseif file_path:find("wanxiang_english") then
        content = content:gsub("([%s]*__patch:%s*wanxiang_algebra:/english/)%S+", "%1" .. target_schema)
    elseif file_path:find("wanxiang.*%.custom") then
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

local function translator(input, seg, env)
    if input == "/zjf" or input == "/jjf" then
        local target_aux = (input == "/zjf") and "直接辅助" or "间接辅助"
        local user_dir = rime_api.get_user_data_dir()
        
        local is_pro = wanxiang.is_pro_scheme(env)
        local main_file = is_pro and "wanxiang_pro.custom.yaml" or "wanxiang.custom.yaml"
        local p = user_dir .. "/" .. main_file

        if file_exists(p) then
            local f = io.open(p, "r")
            local content = f:read("*a")
            f:close()

            local n1, n2 = 0, 0
            content, n1 = content:gsub("(%-+%s*wanxiang_algebra:/[%w_]+/)直接辅助(%s*#?.*)", "%1" .. target_aux .. "%2")
            content, n2 = content:gsub("(%-+%s*wanxiang_algebra:/[%w_]+/)间接辅助(%s*#?.*)", "%1" .. target_aux .. "%2")
            
            if (n1 + n2) > 0 then
                local w = io.open(p, "w")
                if w then 
                    w:write(content)
                    w:close() 
                end
                yield(Candidate("switch", seg.start, seg._end, "当前方案已切换到〔" .. target_aux .. "〕，请重新部署", ""))
            else
                yield(Candidate("switch", seg.start, seg._end, "当前配置未找到可切换的条目", ""))
            end
        else
            yield(Candidate("switch", seg.start, seg._end, "未找到当前配置，请先切换双拼方案", ""))
        end
        return
    end

    local schema_map = {
        ["/flypy"]  = "小鹤双拼",
        ["/mspy"]   = "微软双拼",
        ["/zrm"]    = "自然码",
        ["/sogou"]  = "搜狗双拼",
        ["/znabc"]  = "智能ABC",
        ["/ziguang"]= "紫光双拼",
        ["/pyjj"]   = "拼音加加",
        ["/gbpy"]   = "国标双拼",
        ["/lxsq"]   = "乱序17",
        ["/ltsp"]   = "蓝天双拼",
        ["/zrlong"] = "自然龙",
        ["/hxlong"] = "汉心龙",
        ["/pinyin"] = "全拼",
        ["/sdpy"] = "首道双拼",
    }

    local target_schema = schema_map[input]
    if target_schema then
        local user_dir = rime_api.get_user_data_dir()
        local shared_dir = rime_api.get_shared_data_dir()
        local is_pro = wanxiang.is_pro_scheme(env)
        
        local main_file = is_pro and "wanxiang_pro.custom.yaml" or "wanxiang.custom.yaml"
        local dest_main = user_dir .. "/" .. main_file
        local main_exists = file_exists(dest_main)

        local files = {
            "wanxiang_mixedcode.custom.yaml",
            "wanxiang_reverse.custom.yaml",
            "wanxiang_english.custom.yaml",
            main_file
        }

        for _, name in ipairs(files) do
            local dest = user_dir .. "/" .. name
            if name == main_file and main_exists then
                replace_schema(dest, target_schema)
            else
                local src = shared_dir .. "/custom/" .. name
                if not file_exists(src) then
                    src = user_dir .. "/custom/" .. name
                end
                
                if file_exists(src) then
                    if copy_file(src, dest) then
                        replace_schema(dest, target_schema)
                    end
                end
            end
        end

        local msg = main_exists 
            and ("检测到专属配置，已切换到〔" .. target_schema .. "〕，请手动重新部署") 
            or  ("已从系统目录构建配置并切换到〔" .. target_schema .. "〕，请手动重新部署")
            
        yield(Candidate("switch", seg.start, seg._end, msg, ""))
    end
end

return translator