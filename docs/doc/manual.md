# 方案配置与 Custom 补丁机制

在了解如何为万象切换全拼/双拼之前，我们需要先理解 Rime 引擎两种截然不同的方案管理哲学。这扇大门将带您进入 Rime 的“自定义新世界”。

---

### 1. Rime 的两种方案管理流派

#### 🏛️ 传统流派：多文件拆分
在这种模式下，全拼、自然码、小鹤等输入类型被严格区分成了**不同的独立方案文件**（例如 `zrm.schema.yaml`，`flypy.schema.yaml`）。
如果想启用它们，需要在全局配置文件 `default.yaml` 的 `schema_list` 段落中显式声明：
```yaml
# 方案列表
schema_list:
  - schema: zrm      # 开启自然码
# - schema: flypy    # 被注释掉，未开启
```

#### 🌌 万象流派：单主方案 + 自定义补丁 (Custom Patch)
万象采用的是更加现代且易于维护的底层架构。**万象本质上只有一个主方案**（`wanxiang.schema.yaml` 或 `wanxiang_pro.schema.yaml`）。
我们如何让这一个方案变幻出全拼、小鹤或自然码呢？答案就是利用 Rime 的核心神技 —— **Custom 补丁机制**。

> 💡 **进阶指引**：本文仅介绍基础的输入类型切换。如果您想深度学习如何手写补丁，请跳转阅读完整的 [👉 Custom Patch 方法论]。

---

### 2. 全局挂载与 default.custom.yaml

虽然万象主方案已经写好了，但很多时候我们只需要单独使用 `万象拼音` 或 `万象拼音 PRO`（其他的诸如英文、T9 等辅助方案已在内部挂接，通常不需要独立勾选）。

个别前端 UI 会引导您勾选方案，这种**“勾选”的本质，其实就是前端软件在背后为您创建了一个 `default.custom.yaml` 文件**。当然，我们完全可以脱离前端，手动创建它：

```yaml
# default.custom.yaml
patch:
  schema_list:
    - schema: wanxiang          # 挂载万象主方案
    - schema: wanxiang_english  # 挂载独立英文方案
    - schema: wanxiang_t9       # 挂载 T9 方案
```
*(⚠️ 语法铁律：一个 `.custom.yaml` 文件的顶层**必须只能有一个 `patch:`**，无论原文件结构如何，写在 `patch:` 下的内容都会实现覆盖或者拒不替换替换。)*

---

### 3. ⚖️ 优先级与核心操作原则

**强烈推荐长期使用者牢记以下运行机制！**
`.custom.yaml` 是对方案文件的最后一道补丁，属于您个人的私有配置，**永远不会被万象的后续版本升级所覆盖或删除**。

> 👑 **Rime 优先级金字塔 (从高到低)**
> `wanxiang.custom.yaml` > `wanxiang.schema.yaml` > `default.custom.yaml` > `default.yaml`

!!! danger "🚨 文件位置与修改原则 (极易踩坑)"
    1. **必须放对位置**：所有的 `custom` 文件必须放置在 **Rime 用户根目录**（与 `wanxiang.schema.yaml` 在同一层级）。
    2. **警惕“假文件”**：万象目录下有一个名为 `custom/` 的文件夹，那里**仅仅是存放模版的“仓库”**，直接修改那里的文件是绝对不会生效的！
    3. **指令的本质**：在“快速上手”中，您使用的 `/zrm` 等指令，其实就是脚本自动帮您把 `custom/` 仓库里的模版复制到了根目录。**模版仅是示例，请务必详细阅读并按需保留/删除。**

**常见补丁对应关系：**  
* `wanxiang.custom.yaml` 👉 补丁对象：`wanxiang.schema.yaml` (核心拼写逻辑)  
* `default.custom.yaml` 👉 补丁对象：全局环境配置 (快捷键、挂载列表)  
* `squirrel.custom.yaml` 👉 补丁对象：Mac 鼠须管外观  
* `weasel.custom.yaml` 👉 补丁对象：Win 小狼毫外观  

---

### 4. 🚀 实战：手动切换输入类型 (修改四大文件)

万象方案不仅包含主方案，还有配套的英文、混输和反查附属方案。如果您要手动修改输入习惯（比如从全拼改为自然码），**需要同时对以下四个文件打补丁**（举一反三，只需修改中文名称即可）：

=== "1. 主方案补丁"

    **文件：** `wanxiang.custom.yaml`
    
    ```yaml
    patch:
      speller/algebra:
        __patch:
          #- wanxiang_algebra:/模糊音               # 启用后调用 wanxiang_algebra 内部条目
          - wanxiang_algebra:/base/自然码           # 👈 在此处修改输入方案名称！
    ```
    *(💡 可选名称：全拼, 自然码, 自然龙, 汉心龙, 小鹤双拼, 搜狗双拼, 微软双拼, 智能ABC, 紫光双拼, 国标双拼, 拼音加加, 乱序17)*

=== "2. 英文附属补丁"

    **文件：** `wanxiang_english.custom.yaml`
    
    ```yaml
    patch:
      speller/algebra:
        __include: wanxiang_algebra:/english/通用规则
        __patch: wanxiang_algebra:/english/自然码   # 👈 保持与主方案一致
    ```
    *(💡 可选名称：全拼, 自然码, 小鹤双拼, 微软双拼, 搜狗双拼, 智能ABC, 紫光双拼, 拼音加加, 自然龙, 汉心龙)*

=== "3. 混输派生补丁"

    **文件：** `wanxiang_mixedcode.custom.yaml`
    
    ```yaml
    patch:
      speller/algebra:
        __include: wanxiang_algebra:/mixed/通用派生规则
        __patch: wanxiang_algebra:/mixed/自然码     # 👈 保持与主方案一致
    ```
    *(💡 可选名称与上方英文补丁相同)*

=== "4. 反查附属补丁"

    **文件：** `wanxiang_reverse.custom.yaml`
    *(注：反查补丁多了一个额外的“五笔画打法”设置参数。)*
    
    ```yaml
    patch:
      # 用于反查。此处拼音类型名称需与主方案保持一致
      speller/algebra:
        __include: wanxiang_algebra:/reverse/自然码  
        __patch: wanxiang_algebra:/reverse/hspzn   # 👈 笔画类型：可选 hspzn, hupvd, hslzy(适配乱序17)
    ```

当您在根目录创建并修改完这四个文件后，点击状态栏的 **【重新部署】**，即可享受完全属于您的私有输入习惯。因为这些 `.custom.yaml` 文件归您个人所有，无论日后万象如何更新换代，您的习惯设置都将稳如泰山！

---

!!! danger "⚠️ 终极预警：Custom 补丁并非绝对的“一劳永逸”"
    虽然您的 `.custom.yaml` 文件不会被常规的覆盖更新抹除，但这**并不意味着它可以永远放任不管**。

    如果万象的底层主方案在未来的大版本更新中发生了**破坏性变更**（例如核心架构重构、节点名称被更改），那么您原有的 Custom 补丁就会失效，您必须手动对其进行对应的调整，以匹配新的方案结构。

    **请务必牢记：** `.custom.yaml` 是完全属于您个人的私有财产。万象官方的更新包、脚本和工具箱，**无权、也绝对不会**去擅自读取或操作您的私人文件。因此，在进行跨版本的大升配时，请务必仔细阅读 Release 发布页的更新日志，关注是否有 Breaking Changes（破坏性变更）的提示！