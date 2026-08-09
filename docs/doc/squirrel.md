# Squirrel (鼠须管) 部署指南

欢迎在 macOS 平台使用万象。Squirrel（鼠须管）是 Rime 在 macOS 上常用的前端之一，可以直接加载万象方案、语法模型以及对应的个性化配置。

---

### 1. 下载必要素材

开始部署前，请准备好最新的 **Squirrel 前端**、**万象方案包**和**语法模型**。

**1. 下载 Squirrel**

* [:octicons-download-24: 前往 GitHub Releases 获取最新版](https://github.com/rime/squirrel/releases)

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

### 2. 打开 Rime 用户目录

万象的方案文件、Custom 配置以及语法模型都需要放入鼠须管的 Rime 用户目录。

![用户目录](../image/user_dir_squirrel.jpg){ width="600" style="display: block; margin: 1rem auto; border-radius: 8px; box-shadow: 0 4px 12px rgba(97, 161, 101, 0.15);" }

* **通过鼠须管菜单进入**：点击 macOS 顶部菜单栏中的鼠须管图标，在菜单中选择 **【用户设定...】**。

* **通过 Finder 直接进入**：在 Finder 中按下 **Shift + Command + G**，输入：

    ```text
    ~/Library/Rime
    ```

    该路径对应当前用户的 Rime 用户目录，例如：

    `/Users/用户名/Library/Rime`

---

### 3. 解压并置入万象方案

将下载好的万象方案 `.zip` 压缩包解压。

!!! warning "不要保留额外的外层目录"
    进入解压后的方案文件夹，将其中的**所有文件和文件夹**复制到 `~/Library/Rime`。

    不要把类似 `rime-wanxiang-*` 的最外层文件夹整体放入 Rime 用户目录，否则会多出一层目录，导致方案文件无法位于正确位置。

!!! info "配置文件覆盖说明"
    * `default.yaml`：包含 Rime 的全局默认配置和快捷键等内容。如果当前用户目录中还运行其他方案，覆盖前建议先确认其中是否存在需要保留的个人配置。

    * `squirrel.yaml`：用于鼠须管前端的界面和外观配置。直接覆盖可能改变现有候选窗口样式，因此已有自定义外观时建议先备份或改用 `squirrel.custom.yaml` 维护个人修改。

![鼠须管用户目录](../image/wxconfig.png){ width="600" style="display: block; margin: 1rem auto; border-radius: 8px; box-shadow: 0 4px 12px rgba(97, 161, 101, 0.15);" }

*全部放入后，目录结构应与上图大致一致。若用户目录中存在其他方案留下的 `luna*` 文件，请先确认是否仍在使用对应方案，再决定是否清理。`build` 目录属于部署生成内容，需要排查旧缓存时可以删除，之后重新部署会再次生成。*

---

### 4. 置入语法模型

将下载好的：

`wanxiang-lts-zh-hans.gram`

直接放入：

`~/Library/Rime`

确保语法模型与 `wanxiang.schema.yaml` 等方案文件位于同一级用户目录中。

---

### 5. 执行重新部署

完成方案和语法模型的放置后，点击 macOS 顶部菜单栏中的鼠须管图标，选择 **【重新部署】**。

> **首次部署可能需要一定时间**：Rime 需要编译词库、加载语法模型，并初始化 Lua 等相关组件。具体耗时与设备性能和方案规模有关。部署完成前，建议不要连续重复触发重新部署。

部署完成后，确认方案列表中已经出现“万象拼音”或“万象拼音 Pro”等对应方案，并检查是否能够正常输入。

---

### 6. 初始指令与输入类型切换

部署成功后，万象默认使用以下输入方式：

* **Base 标准版**：默认开启 **全拼**。
* **Pro 增强版**：默认开启 **自然码双拼**。

!!! tip "建议执行一次方案切换指令"
    即使当前默认输入方式已经符合使用习惯，也建议通过 [斜杠指令](../slash_commands.md) 主动选择一次需要的拼音方案。

    该切换不仅涉及主方案，还会同步调整英文、混输、反查等相关方案中的输入类型配置。具体原理可以参考 Custom Patch 相关说明。

    例如，在**任意输入框的中文输入状态下**输入 **`/zrm`**（切换自然码双拼）或 **`/flypy`**（切换小鹤双拼），完成后再通过鼠须管菜单执行一次 **【重新部署】**，使相关配置统一生效。

    --8<-- "docs/doc/slash_commands.md"

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>确认用户目录、方案文件、语法模型和重新部署流程无误后，即可在鼠须管中正常使用万象。</em>
</div>
