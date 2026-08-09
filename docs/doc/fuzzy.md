# 万象模糊音配置指南

万象已经在 `wanxiang_algebra.yaml` 中预设了多组常用模糊音规则，可以根据自己的发音习惯按需启用。

**重要说明：不要直接修改 `wanxiang_algebra.yaml`。** 万象更新时可能覆盖该文件。模糊音的启用和自定义都建议通过个人配置文件 **`wanxiang.custom.yaml`** 完成。

---

## 第一步：了解可用的模糊音规则

可以根据自己的发音习惯，在配置中引用对应的标识符（Key）：

| 标识符 (Key) | 说明 |
| :--- | :--- |
| `模糊音` | 同时启用下列全部模糊音规则 |
| `模糊音_nl` | `n` 和 `l` 不分 |
| `模糊音_ry` | `r` 和 `y` 混淆（声母） |
| `模糊音_hf` | `h` 和 `f` 混淆（声母） |
| `模糊音_rl` | `r` 和 `l` 混淆（声母） |
| `模糊音_kg` | `k` 和 `g` 混淆（声母） |
| `模糊音_en_eng` | `en` 和 `eng` 前后鼻音混淆 |
| `模糊音_in_ing` | `in` 和 `ing` 前后鼻音混淆 |
| `模糊音_c_ch` | 平翘舌 `c` 和 `ch` 混淆 |
| `模糊音_z_zh` | 平翘舌 `z` 和 `zh` 混淆 |
| `模糊音_s_sh` | 平翘舌 `s` 和 `sh` 混淆 |

---

## 第二步：在 Custom 中启用模糊音

打开 **`wanxiang.custom.yaml`**，在 `patch` 中通过 `__patch` 引用需要的模糊音规则。

**配置示例：**

```yaml
patch:
  speller/algebra:
    __patch:
      # 按需引用具体的模糊音规则，可以同时启用多项
      - wanxiang_algebra:/模糊音_nl             # n / l 模糊
      - wanxiang_algebra:/模糊音_s_sh           # s / sh 模糊
      - wanxiang_algebra:/模糊音_en_eng         # en / eng 模糊

      # 主输入方案必须保留一项，用于加载对应的基础拼写规则
      - wanxiang_algebra:/base/全拼
      # 可选：全拼、自然码、小鹤双拼、搜狗双拼、微软双拼、智能ABC、
      #      紫光双拼、国标双拼、拼音加加、乱序17
```

如果只需要其中几组模糊音，建议分别引用对应的 Key；只有确实需要全部规则时，再使用 `wanxiang_algebra:/模糊音`。

---

## 进阶：自定义模糊音规则

如果预设规则中没有需要的发音混淆，可以在 `wanxiang.custom.yaml` 中自行定义一组规则，再通过 `speller/algebra` 引用。

### 注意自定义段落的 YAML 层级

自定义段落（例如 `my_fuzzy:`）**不能写在 `patch:` 的缩进内部**，而应与 `patch:` 保持同级。

为了避免层级混乱，建议将自定义段落放在文件末尾，并保持顶格书写。

**配置示例：**

```yaml
patch:
  speller/algebra:
    __patch:
      - my_fuzzy
      - wanxiang_algebra:/base/全拼

  # 这里可以继续保留其他 Patch 配置


# 自定义规则与 patch 平级，必须顶格书写
my_fuzzy:
  __append:
    # 示例：将 hu 与 fu 互相派生
    - derive/^h/f/
    - derive/^f/h/
```

这里的逻辑分为两步：

1. 在 `speller/algebra/__patch` 中引用自定义规则名，例如 `my_fuzzy`。
2. 在 `patch:` 外部定义 `my_fuzzy:`，并通过 `__append` 写入具体的 `derive` 规则。

---

## 总结

1. **按需启用**：优先引用具体的模糊音 Key，例如 `模糊音_s_sh`、`模糊音_en_eng`，避免无必要地一次启用全部规则。

2. **保留基础拼写规则**：`speller/algebra/__patch` 中需要同时引用当前正在使用的基础拼写方案，例如 `wanxiang_algebra:/base/全拼`。

3. **注意 YAML 层级**：自定义规则段必须与 `patch:` 平级，不要缩进到 `patch:` 内部。

4. **不要修改原始文件**：所有个人调整都放在 `.custom.yaml` 中完成，避免后续更新覆盖自己的配置。

5. **修改后重新部署**：保存配置后需要重新部署 Rime。若规则没有生效，优先检查 YAML 缩进、引用路径、当前拼音方案以及是否存在其他 Patch 覆盖。
