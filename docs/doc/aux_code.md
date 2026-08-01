# ⌨️ 辅助码系统全解：精准定字的终极奥义

> **拼音负责发音，辅助码负责定字。跨越同音重码的鸿沟，享受“三码出字、四码出词”的盲打心流。**

万象内置了多套辅助码方案（默认以“自然码”逻辑举例）。它采用了最符合直觉的 **“拼音 + 部首读音”** 规则：无需死记硬背复杂的字根表，只需在双拼或全拼的基础上，直接追加汉字部首的声母即可极速筛选目标字。

<div align="center" style="margin: 1.5rem 0;">
    <img src="https://storage.deepin.org/thread/202407041144502563_截图_选择区域_20240704121653.png" style="max-width: 100%; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
    <p style="font-size: 0.85em; color: #666; margin-top: 0.5rem;">基于拼音与部首声母的辅助码逻辑</p>
</div>

---

## 🛤️ 双轨并行：直接辅助码 vs 间接辅助码

万象 Pro 版为你提供了两种不同维度的辅助码介入方式，以适应不同的输入节奏和熟练度。

### 1. ⚡ 直接辅助码：行云流水的极速定字 (Pro 专属)

**核心逻辑**：不加任何分隔符，输入拼音后**直接无缝追加**部首声母。

* **基础连招**：以输入“镇”字为例。双拼输入 `vf` (zhen) + 金字旁声母 `j` (jin) ➔ 完整输入 **`vfj`**，瞬间单字上屏。

* **进阶盲打**：如果首选依然不是目标字，可继续输入该字主体部件的声母+/进行极限收拢。

<div align="center" style="margin: 1.5rem 0;">
    <img src="https://storage.deepin.org/thread/202407041147131421_截图_选择区域_20240704121809.png" style="max-width: 100%; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
</div>

!!! warning "冲突解决：重码处理与单字聚拢 (`/` 键的妙用)"
    **痛点**：当“双拼+辅码（3-4码）”恰好与词库中某个四码的词组重码时，系统为了保证整句输入的流畅度，会**优先显示词组**。

    *(注：从与词组重码率的高低，也能客观评判一套辅助码方案的优劣。)*

    **破局之法**：此时只需在编码末尾**追加一个 `/`（斜杠）**，即可触发“聚拢”指令。系统会瞬间忽略词组，强制优先展示带该辅助码的单字！

<div style="display: flex; gap: 20px; justify-content: center; align-items: flex-end; flex-wrap: wrap; margin-bottom: 1.5rem;">
    <div style="text-align: center;">
        <img src="https://storage.deepin.org/thread/202408210142513354_截图_选择区域_20240821093644.png" 
             style="height: 50px; width: auto; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
        <p style="font-size: 0.85em; color: #666; margin-top: 0.8rem;">未加斜杠：优先展示匹配的词组</p>
    </div>
    
    <div style="text-align: center;">
        <img src="https://storage.deepin.org/thread/202408210143144721_截图_选择区域_20240821093701.png" 
             style="height: 50px; width: auto; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
        <p style="font-size: 0.85em; color: #666; margin-top: 0.8rem;">追加斜杠 (/)：强制单字聚拢</p>
    </div>
</div>

### 2. 🛡️ 间接辅助码：新手的安全护城河 (Pro 专属)

**核心逻辑**：使用 `/` 作为前置引导符，格式为：**`拼音/辅码`**。

* **输入演示**：你（ni）+ 亻（re） ➔ **`ni/re`**。

* **设计哲学**：间接辅助码是对“当前字”的强干预，你必须在输入拼音后、打下个字之前完成输入（与输入完一长串再回去找字的“后辅筛”截然不同）。

* **优势**：如果不输入 `/`，系统绝对不会将其误认为辅助码。它彻底杜绝了辅码干扰拼音切分的问题，极度适合刚接触辅助码的新手，让你能安心保持原有的打字节奏。

---

## 🎯 高阶定位：声调与大写字母的自由交织

为了在极其有限的键盘按键中压榨出最高的定字效率，万象引入了“乱序声调”与“大写字母”的混合编码辅助引擎。

### 1. 🎵 声调筛选 (数字 7,8,9,0)

键盘主区的空间寸土寸金，万象摒弃了繁琐的符号映射，直接利用原生词库带调的优势，将 **`7, 8, 9, 0`** 四个数字键分别映射为拼音的 **`1, 2, 3, 4`** 声（轻声归并入 4 声）。

最绝妙的是：**声调与辅助码的输入顺序是完全自由的！** 在双拼的两码之后，你可以在任意位置插入声调数字，彻底释放你的肌肉束缚。


<div style="display: flex; flex-direction: column; gap: 15px; align-items: center; margin-top: 1.5rem; margin-bottom: 2rem;">
    <img src="https://storage.deepin.org/thread/202505120222182012_截图_选择区域_20250512101814.png" style="width: 100%; max-width: 520px; border-radius: 6px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
    <img src="https://storage.deepin.org/thread/20250512022217432_截图_选择区域_20250512101752.png" style="width: 100%; max-width: 520px; border-radius: 6px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
    <img src="https://storage.deepin.org/thread/202505120222163619_截图_选择区域_20250512101713.png" style="width: 100%; max-width: 520px; border-radius: 6px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
    <p style="font-size: 0.85em; color: #666; margin-top: 0.5rem;">声调与字母自由乱序混合输入演示</p>
</div>

### 2. 🔠 大写辅助筛选
除了小写字母和声调，你还可以直接穿插**大写字母**来进行定位。系统支持将小写、大写、声调进行疯狂的排列组合，全部都能精准命中！

* *终极混合演示 (目标词“你”)*：`ni/` `ni9/` `niRE/` `niR9E/` `nirE/` `niRe/` `ni9RE/` `niRE9/` `nire9/` `ni9re/` `nir9e` ... 所有这些变体，引擎都能瞬间解析！

## 输入后反查/辅筛（Lua）

[输入后反查/辅筛](../super_lookup) 由 Lua 脚本实现，可在完成拼音输入后继续进行反查、候选辅筛和整句定字，提供更多维度的辅助码能力。

---

<div align="center" style="margin-top: 3rem; margin-bottom: 1rem;">
    <p style="font-size: 0.9em; color: #666; max-width: 600px; line-height: 1.6; text-align: left; display: inline-block;">
        辅助码的真正意义，绝不是为了增加键盘上的记忆负担，而是为了赋予你一种<strong>“绝对的确定感”</strong>。当你将这套体系内化为肌肉记忆后，翻页寻找重码将彻底成为历史。每一次敲击，都是对文字极其自信的定点释放。在万象的世界里，你不需要去迎合输入法，而是让输入法成为你思维的最快延伸。
    </p>
</div>