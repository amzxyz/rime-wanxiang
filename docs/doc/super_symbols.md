# 超级符号（Super Symbols）

万象拼音集成了 [Typst / Codex](https://github.com/typst/codex) 的符号命名数据，可以直接按名称查找并输入大量 Unicode 符号和 Emoji。

Codex 使用点分路径组织名称，例如：

```text
arrow.r.double
subset.eq.not
chess.king.white
cat.face.angry
```

万象使用 `/sym` 查询符号，使用 `/emoji` 查询 Emoji。

---

## 一、基本用法

| 输入 | 含义 | 示例 |
| --- | --- | --- |
| `/sym` | 进入符号查询 | `. 精确搜索 · ? 模糊搜索` |
| `/sym.<path>` | 按 Codex 路径查询 | `/sym.subset` → ⊂ |
| `/sym?<keyword>` | 全局模糊搜索 | `/sym?double` |
| `/sym/<keyword>` | 全局模糊搜索的等价写法 | `/sym/double` |
| `/sym.<path>?<keyword>` | 在当前路径内模糊搜索 | `/sym.subset?n` |
| `/sym.<path>/<keyword>` | 上一种写法的等价形式 | `/sym.subset/n` |
| `/emoji.<path>` | 查询 Emoji | `/emoji.cat.face` |
| `/emoji?<keyword>` | 全局模糊搜索 Emoji | `/emoji?heart` |

可以简单记成：

```text
. = 沿路径继续
? = 从当前位置搜索
```

---

## 二、递进式路径与自动补全

Super Symbols 会根据当前匹配结果自动补上已经能够确定的公共前缀，省去逐字输入和手动确认分类。

例如数据中存在大量 `subset...` 路径时：

```text
/sym.sub
→ /sym.subset
```

系统只补已经确定的部分，并在真正需要用户选择的地方停下。

到达：

```text
/sym.subset
```

之后可以继续：

```text
/sym.subset.
```

沿 Codex 路径继续浏览；也可以输入：

```text
/sym.subset?
```

直接在 `subset` 这一分支内搜索。

自动补全不会擅自跨过 `.`，因此路径层级始终清晰，用户只需要在真正出现分支时决定下一步。

---

## 三、精确查询

精确查询直接按照 Codex 的完整路径前缀筛选。

例如：

```text
/sym.arrow
```

可以继续收窄为：

```text
/sym.arrow.r
/sym.arrow.r.double
```

路径顺序与 Codex 原始名称保持一致。

如果当前输入本身就是一个完整符号名称，对应字符会优先显示。例如：

```text
/sym.co
```

会优先显示：

```text
℅   co
```

输入：

```text
/sym.
```

则从符号数据起点开始浏览真实候选。

精确查询区分大小写，例如：

```text
/sym.alpha → α
/sym.Alpha → Α
```

---

## 四、模糊搜索

### 全局搜索

不知道完整名称时，可以直接搜索名称片段：

```text
/sym?double
/sym?arrow
/emoji?heart
```

`/sym?keyword` 与 `/sym/keyword` 使用相同的搜索逻辑。

单关键字模糊搜索不要求关键字位于名称开头，并且不区分大小写。

还可以直接反查字符：

```text
/sym?⇒
```

### 当前路径内搜索

已经定位到某个分支后，可以直接在该范围内搜索：

```text
/sym.subset?n
```

候选只来自 `subset` 分支，例如：

```text
⊈   eq.not
⋢   eq.sq.not
⊊   neq
⫋   nequiv
⊄   not
⋤   sq.neq
```

这里不再重复显示已经输入过的 `subset.`，候选更紧凑。

### 多关键字搜索

模糊关键字可以用 `.` 组合多个条件：

```text
/sym?arrow.double
/sym?double.arrow
```

表示名称中同时包含 `arrow` 和 `double`，顺序不限。

---

## 五、模糊搜索也支持递进

单关键字模糊搜索在结果已经形成明确公共前缀时，也会自动向前补全。

例如：

```text
/sym?parallelo
→ /sym?parallelogram
```

局部模糊搜索同样适用。

如果当前结果来自多个不同位置，没有明确的共同前缀，则保持原输入，不强行补全。例如：

```text
/sym.subset?n
```

可能同时命中 `neq`、`not`、`eq.not`、`sq.neq` 等，因此不会继续自动补写。

多关键字搜索主要用于组合筛选，不参与这种单关键字递进补全。

---

## 六、候选与提示

Super Symbols 会尽量让候选区在整个输入过程中保持连续。

### 有真实候选时

候选区只显示真实符号或 Emoji，额外提示用于说明数量、当前范围和下一步操作。

例如：

```text
/sym.subset
```

可能显示：

```text
〔20 条 · .路径 · ?搜索〕
```

局部模糊搜索可能显示：

```text
〔subset · 6 条〕
```

如果结果较多，只显示前若干条时，会同时标出总数和当前显示数量。

### 暂时没有真实候选时

候选区会用简短的状态提示承接当前操作，不让菜单突然消失。

例如输入：

```text
/sym
```

显示：

```text
超级符号    . 精确搜索 · ? 模糊搜索
```

输入：

```text
/sym.subset?
```

显示：

```text
模糊搜索    范围 subset · 继续输入关键词
```

没有匹配结果时会显示：

```text
无匹配    修改关键词
```

这样从进入功能、继续路径、切换搜索到无匹配状态，候选区始终能说明当前所处的位置和下一步可做的操作。

---

## 七、候选注释

候选注释用于显示 Codex 名称。

精确查询和全局模糊搜索通常显示完整路径：

```text
→   arrow.r
⇒   arrow.r.double
```

局部模糊搜索只显示相对于当前路径的部分：

```text
/sym.subset?n
```

显示：

```text
⊈   eq.not
⊊   neq
⊄   not
```

这样既能看到符号对应的 Codex 名称，又不会重复输入框里已经存在的路径。

---

## 八、常用示例

### 希腊字母

| 输入 | 结果 | 输入 | 结果 |
| --- | --- | --- | --- |
| `/sym.alpha` | α | `/sym.Alpha` | Α |
| `/sym.beta` | β | `/sym.Beta` | Β |
| `/sym.gamma` | γ | `/sym.Gamma` | Γ |
| `/sym.delta` | δ | `/sym.Delta` | Δ |
| `/sym.pi` | π | `/sym.Pi` | Π |
| `/sym.omega` | ω | `/sym.Omega` | Ω |

### 箭头

| 输入 | 结果 |
| --- | --- |
| `/sym.arrow.r` | → |
| `/sym.arrow.l` | ← |
| `/sym.arrow.t` | ↑ |
| `/sym.arrow.b` | ↓ |
| `/sym.arrow.r.double` | ⇒ |
| `/sym.arrow.tr` | ↗ |

### 数学符号

| 输入 | 结果 | 输入 | 结果 |
| --- | --- | --- | --- |
| `/sym.plus` | + | `/sym.minus` | − |
| `/sym.times` | × | `/sym.div` | ÷ |
| `/sym.eq` | = | `/sym.eq.not` | ≠ |
| `/sym.lt.eq` | ≤ | `/sym.gt.eq` | ≥ |
| `/sym.subset` | ⊂ | `/sym.supset` | ⊃ |
| `/sym.union` | ∪ | `/sym.inter` | ∩ |
| `/sym.infty` | ∞ | `/sym.emptyset` | ∅ |

### Emoji

| 输入 | 结果 |
| --- | --- |
| `/emoji.apple.red` | 🍎 |
| `/emoji.apple.green` | 🍏 |
| `/emoji.heart.red` | ❤️ |
| `/emoji.heart.broken` | 💔 |
| `/emoji.fire` | 🔥 |
| `/emoji.rocket` | 🚀 |

### 记不清完整名称

```text
/sym?arrow
/sym?double
/sym?alpha
/emoji?heart
/emoji?face
```

### 已经知道大致分支

```text
/sym.subset?n
/sym.arrow?double
/emoji.cat?face
```

---

## 九、Codex 点分名称

Codex 使用：

```text
名称.子路径.子路径...
```

组织符号。

常见片段包括：

| 片段 | 常见含义 | 示例 |
| --- | --- | --- |
| `.l .r .t .b` | 左 / 右 / 上 / 下 | `arrow.r` |
| `.double .triple` | 双线 / 三线 | `arrow.r.double` |
| `.stroked .filled` | 描边 / 实心 | `circle.stroked` |
| `.not` | 否定 | `eq.not` |
| `.big` | 大型变体 | `union.big` |
| `.o` | 外加圆圈 | `plus.o` |
| `.white .black` | 黑白变体 | `chess.king.white` |
| `.alt` | 替代字形 | `phi.alt` |

查询始终遵循 Codex 原始路径，因此路径顺序有意义。

---

## 十、配置

Super Symbols 默认使用：

```text
/sym
/emoji
```

作为入口，并从以下数据文件读取名称：

```text
lua/data/codex_sym.txt
lua/data/codex_emoji.txt
```

`max_candidates` 用于控制单次最多显示多少条真实查询结果，默认值为 `120`。

如果自定义 `/sym`、`/emoji` 等入口，还需要保证方案中的 Recognizer 能识别对应输入形式。

---

## 十一、中文 Tips

候选注释主要用于显示 Codex 名称；万象的中文 Tips 可以继续提供符号语义说明，例如：

```text
⇒ 双线右箭头
🍎 红苹果
```

两者可以同时存在：Codex 名称方便检索和理解路径，中文 Tips 用于快速理解符号含义。

---

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
  <em>Super Symbols 以 Codex 点分路径为索引，通过自动递进、精确查询和局部模糊搜索，让符号查找保持连续而直观。</em>
</div>
