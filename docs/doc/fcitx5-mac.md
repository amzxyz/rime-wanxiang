# Fcitx5-macOS (小企鹅) 部署指南

虽然 macOS 上更常见的是鼠须管（Squirrel），但如果使用 Fcitx5-macOS（小企鹅输入法），同样可以通过中州韵（Rime）插件运行万象。由于前端不同，Fcitx5-macOS 的用户目录、部署入口和主题机制与鼠须管存在明显差异，请按照下面的步骤进行配置。

---

### 1. 下载必要素材

开始部署前，请准备好最新的 **Fcitx5-macOS 前端**、**万象方案包**和**语法模型**。

**1. 下载 Fcitx5-macOS**

可以通过 Homebrew 安装：

```bash
brew install --cask fcitx5-macos
```

也可以前往 GitHub Releases 下载：

* [:octicons-download-24: 前往 GitHub Releases 获取最新版](https://github.com/fcitx/fcitx5-macos/releases)

**2. 下载万象拼音方案**

请根据当前网络环境选择下载源：

* **国内节点 (CNB)**：[:octicons-link-external-24: 点击前往下载](https://cnb.cool/amzxyz/rime-wanxiang/-/releases)

* **GitHub**：[:octicons-link-external-24: 点击前往下载](https://github.com/amzxyz/rime-wanxiang/releases)

**3. 下载语法模型**

* [:octicons-download-24: wanxiang-lts-zh-hans.gram](https://cnb.cool/amzxyz/rime-wanxiang/-/releases/download/model/wanxiang-lts-zh-hans.gram)

!!! tip "Base 与 Pro 应该选择哪个？"
    * **Base 标准版**：适合以全拼、双拼等常规拼音输入为主的用户，配置相对简单。

    * **Pro 增强版**：在词库编码中进一步加入辅助码信息，适合需要使用辅助码筛选的用户。下载时应根据自己实际使用的辅助码类型选择对应分包。

    万象的拼音输入方式并不由安装包永久固定。完成部署后，全拼和不同双拼方案仍可以通过斜杠指令进行切换。

---

安装 Fcitx5-macOS 后，还需要确认中州韵（Rime）插件已经启用：

1. 在插件列表中确认已添加 **【中州韵】** 插件。

2. 点击 macOS 顶部菜单栏中的 Fcitx5 图标，进入 **【输入法】**，将当前输入法切换为 **【中州韵】**。

### 2. 打开 Rime 用户目录

Fcitx5-macOS 的 Rime 用户目录位于：

```text
~/.local/share/fcitx5/rime
```

与鼠须管不同，Fcitx5-macOS 不一定提供直接打开 Rime 用户目录的快捷入口，因此通常需要通过 Finder 手动进入。

!!! warning "macOS 中的隐藏目录"
    macOS 会默认隐藏以 `.` 开头的目录，例如 `.local`。

    * **方法一：显示隐藏文件**

      在 Finder 任意窗口中按下 **Shift + Command + .**，即可显示或隐藏以 `.` 开头的文件和目录。

    * **方法二：直接前往目录**

      在 Finder 中按下 **Shift + Command + G**，输入：

      `~/.local/share/fcitx5/rime`

      然后回车即可直接进入对应目录。

### 3. 解压并置入万象方案与模型

将万象方案压缩包解压后，把其中的**所有文件和文件夹**复制到：

`~/.local/share/fcitx5/rime`

同时将语法模型：

`wanxiang-lts-zh-hans.gram`

一并放入该目录。

注意应复制压缩包内部的方案内容，不要将解压后的最外层文件夹再次整体套入 `rime` 目录，否则会造成目录层级错误。

!!! danger "Fcitx5 的主题与 Rime 皮肤配置不同"
    在 Fcitx5-macOS 中，中州韵只负责提供 Rime 输入功能，候选窗口和整体外观由 Fcitx5 前端管理。

    * 万象压缩包中用于其他前端的皮肤配置，例如 `squirrel.yaml`、`weasel.yaml`，不会直接控制 Fcitx5-macOS 的界面样式。

    * 如果需要调整候选窗口、字体、配色或其他外观，应使用 Fcitx5 自身提供的主题和界面配置。

    * 自定义 Fcitx5 主题时，可以按照 Fcitx5 的主题规则，将对应主题文件放入 `~/.local/share/fcitx5/theme` 目录。

### 4. 执行重新部署

完成方案和语法模型文件的放置后，点击 macOS 顶部菜单栏中的 Fcitx5 图标，选择 **【重新部署】**。

> **首次部署可能需要一定时间**：Rime 需要编译词库、加载语法模型，并初始化 Lua 等相关组件。具体耗时取决于设备性能和方案规模。部署完成前，建议不要反复触发重新部署或频繁切换输入状态。

部署完成后，确认方案列表中已经出现“万象拼音”或“万象拼音 Pro”等对应方案，并检查能否正常切换和输入。

### 5. 初始指令与个性化切换

部署成功后，万象默认使用以下输入方式：

* **Base 标准版**：默认开启 **全拼**。
* **Pro 增强版**：默认开启 **自然码双拼**。

!!! tip "建议执行一次方案切换指令"
    即使当前默认输入方式已经符合使用习惯，也建议通过 [斜杠指令](../slash_commands.md) 主动选择一次需要的拼音方案。

    该切换不仅涉及主方案，还会同步调整相关挂接方案中的输入类型配置。具体原理可参考 Custom Patch 相关说明。

    例如，在**任意输入框的中文输入状态下**输入 **`/zrm`**（切换自然码双拼）或 **`/flypy`**（切换小鹤双拼），完成后再通过顶部菜单栏执行一次 **【重新部署】**，使相关配置统一生效。

    --8<-- "docs/doc/slash_commands.md"

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>确认前端、用户目录、方案文件和重新部署流程无误后，即可在 Fcitx5-macOS 中正常使用万象。</em>
</div>
