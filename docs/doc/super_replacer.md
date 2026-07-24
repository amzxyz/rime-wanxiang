### 🔄 Super Replacer 增强替换器配置手册

#### 1. 核心全局参数 (`super_replacer` 根节点)
控制组件的基础运行环境与全局逻辑。

| 参数名 | 数据类型 | 说明 | 示例值 / 默认值 |
| :--- | :--- | :--- | :--- |
| **`db_name`** | `string` | LevelDB 数据库/词库生成的缓存路径。 | `lua/replacer` (默认) |
| **`delimiter`** | `string` | 多个候选词之间的分隔符配置。 | `"|"` (默认) |
| **`comment_format`** | `string` | 注释显示的样式模板（`%s` 为占位符）。 | `"〔%s〕"` (默认) |
| **`chain`** | `boolean` | **流水线模式**：`true` 串行传递处理（如简转繁再转港），`false` 并行独立处理。 | `true` 或 `false` (默认) |

---
#### 2. 四大核心模式 (`mode`) 详解

| 模式 | 行为描述 | 典型应用场景 |
| :--- | :--- | :--- |
| **`append`** | **新增候选**：在原词后面追加新的候选词。 | `哈哈` -> `1.哈哈 2.😄`<br>(Emoji/中英翻译) |
| **`replace`** | **替换原词**：将原始候选词直接修改为目标词。 | `软件` -> `軟體`<br>(简繁转换/方言转换) |
| **`comment`** | **仅加注释**：不改变候选文字，仅在后方追加提示内容。 | `hello` -> `hello〔你好〕`<br>(英文释义/生僻字注音) |
| **`abbrev`** | **简码模式**：匹配**输入编码**而非文本，触发插队显示。 | `zm` (编码) -> `1.怎么 2.在吗`<br>(快捷短语/懒人简码) |

---

#### 3. 任务规则配置 (`rules` 列表项)
每个 `- option` 代表一个具体的处理模块。**（注：带有 `/s` 的参数，单复数键名均可生效，如 `file` 或 `files`）**

| 参数名 | 数据类型 | 说明 | 示例值 / 默认值 |
| :--- | :--- | :--- | :--- |
| **`option(s)`** | `str/list` | **触发开关**：绑定的方案开关名称（需在 `switches` 中定义），填 `true` 为常驻生效。 | `emoji`, `s2t`, `true` |
| **`mode`** | `string` | **处理模式**：决定结果呈现方式（新增、替换、仅注释、简码）。详见下表。 | `append` (默认) |
| **`comment_mode`**| `string` | **注释继承模式**：<br>`none` (不带注释)<br>`append` (继承原候选注释)<br>`text` (将原候选文字变为注释) | `comment` (默认) |
| **`sentence`** | `boolean` | 是否开启 **句子级别（FMM 分词）** 替换转换。 | `true`, `false` (默认) |
| **`tag(s)`** | `str/list` | **生效引擎**：通常对应拼音引擎的 tag。 | `[abc]` |
| **`prefix`** | `string` | **数据检索前缀**：用于在同一个 DB 中隔离不同功能的数据源。 | `_em_`, `_s2t_` |
| **`file(s)`** | `str/list` | **数据源文件**：关联的 txt 词库列表（UserDir 优先于 SharedDir）。 | `[lua/data/xxx.txt]` |
| **`t9_optimization`**| `boolean` | **九宫格优化**：自动将英文字母映射为 2-9 数字编码，并通过 `==` 拼接预编辑码。 | `true`, `false` (默认) |
| **`cand_type`** | `string` | **自定义候选类型**：用于覆盖默认的 `derived` 或 `abbrev`，便于样式定制。 | `emoji`, `abbrev` |
| **`abbrev_rule`**| `string` | **简码插队规则**：仅在 `abbrev` 模式生效，格式为 `"数量, 起始序号"`。 | `"1,1"` (默认插入1个到第1位) |

---

#### 4. 数据文件 (`.txt`) 编写规范

数据文件需放置于 `file(s)` 指定路径，使用 **Tab (制表符)** 分隔键值，使用 `delimiter`（如 `|`）分隔多个结果：

> **`匹配内容 [Tab] 替换内容1|替换内容2`**

> *可以预设分隔符，也可以直接罗列，同键将自动在导入时合并*

> **`匹配内容 [Tab] 替换内容1`**

> **`匹配内容 [Tab] 替换内容2`**

*示例：*  
*`火 [Tab] 🔥`*  
*`apple [Tab] 苹果`*  
*`zm [Tab] 怎么|在吗`*  

---

### 📝 如何在方案中写 Patch (节点覆写)

为了避免直接修改 Lua 源码或主方案文件，通常建议用户在 `方案名.custom.yaml` 中使用 `patch` 进行定制。

以下是一个标准写法示例，展示了如何修改全局参数以及如何追加/覆盖 `rules` 规则：

```yaml
# wanxiang.custom.yaml
patch:
  # 修改全局基础配置
  super_replacer/db_name: lua/my_custom_replacer

  # ---------- 覆写/添加规则 ----------
  
  # 示例 1: 增加一个自定义颜文字 (常驻生效)
  super_replacer/rules/+:
    option: true
    mode: append
    tags: [abc]
    prefix: "_ki_"
    files: 
      - lua/data/kaomoji.txt
      
  # 示例 2: 增加一个九键专用的简码规则
  super_replacer/rules/+:
    option: [ t9_abbrev ]
    mode: abbrev
    abbrev_rule: "2,1"       # 提取前两个词，插入到第 1 位开始
    t9_optimization: true    # 开启九宫格字母转数字优化
    cand_type: t9
    tags: [abc]
    prefix: "_t9_abbr_"
    file: 
      - lua/data/t9_abbrev.txt
```