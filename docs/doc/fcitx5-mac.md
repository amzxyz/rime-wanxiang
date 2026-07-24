# Fcitx5-macOS (小企鹅) 部署指南

虽然鼠须管是 Mac 首选，但如果您在使用 Fcitx5-macOS（小企鹅输入法），万象同样完美兼容。由于前端不同，其配置路径和皮肤机制与鼠须管有显著差异，请仔细阅读以下步骤。

---

### 1. 下载必要素材

在开始安装前，请确保您已经下载了最新的**前端软件**、**万象方案包**与**语法模型**：

**📦 1. 下载小企鹅前端**

命令方式：

```
brew install --cask fcitx5-macos
```

* [:octicons-download-24: 前往 GitHub Releases 获取最新版](https://github.com/fcitx/fcitx5-macos/releases)

**📦 2. 下载万象拼音方案**

* ⚡ **国内高速节点 (CNB，免翻墙)**：[:octicons-link-external-24: 点击前往下载](https://cnb.cool/amzxyz/rime-wanxiang/-/releases)

* 🌍 **国际开源节点 (GitHub)**：[:octicons-link-external-24: 点击前往下载](https://github.com/amzxyz/rime-wanxiang/releases)

**📦 3. 下载语法模型**

* [:octicons-download-24: wanxiang-lts-zh-hans.gram](https://cnb.cool/amzxyz/rime-wanxiang/-/releases/download/model/wanxiang-lts-zh-hans.gram)

!!! tip "指南：Base 包与 Pro 包该下哪个？"
    * **🟢 Base (标准版) 包**：主打省心顺滑，无需折腾，打字体验类似主流大厂输入法。
    * **🔵 Pro (增强版) 分包**：专为硬核辅码玩家打造，进行了词库编码层辅助码的携带。下载时认准自己使用的“辅助码类型”即可。
    > 🎯 **定心丸**：万象底层极其灵活。“拼音的输入方式”（全拼、各家双拼）在安装后都能通过简单指令随时切换！

---

安装好 Fcitx5 客户端后，它并非直接就是 Rime：

1. 请在插件列表中确保已加入 **【中州韵】** 插件。

2. 点击 Mac 顶部菜单栏的 **【🐧】** 图标 → **【输入法】**，将当前输入法设置为 **【中州韵】**。

### 2. 开启 Rime 用户文件夹

小企鹅无法像鼠须管那样通过点击菜单快捷打开用户目录。您必须手动进入：

**绝对路径：**
```text
~/.local/share/fcitx5/rime
```
!!! warning "⚠️ 找不到文件夹？(Mac 隐藏文件机制)"
    在 macOS 中，以 . 开头的文件夹（如 .local）属于隐藏文件。

    * 方法一 (快捷键)：在访达 (Finder) 任意窗口中，按下 ⇧⌘. (Shift + Command + 句号) 即可让隐藏文件现形。

    * 方法二 (直接前往)：在访达中按下 ⇧⌘G，直接粘贴上方的绝对路径回车即可进入。

### 3. 解压并置入万象方案与模型
将万象方案解压后的所有文件（切勿包含根目录）以及 wanxiang-lts-zh-hans.gram 模型文件，一并拖入上述的 rime 文件夹中。

!!! danger "Fcitx5 皮肤避坑须知"
    请注意：在小企鹅中，Rime 的皮肤文件（如压缩包里的 squirrel.yaml 或 weasel.yaml）是绝对不会生效的！

    * 中州韵只是 Fcitx5 的一个底层插件，外观由 Fcitx5 本体接管。

    * 需要自定义皮肤的用户，请去研究 Fcitx5 专属主题，并将下载好的主题放入 ~/.local/share/fcitx5/theme 目录下。

### 4. 执行重新部署
点击顶部菜单栏的 【🐧】 图标 → 【重新部署】。

> ⏳ **耐心等待**：由于rime是源码式+部署将词库进行转换并对lua等插件进行初始化加载，首次部署的编译量极大，可能需要 **1 分钟以上**。请耐心等待系统右下角弹出部署成功的提示，不要进行任何其他操作，避免体验到卡顿影响心情。

### 5. 初始指令与个性化切换

部署成功后，万象的默认状态如下：

* 🟢 **Base 标准版**：默认开启 **全拼**。
* 🔵 **Pro 增强版**：默认开启 **自然码双拼**。

!!! tip "强烈建议执行一次激活指令"
    即使默认方案恰好是您需要的，我们也建议您利用万象强大的 [斜杠指令](../slash_commands.md) 进行一次主动切换。这一步操作涉及到四个方案文件的自定义输入类型，不仅仅是主方案，背后的逻辑参照custom patch相关教程
    
    例如，**任意输入框，中文模式** 直接打字输入 **`/zrm`** (切换自然码双拼) 或 **`/flypy`** (切换小鹤双拼)，然后再去状态栏点击一次 **【重新部署】**。这能确保万象的底层按键绑定完美契合您的输入习惯。

    --8<-- "docs/doc/slash_commands.md"