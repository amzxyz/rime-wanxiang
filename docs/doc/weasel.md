# Weasel (小狼毫) 部署指南

欢迎在 Windows 平台使用万象。小狼毫（Weasel）是 Rime 的 Windows 前端，万象方案、词库、Lua 模块和语法模型均放置在 Rime 用户目录中，由小狼毫完成部署和实际输入。

---

## 1. 下载必要文件

开始部署前，需要准备：

1. 小狼毫前端
2. 万象拼音方案
3. 万象语法模型

### 下载小狼毫

* [:octicons-download-24: 前往 GitHub Releases](https://github.com/rime/weasel/releases)

建议优先从小狼毫官方 GitHub Releases 获取当前发布版本。

### 下载万象拼音方案

根据网络环境选择对应下载源：

* **国内节点（CNB）**：[:octicons-link-external-24: 前往 Releases](https://cnb.cool/amzxyz/rime-wanxiang/-/releases)

* **GitHub**：[:octicons-link-external-24: 前往 Releases](https://github.com/amzxyz/rime-wanxiang/releases)

### 下载语法模型

* [:octicons-download-24: wanxiang-lts-zh-hans.gram](https://cnb.cool/amzxyz/rime-wanxiang/-/releases/download/model/wanxiang-lts-zh-hans.gram)

!!! tip "Base 与 Pro 应该下载哪个？"
    万象提供 Base 和 Pro 两类方案包：

    * **Base（标准版）**：适合直接使用拼音输入，希望较少关注辅助码编码细节的用户。
    * **Pro（增强版）**：词库编码中携带对应辅助码信息，适合需要辅助码筛选、辅助码提示等功能的用户。下载时根据自己使用的**辅助码类型**选择对应 Pro 包。

    Base / Pro 决定的是方案和词库侧的能力，并不限制拼音键盘类型。

    全拼、自然码、小鹤双拼等输入类型，都可以在安装完成后通过万象的斜杠指令进行切换。

---

## 2. 打开 Rime 用户文件夹

小狼毫默认的 Rime 用户目录为：

```text
%APPDATA%\Rime
```

通常对应：

```text
C:\Users\您的用户名\AppData\Roaming\Rime
```

### 方法一：从小狼毫菜单打开

右键 Windows 任务栏通知区域中的小狼毫图标，在菜单中选择：

```text
用户文件夹
```

### 方法二：直接输入路径

打开文件资源管理器，在地址栏输入：

```text
%APPDATA%\Rime
```

回车即可。

!!! note "如果安装时自定义过用户目录"
    小狼毫默认使用 `%APPDATA%\Rime`。

    如果安装小狼毫时已经主动指定了其他用户目录，则后续万象文件应放入**当前实际使用的小狼毫用户目录**，而不是继续复制到 `%APPDATA%\Rime`。

    普通默认安装无需修改这一目录。

---

## 3. 解压并放入万象方案

将下载好的万象方案压缩包解压。

进入解压后的方案目录，复制其中的**所有文件和文件夹**，放入小狼毫 Rime 用户目录。

!!! warning "不要多套一层压缩包根目录"
    正确结构应类似：

    ```text
    %APPDATA%\Rime\
    ├── wanxiang.schema.yaml
    ├── wanxiang.dict.yaml
    ├── wanxiang_algebra.yaml
    ├── lua\
    ├── dicts\
    ├── default.yaml
    ├── weasel.yaml
    └── ...
    ```

    不要变成：

    ```text
    %APPDATA%\Rime\
    └── rime-wanxiang-某版本\
        ├── wanxiang.schema.yaml
        ├── lua\
        └── dicts\
    ```

    Rime 需要直接从用户目录读取方案源文件，多套一层目录后不会按预期加载。

---

## 4. `default.yaml` 与 `weasel.yaml` 是否覆盖？

万象方案中包含：

```text
default.yaml
weasel.yaml
```

这两个文件与普通词库文件的作用不同。

### `default.yaml`

负责 Rime 全局配置，例如：

```text
方案列表
全局快捷键
公共按键行为
```

如果当前只使用万象，可以直接使用万象提供的配置。

如果还需要与其他 Rime 方案共存，应先检查自己原有的：

```text
default.yaml
default.custom.yaml
```

避免覆盖后把其他方案或个人全局设置一起替换。

### `weasel.yaml`

这是小狼毫前端配置，主要涉及：

```text
候选窗口
字体
配色
布局
小狼毫前端行为
```

如果把万象提供的 `weasel.yaml` 放入用户目录，小狼毫会读取这份用户配置，因此原本依赖其他 `weasel.yaml` 的前端样式可能发生变化。

!!! info "已经自定义过小狼毫外观时"
    如果自己长期维护：

    ```text
    weasel.yaml
    weasel.custom.yaml
    ```

    建议先备份，再决定是否覆盖万象提供的 `weasel.yaml`。

    长期个性化配置更建议继续放在：

    ```text
    weasel.custom.yaml
    ```

    中通过 Patch 管理，这样后续更新万象或小狼毫时更容易维护。

---

## 5. 放入语法模型

将下载好的：

```text
wanxiang-lts-zh-hans.gram
```

复制到小狼毫 Rime 用户目录根部。

例如默认目录下：

```text
%APPDATA%\Rime\wanxiang-lts-zh-hans.gram
```

### 如果提示文件正在被占用

更新已有 `.gram` 文件时，Windows 可能提示文件正被小狼毫相关进程占用。

此时可以：

1. 右键小狼毫状态栏图标。
2. 选择 **【退出算法框架】**。
3. 再覆盖 `wanxiang-lts-zh-hans.gram`。
4. 文件全部整理完成后重新启动 / 部署小狼毫。

如果当前小狼毫版本中的菜单名称略有变化，以实际显示的退出算法服务相关选项为准。

---

## 6. 清理旧方案残留与 `build`

万象文件和语法模型全部放置完成后，再检查一次 Rime 用户目录。

### 删除旧的 `luna` 方案残留

如果目录中还存在以前安装 Rime 默认方案时留下的：

```text
luna*
```

相关方案文件，并且当前不再需要这些旧方案，可以将它们删除，避免继续保留无用的旧方案文件。

例如可能包括：

```text
luna_pinyin.schema.yaml
luna_pinyin.dict.yaml
luna_pinyin_simp.schema.yaml
...
```

!!! warning "仍然需要朙月拼音时不要删除"
    这里只针对已经不再使用、但仍残留在用户目录中的旧 `luna` 文件。

    如果你还需要使用朙月拼音或其他依赖这些文件的方案，则应保留。

### 删除 `build` 文件夹

部署前建议删除用户目录中的：

```text
build
```

文件夹。

`build` 保存的是 Rime 根据源配置生成的编译结果。

删除它不会删除：

```text
*.custom.yaml
用户词典
用户数据库
```

下一次重新部署时，Rime 会根据当前方案重新生成新的 `build` 内容。

这在大版本更新、方案结构变化或旧编译结果异常时尤其有用。

---

## 7. 执行重新部署

所有文件就绪后，右键 Windows 通知区域中的小狼毫图标，选择：

```text
重新部署
```

修改方案、词典和 Custom 配置后，也需要重新部署才能生成新的编译结果。

### 首次部署为什么比较慢？

万象包含：

```text
多份词库
方案依赖
Lua 模块
数据文件
语法模型
```

首次部署时，Rime 需要重新编译方案和词库，因此耗时通常明显高于普通小型方案。

!!! warning "首次部署期间避免连续操作"
    实际耗时取决于：

    * CPU 性能
    * 磁盘性能
    * Base / Pro 方案
    * 当前词库规模
    * 小狼毫与 librime 版本

    有些电脑很快即可完成，也有设备可能需要一分钟以上。

    部署过程中不要连续反复点击“重新部署”，优先等待当前任务结束，并观察系统是否出现部署完成或错误提示。

---

## 8. 部署失败时先检查什么？

如果长时间没有成功，或部署后无法使用万象，建议依次检查。

### 1. 文件层级

确认：

```text
wanxiang.schema.yaml
```

直接位于 Rime 用户目录，而不是：

```text
Rime\rime-wanxiang-xxx\wanxiang.schema.yaml
```

### 2. 语法模型

确认：

```text
wanxiang-lts-zh-hans.gram
```

位于实际使用的 Rime 用户目录根部。

### 3. `build`

删除：

```text
build
```

后重新部署。

### 4. Custom 配置

如果以前使用过旧版万象，检查：

```text
*.custom.yaml
```

是否仍覆盖已经变化的旧节点。

### 5. 查看日志

小狼毫部署失败时，可以检查 Rime 日志中的：

```text
WARNING
ERROR
```

信息。

Windows 上相关日志通常位于系统临时目录中，以：

```text
rime.weasel.*
```

开头。

---

## 9. Base 与 Pro 的初始输入类型

部署完成后，万象当前的默认输入类型为：

* **Base 标准版**：默认 **全拼**
* **Pro 增强版**：默认 **自然码双拼**

这里的“默认”只是初始状态。

安装完成后仍可以通过斜杠指令切换其他输入类型。

---

## 10. 建议主动执行一次输入类型切换

即使当前默认输入类型已经符合自己的习惯，也建议部署成功后通过万象斜杠指令主动设置一次。

例如自然码：

```text
/zrm
```

小鹤双拼：

```text
/flypy
```

执行指令后，再进行一次：

```text
重新部署
```

!!! tip "为什么建议主动设置一次？"
    万象的输入类型不仅涉及主方案，还会同步影响英文、混输、反查等相关方案中的拼写规则。

    因此一次完整的斜杠指令切换，会比只修改主方案中的一处 `speller/algebra` 更容易保持多个相关方案一致。

    具体机制可参考 Custom Patch 与输入类型相关章节。

    --8<-- "docs/doc/slash_commands.md"

---

## 11. 更新万象时的推荐做法

后续更新万象时，可以按照：

```text
下载新版方案
      ↓
退出正在占用文件的小狼毫算法服务（如有需要）
      ↓
解压新版
      ↓
将方案主体覆盖到 Rime 用户目录
      ↓
更新 wanxiang-lts-zh-hans.gram（如有新版）
      ↓
保留个人 *.custom.yaml 和用户数据
      ↓
删除旧 build
      ↓
重新部署
```

!!! warning "不要把用户目录整体删除后重装"
    如果已经使用一段时间，Rime 用户目录里可能包含：

    ```text
    *.custom.yaml
    *.userdb
    installation.yaml
    用户同步数据
    自定义短语
    自定义 Tips
    其他个人文件
    ```

    这些属于个人配置或用户数据。

    更新方案主体时，应先区分“仓库程序文件”和“个人数据”，不要为了更新万象直接清空整个 `%APPDATA%\Rime`。

---

## 12. 推荐首次部署顺序

首次安装可以按以下顺序进行：

```text
安装小狼毫
      ↓
打开默认 %APPDATA%\Rime 用户目录
      ↓
下载万象 Base / Pro
      ↓
下载 wanxiang-lts-zh-hans.gram
      ↓
把万象压缩包内部内容复制到 Rime 用户目录
      ↓
按需决定是否覆盖 default.yaml / weasel.yaml
      ↓
放入 wanxiang-lts-zh-hans.gram
      ↓
删除不再使用的 luna 旧方案文件
      ↓
删除 build
      ↓
重新部署
      ↓
确认万象可以正常输入
      ↓
使用 /zrm、/flypy 等指令设置输入类型
      ↓
再次重新部署
```

---

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>小狼毫负责 Windows 前端与 Rime 部署，万象提供方案、词库、Lua 与语法模型；先保证用户目录结构正确，再进行输入类型和外观上的个性化配置。</em>
</div>
