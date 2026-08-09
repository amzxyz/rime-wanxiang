# 超级符号 (Super Symbols)

万象拼音集成了 [typst/codex](https://github.com/typst/codex) 的符号命名数据，可通过符号名称直接检索并输入大量 Unicode 符号与 Emoji。

数据沿用 Typst / Codex 的点分命名方式，例如：

```text
arrow.r.double
chess.king.white
apple.red
```

在万象中分别通过 `/sym` 与 `/emoji` 进入符号和表情查询。

Typst 官方符号表可参考：

- `sym`（符号）：[Typst Symbols](https://typst.app/docs/reference/symbols/sym/)
- `emoji`（表情）：[Typst Emoji](https://typst.app/docs/reference/symbols/emoji/)

---

## 一、触发方式

| 输入 | 含义 | 示例 |
| --- | --- | --- |
| `/sym.<name>` | 按点分名称查询符号 | `/sym.alpha` → α |
| `/sym.<root>.<mod1>.<mod2>...` | 根名称 + 修饰符链查询 | `/sym.arrow.r.double` → ⇒ |
| `/sym?<keyword>` | 模糊搜索符号名称 | `/sym?double.arrow` |
| `/sym/<keyword>` | 与 `/sym?` 等价的模糊搜索写法 | `/sym/arrow.double` |
| `/emoji.<name>[.<mod>...]` | 查询 Emoji 名称 | `/emoji.apple.red` → 🍎 |
| `/emoji?<keyword>` | 模糊搜索 Emoji 名称 | `/emoji?red.apple` |
| `/emoji/<keyword>` | 与 `/emoji?` 等价的模糊搜索写法 | `/emoji/apple.red` |

!!! tip "两种模糊搜索语法等价"
    `/sym?keyword` 与 `/sym/keyword` 使用相同的搜索逻辑，Emoji 同理。

    * `?` 更接近“搜索”语义，例如 `/sym?arrow`
    * `/` 更接近路径式输入，例如 `/sym/arrow`

    两种写法只是在触发形式上不同，进入的都是 `search` 模式。

---

## 二、精确查询的点分规则

Super Symbols 的精确模式并不是简单地对完整字符串做一次相等比较，而是把查询按 `.` 拆分后分别处理。

例如：

```text
/sym.arrow.r.double
```

去掉 `/sym.` 后，实际查询为：

```text
arrow.r.double
```

可以理解为：

```text
根名称 . 中间修饰符 . 尾值
```

当前规则如下。

!!! tip "精确模式的匹配规则"
    1. **只有一个组件时：按根名称前缀浏览**

       例如：

       ```text
       /sym.arrow
       ```

       此时 `arrow` 会作为根名称前缀处理。

       对于命中的根：

       * 如果该根存在裸字符，则直接给出裸字符
       * 如果该根本身只是分类，没有裸字符，则给出 `（字符分类）<根名>` 占位候选

    2. **出现第二个 `.` 后：根名称改为精确匹配**

       例如：

       ```text
       /sym.arrow.r
       ```

       此时 `arrow` 必须是实际存在的根名称，不再按照多个根前缀展开。

    3. **中间修饰符：精确匹配，顺序不要求与 Codex 原始名称一致**

       例如：

       ```text
       /sym.arrow.r.double
       ```

       中间的 `r` 必须是该条目的完整修饰符。

    4. **最后一个组件：前缀匹配**

       例如：

       ```text
       /sym.arrow.double
       ```

       `double` 作为尾值，会匹配该根下修饰符以 `double` 开头的条目。

    5. **悬垂点表示尾值为空**

       例如：

       ```text
       /sym.arrow.
       ```

       尾值为空，因此会列出 `arrow` 分类下满足条件的全部条目。

    6. **中间修饰符会去重**

       查询中的中间修饰符会先做去重，再参与匹配。尾值仍单独承担前缀匹配职责。

### 关于修饰符顺序

中间修饰符采用“是否存在于该条目的修饰符集合中”进行判断，因此完整修饰符通常可以交换顺序。

例如：

```text
/sym.arrow.r.double
/sym.arrow.double.r
```

在对应修饰符名称都完整且无前缀歧义时，通常可以命中相同目标。

不过需要注意：

**最后一个组件始终使用前缀匹配，而不是 exact match。**

因此如果尾值本身同时是多个修饰符的共同前缀，交换组件位置后，候选集合可能出现差异。更准确地说，Super Symbols 支持的是：

```text
中间修饰符无序精确匹配
+
尾修饰符前缀匹配
```

而不是所有组件完全对称的任意顺序匹配。

---

## 三、字符分类占位符与自动展开

部分 Codex 根名称没有对应的“裸字符”，只用于组织一组变体。

此时输入根名称后，候选区会出现：

```text
（字符分类）<根名>
```

例如某个根只有多个细分变体而没有独立字符时，Super Symbols 不会把分类名称本身当作普通文本上屏。

当前还提供了分类展开 Processor。

!!! info "选择字符分类即可展开"
    当高亮候选为：

    ```text
    （字符分类）<根名>
    ```

    使用以下方式确认：

    * 空格
    * 回车
    * 小键盘回车
    * 当前页对应的数字选词键

    Processor 会拦截这次上屏，并把当前输入改写为：

    ```text
    <精确前缀>.<根名>.
    ```

    例如：

    ```text
    /sym.arrow.
    ```

    随后直接列出该分类下的变体。

因此分类占位符只是交互入口，不会把：

```text
（字符分类）arrow
```

这样的提示文本真正提交到应用程序中。

!!! note "数字键遵循当前候选页大小"
    数字选词会根据当前 `menu/page_size` 计算候选位置。

    `1-9` 对应相应序号，`0` 表示第 10 个候选；如果当前页面大小没有覆盖该序号，则不会触发分类展开。

---

## 四、模糊搜索规则

模糊模式由：

```text
/sym?
```

或：

```text
/sym/
```

进入，Emoji 使用同样的规则。

### 1. 单关键字搜索

如果关键字中没有 `.`：

```text
/sym?arrow
```

则对完整 Codex 名称进行子串匹配。

例如：

```text
/sym?double
/sym?alpha
/emoji?heart
```

都不要求关键字位于名称开头。

同时，单关键字模式还支持**字符本身的精确反查**：

```text
/sym?⇒
```

可以直接匹配字符为 `⇒` 的条目。

### 2. 点分多关键字搜索

如果关键字中包含 `.`：

```text
/sym?double.arrow
```

会先拆成：

```text
double
arrow
```

然后要求每个组件都能作为子串出现在目标 Codex 名称中。

组件顺序不固定，因此：

```text
/sym?double.arrow
/sym?arrow.double
```

使用相同的多组件匹配思路。

多组件搜索还会：

* 自动去除重复组件
* 优先处理较长组件
* 要求所有组件同时命中
* 最终按 Codex 名称排序输出

!!! note "字符反查只属于无点关键字模式"
    `/sym?⇒` 这类直接输入字符的反查可以工作。

    但点分模糊模式的每个组件是对**名称字符串**做子串判断，并不会把每个组件同时当作字符进行匹配。

---

## 五、模式提示

只输入触发前缀、尚未真正查询时，候选区会显示模式提示。

| 输入 | 候选正文 | 候选注释 |
| --- | --- | --- |
| `/sym` | 超级符号 | `~` |
| `/sym.` | 超级符号 | `直接输入` |
| `/sym?` | 超级符号 | `模糊搜索` |
| `/sym/` | 超级符号 | `模糊搜索` |
| `/emoji` | 超级表情 | `~` |
| `/emoji.` | 超级表情 | `直接输入` |
| `/emoji?` | 超级表情 | `模糊搜索` |
| `/emoji/` | 超级表情 | `模糊搜索` |

输入实际查询内容后，才进入精确或模糊匹配流程。

---

## 六、候选注释与 Typst 名称

实际符号候选的注释中会保留完整的 Typst / Codex 名称。

例如输入：

```text
/sym.arrow.double
```

候选可能显示为：

```text
1 ⇒  sym.arrow.r.double
2 ⤇  sym.arrow.r.double.bar
3 ⟹  sym.arrow.r.double.long
```

其中：

```text
sym.arrow.r.double
```

可以直接对应到 Typst 的符号名称。

Super Symbols 在生成候选时：

* `sym` 候选使用 `super_sym` 类型
* `emoji` 候选使用 `super_emoji` 类型

`super_comment_preedit.lua` 对这两种候选类型直接放行，不再进入普通候选的注释清理流程，因此完整 Codex 名称可以持续保留。

!!! info "关闭普通候选注释不会清掉 Super Symbols 名称"
    `super_comment_preedit.lua` 检测到：

    ```text
    super_sym
    super_emoji
    ```

    后，会直接输出原候选。

    因此 Super Symbols 的 Typst 名称注释不受普通拼音候选注释开关的清空逻辑影响。

---

## 七、点分命名规则

Codex 使用：

```text
根名称.修饰符.修饰符...
```

组织符号名称。

### 常见修饰符

| 修饰符 | 常见含义 | 示例 |
| --- | --- | --- |
| `.l .r .t .b` | 左 / 右 / 上 / 下 | `/sym.arrow.l` → ← |
| `.tl .tr .bl .br` | 四个对角方向 | `/sym.arrow.tr` → ↗ |
| `.double .triple` | 双线 / 三线 | `/sym.arrow.r.double` → ⇒ |
| `.stroked .filled` | 描边 / 实心变体 | `/sym.circle.stroked` → ○ |
| `.not` | 否定 | `/sym.eq.not` → ≠ |
| `.big` | 大型运算符变体 | `/sym.union.big` → ⋃ |
| `.o` | 外加圆圈 | `/sym.plus.o` → ⊕ |
| `.inv .rev` | 倒置 / 反向变体 | `/sym.ast.inv` → ⁂ |
| `.white .black` | 黑白变体 | `/sym.chess.king.white` → ♔ |
| `.alt` | 替代字形 | `/sym.phi.alt` → ϕ |

具体含义以 Codex 中对应名称为准；同一个修饰符在不同符号家族中可能承担不同的字形区分作用。

### 嵌套名称

部分符号名称本身具有多层结构，例如：

```text
chess.king.white
gender.male
control.del
```

对应输入：

```text
/sym.chess.king.white
/sym.gender.male
/sym.control.del
```

从 Super Symbols 的实现角度看，第一个组件仍作为根名称，后续组件统一作为修饰符链处理。

---

## 八、常用符号速查

### 希腊字母

| 输入 | 结果 | 输入 | 结果 |
| --- | --- | --- | --- |
| `/sym.alpha` | α | `/sym.Alpha` | Α |
| `/sym.beta` | β | `/sym.Beta` | Β |
| `/sym.gamma` | γ | `/sym.Gamma` | Γ |
| `/sym.delta` | δ | `/sym.Delta` | Δ |
| `/sym.pi` | π | `/sym.Pi` | Π |
| `/sym.omega` | ω | `/sym.Omega` | Ω |
| `/sym.phi` | φ | `/sym.Phi` | Φ |
| `/sym.psi` | ψ | `/sym.Psi` | Ψ |

### 箭头

| 输入 | 结果 | 说明 |
| --- | --- | --- |
| `/sym.arrow.r` | → | 右箭头 |
| `/sym.arrow.l` | ← | 左箭头 |
| `/sym.arrow.t` | ↑ | 上箭头 |
| `/sym.arrow.b` | ↓ | 下箭头 |
| `/sym.arrow.r.double` | ⇒ | 双线右箭头 |
| `/sym.arrow.l.r` | ↔ | 左右箭头 |
| `/sym.arrow.tr` | ↗ | 右上箭头 |
| `/sym.arrow.cw` | ↻ | 顺时针箭头 |
| `/sym.arrow.r.squiggly` | ⇝ | 波浪右箭头 |

### 数学运算

| 输入 | 结果 | 输入 | 结果 |
| --- | --- | --- | --- |
| `/sym.plus` | + | `/sym.minus` | − |
| `/sym.times` | × | `/sym.div` | ÷ |
| `/sym.plus.o` | ⊕ | `/sym.times.o` | ⊗ |
| `/sym.plus.minus` | ± | `/sym.eq` | = |
| `/sym.eq.triple` | ≡ | `/sym.eq.not` | ≠ |
| `/sym.lt.eq` | ≤ | `/sym.gt.eq` | ≥ |
| `/sym.approx` | ≈ | `/sym.infty` | ∞ |
| `/sym.partial` | ∂ | `/sym.nabla` | ∇ |
| `/sym.integral` | ∫ | `/sym.sum` | ∑ |
| `/sym.product` | ∏ | `/sym.forall` | ∀ |
| `/sym.exists` | ∃ | `/sym.in` | ∈ |
| `/sym.union` | ∪ | `/sym.inter` | ∩ |
| `/sym.subset` | ⊂ | `/sym.supset` | ⊃ |
| `/sym.emptyset` | ∅ | `/sym.angle` | ∠ |

### 货币符号

| 输入 | 结果 | 输入 | 结果 |
| --- | --- | --- | --- |
| `/sym.dollar` | $ | `/sym.euro` | € |
| `/sym.yen` | ¥ | `/sym.sterling` | £ |
| `/sym.won` | ₩ | `/sym.ruble` | ₽ |
| `/sym.rupee.indian` | ₹ | `/sym.bitcoin` | ₿ |
| `/sym.cent` | ¢ | `/sym.currency` | ¤ |

### 分隔符

| 输入 | 结果 |
| --- | --- |
| `/sym.paren.l` | ( |
| `/sym.paren.r` | ) |
| `/sym.bracket.l` | [ |
| `/sym.bracket.r` | ] |
| `/sym.brace.l` | { |
| `/sym.brace.r` | } |
| `/sym.chevron.l` | ⟨ |
| `/sym.chevron.r` | ⟩ |
| `/sym.floor.l` | ⌊ |
| `/sym.ceil.l` | ⌈ |

### 常用 Emoji

| 输入 | 结果 | 输入 | 结果 |
| --- | --- | --- | --- |
| `/emoji.apple.red` | 🍎 | `/emoji.apple.green` | 🍏 |
| `/emoji.heart.red` | ❤️ | `/emoji.heart.broken` | 💔 |
| `/emoji.arrow.r.filled` | ➡️ | `/emoji.face.smile` | 😊 |
| `/emoji.fire` | 🔥 | `/emoji.rocket` | 🚀 |

---

## 九、模糊搜索示例

记不清完整 Codex 名称时，可以直接搜索其中的一部分：

```text
/sym?arrow
/sym/arrow

/sym?double
/sym/double

/sym?triple
/sym/triple

/sym?alpha
/sym/alpha

/emoji?heart
/emoji/heart

/emoji?face
/emoji/face
```

也可以使用多个点分关键字：

```text
/sym?arrow.double
/sym?double.arrow
```

如果已经知道字符本身，还可以反查：

```text
/sym?⇒
```

---

## 十、与现有功能的关系

| 功能 | 常见触发 | 适用场景 | 与 Super Symbols 的关系 |
| --- | --- | --- | --- |
| 标点快打 | `/` + 字母 | 常用标点与快捷符号 | 独立功能；`/sym`、`/emoji` 使用自己的识别入口 |
| Unicode 码点输入 | `U` / Unicode 相关入口 | 已知 Unicode 码点 | Super Symbols 补充按名称搜索 |
| 超级计算器 | `V` 引导 | 数学计算 | 独立功能 |
| 日期 / 时间 | `/`、`N` 等入口 | 日期时间内容 | 独立功能 |
| 自定义短语 | `custom_phrase.txt` | 高频固定文本 | 独立功能 |

Super Symbols 的重点不是替代这些功能，而是补充：

```text
已知符号名称或名称片段
→ 查找 Unicode 字符
```

这一输入方式。

---

## 十一、中文 Tips 联动

万象的 `super_tips` 可以为部分 Codex 符号提供中文提示。

开启后，可以在输入过程中看到类似：

```text
⇒ 双线右箭头
🍎 红苹果
```

的辅助说明。

当前数据文件中已经合并了 Codex 相关中文 Tips，并与原有提示数据进行去重。

当前文档所对应的数据版本记录为：

```text
1090 条符号 Tips
341 条 Emoji Tips
合计新增 1431 条
```

!!! note "数量属于当前数据快照"
    Codex 数据和中文 Tips 后续都可能继续更新，因此条目数量不应视为永久固定值。

    如果仓库中的 `codex_sym.txt`、`codex_emoji.txt` 或 `tips_show.txt` 已更新，应以实际文件内容为准。

如需关闭某类提示，可根据当前 `super_tips` 配置中的类型控制项进行调整，例如符号或表情类型。

---

## 十二、数据来源与文件

| 文件 | 用途 | 当前文档记录 |
| --- | --- | --- |
| `lua/data/codex_sym.txt` | Codex `sym` 符号数据 | 1214 条 |
| `lua/data/codex_emoji.txt` | Codex Emoji 数据 | 1389 条 |
| `lua/data/tips_show.txt` | 中文输入提示数据，包含 Codex 相关 Tips | Codex 部分新增 1431 条 |
| `lua/wanxiang/super_symbols.lua` | Super Symbols Translator / Processor | 659 行 |

!!! note "数据条数可能随上游更新"
    表中的数量对应当前文档所使用的数据快照。

    后续同步新版 Codex 后，符号、Emoji 和 Tips 条数都可能变化，文档不应依赖这些数字判断功能是否正常。

### 数据格式

`codex_sym.txt` 与 `codex_emoji.txt` 每行使用两个字段：

```text
typst_name<TAB>char
```

例如：

```text
arrow.r.double	⇒
chess.king.white	♔
emptyset.zero	∅︀
```

这里的重点是：

**`typst_name` 作为一个完整字段保存。**

程序读取后才根据 `.` 拆分为：

```text
root
mods_list
mods_set
```

数据文件本身不会额外拆成：

```text
symbol<TAB>modifier1<TAB>modifier2
```

这样的多列结构。

数据来源于 [typst/codex](https://github.com/typst/codex) 的符号数据。

当前数据转换支持的转义形式包括：

```text
\u{XXXX}
\vs{1} ~ \vs{16}
\vs{text}
\vs{emoji}
```

其中：

```text
\vs{text}
```

对应文本样式 Variation Selector，

```text
\vs{emoji}
```

对应 Emoji 样式 Variation Selector。

---

## 十三、配置参数

默认配置由方案文件提供。个人修改建议通过 `wanxiang.custom.yaml` Patch，而不是直接修改主方案文件。

Super Symbols 当前主要使用：

```yaml
super_symbols:
  prefix_sym: "/sym"
  prefix_emoji: "/emoji"
  max_candidates: 120
  data_sym: "lua/data/codex_sym.txt"
  data_emoji: "lua/data/codex_emoji.txt"
```

其中：

| 参数 | 作用 | 未配置时 |
| --- | --- | --- |
| `prefix_sym` | 未提供 `triggers` 时的符号精确前缀 | `/sym` |
| `prefix_emoji` | 未提供 `triggers` 时的 Emoji 精确前缀 | `/emoji` |
| `max_candidates` | 单次最多输出的查询候选数 | `120` |
| `data_sym` | `sym` 数据文件路径 | `lua/data/codex_sym.txt` |
| `data_emoji` | `emoji` 数据文件路径 | `lua/data/codex_emoji.txt` |

例如只想把最大候选数调整为 30：

```yaml
patch:
  "super_symbols/max_candidates": 30
```

也可以一起修改数据路径：

```yaml
patch:
  "super_symbols/max_candidates": 30
  "super_symbols/data_sym": "lua/data/codex_sym.txt"
  "super_symbols/data_emoji": "lua/data/codex_emoji.txt"
```

---

## 十四、Triggers 配置

精确与模糊查询入口由 `super_symbols/triggers` 控制。

每条触发定义包含：

```text
kind
exact
label
marks
```

其中：

| 字段 | 作用 |
| --- | --- |
| `kind` | 数据类型，目前实际使用 `sym` 或 `emoji` |
| `exact` | 基础触发前缀，例如 `/sym` |
| `label` | 模式提示正文 |
| `marks` | 模糊搜索标记，例如 `?`、`/` |

例如：

```yaml
super_symbols:
  triggers:
    - kind: sym
      exact: /sym
      label: 超级符号
      marks: ["?", "/"]

    - kind: emoji
      exact: /emoji
      label: 超级表情
      marks: ["?", "/"]
```

运行时会由它们派生：

```text
/sym.       → exact
/sym?       → search
/sym/       → search

/emoji.     → exact
/emoji?     → search
/emoji/     → search
```

如果某条 trigger 没有有效的 `marks`，当前实现会回退为：

```yaml
["?", "/"]
```

### `prefix_sym` / `prefix_emoji` 与 `triggers` 的关系

如果 `super_symbols/triggers` 存在有效配置，程序会优先使用整个 `triggers` 列表。

此时：

```text
prefix_sym
prefix_emoji
```

不再负责生成默认触发器。

只有没有有效 `triggers` 时，才会回退为：

```text
prefix_sym   → sym
prefix_emoji → emoji
```

---

## 十五、当前并不是任意数据类型加载器

`triggers` 中存在 `kind` 字段，并不意味着当前版本已经支持通过 YAML 任意增加第三种数据文件。

当前 `load_data()` 实际只加载：

```text
data_sym
data_emoji
```

并创建：

```text
sym
emoji
```

两个数据 Store。

因此不能仅仅新增一个第三方 `kind`，再假设提供对应数据文件后就会自动生效。

**当前源码没有通用的 `data_<kind>` 动态加载逻辑。**

如果 trigger 指向不存在的 Store，Translator 会得到一个空 Store，因此不会自动产生第三类实际符号数据。

!!! warning "当前建议只配置 sym 与 emoji"
    `triggers` 更适合用于调整现有 `sym` / `emoji` 的触发前缀、提示文本和模糊搜索标记。

    如果以后要扩展成任意 `kind → data file` 的通用加载机制，需要同时修改数据加载、Store 建立以及分类展开 Processor，不能只追加一条 YAML trigger。

---

## 十六、修改前缀时的 Recognizer

Lua Translator 能识别新的 trigger，并不代表 Rime 前端一定会把新输入分配给对应的 Segment。

如果修改：

```text
/sym
/emoji
```

这类入口，还需要同步检查方案中的：

```text
recognizer/patterns/super_sym
recognizer/patterns/super_emoji
```

保证 Recognizer 正则能够覆盖新的输入前缀。

因此前缀修改需要同时考虑：

```text
Super Symbols trigger
+
Recognizer pattern
```

两部分。

---

## 十七、技术实现

当前 `super_symbols.lua` 的处理流程可以概括为：

```text
读取 Codex 数据
      ↓
按根名称建立 Store
      ↓
建立 root_map / root_list
      ↓
记录每条目的 mods_list / mods_set
      ↓
根据 triggers 判断 exact / search
      ↓
执行 do_exact / do_fuzzy
      ↓
生成 super_sym / super_emoji 候选
```

### 1. 数据加载

每行：

```text
typst_name<TAB>char
```

读取后，名称按 `.` 拆分。

例如：

```text
arrow.r.double
```

会形成：

```text
root      = arrow
mods_list = [r, double]
mods_set  = { r = true, double = true }
```

同时按根建立：

```text
root_map
root_list
```

如果某个名称没有修饰符，则把对应字符记录为该根的：

```text
bare
```

供单根查询直接使用。

### 2. 精确查询 `do_exact`

`do_exact` 根据点分组件数量选择两种路径：

```text
单组件
→ 根名称前缀浏览

两组件及以上
→ 根 exact
→ 中间 modifier exact
→ 尾 modifier prefix
```

匹配结果会按：

```text
修饰符数量较少优先
→ 名称字典序
```

排列。

### 3. 模糊查询 `do_fuzzy`

无点关键字：

```text
完整名称子串匹配
或
字符精确匹配
```

有点关键字：

```text
拆分组件
→ 去重
→ 全部组件都必须是名称子串
→ 组件顺序不限
```

无点模糊搜索保持数据文件中的原始顺序，因此达到 `max_candidates` 后可以提前停止继续收集。

点分模糊搜索需要先收集匹配项并按名称排序，再裁剪到候选上限。

### 4. 分类展开 Processor

模块同时导出 Processor：

```text
P
```

它负责识别：

```text
（字符分类）<根名>
```

候选。

确认该候选时，不提交文本，而是把输入改写成：

```text
<exact>.<root>.
```

实现分类浏览。

### 5. Translator / Processor 导出

当前模块最终返回：

```lua
return {
    T = M,
    P = P
}
```

也就是说当前对外导出的是：

```text
T → Translator
P → Processor
```

当前版本**没有**原文旧说明中的 `_internals` 导出项。

### 6. 注释保留

候选类型：

```text
super_sym
super_emoji
```

会被 `super_comment_preedit.lua` 直接放行，因此 Typst / Codex 完整名称不会被普通候选注释过滤流程清空。

---

## 十八、使用建议

如果记得完整名称，优先使用：

```text
/sym.<name>
/emoji.<name>
```

如果只记得部分名称，可以使用：

```text
/sym?<keyword>
/emoji?<keyword>
```

如果想同时限定多个特征，可以使用：

```text
/sym?arrow.double
/sym?double.arrow
```

如果只记得大致分类，可以先输入：

```text
/sym.arrow
```

再选择 `（字符分类）` 候选展开。

对于 Typst 用户，候选注释中的完整：

```text
sym.*
emoji.*
```

名称还可以作为对应 Typst 代码的参考。

---

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>Super Symbols 以 Codex 点分名称为索引，同时提供精确查询、组合修饰符查询、模糊搜索和分类展开。</em>
</div>
