# 特殊按键转写：9 键 / 14 键 / 18 键设定指南

> **万象除标准 26 键键盘外，也可以通过拼写运算（Algebra）适配 9 键、14 键、18 键等特殊键盘布局。**

其核心思路是通过正则与转写规则，将方案原本的标准拼音编码映射为特殊键盘实际能够输入的字母或数字编码。只要前端按键布局与转写后的编码保持一致，就可以正常完成输入。

---

## 一、预设的转写规则库 (Algebra 映射)

万象在 `wanxiang_algebra.yaml` 中预设了 9 键、14 键和 18 键对应的转写规则，可以直接在 Custom 配置中引用。

这些规则统一使用 `__append` 追加到现有拼写运算之后。

其中，14 键和 18 键主要通过 `xlit` 合并部分字母；**9 键（T9 拼音）**还需要处理声调、大小写以及九宫格数字映射，因此规则相对更多。

```yaml
# ====== 特殊键盘转写映射区 ======

18jian:
  __append:
    - xlit/qwertyuiopasdfghjklzxcvbnm/qwwrryuiipassffhjjlzxxvbbm/

14jian:
  __append:
    - xlit/qwertyuiopasdfghjklzxcvbnm/qqeettuuooaaddggjjlzzccbbm/

9jian:
  __append:
    - xform/ⅱ//  # 用于 Lua 判断输入类型的标记
    - xform/^(.*);.*$/$1/
    - xlit/āáǎàōóǒòēéěèīíǐìūúǔùǖǘǚǜüńňǹḿm̀/aaaaooooeeeeiiiiuuuuvvvvvnnnmmm/ # 剥离声调
    - derive/^ng$/eng/
    - xform/^n$/en/
    - xform/^m$/me/
    - derive/^(.*)$/\U$1/  # 转换为大写，为后续数字映射做准备
    - derive/^([nl])ve$/$1ue/
    - derive/^([NL])VE$/$1UE/
    - derive/^([jqxy])u/$1v/
    - derive/^([JQXY])U/$1V/
    - xlit/ABCDEFGHIJKLMNOPQRSTUVWXYZ/22233344455566677778889999/ # 标准九宫格数字映射
```

!!! info "转写规则说明"
    * **14 / 18 键**：通过 `xlit` 将多个字母归并到对应代表键，使原本的 26 键拼音编码能够适配较少按键的键盘布局。

    * **9 键**：先移除带调拼音中的声调信息，再完成部分拼音兼容处理，并将编码统一转换为大写，最后按照标准九宫格布局将 `A-Z` 映射为 `2-9` 数字编码。

    * **Lua 标记**：`xform/ⅱ//` 中的 `ⅱ` 用于 Lua 判断当前输入类型，进入实际转写流程后再将该标记移除。

---

## 二、如何在 Custom 中开启？

启用特殊键盘布局时，不需要直接修改 `wanxiang_algebra.yaml`，只需要在当前方案的 `.custom.yaml` 文件中引用对应规则。

例如，在 `wanxiang.custom.yaml` 中启用 18 键：

```yaml
patch:
  speller/algebra:
    __patch:
      #- wanxiang_algebra:/模糊音
      - wanxiang_algebra:/base/全拼

      # 开启需要的特殊键盘布局（以 18 键为例）
      - wanxiang_algebra:/18jian
```

需要使用其他布局时，将最后一行替换为对应规则即可：

* 9 键：`wanxiang_algebra:/9jian`  
* 这个需要注意九键一般不跟在别的后面因为他就是全部转写了，且有单独的方案，因此这里只是示例并不作为最终引用，需要辩证的看待和学习  
* 14 键：`wanxiang_algebra:/14jian`  
* 18 键：`wanxiang_algebra:/18jian`  

!!! danger "特殊键盘转写必须放在拼写运算末尾"
    特殊键盘的转写引用，例如 `- wanxiang_algebra:/18jian`、`- wanxiang_algebra:/14jian` 或 `- wanxiang_algebra:/9jian`，应放在 `speller/algebra/__patch` 列表的最后。

    前面的基础拼写、双拼转换、模糊音等规则需要先完成处理，最后再执行特殊键盘的按键映射。

    如果将特殊键盘转写提前到其他拼写规则之前，后续规则接收到的将不再是标准拼音编码，可能导致基础拼写、模糊音或其他 Algebra 规则无法按照预期工作。

---

## 三、配置顺序示例

如果同时使用基础拼写、模糊音和特殊键盘转写，推荐保持以下顺序：

```yaml
patch:
  speller/algebra:
    __patch:
      # 先处理模糊音
      - wanxiang_algebra:/模糊音_nl
      - wanxiang_algebra:/模糊音_s_sh

      # 再加载基础拼写方案
      - wanxiang_algebra:/base/全拼

      # 最后执行特殊键盘映射
      - wanxiang_algebra:/9jian
```

可以简单理解为：

**基础拼写与派生规则 → 模糊音等扩展处理 → 特殊键盘最终转写**

特殊键盘规则负责的是最终按键层面的编码映射，因此应当尽量放在整个 Algebra 流程的末端。

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>特殊键盘适配的关键不是改变词库，而是在拼写运算的最后一步，将标准编码转换为当前键盘能够输入的形式。</em>
</div>
