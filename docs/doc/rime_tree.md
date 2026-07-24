### 📂 万象拼音完整目录架构

* 📂 **custom/** —— `用户自定义与参考配置示例（仓库内置示例，部署时按需拷贝到用户目录）`
    * 🖼️ **万象键位映射.jpg** —— `双拼与辅助码键位参考图`
    * 🖼️ **赞赏.jpg** —— `开源支持赞赏二维码`
    * 🗜️ **简纯.zip** —— `精简纯净版方案打包`
    * 📄 **aux_code.csv** —— `辅助码映射源数据`
    * 📄 **jm_flypy.txt** —— `小鹤双拼键位映射参考`
    * 📄 **jm_zrm.txt** —— `自然码双拼键位映射参考`
    * 📄 **wubi_chaifen.txt** —— `五笔部件拆分反查参考`
    * 📄 **wanxiang.custom.yaml** —— `🟢 主方案自定义配置文件示例`
    * 📄 **wanxiang_english.custom.yaml** —— `🔠 英文方案自定义配置文件示例`
    * 📄 **wanxiang_mixedcode.custom.yaml** —— `🧬 混输方案自定义配置文件示例`
    * 📄 **wanxiang_reverse.custom.yaml** —— `🧩 反查方案自定义配置文件示例`
    * 📄 **wanxiang_pro.custom.yaml** —— `⚡ 专业版方案自定义配置（含双拼/辅助码增强）`
    * 📄 **wanxiang_pro.dict.yaml** —— `⚡ 专业版方案词库入口`
    * 📄 **wanxiang_pro.schema.yaml** —— `⚡ 专业版方案主文件`
    * 📄 **wanxiang_pure.custom.yaml** —— `🌿 纯净版方案自定义配置`
    * 📄 **wanxiang_pure.dict.yaml** —— `🌿 纯净版方案词库入口`
    * 📄 **wanxiang_pure.schema.yaml** —— `🌿 纯净版方案主文件`
* 📄 **custom_phrase.txt** —— `自定义快捷短语源文件（置顶）`
* ⚙️ **default.yaml** —— `Rime 全局默认行为与快捷键配置`
* 📚 **dicts/** —— `万象词库集群`
    * 📄 **mixed.dict.yaml** —— `中英混合词汇库`
    * 📄 **cuoyin.dict.yaml** —— `常见错音容错词库`
    * 📄 **diming.dict.yaml** —— `全国地名专名词库`
    * 📄 **duoyin.dict.yaml** —— `多音字校对词库`
    * 📄 **en.dict.yaml** —— `基础英文词库`
    * 📄 **jichu.dict.yaml** —— `基础高频核心词库`
    * 📄 **lianxiang.dict.yaml** —— `联想长词库`
    * 📄 **shici.dict.yaml** —— `古诗词与文言文大全词库`
    * 📄 **zi.dict.yaml** —— `单字及带调辅助码映射词库`
    * 📄 **fangyan.dict.yaml** —— `方言词汇库`
    * 📄 **huaxue.dict.yaml** —— `化学专业词库`
    * 📄 **mingren.dict.yaml** —— `名人专有名词库`
    * 📄 **renming.dict.yaml** —— `高频人名库`
    * 📄 **taifeng.dict.yaml** —— `最新台风命名表`
    * 📄 **wuzhong.dict.yaml** —— `物种多样性词库`
    * 📄 **yaopin.dict.yaml** —— `药品名库`
    * 📄 **yiren.dict.yaml** —— `艺人名词库`
    * 📄 **yixue.dict.yaml** —— `医学专业词库`
* 🪄 **lua/** —— `万象底层魔法扩展与数据`
    * 📂 **data/** —— `脚本依赖静态数据库`
        * 📄 **abbrev.txt** —— `简拼与全拼映射表`
        * 📄 **chaifen.txt** —— `汉字部件拆分反查数据`
        * 📄 **charset.reverse.bin** —— `字符集反查二进制加速库`
        * 📄 **chengyu.txt** —— `成语简码数据`
        * 📄 **chinese_english.txt** —— `中翻英释义数据`
        * 📄 **emoji.txt** —— `Emoji 表情中英映射表`
        * 📄 **english_chinese.txt** —— `英翻中释义数据`
        * 📄 **t9_abbrev.txt** —— `九宫格简拼映射表`
        * 📄 **tips_show.txt** —— `万能输入提示文本数据`
        * 📄 **others.txt** —— `其他辅助提示数据`
        * 📄 **HKVariants.txt** —— `香港繁体字形转换表`
        * 📄 **STCharacters.txt** —— `简繁单字转换引擎表`
        * 📄 **STPhrases.txt** —— `简繁词组转换引擎表`
        * 📄 **TWVariants.txt** —— `台湾正体字形转换表`
        * 📄 **codex_sym.txt** —— `超级符号库数据（typst/codex 符号表，供 /sym）`
        * 📄 **codex_emoji.txt** —— `超级表情库数据（供 /emoji）`
        * 📄 **compose.txt** —— `Compose 合成字符静态码表（XCompose 转换，供 C 前缀）`
        * 📄 **en_abbrev.txt** —— `英文简码数据（abbrev 模式英文简码）`
        * 📄 **rev.txt** —— `同音派生数据（append 模式）`
    * 📂 **wanxiang/** —— `Lua 核心功能源码组件`
        * 📄 **auto_phrase.lua** —— `无感造词、中英文造词处理模块`
        * 📄 **bit.lua** —— `跨运行时位运算兼容模块（兼容 LuaJIT bit 库，统一 64 位掩码）`
        * 📄 **charset_filter.lua** —— `字符集过滤模块`
        * 📄 **compose.lua** —— `Compose 合成字符模式模块（仿系统 XCompose，C 前缀触发）`
        * 📄 **force_upper_aux.lua** —— `大写辅助码锁定句子模块`
        * 📄 **input_statistics.lua** —— `输入状态统计与监控模块`
        * 📄 **key_binder.lua** —— `高级快捷键绑定扩展模块`
        * 📄 **librime.lua** —— `Rime 底层 C++ 接口封装`
        * 📄 **number_translator.lua** —— `数字/金额大写快速转换模块`
        * 📄 **partial_commit.lua** —— `分段上屏模块`
        * 📄 **set_schema.lua** —— `方案快捷切换控制模块`
        * 📄 **shijian.lua** —— `动态时间与日期扩展模块`
        * 📄 **super_calculator.lua** —— `内联极速计算器模块`
        * 📄 **super_comment_preedit.lua** —— `候选词超级注释生成模块`
        * 📄 **super_english.lua** —— `英文智能空格、整句、与大小写处理模块`
        * 📄 **super_filter.lua** —— `超级过滤引擎节点`
        * 📄 **super_lookup.lua** —— `超级辅筛/全聚合反查/定点改字模块`
        * 📄 **super_processor.lua** —— `全局按键拦截与中枢处理器`
        * 📄 **super_replacer.lua** —— `滤镜动态替换引擎`
        * 📄 **super_sequence.lua** —— `按键序列处理与手动排序模块`
        * 📄 **super_tips.lua** —— `超级提示组件`
        * 📄 **unicode.lua** —— `Unicode 编码直出解析模块`
        * 📄 **userdb.lua** —— `底层用户词库 LevelDB 操作 API`
        * 📄 **user_predict.lua** —— `N-Gram 语境大脑与动态调频引擎`
        * 📄 **version_display.lua** —— `当前输入法版本号显示模块`
        * 📄 **wanxiang.lua** —— `万象 Lua 功能复用函数集挂载入口`
* 📖 **README.md** —— `项目主页展示文档`
* 🏷️ **version.txt** —— `项目版本标识文件`
* 🧮 **wanxiang_algebra.yaml** —— `全局拼写运算与转写规则库 (含 9键/14键及模糊音逻辑)`
* ⌨️ **输入方案与字典集群** (Schema & Dict)
    * 📄 **wanxiang.dict.yaml** —— `🟢 主方案词库挂载入口`
    * 📄 **wanxiang.schema.yaml** —— `🟢 标准版主输入方案主文件`
    * 📄 **wanxiang_english.dict.yaml** —— `🔠 英文方案词库入口`
    * 📄 **wanxiang_english.schema.yaml** —— `🔠 英文整句输入方案主文件`
    * 📄 **wanxiang_mixedcode.dict.yaml** —— `🧬 混输方案词库入口`
    * 📄 **wanxiang_mixedcode.schema.yaml** —— `🧬 全能混合输入方案主文件`
    * 📄 **wanxiang_reverse.dict.yaml** —— `🧩 反查/拆字方案词库入口`
    * 📄 **wanxiang_reverse.schema.yaml** —— `🧩 生僻字全聚合反查方案主文件`
    * 📄 **wanxiang_t9.schema.yaml** —— `📱 九宫格专属方案主文件`
* 🔣 **wanxiang_symbols.yaml** —— `全局标点符号与快捷键映射表`
* 💻 **weasel.yaml** —— `Windows 端 UI 与外观专属配置文件`