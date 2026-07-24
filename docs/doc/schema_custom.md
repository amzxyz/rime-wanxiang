# 🎛️ 万象拼音：全段落 Patch 终极对照表（完整版）

为了让你在自定义 `wanxiang.custom.yaml` 时不再迷茫，我们对主方案从上到下的**所有命名空间**进行了左右对照。
左侧是 `wanxiang.schema.yaml` 中的原始代码，右侧是如何修改该段落的精准 Patch 补丁。需要说清楚的是，custom patch必须顶部只有一个`patch:`，段落中每个都有写`patch：`只是为了对照段落和缩进。  
⚠️多类型的示例中千万不要这样写完了又那样写一次，在一个patch中是冲突的  
请大家清楚理解本文旨在讲述如何patch（语法），为什么这样做则是另一个命题。需要在了解功能的情况下灵活运用这些方法。  

> **💡 Patch 核心法则**：  

> 1. 层级递进用 `/` 隔开。  

> 2. 遇到以 `-` 打头的列表（数组），用 `@数字` 表示第几个（从 0 开始），用 `@next` 表示在末尾追加，或者使用`/+`表示在末尾追加。  

---

## 1. 方案说明 (schema)
包含名称、作者、简介及挂接模块。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
schema:
  schema_id: wanxiang
  name: 万象拼音
  version: "LTS"
  dependencies:
    - wanxiang_mixedcode
    - wanxiang_reverse
    - wanxiang_english
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 修改方案名称
  schema/name: "自定义万象"
  
  # 追加依赖方案xxx
  # 形态1
  schema/dependencies/@next: xxx
  # 形态2
  schema/dependencies/+: xxx
  # 形态3
  schema/dependencies/+:
    - xxx
```

</div>

---

## 2. 状态机开关 (switches)
控制中文/英文、标点、繁简、简码等状态的默认行为。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
switches:
  - name: ascii_mode
    states: [ 中文, 英文 ]
  - name: ascii_punct
    states: [ 中标, 英标 ]
  # ... 省略中间 ...
  - name: abbrev
    states: [ 简码关, 简码开 ]
    reset: 1
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 数组从0开始数。reset值 0是关闭 1是打开
  # 将第1个开关(中英)默认设为英文
  switches/@0/reset: 1
  
  # 将第2个开关(标点)默认设为英标
  switches/@1/reset: 1
  
  # 关闭简码的默认开启 (数一下它是第9个，索引为8)
  switches/@8/reset: 0
```

</div>

---

## 3. 输入引擎核心流水线 (engine)
向引擎的四大组件中插队、追加或删除滤镜及处理器。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
engine:
  processors:
    - lua_processor@*wanxiang.super_processor
    # ...
  segmentors:
    # ...
  translators:
    # ...
  filters:
    - lua_filter@*wanxiang.auto_phrase
    # ...
    - uniquifier
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 在 processors 最前面插队一个自己的脚本
  engine/processors/@before 0: lua_processor@my_script
  
  # 在 filters 第二行替换成这个值，注意不能换行加小短线
  engine/filters/@1: lua_filter@my_filter
```

</div>

---

## 4. 语法模型配置 (grammar)
控制语言模型的容错率和权重惩罚。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
grammar:
  language: wanxiang-lts-zh-hans
  collocation_max_length: 8
  collocation_min_length: 2
  collocation_penalty: -15
  non_collocation_penalty: -5
  weak_collocation_penalty: -100
  rear_penalty: -10
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 修改惩罚权重参数，其余同理
  grammar/collocation_penalty: -8
```

</div>

---

## 5. 超级注释模块 (super_comment)
控制辅助码提示、错词提示的展示样式。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
super_comment:
  candidate_length: 2
  corrector_type: "〔comment〕"
  cand_type:
    user_phrase: ""
    sentence: "∞"
    phrase: ""
    table: ""
    user_table: ""
    completion: ""
    predict: ""
    abbrev: ""
    fallback: "~"
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 更改包裹括号的样式
  super_comment/corrector_type: "【comment】"
  
  # 修改生效候选长度
  super_comment/candidate_length: 3

```

</div>

---

## 6. 超级处理器 (super_processor)
控制退格限制、空格联想、以词定字等行为。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
super_processor:
  enable_backspace_limit: true
  enable_tone_fallback: true
  select_character: "[,]"
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 关闭退格限制
  super_processor/enable_backspace_limit: false
  
  # 更改以词定字快捷键为分号和单引号
  super_processor/select_character: ";'"
```

</div>

---

## 7. 专属预测联想 (user_predict)
控制上下文联想数量、词库寿命和特定分类调频。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
user_predict:
  db_name: lua/predict
  max_candidates: 10
  expiry_days: 90
  custom_classifiers:
    - 个只名位口头匹条群批伙
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 修改最大候选显示数量
  user_predict/max_candidates: 5
  
  # 向量词列表追加新规则
  user_predict/custom_classifiers/+: 
    - "卷幅节堂门帖"
```

</div>

---

## 8. 超级提示模块 (super_tips)
管理符号、翻译、车牌等候选提示。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
super_tips:
  db_name: "lua/tips"
  tips_key: "comma"
  files:
    - lua/data/tips_show.txt
  disabled_types:
    - "禁用类型A"
    - "禁用类型B"
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 追加用户自己的 tips 文件
  super_tips/files/+: 
    - lua/data/my_tips.txt
  
  # 禁用某种类型的提示
  super_tips/disabled_types/+: 
    - "符号"
```

</div>

---

## 9. 增强替换器 (super_replacer)
简繁转换、Emoji、中英翻译的触发引擎。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
super_replacer:
  db_name: lua/replacer
  delimiter: "|"
  chain: true
  rules:
    - option: emoji
      mode: append
      tags: [abc]
      prefix: "_em_"
      files:
        - lua/data/emoji.txt
    # 后面省略...
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 追加一个新的替换规则 (例如颜文字)
  super_replacer/rules/+:
    - option: true
      mode: append
      tags: [abc]
      prefix: "_kaomoji_"
      files: [ lua/data/kaomoji.txt ]
      # 这里一般都是以一个组合出现，这样一个段落一个段落增加

  # 如果希望对某一个现有的文件进行自定义追加文件
  # 也就是在第二组里面文件后面加一行文件，原来的还在
  super_replacer/rules/@1/files/+: 
    - lua/data/my_custom_en.txt
```

</div>

---

## 10. 字符集过滤 (charset)
控制生僻字开关的白名单与黑名单。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
charset:
  - option: charset_filter
    base: a  #可以填入多个类别如aj
    addlist:
      - "诶濛硷氽尛躝〇冇吔磺咗囧屌鲶芶咲畑垅𰻝𰻞龍朙頔雲"
    blacklist: []
  - option: s2t
    base: fa
    addlist: []
    blacklist: []
  - option: s2hk
    base: ha
    addlist: []
    blacklist: []
  - option: s2tw
    base: ta
    addlist: []
    blacklist: []
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 小字集的白名单里修改特定生僻字
  # 注意这个值可只是个值不是表，下
  # 面这样写就意味着白名单只有两个字了
  # 如果想要自带+你的，则需要复制原来的再写上你的
  charset/@0/addlist:
    - "𰻝𰻞"
```

</div>

---

## 11. 时间与动态格式化 (date_formats 等)
/sj、/rq 的输出格式组合。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
date_formats:
  - "Y年m月d日"
  - "Y-m-d"
  - "Y/m/d"
  - "Y.m.d"
  - "Ymd"
  - "Y年n月j日"
  - "y年n月j日"
  - "n月j日"
time_formats:
  - "H:M"
  - "H点M分"
  - "H:M:S"
  - "H时M分S秒"
  - "AI:M"
  - "I:M P"
datetime_formats:
  - "Y-m-d H:M:S"
  - "Y-m-dTH:M:S O"
  - "YmdHMS"
  - "Y年m月d日 H点M分"
  - "y/m/d I:M p"
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 这个要根据用途改变写patch的方法
  # 由于数组的顺序和类型意味着最终候选
  # 因此这里我们不去使用高级语法
  # 而是原封不动拿过来修改，整体覆盖
date_formats:
  - "Y年m月d日"
  - "Y-m-d"
  - "Y/m/d"
  - "Y.m.d"
time_formats:
  - "H:M"
  - "H点M分"
datetime_formats:
  - "Y-m-d H:M:S"
  - "Y-m-dTH:M:S O"
  # 就像这样，我们减少了候选，只保留我们用到的
```

</div>

---

## 12. 声调下标映射 (tone_preedit)
控制带声调输入时数字变上标的映射逻辑。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
tone_preedit:
  "7": "¹"
  "8": "²"
  "9": "³"
  "0": "⁴"
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 如果想改回常规数字
  tone_preedit/7: "1"
  tone_preedit/8: "2"
```

</div>

---

## 13. 快捷排序置顶 (super_sequence)
手动调整候选词位移的快捷键。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
super_sequence:  # Lua 配置：手动排序的快捷键 super_sequence.lua，不要用方向键，各种冲突，一定要避免冲突
  db_name: "lua/sequence"
  up: "Control+j"    # 上移
  down: "Control+k"  # 下移
  reset: "Control+l" # 重置
  pin: "Control+p"   # 置顶
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 如果加入了shift那么字母就要变成大写避免冲突
  super_sequence/up: "Control+Shift+J"

```

</div>

---

## 14. 自动快符与成对符号 (quick_symbol & paired)
字母触发符号，以及斜杠 `\` 触发成对括号。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
quick_symbol_text:
  trigger: "^([a-z])/$"
  symkey:
    w: "？"

paired_symbols:
  trigger: "\\"
  symkey:
    a: "[]"
  # 这里只是省略，26字母都要写全，便于自己管理
  # 触发方式修改成了分好引导+单字母上屏
  # 其余字母键按需求修改

```

```yaml title="右：wanxiang.custom.yaml"
patch:
  quick_symbol_text:
  trigger: "^;([a-z])$"
  symkey:
    a: "[]"
    ...
  # 这里只是省略，26字母都要写全，便于自己管理
  # 触发方式修改成了分好引导+单字母上屏
  # 其余字母键按需求修改

  # 想要单独修改 a/ 触发的快符也行
  quick_symbol_text/symkey/a: "！！！"
  
  # 新增一个成对符号映射 \my
  paired_symbols/symkey/my: "【【】】"
```

</div>

---

## 15. 输入统计与计算器 (input_stats & recognizer)
时光机统计与 V 模式计算器。

> **注意**：万象拼音没有顶层 `calculator:` 配置块。超级计算器（V 引导）由 `recognizer/patterns/calculator` 正则前缀控制；数字金额大写（R 引导）由 `recognizer/patterns/number` 正则前缀控制，并响应 `lua_translator@*wanxiang.number_translator`。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
input_stats:
  triggers:
    today: "/rtj"

recognizer:
  patterns:
    calculator: "^V.*$"  # 超级计算器功能引导（V 前缀）
    number: "^R[0-9]+[.]?[0-9]*"  # 数字金额大写（R 前缀）
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 修改查今日统计的触发词
  input_stats/triggers/today: "jrtj"
  
  # 修改超级计算器触发前缀（默认 V，一般不建议修改）
  recognizer/patterns/calculator: "^V.*$"
  # 修改数字金额大写触发前缀（默认 R，一般不建议修改）
  recognizer/patterns/number: "^R[0-9]+[.]?[0-9]*"
```

</div>

---

## 16. 主拼音翻译器 (translator)
掌控核心词库行为，也是 Rime 的心脏。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
translator:
  dictionary: wanxiang
  enable_completion: true
  enable_user_dict: true
  core_word_length: 4
  ...
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 替换主词库
  translator/dictionary: my_custom_dict
  
  # 关闭系统自动记录用户词调频
  translator/enable_user_dict: false
  # comment_format和preedit_format是表其他都是简单的键值对
  # 其他雷同，这里主要是多理解参数功能
```

</div>

---

## 17. 外挂词典组合 (custom_phrase 等)
自定义短语、混合词汇、英文的配置。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
custom_phrase:
  user_dict: custom_phrase
  db_class: stabledb

wanxiang_english:
  english_spacing: smart
  trigger: "\\"
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 修改英文自动加空格模式为全开
  wanxiang_english/english_spacing: after
  
  # 更改自定义短语词典名称，更新不会被覆盖
  custom_phrase/user_dict: custom_phrasexxx
```

</div>

---

## 18. 部件反查与检索 (wanxiang_reverse / lookup)
拆字反查前缀及辅助筛选 tag。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
wanxiang_reverse:
  prefix: "`"

wanxiang_lookup:
  tags: [ abc, add_user_dict ]
  key: "`"
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 将反查前缀改为;当然了两个可以不一样
  wanxiang_reverse/prefix: ";"
  wanxiang_lookup/key: ";"
```

</div>

---

## 19. 正则指令分发 (recognizer)
处理特定前缀引导指令的正则表达式。

> **注意**：`recognizer/patterns` 中各前缀的含义——`V` 为超级计算器、`R` 为数字金额大写、`N` 为日期、`U` 为 Unicode 码点、`C` 为 Compose 合成、`/sym` 为超级符号、`/emoji` 为超级表情。请勿混淆 `number`（`R` 金额大写）与日期（`N`）前缀。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
recognizer:
  patterns:
    punct: "^/([0-9]|10|[A-Za-z]+)$"
    number: "^R[0-9]+[.]?[0-9]*"  # R 引导：数字金额大写
    calculator: "^V.*$"  # V 引导：超级计算器
    email: "^[A-Za-z][-_.0-9A-Za-z]*@.*$"
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 更改数字金额大写的触发前缀（默认 R，一般不建议修改）
  recognizer/patterns/number: "^R[0-9]+[.]?[0-9]*"
    # 按需增加了一个原来没有的键xxx，并写上值
  recognizer/patterns/xxx: "^YYY[0-9]+[.]?[0-9]*"
```

</div>

---

## 20. 快捷键与标点映射 (key_binder / punctuator)
快捷键定义、翻页控制与标点替换。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
punctuator:
  digit_separators: ",.:"

key_binder:
  import_preset: default  # 从 default.yaml 继承通用的
  shijian_keys: ["/", "o"]
  bindings:
    - { when: has_menu, accept: minus, send: Page_Up }
    - { when: has_menu, accept: equal, send: Page_Down }
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 去除字母 o 作为时间引导，避免冲突
  key_binder/shijian_keys: ["/"]
  
  # 追加快捷键：用逗号和句号翻页
  key_binder/bindings/+: 
    - { when: paging, accept: comma, send: Page_Up }
    - { when: has_menu, accept: period, send: Page_Down }
  # 但这种写法原来的- =翻页还能用
  # 因此我们可以用局部替换法，原来等于号翻页位于0,1
  key_binder/bindings/@0: { when: paging, accept: comma, send: Page_Up }
  key_binder/bindings/@1: { when: has_menu, accept: period, send: Page_Down }

  # 但一定要注意import_preset是一个大坑，他会把default里面快捷键导入
  # 假设里面也有-=翻页他将会插入到所有的前面，也就是说我们给主方案的
  # patch即使替换了原来的，那么最终还是会有两种翻页方式
  # 此时我们需要同时对default.yaml进行patch，写入default.custom.yaml
  # 这样才能真正解放-=按键，99%的用家不能弄清这里面的门道
  # 只能说能用就行了，两个就两个吧！
```

</div>

---

## 21. 编辑器与导航 (editor / navigator)
退格、回车键等基础按键的行为逻辑。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
editor:
  bindings:
    space: confirm
    Return: commit_raw_input

navigator:
  bindings:
    Left: left_by_char_no_loop
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 修改回车键为：上屏转译后的文字
  # 没啥好说的，参照方案注释设定合适的值即可
  editor/bindings/Return: commit_script_text
```

</div>

---

## 22. 拼写器 (speller)
包含字母表、模糊音、双拼转换规则的底层设置。

> **注意**：`speller` 没有 `visual_delimiter` 字段，拼音之间的分隔符由 `delimiter` 控制（其第二个字符为手动分隔符，如 `'`）。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
speller:
  alphabet: zyxwv...
  delimiter: " '"
  algebra:
    __patch:
      - wanxiang_algebra:/base/全拼
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 末尾增加模糊音规则，注意只是示例，是否在最后要看实际情况
  speller/algebra/+:
    - derive/^z/zh/
  # 如果把这个原始段落拿过来修改替换则去掉/+即可全局替换这些正则
  # 更多的写法参考万象的custom文件夹里面例子
  # 通过单一文件列出多种段落，再依次引用，能做到简单的功能开关切换以及做测试
```

</div>

---

## 23. 自造词模块 (user_dict_set / add_user_dict)
控制 `` 引导的手动造词功能。

<div class="grid" markdown>

```yaml title="左：wanxiang.schema.yaml"
add_user_dict:
  tag: add_user_dict
  prefix: "``"
  enable_auto_phrase: true
```

```yaml title="右：wanxiang.custom.yaml"
patch:
  # 关闭 lua 的无感造词功能
  add_user_dict/enable_auto_phrase: false
  # 其余同
```

</div>