# Rime 设计逻辑与配置思路：从“命名空间”理解方案结构

**前言：**

刚接触 Rime 配置时，最容易产生的困惑并不是“某一行语法看不懂”，而是**不知道这些配置块之间究竟有什么关系**。

一个完整方案通常同时包含方案信息、依赖、状态开关、按键处理、分段、翻译、过滤以及大量 Lua 组件。单独看每一段并不复杂，但如果没有整体结构，很容易陷入“知道这个参数是什么意思，却不知道它为什么写在这里”的状态。

理解 Rime 可以先抓住一条主线：

**方案声明了哪些组件 → Engine 按顺序调用这些组件 → 每个组件再从自己的配置节点中读取参数。**

本文从这个角度出发，用万象方案中的实际结构说明 Rime 的组织方式。

---

## 一、方案基础信息与依赖 (Dependencies)

打开一个方案文件，例如 `wanxiang.schema.yaml`，首先通常会看到 `schema:` 段落。

这里主要用于声明方案本身的信息，例如方案 ID、名称、版本、作者、描述，以及当前方案依赖的其他方案。

```yaml
# 方案说明
schema:
  schema_id: wanxiang
  name: 万象拼音
  version: "LTS"
  author:
    - amzxyz
  description: |
    请勾选【万象拼音】以启用，万象拼音标准版本，带声调的词库，支持语法模型，全拼、简拼、整句、声调辅助筛选。
    【文本框输入：/pinyin全拼，/zrm自然码,/flypy小鹤，/mspy,/sogou,/pyjj等，详见README.md】
  dependencies:
    - wanxiang_mixedcode    # 混合编码
    - wanxiang_reverse      # 部件拆字、反查及辅码
    - wanxiang_english      # 英文
```

### `dependencies` 应该怎么理解？

`dependencies` 用于声明当前方案依赖的其他 Rime 方案。

当主方案部署时，这些依赖方案也会被纳入部署流程，从而保证主方案中引用到的相关词典、翻译器或反查数据已经准备好。

例如万象主方案可能通过：

* `table_translator@wanxiang_english`
* `table_translator@wanxiang_mixedcode`
* `reverse_lookup_translator@wanxiang_reverse`

去调用附属方案提供的数据。

因此，这些附属方案通常不需要全部作为独立的日常输入方案加入 `default.yaml` 的 `schema_list`。它们更多承担的是**被主方案调用的依赖角色**。

!!! tip "dependencies 与 schema_list 不是一回事"
    `dependencies` 解决的是“当前方案依赖哪些其他方案才能完整部署”。

    `schema_list` 解决的是“哪些方案出现在用户可以直接切换的方案列表中”。

    一个方案可以作为依赖参与部署，但不一定需要出现在日常方案切换列表中。

---

## 二、状态开关与选项组 (Switches)

继续往下，通常会看到 `switches:`。

它用于声明当前方案中的状态选项。按下 `Ctrl+`` 打开 Rime 方案选单时，其中很多可以切换的项目都来自这里。

### 1. 普通布尔开关

```yaml
switches:
  - name: ascii_mode
    states: [ 中文, 英文 ]
    #reset: 1

  - name: ascii_punct
    states: [ 中标, 英标 ]
```

可以这样理解：

* `name`：这个开关在 Rime 内部使用的 option 名称。
* `states`：分别描述关闭和开启状态在界面中显示的文字。
* `reset`：可选，用于指定方案初始化时的默认状态。

例如：

```yaml
reset: 0
```

表示初始化时设为第一个状态；

```yaml
reset: 1
```

表示初始化时设为第二个状态。

如果不设置 `reset`，实际状态是否延续上一次使用结果，还会受到前端及运行环境的状态管理方式影响。

### 2. 多选一的 Options 组

除了单个 `name` 对应的布尔开关，也可以定义一组互斥选项：

```yaml
switches:
  - options: [ s2s, s2t, s2hk, s2tw ]
    states: [ 简体, 通繁, 港繁, 臺繁 ]
```

这里不再使用单独的 `name`，而是使用 `options` 声明多个状态。

这类配置适合：

* 简体 / 通用繁体 / 香港繁体 / 台湾繁体
* 多种字符集模式
* 多种互斥的显示或转换状态

同一组选项通常只会保持其中一个处于当前状态。

### 3. 可见开关与快捷键切换

`switches` 负责声明方案中的状态选项，但并不意味着所有 option 都必须通过方案选单手动切换。

在 `key_binder` 或 Lua Processor 中，也可以直接对 option 执行：

* `toggle`
* `set_option`
* `unset_option`

因此可以把它理解为：

**`switches` 定义状态，`key_binder` 等组件决定用户如何操作这些状态。**

---

### 通过 Custom Patch 修改某个 Switch

`switches` 是一个列表，因此可以使用 Patch 的列表索引定位。

例如：

```yaml
switches:
  - name: ascii_mode
  - name: ascii_punct
```

其中：

* `@0` → 第 1 项
* `@1` → 第 2 项

如果要为第二项 `ascii_punct` 增加：

```yaml
reset: 1
```

可以在 `wanxiang.custom.yaml` 中写：

```yaml
patch:
  switches/@1/reset: 1
```

!!! warning "固定索引需要注意方案更新"
    `@1` 表示的是“当前列表中的第 2 项”，并不是永久绑定 `ascii_punct` 这个名称。

    如果以后上游方案调整了 `switches` 的排列顺序，这个索引可能会指向其他项目。因此使用数字索引的 Custom，在较大版本更新后应重新检查。

---

## 三、核心流水线：Engine 与四类组件

理解 Rime 方案结构，最重要的一段就是：

`engine:`

Rime 可以看作一条按阶段运行的输入处理流水线。最常见的四组组件是：

1. **`processors`**：接收和处理键盘事件。
2. **`segmentors`**：分析当前输入码，将不同片段划分并打上 tag。
3. **`translators`**：根据输入码生成候选。
4. **`filters`**：对已经生成的候选继续加工。

可以先记住一个大致方向：

**按键 → 分段 → 生成候选 → 处理候选**

### 1. Processors：先决定“这个按键怎么处理”

Processor 位于输入流程前端，主要负责键盘事件。

例如：

* 中英文切换
* 快捷键
* 拼写输入
* 标点
* 候选选择
* 光标移动
* 回车、空格、退格
* Lua 自定义按键逻辑

万象中的 Processor 配置示例：

```yaml
engine:
  processors:
    - lua_processor@*wanxiang.super_processor
    - lua_processor@*wanxiang.user_predict*P
    - lua_processor@*wanxiang.partial_commit
    - lua_processor@*wanxiang.super_tips
    - lua_processor@*wanxiang.super_sequence*P
    - ascii_composer
    - recognizer
    - key_binder
    - lua_processor@*wanxiang.key_binder
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor
```

这里最重要的是**顺序**。

同一个按键会依次经过 Processor 列表。前面的组件如果已经消费了这个按键，后面的组件可能就不会再得到相同的处理机会。

因此，Processor 不只是“有没有挂载”，还要关注“挂载在哪里”。

### 2. Segmentors：判断当前输入属于哪一类

Segmentor 负责把输入内容分成不同片段，并为这些片段添加 tag。

例如：

```yaml
  segmentors:
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - affix_segmentor@wanxiang_reverse
    - affix_segmentor@add_user_dict
    - punct_segmentor
    - fallback_segmentor
```

常见作用包括：

* `ascii_segmentor`：识别 ASCII 输入区域。
* `matcher`：与 `recognizer` 配合，根据规则识别特殊输入。
* `abc_segmentor`：处理常规拼写输入，并赋予 `abc` tag。
* `affix_segmentor@...`：处理具有前后缀特征的专用输入，例如反查、自造词。
* `punct_segmentor`：识别标点输入。
* `fallback_segmentor`：处理前面未被识别的剩余片段，因此一般放在靠后位置。

这里可以建立一个重要概念：

**tag 是 Segmentor 与 Translator / Filter 之间的重要连接条件。**

前面给输入片段打上什么 tag，后面的组件就可以根据 tag 决定自己是否处理。

### 3. Translators：把编码转换为候选

Translator 的职责是：

**输入一段已经识别好的编码，生成候选。**

万象中同时使用了多种 Translator：

```yaml
  translators:
    - punct_translator
    - script_translator
    - lua_translator@*wanxiang.user_predict*T
    - lua_translator@*wanxiang.version_display
    - lua_translator@*wanxiang.set_schema
    - lua_translator@*wanxiang.shijian
    - lua_translator@*wanxiang.unicode
    - lua_translator@*wanxiang.number_translator
    - lua_translator@*wanxiang.super_calculator
    - lua_translator@*wanxiang.input_statistics
    - table_translator@custom_phrase
    - table_translator@wanxiang_english
    - table_translator@wanxiang_mixedcode
    - reverse_lookup_translator@wanxiang_reverse
    - script_translator@add_user_dict
    - script_translator@user_dict_set
```

这些 Translator 的数据来源和用途并不相同：

* `script_translator`：用于基于音节表的拼音等输入方案。
* `table_translator`：从表格词典中查询候选。
* `reverse_lookup_translator`：用于反查。
* `punct_translator`：生成标点候选。
* `lua_translator`：由 Lua 自定义逻辑生成候选。

同一个输入片段可以同时被多个 Translator 处理，最终形成多个候选来源。

### 4. Filters：对候选做后处理

候选生成以后，还可以继续经过 Filter。

例如：

```yaml
  filters:
    - lua_filter@*wanxiang.auto_phrase
    - lua_filter@*wanxiang.super_lookup
    - lua_filter@*wanxiang.super_english
    - lua_filter@*wanxiang.charset_filter
    - lua_filter@*wanxiang.super_comment_preedit
    - lua_filter@*wanxiang.super_replacer
    - lua_filter@*wanxiang.super_filter
    - lua_filter@*wanxiang.super_sequence*F
    - lua_filter@*wanxiang.user_predict*F
    - uniquifier
```

Filter 可以用于：

* 修改候选文字
* 修改候选注释
* 字符集过滤
* 简繁转换
* 排序
* 上下文调频
* 去重

Filter 与 Processor 一样，**顺序非常重要**。

例如：

`uniquifier`

通常需要放在较后的位置，因为如果过早去重，后面的 Filter 就可能失去本来需要处理的候选。

---

### 万象 Engine 完整结构示例

下面保留一份更接近实际方案的 Engine 配置，方便对照理解组件顺序：

```yaml
# 输入引擎
engine:
  processors:
    - lua_processor@*wanxiang.super_processor            # KP 小键盘、字母选词、符号处理、分词等综合按键逻辑
    - lua_processor@*wanxiang.user_predict*P             # 用户预测相关 Processor
    - lua_processor@*wanxiang.partial_commit             # Ctrl+1~0 局部提交
    - lua_processor@*wanxiang.super_tips                 # 提示模块
    - lua_processor@*wanxiang.super_sequence*P           # 手动候选排序按键处理
    - ascii_composer                                     # 英文模式及中英文切换
    - recognizer                                         # 与 matcher 配合识别特殊输入模式
    - key_binder                                         # Rime 标准快捷键绑定
    - lua_processor@*wanxiang.key_binder                 # Lua 按键绑定扩展
    - speller                                            # 接收并编辑拼写输入
    - punctuator                                         # 标点处理
    - selector                                           # 候选选择与翻页
    - navigator                                          # 输入栏光标移动
    - express_editor                                     # 空格、回车、退格等编辑操作

  segmentors:
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - affix_segmentor@wanxiang_reverse
    - affix_segmentor@add_user_dict
    - punct_segmentor
    - fallback_segmentor

  translators:
    - punct_translator
    - script_translator
    - lua_translator@*wanxiang.user_predict*T
    - lua_translator@*wanxiang.version_display
    - lua_translator@*wanxiang.set_schema
    - lua_translator@*wanxiang.shijian
    - lua_translator@*wanxiang.unicode
    - lua_translator@*wanxiang.number_translator
    - lua_translator@*wanxiang.super_calculator
    - lua_translator@*wanxiang.input_statistics
    - table_translator@custom_phrase
    - table_translator@wanxiang_english
    - table_translator@wanxiang_mixedcode
    - reverse_lookup_translator@wanxiang_reverse
    - script_translator@add_user_dict
    - script_translator@user_dict_set

  filters:
    - lua_filter@*wanxiang.auto_phrase
    - lua_filter@*wanxiang.super_lookup
    - lua_filter@*wanxiang.super_english
    - lua_filter@*wanxiang.charset_filter
    - lua_filter@*wanxiang.super_comment_preedit
    - lua_filter@*wanxiang.super_replacer
    - lua_filter@*wanxiang.super_filter
    - lua_filter@*wanxiang.super_sequence*F
    - lua_filter@*wanxiang.user_predict*F
    - uniquifier
```

*实际组件、排列顺序和 Lua 模块以当前方案文件为准。阅读 Engine 时，重点不是一次记住所有组件，而是先判断它属于 Processor、Segmentor、Translator 还是 Filter。*

---

## 四、从“命名空间”理解组件配置

理解 Engine 后，就可以进一步理解 Rime 配置中经常出现的“命名空间”。

这里可以把它理解成：

**某个组件实例到哪里读取自己的配置。**

### 1. 内建组件通常有对应的默认配置节点

例如 Engine 中启用了：

```yaml
engine:
  processors:
    - speller
```

那么方案顶层通常会有：

```yaml
speller:
  alphabet: zyxwvutsrqponmlkjihgfedcba
  delimiter: " '"
```

这里的 `speller:` 就是拼写处理器使用的配置区域。

类似的还有：

* `recognizer:`
* `key_binder:`
* `punctuator:`
* `translator:`
* `menu:`

因此在读方案时，可以先在 Engine 中找到组件名称，再去寻找与它相关的顶层配置块。

### 2. `@` 用于给同类组件指定不同实例名称

当同一种组件需要挂载多次时，就不能让所有实例共用同一份参数。

例如：

```yaml
engine:
  translators:
    - table_translator@custom_phrase
    - table_translator@wanxiang_english
    - table_translator@wanxiang_mixedcode
```

这里三个组件的类型都是：

`table_translator`

但它们使用了不同的实例名称：

* `custom_phrase`
* `wanxiang_english`
* `wanxiang_mixedcode`

于是就可以分别配置：

```yaml
custom_phrase:
  dictionary: ""
  user_dict: custom_phrase
  db_class: stabledb

wanxiang_english:
  dictionary: wanxiang_english

wanxiang_mixedcode:
  dictionary: wanxiang_mixedcode
```

可以把：

`table_translator@custom_phrase`

拆成两部分理解：

**组件类型 `table_translator` + 实例名称 `custom_phrase`**

`@` 后面的名称用于区分同类组件的不同实例，也通常决定该实例对应的配置命名空间。

---

## 五、Lua 组件为什么看起来不一样？

万象中大量使用：

```yaml
lua_processor@*wanxiang.super_processor
lua_translator@*wanxiang.input_statistics
lua_filter@*wanxiang.super_replacer
```

Lua 组件的写法比普通内建组件多了一层 Lua 模块与导出对象的含义。

例如：

```yaml
lua_filter@*wanxiang.super_replacer
```

表示 Engine 中挂载的是一个 Lua Filter，而实际执行逻辑来自指定的 Lua 模块 / 导出对象。

此时配置读取方式不一定能简单套用：

“`@` 后面是什么，就一定读取同名顶层节点”

这一条。

原因是 Lua 脚本本身可以主动读取配置，例如通过自己的 `env`、命名空间或明确写死的配置路径访问：

```text
super_replacer/...
```

或者：

```text
input_stats/...
```

因此分析 Lua 组件时，通常需要同时看两处：

1. **Schema 中 Lua 组件是如何挂载的。**
2. **Lua 源码实际从哪个配置路径读取参数。**

!!! tip "分析 Lua 配置时不要只看组件名称"
    普通内建组件通常可以通过组件实例名快速找到对应配置节点。

    Lua 组件则可能自行决定读取哪个配置块，因此遇到 `lua_processor`、`lua_translator`、`lua_filter` 时，最好结合 Lua 源码中的 `config:get_*()`、命名空间初始化等逻辑一起判断。

---

## 六、Recognizer、Segmentor、Translator 为什么经常一起出现？

理解命名空间之后，还可以进一步看出 Rime 中另一种常见的连接方式：

**Recognizer 定义特殊编码 → Matcher / Affix Segmentor 打 tag → 对应 Translator 根据 tag 工作。**

例如反查流程大致可以理解为：

```text
按下反查引导符
    ↓
recognizer 识别出符合规则的输入
    ↓
matcher / affix_segmentor 标记为反查 tag
    ↓
reverse_lookup_translator 处理这个 tag
    ↓
生成反查候选
```

因此，配置一个功能时不能只看 Translator。

如果一个特殊 Translator 明明已经挂载，却完全不出候选，还需要继续检查：

* `recognizer` 是否识别到了输入
* `segmentor` 是否生成了正确 tag
* Translator 的 `tag` / `prefix` / `tips` 等参数是否匹配
* Engine 顺序是否正确

这也是为什么复杂 Rime 方案看起来像很多配置块互相分散：它们实际上是在通过**组件、命名空间和 tag** 共同组成一条处理链。

---

## 七、读一个陌生方案时，可以按什么顺序？

面对一个新的 `.schema.yaml`，不需要从第一行开始逐项研究。

可以按照下面的顺序快速建立结构：

### 第一步：看 `schema`

先确认：

* `schema_id`
* 方案名称
* `dependencies`

知道这是什么方案，以及它依赖哪些附属方案。

### 第二步：看 `switches`

确认当前方案提供哪些状态：

* 中英文
* 简繁
* 字符集
* Emoji
* 其他功能开关

### 第三步：看 `engine`

先不要研究参数，只看挂了哪些组件：

```text
processors
segmentors
translators
filters
```

大致判断整个方案有哪些功能。

### 第四步：找组件对应的配置块

例如看到：

```yaml
table_translator@custom_phrase
```

就继续找：

```yaml
custom_phrase:
```

看到：

```yaml
speller
```

就找：

```yaml
speller:
```

### 第五步：再追 `recognizer`、tag 和附属方案

如果是反查、特殊指令、自造词等功能，再继续追踪：

```text
recognizer
→ segmentor
→ tag
→ translator
```

### 第六步：Lua 单独看源码

看到：

```yaml
lua_filter@...
lua_processor@...
lua_translator@...
```

如果仅靠 Schema 无法判断配置来源，就打开对应 Lua 文件，查看它实际读取的配置路径。

---

## 结语

理解 Rime，不需要一次记住所有节点和参数。

更重要的是建立下面这套关系：

**Schema 决定方案结构  
→ Engine 决定启用哪些组件以及执行顺序  
→ Namespace 决定组件从哪里读取配置  
→ Recognizer / Segmentor / tag 决定输入被送到哪里  
→ Translator 生成候选  
→ Filter 对候选继续处理**

掌握这套框架后，再面对复杂方案时，就可以从 Engine 出发逐层追踪，而不是在大量 YAML 节点之间来回猜测。

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>读 Rime 配置的关键，是先找到组件，再找到组件对应的配置与数据流向。</em>
</div>
