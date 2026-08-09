### 万象拼音完整目录架构

下面按仓库目录结构说明万象各类文件的主要用途。文件名与目录层级保持与项目一致，便于查找、维护和排错。

> **说明**：`custom/` 目录主要用于存放自定义配置示例和参考文件。其中的 `.custom.yaml` 通常需要按需复制到 Rime 用户根目录后才会参与实际部署，直接修改示例文件本身不会自动生效。

* **custom/** —— `用户自定义配置示例与参考文件`
    * **万象键位映射.jpg** —— `双拼与辅助码键位参考图`
    * **赞赏.jpg** —— `项目赞赏二维码`
    * **简纯.zip** —— `精简版方案打包文件`
    * **aux_code.csv** —— `辅助码映射源数据`
    * **jm_flypy.txt** —— `小鹤双拼键位映射参考`
    * **jm_zrm.txt** —— `自然码双拼键位映射参考`
    * **wubi_chaifen.txt** —— `五笔部件拆分与反查参考数据`
    * **wanxiang.custom.yaml** —— `标准版主方案自定义配置示例`
    * **wanxiang_english.custom.yaml** —— `英文方案自定义配置示例`
    * **wanxiang_mixedcode.custom.yaml** —— `混输方案自定义配置示例`
    * **wanxiang_reverse.custom.yaml** —— `反查方案自定义配置示例`
    * **wanxiang_pro.custom.yaml** —— `Pro 版主方案自定义配置示例`
    * **wanxiang_pro.dict.yaml** —— `Pro 版词库入口`
    * **wanxiang_pro.schema.yaml** —— `Pro 版主方案文件`
    * **wanxiang_pure.custom.yaml** —— `Pure 版自定义配置示例`
    * **wanxiang_pure.dict.yaml** —— `Pure 版词库入口`
    * **wanxiang_pure.schema.yaml** —— `Pure 版主方案文件`

* **custom_phrase.txt** —— `自定义短语源文件，用于配置固定编码与置顶候选`

* **default.yaml** —— `Rime 全局默认配置，包括方案列表、快捷键及公共行为`

* **dicts/** —— `万象词库数据目录`
    * **mixed.dict.yaml** —— `中英混合词汇库`
    * **cuoyin.dict.yaml** —— `常见错音与容错词库`
    * **diming.dict.yaml** —— `地名专名词库`
    * **duoyin.dict.yaml** —— `多音字校对词库`
    * **en.dict.yaml** —— `基础英文词库`
    * **jichu.dict.yaml** —— `基础高频词库`
    * **lianxiang.dict.yaml** —— `联想与长词词库`
    * **shici.dict.yaml** —— `古诗词与文言词库`
    * **zi.dict.yaml** —— `单字、带调拼音及辅助码映射词库`
    * **fangyan.dict.yaml** —— `方言词汇库`
    * **huaxue.dict.yaml** —— `化学专业词库`
    * **mingren.dict.yaml** —— `名人名称词库`
    * **renming.dict.yaml** —— `常用人名词库`
    * **taifeng.dict.yaml** —— `台风名称词库`
    * **wuzhong.dict.yaml** —— `物种名称词库`
    * **yaopin.dict.yaml** —— `药品名称词库`
    * **yiren.dict.yaml** —— `艺人名称词库`
    * **yixue.dict.yaml** —— `医学专业词库`

* **lua/** —— `Lua 扩展模块及其配套数据`
    * **data/** —— `Lua 模块使用的静态数据文件`
        * **abbrev.txt** —— `简拼与全拼映射数据`
        * **chaifen.txt** —— `汉字部件拆分与反查数据`
        * **charset.reverse.bin** —— `字符集反查二进制数据库`
        * **chengyu.txt** —— `成语简码数据`
        * **chinese_english.txt** —— `中译英释义数据`
        * **emoji.txt** —— `Emoji 中英文映射数据`
        * **english_chinese.txt** —— `英译中释义数据`
        * **t9_abbrev.txt** —— `九宫格简拼映射数据`
        * **tips_show.txt** —— `输入提示文本数据`
        * **others.txt** —— `其他辅助提示数据`
        * **HKVariants.txt** —— `香港繁体字形转换表`
        * **STCharacters.txt** —— `简繁单字转换表`
        * **STPhrases.txt** —— `简繁词组转换表`
        * **TWVariants.txt** —— `台湾正体字形转换表`
        * **codex_sym.txt** —— `Typst / Codex 符号数据，供 `/sym` 等功能使用`
        * **codex_emoji.txt** —— `Emoji 扩展数据，供 `/emoji` 等功能使用`
        * **compose.txt** —— `Compose 合成字符静态码表，供 `C` 前缀模式使用`
        * **en_abbrev.txt** —— `英文简码数据，用于 abbrev 模式`

    * **wanxiang/** —— `万象 Lua 核心功能模块`
        * **auto_phrase.lua** —— `自动造词与英文造词处理模块`
        * **bit.lua** —— `位运算兼容模块，用于统一不同 Lua 运行环境下的位操作`
        * **charset_filter.lua** —— `字符集过滤模块`
        * **compose.lua** —— `Compose 合成字符处理模块`
        * **force_upper_aux.lua** —— `大写辅助码与句子锁定处理模块`
        * **input_statistics.lua** —— `输入数据统计模块`
        * **key_binder.lua** —— `快捷键绑定扩展模块`
        * **librime.lua** —— `librime 底层接口封装`
        * **number_translator.lua** —— `数字与人民币大写转换模块`
        * **partial_commit.lua** —— `局部提交与分段上屏模块`
        * **set_schema.lua** —— `输入类型快捷切换模块`
        * **shijian.lua** —— `日期、时间、农历、节气等动态内容模块`
        * **super_calculator.lua** —— `计算器模块`
        * **super_comment_preedit.lua** —— `候选注释与 Preedit 处理模块`
        * **super_english.lua** —— `英文格式、自动空格、连续输入与大小写处理模块`
        * **super_filter.lua** —— `综合候选过滤模块`
        * **super_lookup.lua** —— `辅助码筛选、反查与定点改字模块`
        * **super_processor.lua** —— `综合按键处理模块`
        * **super_replacer.lua** —— `候选、注释及转换规则动态替换模块`
        * **super_sequence.lua** —— `候选序列与手动排序模块`
        * **super_tips.lua** —— `输入提示模块`
        * **unicode.lua** —— `Unicode 编码输入与解析模块`
        * **userdb.lua** —— `用户词库与 LevelDB 操作封装`
        * **user_predict.lua** —— `N-Gram 用户预测与上下文调频模块`
        * **version_display.lua** —— `版本与项目信息显示模块`
        * **wanxiang.lua** —— `万象 Lua 公共函数与模块挂载入口`

* **README.md** —— `项目主页与总体说明文档`

* **version.txt** —— `项目版本标识文件`

* **wanxiang_algebra.yaml** —— `全局拼写运算与转写规则库，包括全拼、双拼、模糊音及 9 键 / 14 键 / 18 键映射`

* **输入方案与字典集群 (Schema & Dict)**
    * **wanxiang.dict.yaml** —— `标准版主方案词库入口`
    * **wanxiang.schema.yaml** —— `标准版主输入方案文件`
    * **wanxiang_english.dict.yaml** —— `英文方案词库入口`
    * **wanxiang_english.schema.yaml** —— `英文输入方案文件`
    * **wanxiang_mixedcode.dict.yaml** —— `混输方案词库入口`
    * **wanxiang_mixedcode.schema.yaml** —— `中英混合输入方案文件`
    * **wanxiang_reverse.dict.yaml** —— `部件、拆字与反查词库入口`
    * **wanxiang_reverse.schema.yaml** —— `生僻字与部件反查方案文件`
    * **wanxiang_t9.schema.yaml** —— `九宫格输入方案文件`

* **wanxiang_symbols.yaml** —— `全局标点、符号及相关映射配置`

* **weasel.yaml** —— `Windows 小狼毫前端界面与外观配置`
