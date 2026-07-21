# 超级符号库 super_symbols

万象拼音现已集成 [typst/codex](https://github.com/typst/codex) 符号命名库，提供 **数千个 Unicode 符号**的「按名输入」能力。

源自 Typst 排版系统的底层符号表，覆盖数学运算符、希腊字母、箭头、集合论、几何、天文、货币、控制字符图形等十余大类，以及一千余个 emoji 表情。

具体符号库可参考Typst官方文档：

- `sym`(符号): [点击这里](https://typst.app/docs/reference/symbols/sym/)
- `emoji`(表情): [点击这里](https://typst.app/docs/reference/symbols/emoji/)

---

## 一、触发方式

| 输入                                     | 含义                                                                               | 示例                                                          |
| ---------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `/sym.<name>`                            | 精确查找某个符号（含变体）                                                         | `/sym.alpha` → α                                              |
| `/sym.<root>.<mod1>.<mod2>...`           | 点分链式任意顺序精确匹配（首值精确、中间值精确、尾值前缀；修饰符顺序无关、可省略） | `/sym.arrow.r.double` → ⇒ ，且 `/sym.arrow.double.r` 等价     |
| `/sym?<keyword>` 或 `/sym/<keyword>`     | 点分链式任意顺序模糊匹配（关键字按 `.` 拆分，各组件在名字中任意顺序子串命中）      | `/sym?double.arrow` 或 `/sym?arrow.double` 都列出所有双线箭头 |
| `/emoji.<name>[.<mod>...]`               | 同上，针对 emoji 模块                                                              | `/emoji.apple.red` → 🍎                                        |
| `/emoji?<keyword>` 或 `/emoji/<keyword>` | emoji 点分链式任意顺序模糊匹配                                                     | `/emoji?red.apple` 或 `/emoji?apple.red`                      |

!!! tip "两种模糊搜索语法等价"
    `/sym?keyword` 和 `/sym/keyword` 完全等价，可按习惯选用。
    - `/sym?` 风格接近 URL query string，视觉上更突出"搜索"
    - `/sym/` 风格更接近命令行路径，便于在 `/sym` 前缀后自然延续

!!! tip "精确匹配：点分链式任意顺序"
    查询按 `.` 拆分为 `首值.中间值...尾值`，匹配规则如下：
    - **首值**必须匹配字典首值（根/分类）：一旦首值被 `.` 结束（即后面还有组件），首值改用 **exact match**；若首值整串唯一（无末尾点），则用**子串（prefix）match** 匹配根。
    - **中间值**在字典中**任意乱序**匹配修饰符，使用 **exact match**。
    - **尾值**永远使用 **prefix match**（悬垂点 `/sym.arrows.` 视为尾值为空串，列出该分类全部变体）；重复修饰符自动合并成一个。
    - 因此 `/sym.arrow.double` 会列出**所有方向**的双线箭头（含左、右），而 `/sym.arrow.r.double` 与 `/sym.arrow.double.r` 等价。
    - 仅输入首值（如 `/sym.arrow`）时只投“根字符”进候选；若根无裸字符，则投占位符 `（字符分类）<根>`（提示这是一个分类，补 `.` 即可浏览其全部变体）。

!!! info "候选注释强制显示完整 Typst 代码"
    每个候选的注释区会显示**完整的 Typst 代码**（含 `sym.` / `emoji.` 前缀、按字典原序，提供完整版），方便 Typst 用户输入。例如输入 `/sym.arrow.double` 时：
    ```
    1 ⇒  sym.arrow.r.double
    2 ⤇  sym.arrow.r.double.bar
    3 ⟹  sym.arrow.r.double.long
    ```
    注释中的 `sym.arrow.r.double` 与 Typst 中输入 `sym.arrow.r.double` 完全一致。**即使关闭"注释"开关，super_symbols 的注释也会强制显示**，确保符号名始终可见。

---

## 二、模式提示

仅输入前缀（无后续字符）时，候选区会显示引导提示，帮助用户记住下一步该怎么输入：

| 输入      | 候选区显示     |
| --------- | -------------- |
| `/sym`    | 超级符号       |
| `/sym.`   | 超级符号：直输 |
| `/sym?`   | 超级符号：搜索 |
| `/sym/`   | 超级符号：搜索 |
| `/emoji`  | 超级表情       |
| `/emoji.` | 超级表情：直输 |
| `/emoji?` | 超级表情：搜索 |
| `/emoji/` | 超级表情：搜索 |

输入任何字符后即进入实际查询模式。

---

## 三、点分命名规则

codex 使用「**符号 + 修饰符**」的层级命名，符号之间用 `.` 分隔。

### 常见修饰符

| 修饰符             | 含义                 | 示例                        |
| ------------------ | -------------------- | --------------------------- |
| `.l .r .t .b`      | 左 / 右 / 上 / 下    | `/sym.arrow.l` → ←          |
| `.tl .tr .bl .br`  | 四个对角方向         | `/sym.arrow.tr` → ↗         |
| `.double .triple`  | 双线 / 三线          | `/sym.arrow.double` → ⇔     |
| `.stroked .filled` | 空心 / 实心          | `/sym.circle.stroked` → ○   |
| `.not`             | 否定                 | `/sym.eq.not` → ≠           |
| `.big`             | 大号（n-ary 运算符） | `/sym.union.big` → ⋃        |
| `.o`               | 外加圆圈             | `/sym.plus.o` → ⊕           |
| `.inv .rev`        | 倒置 / 镜像          | `/sym.ast.inv` → ⁂          |
| `.white .black`    | 棋类颜色             | `/sym.chess.king.white` → ♔ |
| `.alt`             | 替代字形             | `/sym.phi.alt` → ϕ          |

### 嵌套模块

部分符号位于子模块下，需带模块前缀：

- `chess.*` — 国际象棋：`/sym.chess.queen.black` → ♛
- `gender.*` — 性别符号：`/sym.gender.male` → ♂
- `control.*` — 控制字符图形：`/sym.control.del` → ␡

---

## 四、常用符号速查

### 希腊字母

| 输入         | 结果 | 输入         | 结果 |
| ------------ | ---- | ------------ | ---- |
| `/sym.alpha` | α    | `/sym.Alpha` | Α    |
| `/sym.beta`  | β    | `/sym.Beta`  | Β    |
| `/sym.gamma` | γ    | `/sym.Gamma` | Γ    |
| `/sym.delta` | δ    | `/sym.Delta` | Δ    |
| `/sym.pi`    | π    | `/sym.Pi`    | Π    |
| `/sym.omega` | ω    | `/sym.Omega` | Ω    |
| `/sym.phi`   | φ    | `/sym.Phi`   | Φ    |
| `/sym.psi`   | ψ    | `/sym.Psi`   | Ψ    |

### 箭头家族

| 输入                    | 结果 | 说明       |
| ----------------------- | ---- | ---------- |
| `/sym.arrow.r`          | →    | 右箭头     |
| `/sym.arrow.l`          | ←    | 左箭头     |
| `/sym.arrow.t`          | ↑    | 上箭头     |
| `/sym.arrow.b`          | ↓    | 下箭头     |
| `/sym.arrow.r.double`   | ⇒    | 双线右箭头 |
| `/sym.arrow.l.r`        | ↔    | 左右箭头   |
| `/sym.arrow.tr`         | ↗    | 右上箭头   |
| `/sym.arrow.cw`         | ↻    | 顺时针箭头 |
| `/sym.arrow.r.squiggly` | ⇝    | 波浪右箭头 |

### 数学运算

| 输入              | 结果 | 输入           | 结果 |
| ----------------- | ---- | -------------- | ---- |
| `/sym.plus`       | +    | `/sym.minus`   | −    |
| `/sym.times`      | ×    | `/sym.div`     | ÷    |
| `/sym.plus.o`     | ⊕    | `/sym.times.o` | ⊗    |
| `/sym.plus.minus` | ±    | `/sym.eq`      | =    |
| `/sym.eq.triple`  | ≡    | `/sym.eq.not`  | ≠    |
| `/sym.lt.eq`      | ≤    | `/sym.gt.eq`   | ≥    |
| `/sym.approx`     | ≈    | `/sym.infty`   | ∞    |
| `/sym.partial`    | ∂    | `/sym.nabla`   | ∇    |
| `/sym.integral`   | ∫    | `/sym.sum`     | ∑    |
| `/sym.product`    | ∏    | `/sym.forall`  | ∀    |
| `/sym.exists`     | ∃    | `/sym.in`      | ∈    |
| `/sym.union`      | ∪    | `/sym.inter`   | ∩    |
| `/sym.subset`     | ⊂    | `/sym.supset`  | ⊃    |
| `/sym.emptyset`   | ∅    | `/sym.angle`   | ∠    |

### 货币符号

| 输入                | 结果 | 输入            | 结果 |
| ------------------- | ---- | --------------- | ---- |
| `/sym.dollar`       | $    | `/sym.euro`     | €    |
| `/sym.yen`          | ¥    | `/sym.sterling` | £    |
| `/sym.won`          | ₩    | `/sym.ruble`    | ₽    |
| `/sym.rupee.indian` | ₹    | `/sym.bitcoin`  | ₿    |
| `/sym.cent`         | ¢    | `/sym.currency` | ¤    |

### 分隔符

| 输入             | 结果 |
| ---------------- | ---- |
| `/sym.paren.l`   | (    |
| `/sym.paren.r`   | )    |
| `/sym.bracket.l` | [    |
| `/sym.bracket.r` | ]    |
| `/sym.brace.l`   | {    |
| `/sym.brace.r`   | }    |
| `/sym.chevron.l` | ⟨    |
| `/sym.chevron.r` | ⟩    |
| `/sym.floor.l`   | ⌊    |
| `/sym.ceil.l`    | ⌈    |

### 常用 emoji

| 输入                    | 结果 | 输入                  | 结果 |
| ----------------------- | ---- | --------------------- | ---- |
| `/emoji.apple.red`      | 🍎    | `/emoji.apple.green`  | 🍏    |
| `/emoji.heart.red`      | ❤️    | `/emoji.heart.broken` | 💔    |
| `/emoji.arrow.r.filled` | ➡️    | `/emoji.face.smile`   | 😊    |
| `/emoji.fire`           | 🔥    | `/emoji.rocket`       | 🚀    |

---

## 五、模糊搜索技巧

用 `/sym?<keyword>` 或 `/sym/<keyword>` 可以快速找到记不清全名的符号（两种语法完全等价）。

```
/sym?arrow        # 或 /sym/arrow       所有名字含 "arrow" 的符号
/sym?double       # 或 /sym/double       所有修饰符含 "double" 的符号
/sym?triple       # 或 /sym/triple       三线变体
/sym?alpha        # 或 /sym/alpha        名字含 alpha 的（包括 Alpha 大写）
/emoji?heart      # 或 /emoji/heart      所有心形 emoji
/emoji?face       # 或 /emoji/face       所有人脸 emoji
```

关键字会同时匹配 **符号名、完整路径、字符本身**，例如 `/sym?⇒` 也能反向找到 `arrow.r.double`。

---

## 六、与现有功能的关系

| 现有功能         | 触发                | 适用场景         | 与 super_symbols 关系                               |
| ---------------- | ------------------- | ---------------- | --------------------------------------------------- |
| 标点快打         | `/` + 字母          | 万象精选常用符号 | 互不冲突，`/sym` `/emoji` 由独立 tag 处理           |
| Unicode 码点输入 | `U+xxxx`            | 已知码点         | super_symbols 提供「按名输入」补充                  |
| 超级计算器       | `V` 引导            | 数学运算         | 不冲突                                              |
| 农历/日期        | `/` 或 `o` 引导     | 日期时间         | 不冲突（super_symbols 仅匹配 `/sym` `/emoji` 前缀） |
| 自定义短语       | `custom_phrase.txt` | 高频固定短语     | 互不冲突                                            |

---

## 七、中文 tips 联动

万象的 **super_tips** 模块（开启后输入框右侧实时显示提示）已内置 codex 中文翻译：

- 所有 codex 符号均生成了**纯中文**说明（不含 Typst 代码后缀），便于在输入时快速识别
- 已与原有 tips_show.txt **去重**（按「类型 + 字符」维度去重，避免重复条目）
- 共新增 **1090 条符号 tips + 341 条 emoji tips**
- 开启 `super_tips` 开关后即可在输入时看到「`⇒ 双线右箭头`」「`🍎 红苹果`」风格的提示

如需禁用某类 tips，可在 `wanxiang.schema.yaml` 的 `super_tips/disabled_types` 中加入类型名（如 `符号` 或 `表情`）。

---

## 八、数据来源与文件清单

| 文件                             | 用途                                                  | 行数     |
| -------------------------------- | ----------------------------------------------------- | -------- |
| `lua/data/codex_sym.txt`         | 符号数据（`typst_name<TAB>char`）                     | 1214 条  |
| `lua/data/codex_emoji.txt`       | emoji 数据（同上）                                    | 1389 条  |
| `lua/data/tips_show.txt`         | 已合并中文 tips（含 codex 符号/emoji 翻译，末尾追加） | +1431 条 |
| `lua/wanxiang/super_symbols.lua` | 翻译器主逻辑                                          | 410 行   |

中文 tips 已合并进 `tips_show.txt`，原 `codex_tips_sym.txt` / `codex_tips_emoji.txt` 不再单独存在。

**数据格式**：
```
typst_name<TAB>char
arrow.r.double	⇒
chess.king.white	♔
emptyset.zero	∅︀
```

标识符为 Typst 写法全文，只有一个字段。

数据源自 [typst/codex](https://github.com/typst/codex) 的 `sym.txt` / `emoji.txt`。支持的转义序列（与 codex `build.rs` 一致）：
- `\u{XXXX}`：Unicode 码点（如 `\u{2192}` → `→`）
- `\vs{1}` ~ `\vs{16}`：Variation Selector U+FE00 ~ U+FE0F
- `\vs{text}`：等价于 `\vs{15}`（U+FE0E）
- `\vs{emoji}`：等价于 `\vs{16}`（U+FE0F）

---

## 九、配置参数

在 `wanxiang.schema.yaml`（或 `custom/wanxiang_pro.schema.yaml`）的 `super_symbols` 节点自定义：

```yaml
super_symbols:
  prefix_sym:    "/sym"      # 仅当未配置 triggers 时作为回退精确前缀
  prefix_emoji:  "/emoji"    # 仅当未配置 triggers 时作为回退精确前缀
  max_candidates: 30         # 模糊搜索最大候选数
  data_sym:      "lua/data/codex_sym.txt"
  data_emoji:    "lua/data/codex_emoji.txt"
```

精确与模糊两种模式的触发符号均由可 patch 的 `triggers` 列表驱动；未配置时回退到上面的 `prefix_sym` / `prefix_emoji`。每条含 `kind`（类型键，对应数据表 `sym` / `emoji`，也用于 `super_<kind>` 候选 tag）、`exact`（精确前缀，后接 `.` 直输）、`label`（模式提示语）、`marks`（模糊搜索标记，默认 `["?", "/"]`）：

```yaml
super_symbols:
  triggers:
    - { kind: sym,    exact: /sym,   label: 超级符号 }   # /sym.arrow.r 直输；/sym?arrow 与 /sym/arrow 模糊
    - { kind: emoji,  exact: /emoji, label: 超级表情 }
    - { kind: kaomoji, exact: /kk,   label: 颜文字, marks: ["?"] }  # 自定义类型，仅 ? 触发模糊
```

模糊搜索前缀由精确前缀 + 标记派生：`?` 与 `/` 平级，例如 `/sym?arrow` 与 `/sym/arrow` 等价。新增类型只需在 `triggers` 中追加一项，并在 `data_sym`/`data_emoji` 之外自行提供数据表（或复用现有表）。

修改前缀后，需同步更新 `recognizer/patterns/super_sym` 与 `super_emoji` 的正则。

---

## 十、技术实现

- **经过简化的数据格式**：每条记录只有一个标识符字段 `typst_name`（如 `arrow.r.double`，不含 `sym.`/`emoji.` 前缀），不拆分 symbol + modifiers
- **点分链式任意顺序精确匹配**（`do_exact`）：加载时单次遍历构建 `by_root`（按根/分类分组）、`roots`（所有根去重列表，供首值子串匹配）、`bare_root`（裸根字符，供首值单值候选）。查询按 `.` 拆分（`split_dot`，悬垂点视为尾值空串）：
  1. **首值**：被 `.` 结束时 **exact match** 根；整串唯一时用**子串 match** 根（仅投根字符 / `（字符分类）<根>` 占位符）
  2. **中间值**：在字典修饰符中**任意乱序 exact match**
  3. **尾值**：永远 **prefix match**（空串匹配全部）
  4. 重复修饰符 `dedup_list` 自动合并；候选按匹配度（修饰符更少者更贴合）排序，注释补回 `sym.`/`emoji.` 前缀并按字典原序
- **点分链式任意顺序模糊匹配**（`do_fuzzy`）：关键字含 `.` 时按 `.` 拆分为若干组件，每个组件必须是某条目标名字的**子串**（任意顺序、可乱序）；无 `.` 时退化为旧式子串匹配（名字含关键字 或 字符精确相等）
- **强制注释**：candidate type 设为 `super_sym` / `super_emoji`，`super_comment_preedit.lua` 识别此类型后跳过清空逻辑，确保 Typst 代码（含前缀、字典原序）始终可见
- **模式提示**：仅输入前缀（如 `/sym.`）时显示引导文案，输入实际字符后自动进入查询模式
- **零依赖**：纯 Lua 实现，兼容 librime-lua 标准 API；模块末尾通过 `_internals` 暴露纯函数便于单元测试

完整实现细节见 `lua/wanxiang/super_symbols.lua` 文件头注释。
