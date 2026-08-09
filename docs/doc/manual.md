# 方案配置与 Custom 补丁机制

在为万象切换全拼、双拼或其他输入类型之前，建议先理解 Rime 的方案文件与 Custom 补丁之间是如何配合工作的。

万象没有为每一种拼音输入方式单独维护一套完整主方案，而是通过统一的主方案配合 `.custom.yaml` 补丁完成切换。理解这一点之后，后续修改输入类型、挂载方案和维护个人配置都会更清晰。

---

### 1. 两种常见的方案管理方式

#### 传统方式：多个独立方案文件

一种常见做法，是把全拼、自然码、小鹤双拼等输入类型分别制作成独立的方案文件，例如：

`zrm.schema.yaml`

`flypy.schema.yaml`

需要启用某个方案时，再通过全局配置中的 `schema_list` 挂载：

```yaml
# 方案列表
schema_list:
  - schema: zrm      # 启用自然码
# - schema: flypy    # 当前未启用
```

这种方式的特点是不同输入类型彼此独立，文件关系比较直观，但当多个方案需要共享词库、Lua、反查或其他配置时，也容易出现重复维护。

#### 万象方式：单主方案 + Custom Patch

万象主要使用统一的主方案：

`wanxiang.schema.yaml`

或：

`wanxiang_pro.schema.yaml`

全拼、自然码、小鹤双拼等输入类型并不是分别对应一套完整主方案，而是通过 Rime 的 **Custom Patch** 修改主方案中的相关节点。

这样可以让词库、Lua、反查、英文和混输等公共配置继续复用，只针对需要变化的部分进行补丁覆盖。

> **进一步阅读**：本文主要说明输入类型切换和常用 Custom 文件之间的关系。如果需要自行编写更复杂的补丁，可以继续阅读 [Custom Patch 方法论]。

---

### 2. 全局方案挂载与 default.custom.yaml

万象通常只需要在前端中启用 `万象拼音` 或 `万象拼音 Pro` 主方案。英文、T9 等附属方案根据实际结构由主方案调用或挂接，一般不需要全部作为日常输入方案单独切换。

部分 Rime 前端提供图形化的“方案选择”界面。其最终效果通常会体现在全局方案列表配置中，也可以通过 `default.custom.yaml` 手动维护。

例如：

```yaml
# default.custom.yaml
patch:
  schema_list:
    - schema: wanxiang          # 万象主方案
    - schema: wanxiang_english  # 独立英文方案
    - schema: wanxiang_t9       # T9 方案
```

!!! warning "一个 Custom 文件只保留一个 patch 顶层节点"
    在同一个 `.custom.yaml` 文件中，建议只保留一个顶层 `patch:`，需要修改的内容统一写在这个节点下面。

    不要在同一个文件中重复写多个同名的顶层 `patch:`。YAML 中重复键可能导致前面的内容被覆盖或解析结果与预期不一致。

---

### 3. 配置覆盖关系与基本原则

`.custom.yaml` 的作用，是在原始配置文件基础上追加或覆盖个人修改。

例如：

* `wanxiang.custom.yaml` 用于修改 `wanxiang.schema.yaml`
* `default.custom.yaml` 用于修改 `default.yaml`
* `squirrel.custom.yaml` 用于修改鼠须管对应配置
* `weasel.custom.yaml` 用于修改小狼毫对应配置

因此，更适合把它理解为：

**原始配置提供默认值，`.custom.yaml` 在部署时对对应配置进行补丁修改。**

Custom 文件通常由用户自己维护，常规更新方案文件时不会主动覆盖这些个人补丁。

!!! danger "文件位置与修改原则"
    1. **Custom 文件应放在 Rime 用户根目录**：例如 `wanxiang.custom.yaml` 应与 `wanxiang.schema.yaml` 位于同一级目录。

    2. **不要直接修改 `custom/` 示例目录中的文件**：万象提供的 `custom/` 文件夹主要用于存放示例模板。仅修改其中的模板文件，并不会自动成为当前正在使用的根目录补丁。

    3. **斜杠指令本质上也是在生成或更新 Custom 配置**：例如 `/zrm` 等指令，会根据预设模板生成或调整对应的根目录 Custom 文件。

    因此，通过模板或指令生成配置后，仍建议打开实际使用的 `.custom.yaml` 检查内容，只保留自己需要的部分。

**常见 Custom 文件对应关系：**

* `wanxiang.custom.yaml` → `wanxiang.schema.yaml`，主要负责主方案拼写和相关逻辑
* `default.custom.yaml` → `default.yaml`，主要负责全局方案列表和公共配置
* `squirrel.custom.yaml` → 鼠须管相关配置
* `weasel.custom.yaml` → 小狼毫相关配置

---

### 4. 手动切换输入类型：同步修改四个 Custom 文件

万象除主方案外，还包含英文、混输和反查等配套方案。

如果不使用斜杠指令，而是手动把输入类型从全拼改为自然码等方案，需要同步检查以下四个 Custom 文件，使各部分使用一致的拼音类型。

=== "1. 主方案补丁"

    **文件：** `wanxiang.custom.yaml`

    ```yaml
    patch:
      speller/algebra:
        __patch:
          #- wanxiang_algebra:/模糊音               # 如需模糊音，可在这里引用
          - wanxiang_algebra:/base/自然码           # 修改为需要的输入方案
    ```

    *可选名称：全拼、自然码、自然龙、汉心龙、小鹤双拼、搜狗双拼、微软双拼、智能ABC、紫光双拼、国标双拼、拼音加加、乱序17。*

=== "2. 英文附属补丁"

    **文件：** `wanxiang_english.custom.yaml`

    ```yaml
    patch:
      speller/algebra:
        __include: wanxiang_algebra:/english/通用规则
        __patch: wanxiang_algebra:/english/自然码   # 与主方案保持一致
    ```

    *可选名称：全拼、自然码、小鹤双拼、微软双拼、搜狗双拼、智能ABC、紫光双拼、拼音加加、自然龙、汉心龙。*

=== "3. 混输派生补丁"

    **文件：** `wanxiang_mixedcode.custom.yaml`

    ```yaml
    patch:
      speller/algebra:
        __include: wanxiang_algebra:/mixed/通用派生规则
        __patch: wanxiang_algebra:/mixed/自然码     # 与主方案保持一致
    ```

    *可选名称与英文附属补丁基本一致。*

=== "4. 反查附属补丁"

    **文件：** `wanxiang_reverse.custom.yaml`

    反查方案除拼音类型外，还包含一项笔画输入方式配置：

    ```yaml
    patch:
      # 反查使用的拼音类型应与主方案保持一致
      speller/algebra:
        __include: wanxiang_algebra:/reverse/自然码
        __patch: wanxiang_algebra:/reverse/hspzn   # 笔画类型：hspzn、hupvd、hslzy（适配乱序17）
    ```

完成四个 Custom 文件的修改后，执行一次 **【重新部署】**，使新的拼音类型配置统一生效。

如果平时主要通过 `/zrm`、`/flypy` 等斜杠指令切换，这些文件通常会由相应逻辑协同更新；手动修改时，则需要特别注意四处配置是否保持一致。

---

!!! danger "Custom 补丁需要随重大版本变化进行检查"
    `.custom.yaml` 通常不会被万象的常规更新直接覆盖，但这并不意味着一份 Custom 配置可以永久不再维护。

    如果后续版本对主方案进行了较大的结构调整，例如节点名称、调用路径或方案组织方式发生变化，旧的 Custom Patch 可能无法继续匹配新的配置结构。

    因此，在跨较大版本更新时，建议阅读 Release 页面中的更新说明，特别关注是否存在 **Breaking Changes（破坏性变更）**。

    `.custom.yaml` 属于用户自己的配置文件。万象的常规更新不会主动替用户重写其中的个性化内容，因此涉及结构变化时，需要由用户根据新版配置自行调整对应补丁。

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>原始方案负责提供默认配置，Custom Patch 负责保存个人修改；理解两者的边界，是长期维护 Rime 配置的基础。</em>
</div>
