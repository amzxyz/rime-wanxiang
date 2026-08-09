### Super Replacer 增强替换器配置手册

`super_replacer.lua` 是万象用于候选替换、派生、注释、简码插队以及整句转换的统一 Filter。

它会把多个 TXT 数据源构建到共享 LevelDB 中，再根据当前方案状态、输入类型、Segment Tag 和规则顺序决定哪些规则参与处理。

当前主要支持四种模式：

```text
append   新增候选
replace  替换候选
comment  生成候选注释
abbrev   按输入编码查询简码并插入候选
```

---

#### 1. 根节点全局参数

当前 `super_replacer` 根节点实际支持以下全局参数：

| 参数名 | 数据类型 | 说明 | 当前万象配置 / Lua 缺省值 |
| :--- | :--- | :--- | :--- |
| **`db_name`** | `string` | Super Replacer 使用的 LevelDB 名称。多个万象相关方案可以共享同名数据库。 | `lua/replacer` |
| **`comment_format`** | `string` | `append` / `replace` 派生候选需要附加来源注释时的格式模板，`%s` 为内容占位符；`comment` 模式最终注释也使用此格式。 | `"〔%s〕"` |
| **`chain`** | `boolean` | 是否启用串行替换。`true` 时，前一条 `replace` 产生的主结果继续交给后续规则查询；`false` 时，各规则都以原候选文本为查询对象。 | 万象当前配置 `true`；Lua 未配置时为 `false` |

!!! warning "当前没有 delimiter 根参数"
    旧版说明中的：

    ```yaml
    super_replacer/delimiter: "|"
    ```

    当前 Lua 已不再读取这个参数，应从自定义配置和文档中删除。

    Super Replacer 内部的数据分隔方式现在是固定的，具体格式见后文“数据文件编写规范”。

---

#### 2. `chain`：串行与并行的区别

`chain` 主要影响普通的 `append / replace / comment` 规则。

##### `chain: true`

后续规则查询时使用当前已经被前一条 `replace` 修改后的文本。

例如：

```text
软件
 ↓ s2t
軟件
 ↓ t2hk
軟件 / 香港字形结果
```

因此简体转通繁、再转港繁或台繁这类连续转换适合使用流水线模式。

##### `chain: false`

每条规则都直接查询原候选：

```text
原候选 ─→ 规则 A
       ├→ 规则 B
       └→ 规则 C
```

前一条规则产生的替换文本不会成为后一条规则的查询输入。

!!! note "abbrev 不依赖 chain 查询输入"
    `abbrev` 会根据当前输入编码单独查询简码数据库，再把命中的结果插入候选序列。

    因此它与普通候选的 `replace` 流水线属于不同处理路径。

---

#### 3. 四种核心模式 (`mode`)

| 模式 | 查询对象 | 主要行为 | 典型用途 |
| :--- | :--- | :--- | :--- |
| **`append`** | 候选文本 | 保留原候选，同时新增映射结果 | Emoji、同义派生、其他扩展候选 |
| **`replace`** | 候选文本 | 用映射结果替换原候选；流水线开启时首个结果继续传给下一规则 | 简繁、港繁、台繁等文字转换 |
| **`comment`** | 候选文本 | 不改变候选文字，把映射结果整理为候选注释 | 翻译、释义、提示 |
| **`abbrev`** | 当前输入编码 | 直接按编码查询数据，并按 `abbrev_rule` 插入候选 | 简码、固定短语、英文简码 |

---

#### 4. `append`：新增候选

例如数据中存在：

```text
哈哈<Tab>😄
```

规则：

```yaml
- option: emoji
  mode: append
  comment_mode: none
  tags: [abc]
  prefix: "_em_"
  files:
    - lua/data/emoji.txt
```

输入“哈哈”时，原候选仍然保留，同时新增：

```text
哈哈
😄
```

如果一个 key 对应多个结果，则会依次生成多个新增候选。

---

#### 5. `replace`：替换候选

例如：

```yaml
- option: [s2t, s2hk, s2tw]
  mode: replace
  comment_mode: comment
  sentence: true
  tags: [abc]
  prefix: "_s2t_"
  files:
    - lua/data/STCharacters.txt
    - lua/data/STPhrases.txt
```

当规则命中时，候选文本会被对应数据替换。

在：

```yaml
chain: true
```

的情况下，映射值中的**第一个结果**会成为新的主候选文本，并继续参与后续替换规则。

如果同一个 key 配置了多个映射结果：

```text
A<Tab>B\tC
```

流水线模式下：

* `B` 成为主替换结果；
* `C` 作为额外候选输出。

---

#### 6. `comment`：生成候选注释

`comment` 模式不会改变候选本身，只读取数据文件中的映射值作为注释。

例如：

```text
hello<Tab>你好\t哈喽
```

规则：

```yaml
- option: chinese_english
  mode: comment
  tags: [abc]
  prefix: "_en_"
  files:
    - lua/data/english_chinese.txt
```

候选可以显示为：

```text
hello〔你好 哈喽〕
```

多个注释结果最终使用空格连接，并统一套用：

```yaml
comment_format: "〔%s〕"
```

!!! note "与输入编码相同的注释会被忽略"
    `comment` 模式在生成注释时，会跳过与当前输入编码完全相同的值，避免把已经输入的编码再次作为无意义注释显示。

---

#### 7. `abbrev`：简码与自定义编码

`abbrev` 与前三种模式不同，它查询的是**输入编码**，不是候选文字。

例如数据：

```text
zm<Tab>怎么\t在吗
```

规则：

```yaml
- option: abbrev
  mode: abbrev
  tags: [abc]
  prefix: "_abbr_"
  abbrev_rule: "1,6"
  files:
    - lua/data/abbrev.txt
```

输入：

```text
zm
```

后，Super Replacer 会直接查询：

```text
_abbr_zm
```

再将命中的简码候选插入正常候选序列。

---

#### 8. `abbrev_rule`：简码插入规则

格式：

```text
"前置数量, 起始位置"
```

例如：

```yaml
abbrev_rule: "1,6"
```

表示：

* 数据值中的前 `1` 个候选属于优先候选；
* 从第 `6` 个候选位置开始插入。

例如：

```text
zm<Tab>怎么\t在吗\t怎么了
```

其中第一个结果“怎么”属于固定插入候选，其余结果作为后备简码候选。

再例如：

```yaml
abbrev_rule: "2,3"
```

表示前两个结果从第 3 个候选位置开始依次插入。

未配置时，Lua 使用：

```text
1,1
```

作为缺省值。

!!! note "后备简码并不等于永远全部显示"
    `abbrev` 会结合当前正常候选序列进行去重和插入。

    当前面设定的简码结果已经成功插入正常候选序列后，同组后备结果不会无条件全部追加；当缺少合适的正常候选结构时，后备结果才承担兜底显示作用。

---

#### 9. `comment_mode`：派生候选如何处理来源注释

`comment_mode` 主要用于 `append` 和 `replace`。

当前 Lua 真正单独处理的值是：

| 值 | 行为 |
| :--- | :--- |
| **`none`** | 不为派生候选附加来源注释；流水线 `replace` 的主结果会清空原 comment |
| **`text`** | 把**原候选文本**作为新候选注释，并套用 `comment_format` |
| **`comment`** | 把**原候选已有 comment** 作为新候选注释，并套用 `comment_format` |

例如：

```yaml
comment_mode: text
```

原候选：

```text
hello
```

映射为：

```text
你好
```

可以得到：

```text
你好〔hello〕
```

##### 关于旧配置中的 `append`

当前万象 Schema 中部分简繁规则仍存在：

```yaml
comment_mode: append
```

但当前 Lua 并没有把 `append` 作为独立分支处理。

在 `chain: true + mode: replace` 的主结果场景中，它会因为“不清空原 comment”而表现为保留原注释，因此现有简繁流水线仍可使用。

但如果新建自定义规则，希望明确继承原候选 comment，建议使用：

```yaml
comment_mode: comment
```

而不是继续把 `append` 当成通用注释模式。

---

#### 10. `rules` 规则参数

当前每一条 `rules` 支持以下主要参数：

| 参数名 | 数据类型 | 说明 |
| :--- | :--- | :--- |
| **`option` / `options`** | `string / list / boolean` | 规则触发条件。可以绑定一个或多个 Rime Option；写 `true` 表示常驻启用 |
| **`mode`** | `string` | `append`、`replace`、`comment`、`abbrev`；缺省为 `append` |
| **`comment_mode`** | `string` | 派生候选的来源注释策略，推荐使用 `none`、`text`、`comment` |
| **`sentence`** | `boolean` | 对候选文本启用整句 FMM 转换；主要用于 `append / replace` |
| **`tag` / `tags`** | `string / list` | 限制规则只在指定 Segment Tag 中生效 |
| **`prefix`** | `string` | 数据库 key 前缀，用于隔离不同功能的数据 |
| **`file` / `files`** | `string / list` | 数据源文件；支持一个或多个 TXT 文件 |
| **`cand_type`** | `string` | 自定义生成候选的 `type`；未指定时普通派生默认 `derived`，简码默认 `abbrev` |
| **`abbrev_rule`** | `string` | 仅 `abbrev` 使用，格式 `"数量,位置"`，缺省 `"1,1"` |
| **`t9_optimization`** | `boolean` | 构建数据时把字母 key 转为九宫格数字，并为候选保存原始编码 Preedit |
| **`only_types`** | `list` | 仅在当前输入类型属于列表时加载这条规则 |
| **`exclude_types`** | `list` | 当前输入类型属于列表时跳过这条规则 |

---

#### 11. `option / options`：规则开关

可以绑定单个 Option：

```yaml
option: emoji
```

也可以绑定多个：

```yaml
option: [s2t, s2hk, s2tw]
```

或：

```yaml
options: [s2t, s2hk, s2tw]
```

多个 Option 的判断关系是：

**其中任意一个为 `true`，这条规则即可启用。**

如果希望规则始终生效：

```yaml
option: true
```

!!! warning "rules 不能省略 option"
    当前 Lua 在初始化规则时，如果 `option / options` 没有解析出任何触发条件，会直接跳过这条规则。

    因此需要常驻执行的规则，应明确写：

    ```yaml
    option: true
    ```

---

#### 12. `tag / tags`：限制生效 Segment

例如：

```yaml
tags: [abc]
```

表示只有当前 Segment 带有 `abc` Tag 时，这条规则才执行。

也支持：

```yaml
tag: abc
```

以及多 Tag：

```yaml
tags: [abc, add_user_dict]
```

多个 Tag 采用“任意命中”逻辑。

如果不配置 `tag / tags`，则不会额外进行 Tag 限制。

---

#### 13. `only_types / exclude_types`：按输入类型加载规则

这是当前版本已经支持、旧说明中缺失的参数。

它们根据万象当前的拼音 / 键盘类型决定一条规则是否参与运行。

##### `only_types`

只允许指定输入类型加载：

```yaml
only_types: [t9]
```

表示仅九宫格方案加载这条规则。

也可以：

```yaml
only_types: [zrm, flypy]
```

表示仅自然码、小鹤双拼加载。

##### `exclude_types`

排除指定输入类型：

```yaml
exclude_types: [pinyin]
```

表示全拼不加载这条规则，其他输入类型仍可使用。

当前万象常见输入类型标识包括：

```text
pinyin
zrm
flypy
mspy
sogou
abc
ziguang
pyjj
gbpy
zrlong
hxlong
ltsp
lxsq
sdpy
t9
```

!!! warning "only_types / exclude_types 必须写成列表"
    当前 Lua 对这两个参数只读取 YAML List。

    正确：

    ```yaml
    only_types: [t9]
    exclude_types: [pinyin]
    ```

    不建议写成单个字符串：

    ```yaml
    only_types: t9
    ```

    这种写法当前不会按照预期执行输入类型筛选。

---

#### 14. `prefix`：同一数据库中的数据隔离

Super Replacer 的不同功能可以共用：

```yaml
db_name: lua/replacer
```

真正用于区分 Emoji、翻译、简繁、简码等数据的是每条规则的：

```yaml
prefix
```

例如：

```text
_em_
_en_
_s2t_
_s2hk_
_abbr_
```

数据库查询时实际使用：

```text
prefix + key
```

因此：

```text
_em_火
_s2t_火
_abbr_h
```

属于完全不同的数据记录。

!!! tip "重复判断也是按 prefix + key 维度区分"
    同一个业务 key 只要位于不同 `prefix` 下，就属于不同功能的数据，不会因为 key 文本相同而互相冲突。

---

#### 15. `sentence`：整句 FMM 转换

普通模式优先对整个候选文本进行精确匹配。

如果没有精确命中，并且：

```yaml
sentence: true
```

则会进一步启用 FMM 分段转换。

例如简繁转换中：

```yaml
- option: [s2t, s2hk, s2tw]
  mode: replace
  sentence: true
  prefix: "_s2t_"
```

可以对较长候选逐段查找转换数据，而不是要求整句话必须作为一个完整 key 存在。

当前 FMM 会优先匹配较长词条，再处理较短片段和单字，因此适合简繁、地区字形等文字转换任务。

---

#### 16. `cand_type`：自定义候选类型

普通派生候选未设置 `cand_type` 时使用：

```text
derived
```

`abbrev` 未设置时使用：

```text
abbrev
```

可以自行覆盖：

```yaml
cand_type: emoji
```

或：

```yaml
cand_type: t9
```

该字段主要用于区分候选来源，方便后续 Filter、注释逻辑或其他处理模块识别不同类型的候选。

---

#### 17. 数据文件编写规范

当前数据源格式已经固定，不再使用旧版可配置 `delimiter: "|"`。

每一行必须满足：

```text
key<真实 Tab>value
```

也就是：

**第一个字段分隔必须使用真正的 Tab 制表符。**

例如：

```text
火	🔥
apple	苹果
zm	怎么
```

### 一个 key 对应多个候选

多个候选不再使用 `|` 分隔，而是在 value 内使用**字面量 `\t`**：

```text
zm	怎么\t在吗\t怎么了
```

这里需要特别区分：

* `key` 与 `value` 之间：**真实 Tab**
* 多个 value 之间：**两个普通字符 `\` + `t`**

可以概念化写成：

```text
zm<Tab>怎么\t在吗\t怎么了
```

!!! danger "value 中不要再放第二个真实 Tab"
    当前解析器只允许第一处字段分隔使用真实 Tab。

    如果 value 部分再次出现真正的 Tab，这一行会被判定为无效数据。

    多候选必须使用字面量：

    ```text
    \t
    ```

    进行分隔。

### 同 key 多行不会自动合并

旧说明中的：

```text
zm<Tab>怎么
zm<Tab>在吗
```

“导入时自动合并”已经不符合当前实现。

普通数据构建时，同一 `prefix + key` 重复出现，只保留先写入的记录，后续同 key 不会继续自动拼接。

因此需要多个候选时，应直接写成同一行：

```text
zm<Tab>怎么\t在吗
```

---

#### 18. T9 Optimization：九宫格简码构建

`t9_optimization` 主要用于把现有字母简码数据直接复用到九宫格。

例如：

```yaml
- option: true
  mode: abbrev
  only_types: [t9]
  t9_optimization: true
  prefix: "_t9_"
  files:
    - lua/data/abbrev.txt
```

源文件仍然维护字母编码：

```text
zdtp	重大突破
```

构建时会按照九宫格映射：

```text
abcdefghijklmnopqrstuvwxyz
22233344455566677778889999
```

把：

```text
zdtp
```

转换为对应数字 key。

同时，候选内部会保存：

```text
候选文本==原始字母编码
```

用于恢复候选 Preedit。

例如数据库中的逻辑结果可以理解为：

```text
数字编码 → 重大突破==zdtp
```

!!! info "T9 的 == 是内部 Preedit 分隔，不需要手工维护"
    普通源文件仍然只需要写：

    ```text
    zdtp<Tab>重大突破
    ```

    开启 `t9_optimization: true` 后，构建过程会自动追加：

    ```text
    ==zdtp
    ```

    不需要在 TXT 数据中手工添加。

### 九宫格编码碰撞会自动聚合

多个不同字母编码可能映射成同一串 T9 数字。

当前构建逻辑会识别这种数字 key 碰撞，并将这些不同来源的候选聚合到同一个数字编码下，同时分别保存各自的原始字母 Preedit。

这属于 T9 转换产生的正常聚合，与普通数据文件中“重复 key 多行”不是同一机制。

---

#### 19. 多方案联合数据库

当前 Super Replacer 不再只根据正在运行的单一方案构建数据。

它会读取已经部署的 `build/default.yaml`，检查当前启用的万象相关方案，并合并这些方案中的 Super Replacer 数据任务。

当前参与联合处理的方案范围包括：

```text
wanxiang_pro
wanxiang
wanxiang_english
wanxiang_t9
wanxiang_t9i
```

因此多个已启用方案可以共享同一个：

```yaml
db_name: lua/replacer
```

而不需要每个方案分别维护一份重复数据库。

联合构建时，完全相同的：

```text
数据文件 + prefix + T9 转换方式
```

会进行任务去重。

---

#### 20. 一个较完整的规则示例

```yaml
super_replacer:
  db_name: lua/replacer
  comment_format: "〔%s〕"
  chain: true

  rules:
    # Emoji 派生
    - option: emoji
      mode: append
      comment_mode: none
      tags: [abc]
      prefix: "_em_"
      files:
        - lua/data/emoji.txt

    # 简体 → 通繁，作为后续港繁 / 台繁的流水线基础
    - option: [s2t, s2hk, s2tw]
      mode: replace
      comment_mode: comment
      sentence: true
      tags: [abc]
      prefix: "_s2t_"
      files:
        - lua/data/STCharacters.txt
        - lua/data/STPhrases.txt

    # 常规简码：排除全拼
    - option: abbrev
      exclude_types: [pinyin]
      mode: abbrev
      tags: [abc]
      prefix: "_abbr_"
      abbrev_rule: "1,6"
      files:
        - lua/data/abbrev.txt
        - lua/data/chengyu.txt

    # T9 专用简码
    - option: true
      only_types: [t9]
      mode: abbrev
      tags: [abc]
      prefix: "_t9_abbr_"
      abbrev_rule: "1,3"
      t9_optimization: true
      cand_type: t9
      files:
        - lua/data/abbrev.txt
```

---

#### 21. 如何通过 Custom Patch 修改？

如果只是修改现有规则中的某个参数，可以按列表索引 Patch。

例如修改第一条规则的 Emoji 数据：

```yaml
patch:
  "super_replacer/rules/@0/files":
    - lua/data/my_emoji.txt
```

修改全局数据库名：

```yaml
patch:
  "super_replacer/db_name": lua/my_replacer
```

### 追加一条新规则

`rules` 是列表。

追加一条规则时，应把新增规则作为一个完整列表项加入：

```yaml
patch:
  "super_replacer/rules/+":
    - option: true
      mode: append
      comment_mode: none
      tags: [abc]
      prefix: "_ki_"
      files:
        - lua/data/kaomoji.txt
```

!!! warning "追加列表项时注意 YAML 层级"
    `super_replacer/rules/+` 的目标本身是一个列表，因此新增完整 Rule 时建议保留：

    ```yaml
    - option: ...
    ```

    这一层列表短横线。

    如果只是修改已有规则的某一个字段，则使用：

    ```yaml
    super_replacer/rules/@索引/字段
    ```

    直接定位即可。

---

#### 22. 当前参数总表

##### 根节点

```text
db_name
comment_format
chain
rules
```

##### Rule 通用参数

```text
option / options
mode
comment_mode
sentence
tag / tags
prefix
file / files
cand_type
only_types
exclude_types
```

##### abbrev / T9 相关

```text
abbrev_rule
t9_optimization
```

当前版本**没有**需要用户配置的：

```text
super_replacer/delimiter
```

数据候选分隔也已经固定为字面量：

```text
\t
```

---

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>Super Replacer 的配置核心是：用 option 决定何时工作，用 tag 与输入类型限定作用范围，用 prefix 隔离数据，再由 mode 决定候选如何输出。</em>
</div>
