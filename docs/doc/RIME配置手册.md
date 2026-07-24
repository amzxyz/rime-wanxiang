# 📖 RIME 输入法方案配置手册

## 一、 `Schema.yaml` 文件详解

### 1.1 开始之前
```yaml
# Rime schema
# encoding: utf-8
```

### 1.2 描述档
1. `name:` 方案的显示名称〔即出现于方案选单中以示人的，通常为中文〕
2. `schema_id:` 方案内部名，在代码中引用此方案时以此名为正，通常由英文、数字、下划线组成
3. `author:` 发明人、撰写者。如果您对方案做出了修改，请保留原作者名，并将自己的名字加在后面
4. `description:` 请简要描述方案历史、码表来源、该方案规则等
5. `dependencies:` 如果本方案依赖于其它方案〔通常来说会依赖其它方案做为反查，抑或是两种或多种方案混用时〕
6. `version:` 版本号，在发布新版前请确保已升版本号

#### 示例
```yaml
schema:
  name: "苍颉检字法"
  schema_id: cangjie6
  author:
    - "发明人 朱邦复先生、沉红莲女士"
  dependencies:
    - luna_pinyin
    - jyutping
    - zyenpheng
  description: |
    第六代仓颉输入法
    码表由雪斋、惜缘和crazy4u整理
  version: 0.19
```

### 1.3 开关
通常包含以下数个：

1. `ascii_mode` 是中英文转换开关。默认 `0` 为中文，`1` 为英文
2. `full_shape` 是全角符号／半角符号开关。注意，开启全角时英文字母亦为全角。`0` 为半角，`1` 为全角
3. `extended_charset` 是字符集开关。`0` 为CJK基本字符集，`1` 为CJK全字符集
   - 仅 `table_translator` 可用
5. `ascii_punct` 是中西文标点转换开关，`0` 为中文句读，`1` 为西文标点。
6. `simplification` 是转化字开关。一般情况下与上同，`0` 为不开启转化，`1` 为转化。

- `simplification` 选项名称可自定义，亦可添加多套替换用字方案：

```yaml
- name: zh_cn
  states: ["汉字", "汉字"]
  reset: 0
```
或
```yaml
- options: [ zh_trad, zh_cn, zh_mars ]
  states:
    - 字型 → 汉字
    - 字型 → 汉字
    - 字型 → 䕼茡
  reset: 0
```
- `name`/`options` 名：须与 `simplifier` 中 `option_name` 相同
- `states`：可不写，如不写则此开关存在但不可见，可由快捷键操作
- `reset`：设置默认状态〔`reset` 可不写，此时切换窗口时不会重置到默认状态〕

9. 字符集过滤。此选项没有默认名称，须配合 `charset_filter` 使用。可单用，亦可添加多套字符集：

```yaml
- name: gbk
  states: [ 增广, 常用 ]
  reset: 0
```
或
```yaml
- options: [ utf-8, big5hkscs, big5, gbk, gb2312 ]
  states:
    - 字集 → 全
    - 字集 → 港台
    - 字集 → 台
    - 字集 → 大陆
    - 字集 → 简体
  reset: 0
```
- `name`/`options` 名：须与 `charset_filter` `@` 后的 tag 相同
- 避免同时使用字符集过滤和 `extended_charset`

#### 示例
```yaml
switches:
  - name: ascii_mode
    reset: 0
    states: ["中文", "西文"]
  - name: full_shape
    states: ["半角", "全角"]
  - name: extended_charset
    states: ["通用", "增广"]
  - name: simplification
    states: ["汉字", "汉字"]
  - name: ascii_punct
    states: ["句读", "符号"]
```

### 1.4 引擎
- 以下 **加粗** 项为可细配者，*斜体* 者为不常用者

引擎分四组：

#### 一、`processors`
- 这批组件处理各类按键消息

1. `ascii_composer` 处理西文模式及中西文切
2. **`recognizer`** 与 `matcher` 搭配，处理符合特定规则的输入码，如网址、反查等 `tags`
3. **`key_binder`** 在特定条件下将按键绑定到其他按键，如重定义逗号、句号为候选翻页、开关快捷键等
4. **`speller`** 拼写处理器，接受字符按键，编辑输入
5. **`punctuator`** 句读处理器，将单个字符按键直接映射为标点符号或文字
6. `selector` 选字处理器，处理数字选字键〔可以换成别的哦〕、上、下候选定位、换页
7. `navigator` 处理输入栏内的光标移动
8. `express_editor` 编辑器，处理空格、回车上屏、回退键
9. *`fluid_editor`* 句式编辑器，用于以空格断词、回车上屏的【注音】、【语句流】等输入方案，替换 `express_editor`
10. *`chord_composer`* 和弦作曲家或曰并击处理器，用于【宫保拼音】等多键并击的输入方案
11. `lua_processor` 使用 `lua` 自定义按键，后接 `@` + `lua` 函数名
    - `lua` 函数名即用户文件夹内 `rime.lua` 中函数名，参数为 `(key, env)`

#### 二、`segmentors`
- 这批组件识别不同内容类型，将输入码分段并加上 `tag`

1. `ascii_segmentor` 标识西文段落〔譬如在西文模式下〕字母直接上屏
2. `matcher` 配合 `recognizer` 标识符合特定规则的段落，如网址、反查等，加上特定 `tag`
3. **`abc_segmentor`** 标识常规的文字段落，加上 `abc` 这个 `tag`
4. `punct_segmentor` 标识句读段落〔键入标点符号用〕加上 `punct` 这个 `tag`
5. `fallback_segmentor` 标识其他未标识段落
6. **`affix_segmentor`** 用户自定义 `tag`
    - 此项可加载多个实例，后接 `@` + `tag` 名
8. *`lua_segmentor`* 使用 `lua` 自定义切分，后接 `@` + `lua` 函数名

#### 三、`translators`
- 这批组件翻译特定类型的编码段为一组候选文字

1. `echo_translator` 没有其他候选字时，回显输入码〔输入码可以 `Shift` + `Enter` 上屏〕
2. `punct_translator` 配合 `punct_segmentor` 转换标点符号
3. **`table_translator`** 码表翻译器，用于仓颉、五笔等基于码表的输入方案
    - 此项可加载多个实例，后接 `@` + 翻译器名〔如：`cangjie`、`wubi` 等〕
7. **`script_translator`** 脚本翻译器，用于拼音、粤拼等基于音节表的输入方案
    - 此项可加载多个实例，后接 `@` + 翻译器名〔如：`pinyin`、`jyutping` 等〕
11. *`reverse_lookup_translator`* 反查翻译器，用另一种编码方案查码
12. **`lua_translator`** 使用 `lua` 自定义输入，例如动态输入当前日期、时间，后接 `@` + `lua` 函数名
    - `lua` 函数名即用户文件夹内 `rime.lua` 中函数名，参数为 `(input, seg, env)`
    - 可以 `env.engine.context:get_option("option_name")` 方式绑定到 `switch` 开关／`key_binder` 快捷键

#### 四、`filters`
- 这批组件过滤翻译的结果

1. `uniquifier` 过滤重复的候选字，有可能来自 **`simplifier`**
2. `cjk_minifier` 字符集过滤〔仅用于 `script_translator`，使之支持 `extended_charset` 开关〕
3. **`single_char_filter`** 单字过滤器，如加载此组件，则屏蔽词典中的词组〔仅 `table_translator` 有效〕
4. **`simplifier`** 用字转换
5. **`reverse_lookup_filter`** 反查滤镜，以更灵活的方式反查，Rime1.0后替代 *`reverse_lookup_translator`*
    - 此项可加载多个实例，后接 `@` + 滤镜名〔如：`pinyin_lookup`、`jyutping_lookup` 等〕
7. **`charset_filter`** 字符集过滤
    - 后接 `@` + 字符集名〔如：`utf-8` (无过滤)、`big5`、`big5hkscs`、`gbk`、`gb2312`〕
9. **`lua_filter`** 使用 `lua` 自定义过滤，例如过滤字符集、调整排序，后接 `@` + `lua` 函数名
    - `lua` 函数名即用户文件夹内 `rime.lua` 中函数名，参数为 `(input, env)`
    - 可以 `env.engine.context:get_option("option_name")` 方式绑定到 `switch` 开关／`key_binder` 快捷键

#### 示例
`cangjie6.schema.yaml`

```yaml
engine:
  processors:
    - ascii_composer
    - recognizer
    - key_binder
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor
  segmentors:
    - ascii_segmentor
    - matcher
    - affix_segmentor@pinyin
    - affix_segmentor@jyutping
    - affix_segmentor@pinyin_lookup
    - affix_segmentor@jyutping_lookup
    - affix_segmentor@reverse_lookup
    - abc_segmentor
    - punct_segmentor
    - fallback_segmentor
  translators:
    - punct_translator
    - table_translator
    - script_translator@pinyin
    - script_translator@jyutping
    - script_translator@pinyin_lookup
    - script_translator@jyutping_lookup
    - lua_translator@get_date
  filters:
    - simplifier@zh_simp
    - uniquifier
    - cjk_minifier
    - charset_filter@gbk
    - reverse_lookup_filter@middle_chinese
    - reverse_lookup_filter@pinyin_reverse_lookup
    - reverse_lookup_filter@jyutping_reverse_lookup
    - lua_filter@single_char_first
```

### 1.5 细项配置

- 凡 `comment_format`、`preedit_format`、`speller/algebra` 所用之正则表达式，请参考「Perl正则表达式」

**引擎中所举之加粗者均可在下方详细描述，格式为：**

```yaml
name:
  branches: configurations
```
或
```yaml
name:
  branches:
    - configurations
```

#### 一、`speller`
1. `alphabet:` 定义本方案输入键
2. `initials:` 定义仅作始码之键
3. `finals:` 定义仅作末码之键
4. `delimiter:` 上屏时的音节间分音符
5. `algebra:` 拼写运算规则，由之算出的拼写汇入 `prism` 中
6. `max_code_length:` 形码最大码长，超过则顶字上屏〔`number`〕
7. `auto_select:` 自动上屏〔`true` 或 `false`〕
8. `auto_select_pattern:` 自动上屏规则，以正则表达式描述，当输入串可以被匹配时自动顶字上屏。
9. `use_space:` 以空格作输入码〔`true` 或 `false`〕

- `speller` 的演算包含：

```yaml
xform --改写〔不保留原形〕
derive --衍生〔保留原形〕
abbrev --简拼〔出字优先级较上两组更低〕
fuzz --略拼〔此种简拼仅组词，不出单字〕
xlit --变换〔适合大量一对一变换〕
erase --删除
```

##### 示例
`luna_pinyin.schema.yaml`

```yaml
speller:
  alphabet: zyxwvutsrqponmlkjihgfedcba
  delimiter: " '"
  algebra:
    - erase/^xx$/
    - abbrev/^([a-z]).+$/$1/
    - abbrev/^([zcs]h).+$/$1/
    - derive/^([nl])ve$/$1ue/
    - derive/^([jqxy])u/$1v/
    - derive/un$/uen/
    - derive/ui$/uei/
    - derive/iu$/iou/
    - derive/([aeiou])ng$/$1gn/
    - derive/([dtngkhrzcs])o(u|ng)$/$1o/
    - derive/ong$/on/
    - derive/ao$/oa/
    - derive/([iu])a(o|ng?)$/a$1$2/
```

#### 二、`segmentor`
- `segmentor` 配合 `recognizer` 标记出 `tag`。这里会用到 `affix_segmentor` 和 `abc_translator`
- `tag` 用在 `translator`、`reverse_lookup_filter`、`simplifier` 中用以标定各自作用范围
- 如果不需要用到 `extra_tags` 则不需要单独配置 `segmentor`

1. `tag:` 设置其 `tag`
2. `prefix:` 设置其前缀标识，可不填，不填则无前缀
3. `suffix:` 设置其尾缀标识，可不填，不填则无尾缀
4. `tips:` 设置其输入前提示符，可不填，不填则无提示符
5. `closing_tips:` 设置其结束输入提示符，可不填，不填则无提示符
6. `extra_tags:` 为此 `segmentor` 所标记的段落插上其它 `tag`

**当 `affix_segmentor` 和 `translator` 重名时，两者可并在此处配置，此处1-5条对应下面19-23条。`abc_segmentor` 仅可设 `extra_tags`**

##### 示例
`cangjie6.schema.yaml`

```yaml
reverse_lookup:
  tag: reverse_lookup
  prefix: "`"
  suffix: ";"
  tips: "【反查】"
  closing_tips: "【苍颉】"
  extra_tags:
    - pinyin_lookup
    - jyutping_lookup
```

#### 三、`translator`
- 每个方案有一个主 `translator`，在引擎列表中不以 `@` + 翻译器名定义，在细项配置时直接以 `translator:` 命名。以下加粗项为可在主 `translator` 中定义之项，其它可在副〔以 `@` + 翻译器名命名〕`translator` 中定义

1. **`enable_charset_filter:`** 是否开启字符集过滤〔仅 `table_translator` 有效。启用 `cjk_minifier` 后可适用于 `script_translator`〕
2. **`enable_encoder:`** 是否开启自动造词〔仅 `table_translator` 有效〕
3. **`encode_commit_history:`** 是否对已上屏词自动成词〔仅 `table_translator` 有效〕
4. **`max_phrase_length:`** 最大自动成词词长〔仅 `table_translator` 有效〕
5. **`enable_completion:`** 提前显示尚未输入完整码的字〔仅 `table_translator` 有效〕
6. **`sentence_over_completion:`** 在无全码对应字而仅有逐键提示时也开启智能组句〔仅 `table_translator` 有效〕
7. **`strict_spelling:`** 配合 `speller` 中的 `fuzz` 规则，仅以略拼码组词〔仅 `table_translator` 有效〕
8. **`disable_user_dict_for_patterns:`** 禁止某些编码录入用户词典
9. **`enable_sentence:`** 是否开启自动造句
10. **`enable_user_dict:`** 是否开启用户词典〔用户词典记录动态字词频、用户词〕
    - 以上选填 `true` 或 `false`
12. **`dictionary:`** 翻译器将调取此字典文件
13. **`prism:`** 设置由此主翻译器的 `speller` 生成的棱镜文件名，或此副编译器调用的棱镜名
14. **`user_dict:`** 设置用户词典名
15. **`db_class:`** 设置用户词典类型，可设 `tabledb`〔文本〕或 `userdb`〔二进制〕
16. **`preedit_format:`** 上屏码自定义
17. **`comment_format:`** 提示码自定义
18. **`spelling_hints:`** 设置多少字以内候选标注完整带调拼音〔仅 `script_translator` 有效〕
19. **`initial_quality:`** 设置此翻译器出字优先级
20. `tag:` 设置此翻译器针对的 `tag`。可不填，不填则仅针对 `abc`
21. `prefix:` 设置此翻译器的前缀标识，可不填，不填则无前缀
22. `suffix:` 设置此翻译器的尾缀标识，可不填，不填则无尾缀
23. `tips:` 设置此翻译器的输入前提示符，可不填，不填则无提示符
24. `closing_tips:` 设置此翻译器的结束输入提示符，可不填，不填则无提示符
25. `contextual_suggestions:` 是否使用语言模型优化输出结果〔需配合 `grammar` 使用〕
26. `max_homophones:` 最大同音簇长度〔需配合 `grammar` 使用〕
27. `max_homographs:` 最大同形簇长度〔需配合 `grammar` 使用〕

##### 示例
`cangjie6.schema.yaml` 苍颉主翻译器

```yaml
translator:
  dictionary: cangjie6
  enable_charset_filter: true
  enable_sentence: true
  enable_encoder: true
  encode_commit_history: true
  max_phrase_length: 5
  preedit_format:
    - xform/^([a-z ])$/$1｜\U$1\E/
    - xform/(?<=[a-z])\s(?=[a-z])//
    - "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ|日月金木水火土竹戈十大中一弓人心手口尸廿山女田止卜片|"
  comment_format:
    - "xlit|abcdefghijklmnopqrstuvwxyz~|日月金木水火土竹戈十大中一弓人心手口尸廿山女田止卜片・|"
  disable_user_dict_for_patterns:
    - "^z.$"
  initial_quality: 0.75
```

`cangjie6.schema.yaml` 拼音副翻译器

```yaml
pinyin:
  tag: pinyin
  dictionary: luna_pinyin
  enable_charset_filter: true
  prefix: 'P' #须配合recognizer
  suffix: ';' #须配合recognizer
  preedit_format:
    - "xform/([nl])v/$1ü/"
    - "xform/([nl])ue/$1üe/"
    - "xform/([jqxy])v/$1u/"
  tips: "【汉拼】"
  closing_tips: "【苍颉】"
```

`pinyin_simp.schema.yaml` 拼音・简化字主翻译器

```yaml
translator:
  dictionary: luna_pinyin
  prism: luna_pinyin_simp
  preedit_format:
    - xform/([nl])v/$1ü/
    - xform/([nl])ue/$1üe/
    - xform/([jqxy])v/$1u/
```

`luna_pinyin.schema.yaml` 明月拼音用户短语

```yaml
custom_phrase: #这是一个table_translator
  dictionary: ""
  user_dict: custom_phrase
  db_class: tabledb
  enable_sentence: false
  enable_completion: false
  initial_quality: 1
```

#### 四、`reverse_lookup_filter`
- 此滤镜须挂在 `translator` 上，不影响该 `translator` 工作

1. `tags:` 设置其作用范围
2. `overwrite_comment:` 是否覆盖其他提示
3. `dictionary:` 反查所得提示码之码表
4. `comment_format:` 自定义提示码格式

##### 示例
`cangjie6.schema.yaml`

```yaml
pinyin_reverse_lookup: #该反查滤镜名
  tags: [ pinyin_lookup ] #挂在这个tag所对应的翻译器上
  overwrite_comment: true
  dictionary: cangjie6 #反查所得为苍颉码
  comment_format:
    - "xform/$/〕/"
    - "xform/^/〔/"
    - "xlit|abcdefghijklmnopqrstuvwxyz |日月金木水火土竹戈十大中一弓人心手口尸廿山女田止卜片、|"
```

#### 五、`simplifier`
1. `option_name:` 对应 `switches` 中设置的切换项名
2. `opencc_config:` 用字转换配置文件
   - 位于：`rime_dir/opencc/`，自带之配置文件含：
     1. 繁转简〔默认〕：`t2s.json`
     2. 繁转台湾：`t2tw.json`
     3. 繁转香港：`t2hk.json`
     4. 简转繁：`s2t.json`
3. `tags:` 设置转换范围
4. `tips:` 设置是否提示转换前的字，可填 `none`〔或不填〕、`char`〔仅对单字有效〕、`all`
5. `show_in_comment:` 设置是否仅将转换结果显示在备注中
6. *`excluded_types:`* 取消特定范围〔一般为 *`reverse_lookup_translator`*〕转化用字

##### 示例
修改自 `luna_pinyin_kunki.schema`

```yaml
zh_tw:
  option_name: zh_tw
  opencc_config: t2tw.json
  tags: [ abc ] #abc对应abc_segmentor
  tips: none
```

#### 六、`chord_composer`
- 并击把键盘分两半，相当于两块键盘。两边同时击键，系统默认在其中一半上按的键先于另一半，由此得出上屏码

1. `alphabet:` 字母表，包含用于并击的按键。击键虽有先后，形成并击时，一律以字母表顺序排列
2. `algebra:` 拼写运算规则，将一组并击编码转换为拼音音节
3. `output_format:` 并击完成后套用的式样，追加隔音符号
4. `prompt_format:` 并击过程中套用的式样，加方括弧

##### 示例
`combo_pinyin.schema.yaml`

```yaml
chord_composer:
  # 字母表，包含用于并击的按键
  # 击键虽有先后，形成并击时，一律以字母表顺序排列
  alphabet: "swxdecfrvgtbnjum ki,lo."
  # 拼写运算规则，将一组并击编码转换为拼音音节
  algebra:
    # 先将物理按键字符对应到宫保拼音键位中的拼音字母
    - 'xlit|swxdecfrvgtbnjum ki,lo.|sczhlfgdbktpRiuVaNIUeoE|'
    # 以下根据宫保拼音的键位分别变换声母、韵母部分
    # 组合声母
    - xform/^zf/zh/
    - xform/^cl/ch/
    - xform/^fb/m/
    - xform/^ld/n/
    - xform/^hg/r/
    ……
    # 声母独用时补足隐含的韵母
    - xform/^([bpf])$/$1u/
    - xform/^([mdtnlgkh])$/$1e/
    - xform/^([mdtnlgkh])$/$1e/
    - xform/^([zcsr]h?)$/$1i/
  # 并击完成后套用的式样，追加隔音符号
  output_format:
    - "xform/^([a-z]+)$/$1'/"
  # 并击过程中套用的式样，加方括弧
  prompt_format:
    - "xform/^(.*)$/[$1]/"
```

#### 七、`lua`
- 请参考 [hchunhui/librime-lua](https://github.com/hchunhui/librime-lua) 以寻求更多灵感。

1. `lua_translator`
2. `lua_filter`
3. `lua_processor`
4. `lua_segmentor`

##### 示例
`rime.lua`

```lua
function get_date(input, seg, env)
  --- 以 show_date 为开关名或 key_binder 中 toggle 的对象
  on = env.engine.context:get_option("show_date")
  if (on and input == "date") then
    --- Candidate(type, start, end, text, comment)
    yield(Candidate("date", seg.start, seg._end, os.date("%Y年%m月%d日"), " 日期"))
  end
end
```

#### 八、其它
- 包括 `recognizer`、`key_binder`、`punctuator`。**标点**、**快捷键**、**二三选重**、**特殊字符**等均于此设置

1. **`import_preset:`** 由外部统一文件导入
2. `grammar:` 下设：
   - `language:` 取值 `zh-han[ts]-t-essay-bg[wc]`
   - `collocation_max_length:` 最大搭配长度（整句输入可忽略此项）
   - `collocation_min_length:` 最小搭配长度（整句输入可忽略此项）
3. `recognizer:` 下设 `patterns:` 配合 `segmentor` 的 `prefix` 和 `suffix` 完成段落划分、`tag` 分配
   - 前字段可以为以 `affix_segmentor@someTag` 定义的 `Tag` 名，或者 `punct`、`reverse_lookup` 两个内设的字段。其它字段不调用输入法引擎，输入即输出〔如 `url` 等字段〕
4. `key_binder:` 下设 `bindings:` 设置功能性快捷键
   - 每一条 `binding` 可能包含：`accept` 实际所按之键、`send` 输出效果、`toggle` 切换开关和 `when` 作用范围〔`send` 和 `toggle` 二选一〕
   - `toggle` 可用字段包含各开关名
   - `when` 可用字段包含：

```yaml
paging      翻页用
has_menu    操作候选项用
composing   操作输入码用
always      全域
```

   - `accept` 和 `send` 可用字段除 A-Za-z0-9 外，还包含以下键盘上实际有的键：

```yaml
BackSpace   退格
Tab         水平定位符
Linefeed    换行
Clear       清除
Return      回车
Pause       暂停
Sys_Req     印屏
Escape      退出
Delete      删除
Home        原位
Left        左箭头
Up          上箭头
Right       右箭头
Down        下箭头
Prior、Page_Up     上翻
Next、Page_Down    下翻
End         末位
Begin       始位
Shift_L     左Shift
Shift_R     右Shift
Control_L   左Ctrl
Control_R   右Ctrl
Meta_L      左Meta
Meta_R      右Meta
Alt_L       左Alt
Alt_R       右Alt
Super_L     左Super
Super_R     右Super
Hyper_L     左Hyper
Hyper_R     右Hyper
Caps_Lock   大写锁
Shift_Lock  上档锁
Scroll_Lock 滚动锁
Num_Lock    小键盘锁
Select      选定
Print       打印
Execute     执行
Insert      插入
Undo        还原
Redo        重做
Menu        菜单
Find        搜寻
Cancel      取消
Help        帮助
Break       中断
space       空格
exclam      !
quotedbl    "
numbersign  #
dollar      $
percent     %
ampersand   &
apostrophe  '
parenleft   (
parenright  )
asterisk    *
plus        +
comma       ,
minus       -
period      .
slash       /
colon       :
semicolon   ;
less        <
equal       =
greater     >
question    ?
at          @
bracketleft [
backslash   \
bracketright ]
asciicircum ^
underscore  _
grave       `
braceleft   {
bar         |
braceright  }
asciitilde  ~
KP_Space    小键盘空格
KP_Tab      小键盘水平定位符
KP_Enter    小键盘回车
KP_Delete   小键盘删除
KP_Home     小键盘原位
KP_Left     小键盘左箭头
KP_Up       小键盘上箭头
KP_Right    小键盘右箭头
KP_Down     小键盘下箭头
KP_Prior、KP_Page_Up      小键盘上翻
KP_Next、KP_Page_Down     小键盘下翻
KP_End      小键盘末位
KP_Begin    小键盘始位
KP_Insert   小键盘插入
KP_Equal    小键盘等于
KP_Multiply 小键盘乘号
KP_Add      小键盘加号
KP_Subtract 小键盘减号
KP_Divide   小键盘除号
KP_Decimal  小键盘小数点
KP_0        小键盘0
KP_1        小键盘1
KP_2        小键盘2
KP_3        小键盘3
KP_4        小键盘4
KP_5        小键盘5
KP_6        小键盘6
KP_7        小键盘7
KP_8        小键盘8
KP_9        小键盘9
```

5. `editor` 用以订制操作键〔不支持 `import_preset:`〕，键盘键名同 `key_binder/bindings` 中的 `accept` 和 `send`，效果定义如下：

```yaml
confirm             上屏候选项
commit_comment      上屏候选项备注
commit_raw_input    上屏原始输入
commit_script_text  上屏变换后输入
commit_composition  语句流单字上屏
revert              撤消上次输入
back                按字符回退
back_syllable       按音节回退
delete_candidate    删除候选项
delete              向后删除
cancel              取消输入
noop                空
```

7. `punctuator:` 下设 `full_shape:` 和 `half_shape:` 分别控制全角模式下的符号和半角模式下的符号，另有 `use_space:` 空格顶字〔`true` 或 `false`〕
   - 每条标点项可加 `commit` 直接上屏和 `pair` 交替上屏两种模式，默认为选单模式

##### 示例
修改自 `cangjie6.schema.yaml`

```yaml
key_binder:
  import_preset: default
  bindings:
    - {accept: semicolon, send: 2, when: has_menu} #分号选第二重码
    - {accept: apostrophe, send: 3, when: has_menu} #引号选第三重码
    - {accept: "Control+1", select: .next, when: always}
    - {accept: "Control+2", toggle: full_shape, when: always}
    - {accept: "Control+3", toggle: simplification, when: always}
    - {accept: "Control+4", toggle: extended_charset, when: always}
editor:
  bindings:
    Return: commit_comment
punctuator:
  import_preset: symbols
  half_shape:
    "'": {pair: ["「", "」"]} #第一次按是「，第二次是」
    "(": ["〔", "［"] #弹出选单
    .: {commit: "。"} #无选单，直接上屏。优先级最高
```

### 1.6 其它
- Rime还为每个方案提供选单和一定的外观订制能力
- 通常情况下 `menu` 在 `default.yaml` 中定义〔或用户修改档 `default.custom.yaml`〕，`style` 在 `squirrel.yaml` 或 `weasel.yaml`〔或用户修改档 `squirrel.custom.yaml` 或 `weasel.custom.yaml`〕

#### 示例
```yaml
menu:
  alternative_select_labels: [ ①, ②, ③, ④, ⑤, ⑥, ⑦, ⑧, ⑨ ]  # 修改候选标签
  alternative_select_keys: ASDFGHJKL #如编码字符占用数字键则须另设选字键
  page_size: 5 #选单每页显示个数
```

## `Dict.yaml` 详解

### 开始之前
```yaml
# Rime dict
# encoding: utf-8
〔你还可以在这注释字典来源、变动记录等〕
```

### 描述档
1. `name:` 内部字典名，也即 `schema` 所引用的字典名，确保与文件名相一致
2. `version:` 如果发布，请确保每次改动升版本号

#### 示例
```yaml
name: "cangjie6.extended"
version: "0.1"
```

### 配置
1. `sort:` 字典 **初始** 排序，可选 `original` 或 `by_weight`
2. `use_preset_vocabulary:` 是否引入「八股文」〔含字词频、词库〕
3. `max_phrase_length:` 配合 `use_preset_vocabulary:`，设置导入词条最大词长
4. `min_phrase_weight:` 配合 `use_preset_vocabulary:`，设置导入词条最小词频
5. `columns:` 定义码表以 `Tab` 分隔出的各列，可设 `text`【文本】、`code`【码】、`weight`【权重】、`stem`【造词码】
6. `import_tables:` 加载其它外部码表
7. `encoder:` 形码造词规则
8. `exclude_patterns:`
9. `rules:` 可用 `length_equal:` 和 `length_in_range:` 定义。大写字母表示字序，小写字母表示其所跟随的大写字母所以表的字中的编码序
10. `tail_anchor:` 造词码包含结构分割符〔仅用于仓颉〕
11. `exclude_patterns` 取消某编码的造词资格

#### 示例
`cangjie6.extended.dict.yaml`

```yaml
sort: by_weight
use_preset_vocabulary: false
import_tables:
  - cangjie6 #单字码表由cangjie6.dict.yaml导入
columns: #此字典为纯词典，无单字编码，仅有字和词频
  - text #字／词
  - weight #字／词频
encoder:
  exclude_patterns:
    - '^z.*$'
  rules:
    - length_equal: 2 #对于二字词
      formula: "AaAzBaBbBz" #取第一字首尾码、第二字首次尾码
    - length_equal: 3 #对于三字词
      formula: "AaAzBaYzZz" #取第一字首尾码、第二字首尾码、第三后缀码
    - length_in_range: [4, 5] #对于四至五字词
      formula: "AaBzCaYzZz" #取第一字首码，第二后缀码、第三字首码、倒数第二后缀码、最后一后缀码
  tail_anchor: "'"
```

### 码表
- 以 `Tab` 分隔各列，各列依 `columns:` 定义排列。

#### 示例
`cangjie6.dict.yaml`

```yaml
columns:
  - text #第一列字／词
  - code #第二列码
  - weight #第三列字／词频
  - stem #第四列造词码
```

`cangjie6.dict.yaml`

```yaml
个	owjr	246268	ow'jr
看	hqbu	245668
中	l	243881
呢	rsp	242970
来	doo	235101
吗	rsqf	221092
为	bhnf	211340
会	owfa	209844
她	vpd	204725
与	xyc	203975
给	vfor	193007
等	hgdi	183340
这	yymr	181787
用	bq	168934	b'q
```