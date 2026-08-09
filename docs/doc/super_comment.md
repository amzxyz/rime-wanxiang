# 超级注释 & Preedit：候选注释与编码显示

> **`super_comment_preedit.lua` 负责处理候选注释与 Preedit 显示，将词库中已有的拼音、辅助码等编码信息按当前状态重新组织，而不是依赖固定的正则格式去猜测最终显示内容。**

万象的词库编码中保留了带调拼音、辅助码等信息。超级注释模块会读取候选原始注释，并根据当前输入状态分别生成带调拼音、无调拼音、辅助码、错音纠正以及反查信息；与此同时，Preedit 部分还可以把双拼、简码等当前输入重新显示为完整拼音。

这一模块的重点不是“给候选统一追加一段文字”，而是根据不同输入场景决定：**当前应该显示什么、哪些信息应当保留，以及哪一种提示具有更高优先级。**

---

## 一、注释与 Preedit 分别负责什么？

可以先把这两个概念分开：

* **Comment（候选注释）**：显示在候选词旁边，例如读音、辅助码、错音纠正或反查信息。
* **Preedit（编码显示）**：显示当前正在输入的编码，例如原始双拼码、带调全拼或无调全拼。

两部分由同一个 Lua 模块统一处理，但控制状态彼此独立。

---

## 二、候选注释：带调、无调与辅助码

超级注释会读取候选原始 comment，并根据当前 option 决定最终显示内容。

Lua 当前支持以下几种主要状态：

* `tone_hint`：显示带声调拼音。
* `toneless_hint`：显示去掉声调后的拼音。
* `fuzhu_hint`：显示辅助码。
* 未开启对应提示时：普通候选注释可以被清空，让候选区保持简洁。

其中，带调和无调模式并不是重新通过候选文字“猜读音”，而是从候选已有的编码注释中提取拼音部分。

例如原始编码信息中包含：

`zhèn;yh`

可以按当前状态分别整理为：

```text
zhèn
zhen
yh
```

分别对应带调拼音、无调拼音与辅助码提示。

!!! note "Base 当前默认暴露的注释状态"
    当前 Base 方案的 `switches` 中使用：

    ```yaml
    - options: [comment_off, tone_hint, toneless_hint]
      states: [注释关, 有声调, 无声调]
    ```

    因此 Base 默认界面主要提供 **关闭注释 / 带调拼音 / 无调拼音** 三种状态。

    Lua 本身仍保留 `fuzhu_hint` 的辅助码提示处理能力。如果当前方案没有在 `switches` 中暴露这个 option，则不能仅根据 Lua 中存在该逻辑，就认为当前界面一定提供辅助码三态切换。

---

## 三、Preedit：原编码、带调全拼与无调全拼

Preedit 使用另一组状态：

```yaml
- options: [raw_input, tone_display, full_pinyin]
  states: [原编码, 有声调, 无声调]
```

可以理解为：

* `raw_input`：保持当前实际输入编码。
* `tone_display`：将当前编码按候选真实读音显示为带调全拼。
* `full_pinyin`：显示完整全拼，但去掉声调。

例如使用双拼输入时，实际敲击的仍然是双拼编码，但 Preedit 可以根据当前第一候选所携带的拼音信息重新显示成完整拼音。

<div style="display: flex; flex-direction: column; gap: 30px; align-items: center; margin: 2rem auto;">
    <div style="text-align: center; width: 100%; max-width: 600px;">
        <img src="https://storage.deepin.org/thread/202509260134283927_辅助码提示.jpg"
             style="width: 100%; height: auto; border-radius: 10px; box-shadow: 0 6px 16px rgba(0,0,0,0.12);">
        <p style="font-size: 0.95em; color: #666; margin-top: 0.8rem;">候选注释显示示例</p>
    </div>

    <div style="text-align: center; width: 100%; max-width: 600px;">
        <img src="https://storage.deepin.org/thread/202509260134278003_声调提示.jpg"
             style="width: 100%; height: auto; border-radius: 10px; box-shadow: 0 6px 16px rgba(0,0,0,0.12);">
        <p style="font-size: 0.95em; color: #666; margin-top: 0.8rem;">带调拼音显示示例</p>
    </div>
</div>

---

## 四、为什么双拼也能还原成完整拼音？

传统的 `preedit_format` 更适合处理规则明确、能够直接通过 Algebra 逆向转换的编码。

万象的做法不同：Lua 会把当前 Preedit 按音节拆开，同时从候选原始 comment 中提取与之对应的真实拼音，再逐个音节重新组合。

处理过程可以简单理解为：

```text
当前输入编码
    ↓
按照自动 / 手动分隔符拆分音节
    ↓
从候选 comment 中提取对应拼音
    ↓
逐音节重新对齐
    ↓
生成带调或无调 Preedit
```

因此，最终显示的拼音主要来自候选自身携带的编码数据，而不是单纯根据当前双拼键位反推。

### 分隔符会被保留

Lua 会读取：

`speller/delimiter`

并分别识别自动分隔符与手动分隔符。

在重新生成 Preedit 时，这些分隔符仍然保留在原来的位置，因此手动使用 `'` 等分词方式时，不会因为切换拼音显示而丢失原有音节边界。

---

## 五、简码 Preedit 的处理

当前 Lua 还专门处理了简码场景。

配置项：

```yaml
super_comment:
  convert_abbrev_preedit: false
```

默认关闭时，单字母简码会尽量保留用户实际输入的简码形式；`zh`、`ch`、`sh` 则按照完整声母处理。

如果开启：

```yaml
patch:
  super_comment/convert_abbrev_preedit: true
```

简码也会直接转换为候选对应的完整拼音。

这项设置主要影响 **Preedit 的显示方式**，不会改变用户实际输入的编码。

---

## 六、26 键与 T9 使用不同的 Preedit 处理

超级 Preedit 并不是用同一套规则处理所有键盘。

当前 Lua 会从万象的输入类型标记中判断是否属于 T9，再选择对应的音节处理方式。

### 26 键

普通 26 键输入会区分：

* 完整音节
* 单字母简码
* `zh / ch / sh`
* Pro 方案
* 是否启用声调隔离

### T9

T9 会单独进入九宫格处理逻辑。

单数字简码与完整数字音节的显示策略不同，并且 T9 不会继续执行普通的数字声调上标转换，避免把九宫格数字误当作声调数字处理。

!!! info "为什么不能只看输入是否以数字开头？"
    当前 Lua 不再简单使用“当前输入是不是数字开头”判断 T9，而是读取万象已经解析出的实际输入类型。

    这样即使经过局部选字、分段等操作后剩余编码的形态发生变化，也不会因此错误退出 T9 显示逻辑。

---

## 七、数字声调与双大写辅助码的 Preedit 处理

除了拼音还原，Lua 还会对 Preedit 做两类显示整理。

### 1. 数字声调映射

方案可以通过：

```yaml
tone_preedit:
  "7": "¹"
  "8": "²"
  "9": "³"
  "0": "⁴"
```

定义数字到显示字符的映射。

Lua 会读取 `tone_preedit/0..9`，将符合条件的数字声调转换成对应显示形式。

这只是 Preedit 显示转换，不会改变实际输入编码。

### 2. 双大写辅助码隐藏

如果配置了：

`force_upper_aux/symbol`

Lua 会识别 Preedit 中连续的大写辅助码，并将其替换为配置的显示符号。

因此，大写辅助码可以继续参与实际编码处理，但不必把完整的大写字符串直接暴露在输入区。

---

## 八、错音纠正不是普通注释的一部分

超级注释中还包含独立的错音 / 错字提示模块。

Base 与 Pro 会分别读取：

```text
dicts/cuoyin.dict.yaml
dicts/cuoyin.pro.dict.yaml
```

Lua 会根据候选文字与候选原始编码同时确认是否命中纠正数据，只有两者都对应时才替换为纠正提示。

例如某个错误读音命中纠错词典后，最终 comment 可以使用：

```text
〔正确读音〕
```

显示。

括号样式由：

```yaml
super_comment:
  corrector_type: "〔comment〕"
```

控制。

其中 `comment` 是内容占位符，可以修改左右样式，但应保留该占位符。

---

## 九、反查模式拥有更高的注释优先级

进入生僻字反查后，超级注释会重新组织候选信息。

反查注释可以同时包含：

* **音**：目标字读音
* **辅**：辅助码
* **字符区**：基本区、扩展 A-I 区或兼容区

例如：

```text
震 〔音zhèn・辅yh・基本〕
```

Lua 会根据目标字符的 Unicode 码位判断：

```text
基本
扩A
扩B
扩C
扩D
扩E
扩F
扩G
扩H
扩I
兼容
```

因此反查模式不仅用于找到目标字，也可以同时补充读音、辅助码和字符区信息。

---

## 十、注释真正的优先级

当前 Lua 的处理顺序值得单独说明。

普通候选进入模块后，大致按照以下顺序处理：

```text
普通辅助码 / 带调 / 无调提示
        ↓
错音纠正
        ↓
反查模式提示
```

也就是说，后面的特殊提示可以覆盖前面的普通提示。

可以简化理解为：

**反查提示 > 错音纠正 > 普通注释状态**

另外，如果候选原始 comment 中已经带有 `~`，Lua 会优先保留该 comment，不先把它按照普通提示模式清空。

这也是为什么兜底候选的 `~` 标记能够继续保留下来。

!!! info "部分特殊候选不会进入普通注释处理"
    当前 Lua 会直接放行以下候选类型：

    * `shijian`
    * `compose`
    * `super_sym`
    * `super_emoji`

    这些功能拥有自己的显示内容，因此不会再由超级注释统一重写。

---

## 十一、候选类型标记与超级注释的关系

方案中还存在：

```yaml
super_comment:
  cand_type:
    user_phrase: ""
    sentence: ""
    phrase: ""
    table: ""
    user_table: ""
    completion: ""
    predict: ""
    abbrev: ""
    fallback: "~"
```

这些配置虽然统一放在 `super_comment/cand_type` 下，但**当前实际读取并追加这些候选类型标记的是 `super_filter`，并不是 `super_comment_preedit.lua` 本身。**

例如：

```yaml
fallback: "~"
```

会用于兜底候选的类型标记。

因此更准确的理解是：

**`super_comment` 是这一组显示配置的公共命名空间，其中部分参数由超级注释读取，部分候选类型标记由其他显示 Filter 使用。**

如果需要自定义：

```yaml
patch:
  "super_comment/cand_type/user_phrase": " ⁺"
  "super_comment/cand_type/sentence": " ∞"
  "super_comment/cand_type/fallback": "~"
```

修改的是候选类型的外显标识，不是拼音 / 辅助码注释本身。

---

## 十二、快捷键与状态切换

当前 Base 方案中，与超级注释和 Preedit 直接相关的快捷键主要包括：

```yaml
key_binder:
  bindings:
    # 注释状态
    - {when: has_menu, accept: "Control+a", toggle: tone_hint}

    # Preedit 状态
    - {when: has_menu, accept: "Control+s", toggle: tone_display}
```

对应的状态组分别是：

```yaml
# Preedit
- options: [raw_input, tone_display, full_pinyin]
  states: [原编码, 有声调, 无声调]

# Comment
- options: [comment_off, tone_hint, toneless_hint]
  states: [注释关, 有声调, 无声调]
```

因此当前文档应以实际 Schema 中声明的状态为准，不建议再把旧版本中的其他快捷键或 option 直接写成现行默认行为。

---

## 十三、Preedit 与 Comment 还可以直接上屏

Rime 编辑器还提供了两种与这一模块非常适合配合使用的提交方式：

```yaml
editor:
  bindings:
    Control+Return: commit_script_text
    Control+Shift+Return: commit_comment
```

其中：

* **`Control + Return`**：提交转换后的 Preedit 文本。
* **`Shift + Return`**：提交转换后的 Preedit 文本也可。
* **`Control + Shift + Return`**：提交当前候选的 comment。

例如当前 Preedit 已经被转换为带调全拼时，可以通过 `Control + Return` 直接将转换后的拼音作为文本提交。

---

## 十四、常用自定义参数

可以在 `wanxiang.custom.yaml` 中按需 Patch。

```yaml
patch:
  # 常规注释处理的最大候选长度
  "super_comment/candidate_length": 2

  # 错音纠正提示样式，comment 为内容占位符
  "super_comment/corrector_type": "〔comment〕"

  # 简码是否也直接转换成完整拼音 Preedit
  "super_comment/convert_abbrev_preedit": false

  # 候选类型标记：由相关 Filter 读取
  "super_comment/cand_type/user_phrase": " ⁺"
  "super_comment/cand_type/sentence": " ∞"
  "super_comment/cand_type/fallback": "~"
```

!!! warning "candidate_length 不只影响辅助码"
    当前 Lua 中，`candidate_length` 会在生成常规辅助码 / 拼音注释时统一参与长度判断。

    因此它更准确的含义是“常规注释处理的候选长度上限”，而不只是“辅助码提醒长度”。

---

## 十五、当前实现中需要注意的一点

当前 Lua 中错音纠正开关初始化写法等价于：

```lua
corrector_enabled = config:get_bool("super_comment/corrector") or true
```

由于 Lua 中 `false or true` 的结果仍然是 `true`，因此即使配置：

```yaml
super_comment:
  corrector: false
```

当前实现也仍会得到开启状态。

如果希望真正支持通过 YAML 关闭错音纠正，这一处代码需要改为显式判断 `nil`，而不能直接使用 `or true`。

这属于当前 Lua 实现细节，文档中不应把 `super_comment/corrector: false` 写成已经可用的关闭方式。

---

## 总结

`super_comment_preedit.lua` 当前实际承担的工作可以概括为：

1. **候选注释切换**：带调、无调、辅助码等不同显示内容。
2. **Preedit 还原**：原编码、带调全拼、无调全拼。
3. **简码处理**：决定简码保持原样还是显示完整拼音。
4. **T9 / 26 键适配**：根据实际输入类型选择不同的编码显示逻辑。
5. **数字声调显示**：通过 `tone_preedit` 转换数字标记。
6. **辅助码显示整理**：隐藏连续双大写编码。
7. **错音纠正**：从 Base / Pro 对应错音词典读取纠正提示。
8. **反查信息整合**：显示读音、辅助码及 Unicode 字符区。
9. **特殊候选保护**：避免时间、Compose、超级符号、超级 Emoji 等功能的自有注释被重写。
10. **优先级调度**：让反查和错音等特殊提示能够覆盖普通显示状态。

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>超级注释与 Preedit 的核心不是增加更多提示，而是根据当前输入场景选择正确的信息，并让不同来源的显示内容保持明确的优先级。</em>
</div>
