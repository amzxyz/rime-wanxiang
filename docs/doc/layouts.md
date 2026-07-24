# 📱 特殊按键转写：9键 / 14键 / 18键 设定指南

> **万象不仅支持标准的 26 键全键盘，还通过极其灵活的拼写运算（Algebra）实现了对 9 键、14 键、18 键等特殊键盘布局的完美兼容。**

其核心逻辑非常简单：通过正则和转写规则，将方案原本的标准拼音编码，**映射/转换**成你键盘上实际能打出来的字母或数字按键。按键相呼应，自然就能打出想要的字。

---

## ⚙️ 一、预设的转写规则库 (Algebra 映射)

在万象的 `wanxiang_algebra.yaml` 文件末尾，我们预设了针对各种特殊键盘的转写段落。一切都可以在此处集中管理和自定义。

为了保持结构统一，我们使用 `__append` 追加模式。其中 14 键和 18 键主要是简单的字母合并，而 **9 键（T9 拼音）**由于涉及声调剥离、大小写转换和九宫格数字映射（2-9），最终实现了26键字母编码（配合前端拼音选择器）+九键数字的编码集合，规则会更加精细：

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

!!! info "原理解析"
    * **14/18 键**：通过 `xlit` 将相邻的几个字母强行归并为一个字母（即你按下的那个代表键）。

    * **9 键**：先去除带调拼音的声调标记，将拼音统一转为大写，最后根据手机九宫格的标准布局，将大写字母全部映射替换为 `2` 到 `9` 的数字。

---

## 🚀 二、如何在 Custom 中开启？

想要激活上述的特殊键盘布局，你无需修改方案的核心文件，只需在你当前使用方案的 `.custom.yaml` 文件（例如 `wanxiang.custom.yaml`）中，将相应的段落引用到拼写运算节点后面即可。

**配置示例：**

```yaml
patch:
  speller/algebra:
    __patch:
      #- wanxiang_algebra:/模糊音
      - wanxiang_algebra:/base/全拼
      
      # 👇 开启你需要的特殊键盘布局（以 18 键为例）
      - wanxiang_algebra:/18jian    
```

!!! danger "排版避坑警告 (非常重要)"
    特殊键盘的转写引用（如 `- wanxiang_algebra:/18jian` 或 `/9jian`）**必须严格放置在拼写运算列表的最后一行！**
    
    无论前面配置了什么全拼运算或是模糊音规则，都要先让标准拼音运算完成，最后再由这行代码执行按键层面的“物理归并转写”。如果放错位置，会导致前面的拼写规则彻底失效。