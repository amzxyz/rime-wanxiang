# 💡 超级 Tips (Super Tips)：轻量化的智能外挂

> **在不抢占宝贵候选位的前提下，让你的输入法瞬间拥有化学式、翻译、简码、表情等全方位“外挂”提示。**

传统的输入法在处理非文字内容时，往往会强行挤占主候选框。万象通过 `super_tips.lua` 实现了提示与输入的分离，让输入法在保持纯净的同时，具备极强的扩展性。

---

## 🎨 视觉直观：无处不在的智能外挂

!!! success "多模态提示能力演示"
    **万象的 Super Tips 能够极其丝滑地识别并提示不同类型的数据内容。以下是部分功能的实战截图，感受指尖的智能连击：**

    <div style="display: flex; gap: 20px; justify-content: center; align-items: flex-end; flex-wrap: wrap; margin-top: 2rem; margin-bottom: 2rem;">
        <div style="text-align: center;">
            <img src="https://storage.deepin.org/thread/202509260128462735_tips化学式.jpg" style="height: 100px; width: auto; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); border: 1px solid rgba(0,0,0,0.05);">
            <p style="font-size: 0.85em; color: #666; margin-top: 0.8rem;">🧪 化学式输入示例</p>
        </div>
        <div style="text-align: center;">
            <img src="https://storage.deepin.org/thread/202509260128454675_tips符号.jpg" style="height: 100px; width: auto; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); border: 1px solid rgba(0,0,0,0.05);">
            <p style="font-size: 0.85em; color: #666; margin-top: 0.8rem;">🔢 特殊符号输入示例</p>
        </div>
        <div style="text-align: center;">
            <img src="https://storage.deepin.org/thread/202509260128457494_tips表情.jpg" style="height: 100px; width: auto; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); border: 1px solid rgba(0,0,0,0.05);">
            <p style="font-size: 0.85em; color: #666; margin-top: 0.8rem;">🤣 Emoji 表情输入示例</p>
        </div>
    </div>

---

## 🚫 核心使用哲学与性能边界

!!! warning "性能与体验警告 (PERFORMANCE WARNING)"
    **Tips 模块的设计初衷是：简短、唯一、轻量。**

    * **严禁臃肿**：请绝对避免向 Tips 数据库中塞入巨大体积的文本或重度内容。Tips 是为了“提示”而生，不是为了“存储”而生。塞入大文件会直接导致 Rime 引擎思考停顿，产生明显的打字延迟！
    * **移动端建议**：在手机端使用时，**强烈建议关闭“内嵌编码（Preedit）”**。这样 Tips 会在输入框下方的独立扩展区显示，视觉上像是一个优雅的插件面板，而非杂乱的编码。
    * **场景隔离**：
        * **社交聊天**：手握快捷键，尽情开启，让表情和翻译快人一步。
        * **办公文档**：建议按 `Ctrl + t` 彻底关闭，不让任何非文字内容干扰你的创作心流。

---

## 🛠️ 如何通过 Patch 自定义配置？

万象遵循 Rime 的补丁机制，你无需修改原始方案文件，只需在你的用户文件夹下的 `wanxiang.custom.yaml`（或对应方案的 custom 文件）中加入以下 `patch` 内容：

!!! note "参数释义"
    * **更改触发按键** (`tips_key`)：如果你习惯用逗号翻页且不想被 Tips 拦截，可改为其他按键（如 `period` 句号，或 `space` 补全）。
    * **屏蔽特定提示** (`disabled_types`)：如果你不需要某类提示，直接在列表内声明即可。可选项包括：`偏旁`、`符号`、`化学式`、`时间`、`组字`、`翻译`、`表情`、`货币`、`车牌`、`单位`。

**配置示例：**

```yaml
patch:
  # 修改 Super Tips 核心参数
  super_tips/tips_key: "comma"           # 默认逗号，可改为 "period", "semicolon" 等
  super_tips/disabled_types:             # 在下方列表内填入你想禁用的类型
    - "化学式"
    - "车牌"
    - "货币"
  # 追加用户自己的 tips 文件
  super_tips/files/+: 
    - lua/data/my_tips.txt
```

```yaml
  patch:
    switches/@7/reset: 1   # @7 代表在 switches 的第8组里加入 reset: 1 参数,即可长期启用
```

---

## 🧠 绝妙的按键复用逻辑

!!! tip "为什么默认触发键是逗号（`,`）？"
    很多用户担心逗号被 Tips 占用后无法正常向前翻页，其实万象内部有一套极其精密的拦截逻辑：

    1. **命中提示时**：当你输入的编码匹配到了 Tips（如输入 `hx` 提示了 `H₂O`），按下 `,` 会执行 **Tips 上屏**，此时逗号作为“确认功能键”。
    2. **无提示/正常翻页时**：如果你按下 `.`（句号）翻到了下一页，或者当前编码本身没有匹配任何 Tips，逗号会**瞬间恢复原本的向前翻页或打出标点功能**。两者完美共存，互不干扰！

---

## ⚠️ 兼容性与排错指南

!!! bug "特殊场景注意事项"
    * **移动端（仓输入法 / 超越输入法）**
      移动端的按键处理请一律交由 Rime 引擎底层去接管，不要在 App 设置里进行特殊映射干扰。如果需要彻底停用 Tips，请将方案内的 tips 开关 `reset` 设置为 `0`。
    * **PC 端窗口兼容性**
      在某些开启了“嵌入式编码（内嵌光标）”且窗口交互复杂的软件中，开启 Tips 可能会触发异常的乱码编码上屏。**解决对策：** 遇到此类软件，请果断按下 `Ctrl + t` 临时关闭功能，回归纯净输入模式。

---
<div align="center" style="opacity: 0.5; font-size: 0.85em;">
    万象 Super Tips：用更轻的逻辑，承载更重的功能。
</div>