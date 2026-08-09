# 个性化词库与同步：自定义与管理个人输入数据

> **从少量固定短语，到大规模专业词库，再到多设备之间的用户词同步，万象提供了不同层级的数据扩展方式。**

根据数据规模、使用方式和是否需要参与正常组句，可以将个性化词库大致分为以下几类。选择合适的方式，可以避免不同词库之间相互干扰，也便于后续更新、维护和同步。

---

## 1. 自定义短语 (Custom Phrase)：适合固定内容快速上屏

自定义短语是最简单、最轻量的扩展方式，主要适合**短编码触发固定内容**，例如常用短语、特殊符号串、邮箱地址、固定签名等。

!!! tip "工作方式与配置规范"
    系统会读取用户目录中的文本文件，例如 `custom_phrase.txt`，并将其中的内容作为固定短语加载。

    * **数据格式**：`上屏文本\t编码\t组内排序权重`

      其中 `\t` 表示 **Tab 制表符**，不能使用普通空格代替。

    * **排序规则**：最后一列数字用于控制相同编码下词条在该文件内部的排序，数值越大，位置越靠前。Custom Phrase 本身通常用于提供优先显示的固定候选。

    * **编辑工具**：建议使用 VS Code、Sublime Text 等能够明确显示编码和制表符的文本编辑器，避免因为 Tab、文件编码等问题造成格式错误。

    **避免更新覆盖**

    如果需要长期维护自己的短语文件，建议新建独立文件，并通过 `wanxiang.custom.yaml` 修改调用路径，而不是直接修改万象随版本提供的默认文件。

    ```yaml
    patch:
      # 将自定义短语源文件改为自己维护的 my_phrase.txt
      "custom_phrase/user_dict": my_phrase
    ```

这样后续更新万象时，可以保留自己的短语文件，不必反复合并修改。

---

## 2. 固定词库自定义：扩展专业或行业词汇

如果需要加入较大规模的医学、法律、工程、专业术语或其他领域词汇，并希望这些词像主词库一样参与正常候选和组句，更适合使用**固定词库 (Dict)**。

### 词库预处理

!!! danger "万象词库的编码要求"
    普通的纯拼音词库不能直接作为万象固定词库使用，因为万象的基础词库包含带调拼音等编码信息，Pro 版还涉及辅助码数据。

    外部词库需要先通过对应工具处理，使词条编码与万象当前使用的 `chars` 数据保持一致。

    Base 版通常需要先处理拼音；Pro 版在完成拼音处理后，还需要进一步生成对应的辅助码数据。

    相关工具可以在下面的页面获取：

    [点击获取：万象词库刷拼音/辅助码工具](https://github.com/amzxyz/RIME-LMDG/releases/tag/tool)

### 挂载固定词库的两种方式

完成预处理后，可以通过 `wanxiang.custom.yaml` 将自己的固定词库加入方案。

**方法 A：通过 Packs 扩展（推荐）**

这种方式不需要修改主词库文件，自己的词库可以单独维护，后续更新也更加方便。

假设新词库文件命名为：

`userxx.dict.yaml`

其词库表头中的 `name` 需要保持一致：

```text title="词库表头示例"
# rime dictionary
---
name: userxx
version: "LTS"
sort: by_weight
...
```

然后在 `wanxiang.custom.yaml` 中追加：

```yaml title="wanxiang.custom.yaml"
patch:
  translator/packs/+:
    - userxx  # 填写词库名称，不需要包含 .dict.yaml
```

重新部署后，该词库即可作为主词库的扩展参与输入。

**方法 B：自定义主词库**

如果需要直接维护一套自己的完整主词库，可以复制根目录中的 `wanxiang.dict.yaml`，例如重命名为：

`wanxianguser.dict.yaml`

同时将词库内部的 `name` 等信息修改为对应名称。

随后通过 Patch 将相关词库调用统一指向新的主词库：

```yaml title="wanxiang.custom.yaml"
patch:
  translator/dictionary: wanxianguser
  user_dict_set/dictionary: wanxianguser
  add_user_dict/dictionary: wanxianguser
```

这种方式会直接替换方案原本调用的主词库，更适合已经了解万象词库结构和相关调用关系的用户。

---

## 3. 挂接方案与主方案：扩展词库的调用关系

在万象中，`wanxiang.schema` 和 `wanxiang_pro.schema` 属于主输入方案，而 `wanxiang_english.schema` 等方案则承担独立词库的编译和挂接工作。

理解两者之间的关系后，可以进一步替换或扩展英文等独立词库。

!!! info "挂接方案与主方案的关系"
    以 `wanxiang_english.schema` 为例，它负责调用对应的英文词典并完成编译，最终生成主方案可以使用的词库数据。

    主方案中则存在对应的 Translator 配置，用于调用这套已经编译完成的英文词库：

    ```yaml
    wanxiang_english:
      dictionary: wanxiang_english
    ```

    因此可以简单理解为：

    **挂接方案负责生成对应词库，主方案负责调用该词库。**

    如果修改了挂接方案使用的词库名称，主方案中的调用名称也需要同步修改。

### 示例：替换或扩展英文挂接词库

假设需要使用一套自己的专业英文词库，可以同时调整挂接方案和主方案。

**步骤 1：修改挂接方案使用的词库**

例如将原来的：

`wanxiang_english.dict.yaml`

复制或重命名为：

`wanxiang_english_user.dict.yaml`

并确保词典内部的 `name` 与文件名对应。

随后新建或修改 `wanxiang_english.custom.yaml`：

```yaml title="wanxiang_english.custom.yaml"
patch:
  # 其他已有 Patch 保持不变
  translator/dictionary: wanxiang_english_user
```

这样重新部署时，英文挂接方案会使用新的词库进行编译。

**步骤 2：修改主方案中的调用名称**

随后在主方案对应的补丁文件中修改英文词库调用。

Base 版使用 `wanxiang.custom.yaml`，Pro 版使用对应的 `wanxiang_pro.custom.yaml`：

```yaml title="wanxiang.custom.yaml"
patch:
  # 其他已有 Patch 保持不变
  wanxiang_english/dictionary: wanxiang_english_user
```

两处名称保持一致后重新部署，即可让主方案调用新的英文词库。

---

## 4. 用户词库同步：在多设备之间迁移 UserDB

日常输入过程中产生的用户词会记录在动态数据库中。

Base 版主要使用：

`wanxiang.userdb`

Pro 版则根据当前方案配置使用对应的 UserDB，例如：

`zc.userdb`

Rime 自带同步机制，可以将用户数据库导出为文本数据，并在不同设备之间进行合并。

!!! bug "不要直接使用网盘同步整个 Rime 用户目录"
    不建议将正在运行的整个 Rime 用户目录直接放入坚果云、OneDrive 等网盘中进行实时同步。

    UserDB 属于运行中的动态数据库文件。网盘程序直接读取、占用或同步这些数据库文件，可能造成文件锁定，从而影响 Rime 正常读写用户词库。

    更合适的方式是使用 **Rime 自带的同步功能**：先将 UserDB 导出到同步目录，再通过网盘同步这个目录。

    **只同步 Rime 设置的 `sync` 目录，不直接同步正在使用的 UserDB 数据库目录。**

### 步骤 1：设置同步目录与设备 ID

打开用户目录中的 `installation.yaml`，为当前设备设置独立的 `installation_id`：

```yaml title="installation.yaml"
distribution_name: Rime
installation_id: "windows"  # 建议使用容易识别的设备名称，例如 windows、mac、linux
```

然后配置 `sync_dir`。

Linux、macOS、Android 等环境可以使用类似：

```yaml
sync_dir: "/home/amz/sync"
```

Windows 可以根据 YAML 字符串写法选择双引号或单引号：

```yaml
sync_dir: "D:\\home\\amz\\sync"
```

或者：

```yaml
sync_dir: 'D:\home\amz\sync'
```

建议将最终同步目录统一设置到网盘中的 `sync` 目录，便于多设备共享。

### 步骤 2：了解同步后的目录结构

执行 Rime 同步后，会在 `sync` 目录中创建以当前 `installation_id` 命名的设备目录。

例如当前设备设置为：

`installation_id: "windows"`

则可能生成：

`/sync/windows/`

用户词库会被导出为对应的文本文件，例如：

`wanxiang.userdb.txt`

文件头包含数据库和设备相关信息：

```text
# Rime user dictionary
#@/db_name  wanxiang
#@/db_type  userdb
#@/rime_version 1.13.1
#@/tick 793
#@/user_id  windows
```

其中需要特别注意：

* `db_name` 应与当前方案实际使用的 UserDB 名称对应。

* `user_id` 应与当前设备的 `installation_id` 保持一致。

* 对应的设备目录名称也应与该设备 ID 对应。

Pro 版如果实际使用的是 `zc.userdb`，导出的数据库名称也应以当前实际配置为准。

### 步骤 3：导入旧数据与多设备同步

* **导入已有用户词数据**

  如果需要恢复以前的用户词，可以在确认数据库名称和编码格式正确的前提下，将历史数据整理到对应的 `*.userdb.txt` 文件中。

  用户词编码必须与当前万象方案使用的编码体系保持一致；从其他词库导入的数据，应先完成必要的编码预处理。

  完成后执行 Rime 的同步操作，由同步机制重新读取并合并这些数据。

* **多设备同步**

  每台设备应设置不同的 `installation_id`，例如：

  `windows`

  `linux`

  `mac`

  执行同步后，各设备会在共同的 `sync` 目录中保留自己的同步数据。

  Rime 在执行同步时会读取这些设备目录中的用户词数据，并按照自身的同步机制进行合并，使不同设备产生的用户词可以相互迁移。

---

## 如何选择合适的方式？

几种方式的用途并不相同：

* **少量固定内容、邮箱、签名、特殊短语**：使用 Custom Phrase。

* **大量行业词汇或专业语料**：制作独立固定词库，并通过 `translator/packs` 挂载。

* **需要替换英文等独立挂接词库**：同时调整挂接方案与主方案中的词库名称。

* **日常输入产生的人名、术语和个人造词**：保存在 UserDB，并通过 Rime 原生同步机制进行多设备迁移。

固定词库解决的是**预先准备的数据扩展**，UserDB 解决的是**使用过程中逐渐积累的个人数据**。将两者分开管理，后续更新、备份和同步会更加清晰。

---

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>固定数据独立维护，个人词汇持续积累，并通过 Rime 的同步机制在不同设备之间迁移。</em>
</div>
