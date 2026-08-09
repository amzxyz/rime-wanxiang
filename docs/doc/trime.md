# Trime (同文输入法) 部署指南

欢迎在 Android 平台使用万象。Trime（同文输入法）是 Android 上的 Rime 前端，方案文件、词库和语法模型的部署思路与桌面端基本一致，但用户目录授权、方案选择和主题配置由 Trime 自身负责。

[:octicons-download-24: 前往 GitHub Releases 获取 Trime](https://github.com/osfans/trime/releases)

---

## 1. 安装 Trime 并授权用户目录

安装 Trime 后，先按照应用引导完成输入法启用、切换以及存储目录授权。

Trime 默认使用手机存储中的：

```text
/rime
```

作为 Rime 用户目录，万象方案、词库、Lua 文件和语法模型默认都放在这里。

较新的 Android 系统受到存储访问机制限制，首次使用时需要按照 Trime 的提示授权该目录。

!!! tip "默认使用 /rime，也可以在设置中自定义"
    正常情况下直接使用 Trime 默认的 `/rime` 用户目录即可。

    如果希望把 Rime 数据放在其他位置，也可以进入 Trime 设置，自定义其他位于 SD 卡或手机存储空间中的目录。

    一旦修改了用户目录，后续万象方案、语法模型和相关配置都应放入**当前实际设置的 Rime 用户目录**，而不是继续复制到默认 `/rime`。

因此：

```text
未修改目录 → 使用默认 /rime
已经自定义目录 → 使用设置中指定的目录
```

完成授权后，再继续复制万象文件。

---

## 2. 下载万象方案与语法模型

### 下载万象拼音方案

* **国内节点（CNB）**：[:octicons-link-external-24: 前往 Releases](https://cnb.cool/amzxyz/rime-wanxiang/-/releases)

* **GitHub**：[:octicons-link-external-24: 前往 Releases](https://github.com/amzxyz/rime-wanxiang/releases)

### 下载语法模型

* [:octicons-download-24: wanxiang-lts-zh-hans.gram](https://cnb.cool/amzxyz/rime-wanxiang/-/releases/download/model/wanxiang-lts-zh-hans.gram)

下载完成后，将万象方案压缩包解压。

---

## 3. 将万象文件放入 Trime 用户目录

进入 Trime 默认的 `/rime` 用户目录；如果已经在设置中自定义了其他目录，则进入当前实际设置的 Rime 用户目录。然后执行以下操作：

1. 将 **`wanxiang-lts-zh-hans.gram`** 放入用户数据目录根部。
2. 打开万象方案解压后的文件夹。
3. 将其中的**所有文件和文件夹**复制到 Trime 用户数据目录。
4. 如果存在同名文件，根据自己的配置情况决定是否覆盖；全新安装通常可以直接覆盖。

!!! warning "不要多套一层压缩包根目录"
    正确结构应当是：

    ```text
    Rime 用户目录/
    ├── wanxiang.schema.yaml
    ├── wanxiang.dict.yaml
    ├── wanxiang_algebra.yaml
    ├── lua/
    ├── dicts/
    ├── wanxiang-lts-zh-hans.gram
    └── ...
    ```

    而不是：

    ```text
    Rime 用户目录/
    └── rime-wanxiang-某版本/
        ├── wanxiang.schema.yaml
        ├── lua/
        └── dicts/
    ```

    Trime 默认直接从 `/rime` 读取这些方案文件；如果已经修改用户目录，则从设置中指定的新目录读取。

---

## 4. 关于 Trime 主题与键盘布局

Trime 除了 Rime 方案本身，还拥有独立的前端主题配置。`.trime.yaml` 文件可以定义键盘布局、按键、候选区、配色、符号面板等 Trime 专属内容。

万象仓库的 `custom` 目录提供了额外的 Trime 配置参考，例如：

```text
custom/简纯.zip
```

其中包含适用于 Trime 的键盘主题配置，可按需自行使用。

!!! info "为什么万象发布包不强制附带 Trime 皮肤？"
    Trime 主题不仅控制颜色，还可能接管键盘布局、按键功能和符号面板。

    不同用户对手机键盘高度、按键数量、符号布局和手势习惯差异较大，因此万象方案本体不适合强制覆盖用户已经使用的 Trime 主题。

    如果希望直接使用万象提供的参考布局，可以另外下载 `custom/简纯.zip`；如果已经有自己的 Trime 主题，则继续使用原主题即可。

!!! note "主题与输入方案是两套配置"
    万象方案负责：

    ```text
    拼音
    词库
    Lua
    语法模型
    反查
    辅助码
    ```

    Trime 主题主要负责：

    ```text
    手机键盘布局
    候选区显示
    按键外观
    符号面板
    前端交互
    ```

    不安装万象附带的参考主题，并不会导致万象词库本身失效。

---

## 5. 选择需要使用的方案

文件复制完成后，回到 Trime 主界面。

通常可以从 **【方案】** 页面管理需要启用的 Rime Schema：

1. 打开 **【方案】**。
2. 点击添加或方案选择入口。
3. 勾选需要使用的万象方案：

   ```text
   万象拼音
   ```

   或：

   ```text
   万象拼音 Pro
   ```

4. 如果不需要其他方案，可以取消无关方案的勾选。
5. 保存后执行部署。

!!! note "方案选择最终对应 schema_list"
    Rime 实际启用哪些方案，由 `default` 配置中的 `schema_list` 决定。

    Trime 的方案选择界面本质上是在帮助用户维护这部分配置，因此熟悉 Rime 后，也可以通过 `default.custom.yaml` 自行管理方案列表。

    例如：

    ```yaml
    patch:
      schema_list:
        - schema: wanxiang
    ```

    Pro 用户则根据当前实际 Schema ID 选择对应方案。

---

## 6. 执行部署

完成方案选择后，在 Trime 中执行 **【部署】**。

不同版本的 Trime 在按钮名称和图标位置上可能略有差异，一般可以在方案页面或应用主界面找到部署入口。

### 为什么第一次部署会比较慢？

万象包含：

```text
多份词典
Lua 模块
方案依赖
OpenCC / 数据文件
语法模型
```

首次部署时，Rime 需要根据配置生成相应的编译数据，因此耗时会明显高于普通的小型方案。

!!! warning "首次部署期间避免频繁重复操作"
    实际耗时与以下因素有关：

    * 手机处理器性能
    * 存储读写速度
    * 当前万象版本的数据量
    * Base / Pro 版本
    * Trime 与 librime 版本

    某些设备可能几十秒完成，也可能需要数分钟。

    部署过程中如果界面短时间没有明显变化，不要连续点击部署按钮，也不要立即判断为应用崩溃。优先等待当前部署过程结束，并观察 Trime 是否给出成功或失败提示。

!!! danger "如果长时间始终无法完成部署"
    不要无限重复点击部署。

    可以依次检查：

    1. 万象文件是否放在默认 `/rime`，或当前设置中指定的自定义 Rime 用户目录。
    2. 是否误把整个 `rime-wanxiang-xxx` 外层文件夹复制进用户目录。
    3. `wanxiang-lts-zh-hans.gram` 是否位于默认 `/rime`，或当前实际使用的自定义 Rime 用户目录根部。
    4. 用户数据目录是否仍然具有访问权限。
    5. 是否存在旧版本残留的 `build` 数据导致异常。
    6. Trime 日志中是否存在具体的 YAML、词典或 Lua 报错。

---

## 7. 启用 Trime 主题

如果已经另外复制了万象提供的 Trime 参考主题，可以在部署后进入 Trime 的主题设置。

一般操作思路为：

1. 打开 Trime。
2. 进入 **【主题】**。
3. 找到已经放入 Trime 配置目录的主题。
4. 选择并应用。

例如使用 `简纯.zip` 中提供的主题时，主题列表中会显示对应的主题名称。

!!! note "找不到主题时先检查文件，而不是重新部署词库"
    如果万象输入方案已经能正常打字，但主题列表中没有目标主题，应优先检查：

    * `.trime.yaml` 是否已经放入 Trime 能读取的位置
    * 主题压缩包是否已经正确解压
    * 文件名与 YAML 内容是否完整
    * 当前 Trime 版本是否能够读取该主题格式

    这属于 Trime 前端主题问题，与万象词库是否成功编译是两回事。

---

## 8. Base 与 Pro 的默认输入类型

万象当前两类主要方案的初始输入方式不同：

* **Base 标准版**：默认使用 **全拼**
* **Pro 增强版**：默认使用 **自然码双拼**

这里的“默认”只是初始配置，并不意味着只能使用这一种输入类型。

万象可以通过斜杠指令切换全拼、不同双拼以及对应的辅助码配置。

---

## 9. 建议执行一次输入类型切换指令

部署成功后，即使当前默认输入方式已经符合自己的习惯，也建议通过万象的斜杠指令主动设置一次输入类型。

!!! tip "为什么建议主动切换一次？"
    万象的输入类型并不只影响主方案。

    一次完整切换还会协调主方案、英文、混输、反查等相关配置，使多个组件保持一致的拼写规则。

    例如需要自然码双拼，可以在中文输入状态下输入：

    ```text
    /zrm
    ```

    需要小鹤双拼：

    ```text
    /flypy
    ```

    切换完成后，再回到 Trime 执行一次部署，使修改后的 Custom 配置正式生效。

    --8<-- "docs/doc/slash_commands.md"

---

## 10. `default.custom.yaml` 与万象 Custom 文件

在 Trime 上使用万象时，仍然遵循标准 Rime Custom Patch 机制。

常见文件包括：

```text
default.custom.yaml
wanxiang.custom.yaml
wanxiang_english.custom.yaml
wanxiang_mixedcode.custom.yaml
wanxiang_reverse.custom.yaml
```

Pro 用户还会涉及对应的 Pro 配置。

其中：

```text
default.custom.yaml
```

主要负责全局层面的方案列表等配置；

而：

```text
wanxiang*.custom.yaml
```

用于覆盖各个万象方案自身的设置。

因此，如果后续使用斜杠指令生成或修改了 Custom 文件，不要只复制一个 `wanxiang.custom.yaml` 就认为所有子方案已经同步。

---

## 11. 更新万象时怎么覆盖？

后续升级万象时，仍然建议：

```text
下载新版
→ 解压
→ 将方案文件复制到原 Trime Rime 用户目录
→ 覆盖程序文件
→ 保留自己的 *.custom.yaml
→ 部署
```

!!! warning "先区分程序文件与个人 Custom"
    如果已经长期使用万象并积累了自己的配置，不建议不加区分地删除整个用户目录。

    一般应重点保留：

    ```text
    *.custom.yaml
    用户词典
    用户数据库
    个人 Tips / 短语等自定义数据
    ```

    再用新版仓库文件更新程序主体。

---

## 12. 常见问题

### 1. 部署成功，但找不到万象方案

检查：

```text
wanxiang.schema.yaml
```

是否直接位于 Trime 的 Rime 用户数据目录，而不是被多套了一层文件夹。

然后重新进入方案管理页面检查。

### 2. 能看到万象方案，但部署失败

优先查看 Trime 日志。

常见原因包括：

```text
文件复制不完整
词典缺失
YAML 配置错误
Custom 与新版结构不兼容
Lua 文件缺失
语法模型位置错误
```

### 3. 可以输入，但语法模型没有效果

检查：

```text
wanxiang-lts-zh-hans.gram
```

是否放在默认 `/rime`，或当前 Trime 设置中指定的自定义 Rime 用户目录中。

### 4. Base / Pro 的输入类型不符合预期

使用对应斜杠指令重新切换一次，然后重新部署。

### 5. 主题没有变化

主题属于 Trime 前端配置。

确认已经：

```text
解压主题
→ 放入 Trime 可读取的配置目录
→ 在【主题】中主动选择
```

不要仅通过重新部署 Rime 方案来判断主题是否加载。

### 6. 更新后旧 Custom 出现异常

万象跨较大版本更新时，主方案节点可能发生调整。

如果旧 Custom 覆盖了已经变化的节点，应根据当前版本配置重新核对，而不是直接删除所有 Custom。

---

## 13. 推荐部署顺序

首次安装可以按照下面的顺序操作：

```text
安装并启用 Trime
        ↓
授权默认 /rime 用户目录（或确认已设置的自定义目录）
        ↓
下载万象方案
        ↓
下载 wanxiang-lts-zh-hans.gram
        ↓
把解压后的方案内容复制到用户目录
        ↓
在【方案】中选择万象 Base 或 Pro
        ↓
执行第一次部署
        ↓
确认万象能够正常输入
        ↓
按需安装 / 选择 Trime 主题
        ↓
使用 /zrm、/flypy 等指令设置输入类型
        ↓
再次部署
```

这样可以把：

```text
Rime 方案问题
```

和：

```text
Trime 主题问题
```

分开确认，出现异常时更容易定位原因。

---

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>Trime 负责 Android 端的键盘与前端交互，万象负责 Rime 方案、词库与 Lua 功能；先确认方案部署正常，再按需配置移动端主题。</em>
</div>
