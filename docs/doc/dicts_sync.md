# 📚 个性化词库与同步：打造独属于你的输入大脑

> **从快捷短语到几十万条的行业专属语料，再到多设备的数据漫游，万象为你提供了全套的词库接管方案。**

万象的词库系统分为三个完全独立的层级。请根据你的具体需求，选择最合适的自定义方式：

---

## ⚡ 1. 自定义短语 (Custom Phrase)：快捷上屏的置顶外挂

这是最简单、最轻量的自定义方式。主要用于**短编码触发长短语、特殊符号串、邮箱地址等需要绝对“置顶”的内容**。

!!! tip "工作原理与配置规范"
    系统会读取根目录下的文本文件（如 `custom_phrase.txt`）并直接挂载。

    * **数据格式**：`你想上屏的文本\t拼音编码\t组内排序权重` (注意：`\t` 代表制表符 Tab 键，绝对不能用空格代替！)。

    * **排序**：数字仅仅是代表此文件内如果编码相同哪个靠前，数字越大越靠前。整体的排序本文件设计都是置顶**。

    * **编辑器警告**：强烈建议使用 VS Code、Sublime 等现代代码编辑器，**绝对不要使用 Windows 自带的记事本**。
    
    **⚠️ 防覆盖指南 (Patch)**：

    为了避免万象后续更新时覆盖你的自定义短语文件，请务必在 `wanxiang.custom.yaml` 中将短语文件重命名挂载：

    ```yaml
    patch:
      # 将自定义短语源文件指向你新建的 my_phrase.txt
      "custom_phrase/user_dict": my_phrase
    ```

---

## 🗄️ 2. 固定词库自定义：构建你的专属行业语料

如果你手里有一份几十万条的医学、法律或二次元词库，希望它像主词库一样参与输入法的长句转写，你需要将其制作为**固定词库 (Dict)**。

### 🔨 核心门槛：词库格式预处理 (刷拼音)
!!! danger "万象的底层数据约束"

    普通的开源词库（纯拼音）**不能**直接塞进万象！因为万象的底层模型是基于“带调拼音”甚至“声调+辅助码”构建的。

    你必须先利用专用工具，将你的外部词库“刷”成与万象主词库完全一致的编码形态，保证每个字的编码与 `chars` 一致。

    Pro版本需先刷新拼音，产物再次刷辅助码，下载下面的工具一看就懂。
    
    👉 [点击获取：万象词库刷拼音/辅助码专属工具](https://github.com/amzxyz/RIME-LMDG/releases/tag/tool)

### 🧩 挂载固定词库的两种 Patch 战术

预处理完成后，你有两种安全挂载的方式（均通过 `wanxiang.custom.yaml` 实现）：

**方法 A：Packs 扩展法 (推荐，灵活解耦)**

将你的词库命名为 `userxx.dict.yaml`（内部必须包含 `name: userxx` 表头）。

```text title="内部表头解析"
# rime dictionary
---
name: userxx
version: "LTS"
sort: by_weight
...
```

```text title="patch方法"
patch:
  translator/packs/+:
    - userxx  # 这里写词库名称，不要带dict.yaml
```

**方法 B：主词库重命名法 (适合魔改级玩家)**

将根目录下的 `wanxiang.dict.yaml` 复制并重命名为 `wanxianguser.dict.yaml`，在里面尽情添加你的数据。然后在 Patch 中全面接管：

```yaml
patch:
  # 将所有调用主词库的节点，全部指向你的魔改版，如果不能看懂方案整体设计，则不适合使用
  translator/dictionary: wanxianguser
  user_dict_set/dictionary: wanxianguser
  add_user_dict/dictionary: wanxianguser
```

---

## 🔗 3. 挂接方案与主方案协同：词库扩展的底层逻辑

在万象的架构中，`wanxiang.schema` 和 `wanxiang_pro.schema` 是**主方案**，而像 `wanxiang_english.schema` 这样的则是**挂接方案**。理解它们之间的协同原理，是你进行深度词库魔改的关键。

!!! info "运行原理揭秘：谁生产，谁消费？"
    挂接方案的作用，本质上是**“生产弹药”**。例如，`wanxiang_english.schema` 最终会协助引擎编译生成一个名为 `wanxiang_english.bin` 的词库文件。
    
    而在主方案 `wanxiang.schema` 的底层代码中，存在对应的调用指令（**“消费弹药”**）：
    ```yaml
    wanxiang_english:
      dictionary: wanxiang_english  # 调用编译好的 bin 词库
    ```
    总结来说：**挂接方案负责生产 `.bin` 词库文件，主方案负责调用并使用这个 `.bin` 词库文件。**

### 🛠️ 实战演练：如何优雅地替换/扩展英文挂接词库？

假设你手头有一份极其专业的医学英语词汇表，想要扩展默认的英文词库，你需要分两步走，实现“生产端”与“消费端”的同步修改。

**📌 步骤 1：修改挂接方案（指定新的生产目标）**

首先，将你用户目录下的原始英文词库源文件 `wanxiang_english.dict.yaml`，重命名为你自己的专属名称，例如：`wanxiang_english_user.dict.yaml`。

然后，新建或打开 `wanxiang_english.custom.yaml`，写入 Patch 指令，告诉挂接方案去编译你的新词库：

```yaml title="wanxiang_english.custom.yaml"
patch:
  # 其他已有的 Patch 内容保持不变...
  translator/dictionary: wanxiang_english_user  # 👈 指向你刚刚重命名的新词库
```

**📌 步骤 2：修改主方案（指定新的消费目标）**

“弹药”换了新名字，主方案的“枪膛”也必须跟着适配。新建或打开主方案的补丁文件 `wanxiang.custom.yaml`（Pro 版则为 `wanxiang_pro.custom.yaml`），将引用路径指向你的新词库：

```yaml title="wanxiang.custom.yaml"
patch:
  # 其他已有的 Patch 内容保持不变...
  wanxiang_english/dictionary: wanxiang_english_user  # 👈 让主方案调用你编译出的新词库
```

完成这两步后，重新部署 Rime，你的专业英文扩展词库便会完美融入万象的输入生态中。

---


## ☁️ 4. 用户词库漫游与同步：多端无缝闭环

你在日常打字时积累的造词，会被实时记录在动态数据库中（Base为 `wanxiang.userdb`，Pro版为 `zc.userdb`）。

rime通过**时序合并算法**，实现跨设备的造词数据漫游。

!!! bug "致命警告：千万别把 Rime 整个用户目录文件夹放进坚果云/OneDrive！"

    直接使用网盘同步整个 Rime 工作目录，会导致动态数据库文件（UserDB）被网盘程序**强制锁定**，这会导致无法使用用户词，不能被输入法读取报错。

    **正确的做法是：利用 Rime 原生的同步机制，将数据导出（点击同步按钮）为纯文本后再进行网盘同步。只同步同步目录**

### 📌 步骤 1：配置专属同步目录与设备 DNA

打开用户根目录下的 `installation.yaml`，定义你的网盘同步路径（最高级目录务必命名为 `/sync`）以及当前设备 ID：

```yaml
# installation.yaml 配置示例
distribution_name: Rime
installation_id: "windows"  # 修改为极具辨识度的设备名称 (如 windows, mac, linux)
```

设定同步目录 (指向你的网盘路径)
linux\mac\android这样写：
```
sync_dir: "/home/amz/sync"
```

windows这样写：
```
sync_dir: "D:\\home\\amz\\sync"  #双引号
sync_dir: 'D:\home\amz\sync'     #单引号
```

### 📌 步骤 2：理解数据流转与合并逻辑
执行同步后，系统会在你的网盘 `/sync` 目录下生成以 `installation_id` 命名的文件夹（如 `/sync/windows/`），并在里面释放出一个 `wanxiang.userdb.txt` 纯文本文件。

该文件的表头记录了极其严格的设备校验信息：
```text
# Rime user dictionary
#@/db_name  zc             <-- 必须与当前方案调用的数据库名称绝对一致
#@/db_type  userdb
#@/rime_version 1.13.1
#@/tick 793
#@/user_id  windows        <-- 必须与文件夹名称、installation_id 绝对一致
```

### 📌 步骤 3：单设备强行导入或多端合并操作

* **手动导入旧数据**：如果你只有一台设备，你可以清空本地的 `.userdb` 文件夹，然后在 `/sync/windows/wanxiang.userdb.txt` 中手动添加你的历史词汇（**注意：编码必须经过万象工具预处理过！**）。保存后再次点击“同步”，数据就会被完美吸入并重建为本地数据库。

* **多端完美漫游**：你甚至可以伪造其他设备的数据（例如把表头的 `user_id` 改成 `linux`，放进 `/sync/linux/` 文件夹下）。点击同步时，Rime 底层引擎会读取 `/sync` 下所有设备的数据，并按时间戳执行一次完美的冲突去重与合并！

---
<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem;">
    掌控了数据，你就真正掌控了万象。
</div>