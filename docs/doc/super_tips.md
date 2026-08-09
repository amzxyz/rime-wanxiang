# 超级 Tips (Super Tips)：输入提示与快捷上屏

> **Super Tips 用于在不新增普通候选的情况下，根据当前输入编码或高亮候选显示一条辅助提示；当提示内容具有可提交部分时，还可以通过指定按键直接上屏。**

万象通过 `super_tips.lua` 将化学式、翻译、符号、表情、单位等辅助信息写入当前输入段的 `segment.prompt`。

因此，它与“把 Emoji、翻译结果继续塞进候选列表”的思路不同：

```text
正常候选
    +
当前输入对应的一条 Tips 提示
```

Tips 本身不会作为普通候选插入候选序列，也不会改变原候选的排序。

---

## 一、显示效果

Super Tips 可以根据当前输入内容显示不同类型的辅助信息。

<div style="display: flex; gap: 20px; justify-content: center; align-items: flex-end; flex-wrap: wrap; margin-top: 2rem; margin-bottom: 2rem;">
    <div style="text-align: center;">
        <img src="https://storage.deepin.org/thread/202509260128462735_tips化学式.jpg" style="height: 100px; width: auto; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); border: 1px solid rgba(0,0,0,0.05);">
        <p style="font-size: 0.85em; color: #666; margin-top: 0.8rem;">化学式提示示例</p>
    </div>
    <div style="text-align: center;">
        <img src="https://storage.deepin.org/thread/202509260128454675_tips符号.jpg" style="height: 100px; width: auto; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); border: 1px solid rgba(0,0,0,0.05);">
        <p style="font-size: 0.85em; color: #666; margin-top: 0.8rem;">符号提示示例</p>
    </div>
    <div style="text-align: center;">
        <img src="https://storage.deepin.org/thread/202509260128457494_tips表情.jpg" style="height: 100px; width: auto; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); border: 1px solid rgba(0,0,0,0.05);">
        <p style="font-size: 0.85em; color: #666; margin-top: 0.8rem;">Emoji 提示示例</p>
    </div>
</div>

---

## 二、Super Tips 实际显示在哪里？

当前 Lua 并不会创建一个新的普通候选，而是把提示写入当前 Segment 的：

```text
segment.prompt
```

最终显示形式由 Rime 前端决定。

Lua 写入的内容形如：

```text
〔提示内容〕
```

可以把整体流程理解为：

```text
当前输入发生变化
      ↓
查询 Tips 数据库
      ↓
找到对应提示
      ↓
写入 segment.prompt
      ↓
由当前 Rime 前端显示
```

!!! note "不同前端的显示位置可能不同"
    Super Tips 负责的是 `segment.prompt` 内容本身。

    鼠须管、小狼毫、Fcitx5、iOS 前端等如何摆放或呈现这段 Prompt，取决于前端自身的候选窗、Preedit 和内嵌编码显示方式。

    因此不应把 Super Tips 固定描述成“所有平台都会显示在某个独立扩展区”。

---

## 三、什么时候会查询 Tips？

Super Tips 依赖方案中的：

```text
super_tips
```

Option。

只有这个开关处于开启状态时，Lua 才会继续查询提示。

当前 Base 方案定义：

```yaml
- name: super_tips
  states: [提示关, 提示开]
```

并绑定：

```yaml
- {when: has_menu, accept: "Control+t", toggle: super_tips}
```

因此在出现候选菜单时，可以通过：

```text
Ctrl + t
```

切换 Tips 的开启与关闭。

!!! info "关闭后不会继续查询和显示 Tips"
    `super_tips` Option 关闭时，当前更新函数会直接返回，不再生成新的 Tips Prompt。

---

## 四、Tips 不只匹配输入编码

当前实现支持两类查询来源：

```text
当前输入编码
当前高亮候选文本
```

这也是 Super Tips 能够同时处理“编码提示”和“候选内容提示”的基础。

### 第一页候选

当前高亮仍位于第一页时，查询顺序是：

```text
1. 当前完整输入编码
2. 当前高亮候选文本
```

也就是说，如果输入编码本身已经有 Tips，会优先使用编码对应的提示。

如果输入编码没有命中，再尝试当前高亮候选文字。

### 后续候选页

当选中位置已经超过第一页范围后，只按照：

```text
当前高亮候选文本
```

查询。

因此移动候选高亮时，Tips 也可以随当前候选变化。

可以简化理解为：

```text
第一页：
输入编码 → 高亮候选

后续页：
高亮候选
```

---

## 五、`tips_key`：提示内容直接上屏

Super Tips 除了显示 Prompt，还可以使用指定按键直接提交提示中的有效内容。

当前方案配置：

```yaml
super_tips:
  tips_key: "comma"
```

也就是：

```text
,
```

对应的 Rime Key 名称：

```text
comma
```

### 什么情况下会拦截这个按键？

必须同时满足：

1. `super_tips` 已开启
2. 配置了 `tips_key`
3. 当前按下的按键与 `tips_key` 完全一致
4. 当前不处于其他万象功能模式
5. 当前确实存在 Tips
6. Tips 中能够提取出冒号后的可提交内容

全部成立后，Lua 才会：

```text
提交 Tips 内容
→ 清空当前输入
→ 吞掉这次按键
```

否则返回：

```text
kNoop
```

让按键继续进入后面的 Rime 处理流程。

---

## 六、为什么逗号既能上屏 Tips，又不影响正常功能？

当前默认：

```yaml
tips_key: "comma"
```

并不是把逗号全局占用。

例如当前存在：

```text
〔化学式：H₂O〕
```

按下 `,` 时，Lua 会从提示中提取：

```text
H₂O
```

并直接提交。

但如果：

* Super Tips 已关闭
* 当前没有匹配 Tips
* 当前 Tips 没有可提交内容
* 当前处于其他功能模式

则 Super Tips 不处理这个逗号，按键继续交给后续 Rime 组件。

因此原有的：

```text
翻页
标点
其他 Key Binder 行为
```

仍有机会继续处理。

!!! tip "按键复用的关键不是固定优先级，而是条件拦截"
    `tips_key` 只有在“当前确实可以提交 Tips”时才被 Super Tips 接受。

    没有 Tips 时，它不会为了等待提示而长期占住这个按键。

---

## 七、什么样的 Tips 才能直接上屏？

当前 Lua 从提示文本中查找：

```text
：
```

或：

```text
:
```

并把**第一个冒号之后的内容**作为提交文本。

例如：

```text
化学式：H₂O
```

按下 `tips_key` 后提交：

```text
H₂O
```

再例如：

```text
翻译：hello
```

提交：

```text
hello
```

如果提示只是：

```text
某段说明文字
```

完全没有中英文冒号，那么它仍然可以作为 Prompt 显示，但按 `tips_key` 时不会直接上屏。

!!! warning "类型前缀与可提交内容由冒号连接"
    推荐将可直接上屏的 Tips 写成：

    ```text
    类型：内容
    ```

    这样同一条数据可以同时用于：

    * 显示类型
    * `disabled_types` 分类过滤
    * 提取冒号后的提交文本

---

## 八、数据文件格式

当前 `super_tips.lua` 读取的数据格式是：

```text
提示内容<Tab>查询键
```

注意顺序：

**左边是显示内容，右边才是查询 key。**

例如自定义一条：

```text
符号：→	jt
```

其中：

```text
value = 符号：→
key   = jt
```

输入：

```text
jt
```

命中后可以显示：

```text
〔符号：→〕
```

再按 `tips_key`，则提交：

```text
→
```

### 只有一个真正的 Tab

当前每一行解析为两个字段：

```text
非 Tab 内容<Tab>非 Tab 内容
```

因此一条普通 Tips 数据不要继续塞入额外的真实 Tab。

推荐格式始终保持：

```text
类型：内容<Tab>查询键
```

---

## 九、同一个 key 建议保持唯一

当前版本的代码注释明确要求：

```text
数据文件应自行保证 key 唯一
```

构建数据库时，一条记录实际按照：

```text
key + value
```

写入 UserDb 风格的 LevelDB。

运行时查询某个 key 时，只读取该前缀下遇到的第一条记录作为当前 Tips。

因此不要依赖：

```text
同一个 key 写很多行
```

实现“多个 Tips 候选”。

Super Tips 的定位就是：

**当前状态只显示一条提示。**

如果一个查询键对应多个可能内容，更适合：

* 在数据生成阶段先决定唯一提示
* 使用普通候选功能
* 使用 Super Replacer 的 `append`
* 使用专门的 Translator

而不是把 Super Tips 当作多候选列表。

---

## 十、`disabled_types` 如何工作？

`disabled_types` 并不是在每次输入时临时隐藏提示。

它是在构建 Tips 数据库时，根据提示文本开头的：

```text
类型：
```

或：

```text
类型:
```

决定是否将该条数据写入数据库。

例如：

```text
化学式：H₂O
```

会识别类型：

```text
化学式
```

如果配置：

```yaml
super_tips:
  disabled_types:
    - "化学式"
```

那么这类记录在数据库重建时会被直接忽略。

当前方案中常见类型包括：

```text
偏旁
符号
化学式
时间
组字
翻译
表情
货币
车牌
单位
```

!!! info "disabled_types 不是写死的枚举"
    Lua 并没有把上述类型硬编码成固定列表。

    它只是提取提示文本第一个冒号前的类型名称。

    因此如果自定义数据使用：

    ```text
    编程：lambda
    ```

    那么同样可以配置：

    ```yaml
    disabled_types:
      - "编程"
    ```

    禁用这一自定义类别。

---

## 十一、数据文件与 `files`

Super Tips 支持：

```yaml
super_tips/files
```

列表配置。

当前 Base 方案显式配置：

```yaml
super_tips:
  files:
    - lua/data/tips_show.txt
```

因此当前实际加载的是这个列表中明确写出的文件。

### Lua 自身的回退文件

如果方案中**完全没有有效的 `super_tips/files`**，Lua 才会回退到：

```text
lua/data/tips_show.txt
lua/data/tips_user.txt
```

两个默认文件。

这意味着：

!!! warning "显式配置 files 后，不会自动再追加 tips_user.txt"
    当前方案已经显式配置：

    ```yaml
    files:
      - lua/data/tips_show.txt
    ```

    因此 Lua 不会再自动帮你补上：

    ```text
    lua/data/tips_user.txt
    ```

    如果希望加载自己的 Tips 文件，需要显式加入列表。

### 通过 Custom 追加文件

例如：

```yaml
patch:
  "super_tips/files/+":
    - lua/data/my_tips.txt
```

这样可以在保留现有：

```text
lua/data/tips_show.txt
```

的基础上继续加载自己的数据文件。

---

## 十二、配置参数

当前用户真正需要关注的参数主要有四个：

| 参数 | 类型 | 作用 | 当前 Base 方案 |
| --- | --- | --- | --- |
| `db_name` | `string` | Tips LevelDB 名称 | `lua/tips` |
| `tips_key` | `string` | 有有效 Tips 时用于直接上屏的按键 | `comma` |
| `files` | `list` | 数据文件列表 | `[lua/data/tips_show.txt]` |
| `disabled_types` | `list` | 构建数据库时排除指定类型 | 以方案实际配置为准 |

### `db_name` 的两个“默认”不要混淆

当前方案文件明确写了：

```yaml
db_name: "lua/tips"
```

所以正常使用万象 Base 时，实际数据库名称是：

```text
lua/tips
```

但 `super_tips.lua` 自己的代码级回退值是：

```text
tips
```

也就是说，只有方案完全没有提供 `super_tips/db_name` 时，Lua 才会使用：

```text
tips
```

文档中应区分：

```text
当前方案配置值 ≠ Lua 内建回退值
```

---

## 十三、完整 Patch 示例

```yaml
patch:
  # Tips 数据库
  "super_tips/db_name": "lua/tips"

  # 提示直接上屏按键
  "super_tips/tips_key": "comma"

  # 禁用不需要的提示类型
  "super_tips/disabled_types":
    - "化学式"
    - "车牌"
    - "货币"

  # 在现有数据文件基础上追加自己的 Tips
  "super_tips/files/+":
    - lua/data/my_tips.txt
```

如果希望把 Tips 上屏键改成句号：

```yaml
patch:
  "super_tips/tips_key": "period"
```

或者改成分号：

```yaml
patch:
  "super_tips/tips_key": "semicolon"
```

!!! warning "修改 tips_key 时要检查现有按键职责"
    `tips_key` 使用的是 Rime 的按键名称。

    改成 `period`、`semicolon`、`space` 等按键前，应先确认当前方案里该键是否承担：

    * 翻页
    * 次选
    * 标点
    * 其他 Processor / Key Binder 功能

    Super Tips 虽然只在“存在有效 Tips”时拦截，但命中时仍会优先执行 Tips 上屏。

---

## 十四、如何设置默认开启？

当前 Base 的 `switches` 顺序中，`super_tips` 位于第 11 项。

因为列表索引从 `0` 开始，所以当前版本对应：

```yaml
patch:
  "switches/@10/reset": 1
```

表示初始化时默认进入：

```text
提示开
```

不过不建议把这个索引当成长期固定接口。

!!! warning "switches 索引会随方案结构变化"
    `@10` 只代表**当前版本 `switches` 列表的第 11 项**。

    如果未来上游新增、删除或调整 Switch 顺序，`@10` 可能不再对应 `super_tips`。

    因此跨版本维护 Custom 时，应重新检查当前 `switches` 列表后再确认索引。

日常临时切换则直接使用：

```text
Ctrl + t
```

更方便。

---

## 十五、数据库什么时候会重建？

当前 Super Tips 不会每次启动都重新逐行导入 TXT。

初始化时会检查：

```text
数据库格式版本
disabled_types 配置指纹
数据文件特征
```

如果这些信息与数据库中记录的一致，就直接以只读方式复用现有 LevelDB。

只有以下情况发生变化时，才会重新构建：

* Tips 数据库不存在
* 数据格式版本变化
* `disabled_types` 变化
* `files` 对应的数据内容变化

可以简化为：

```text
配置和数据没变
→ 直接打开现有 DB

配置或数据变化
→ 清空并重新构建 DB
→ 再以只读方式运行
```

### 数据量应该怎样理解？

Super Tips 仍然适合保存：

```text
短提示
唯一映射
查询型辅助信息
```

但原因不应描述成“运行时每次都扫描整个大文件”。

当前正常输入阶段是：

```text
LevelDB 按 key 查询
```

较大的 TXT 数据主要会增加：

* 首次构建时间
* 数据变更后的重建时间
* 数据库占用
* 无必要提示数据的维护成本

因此仍建议控制数据质量和用途，但不需要把 Super Tips 限制成只能容纳极少量记录。

---

## 十六、多方案共享同名 Tips 数据库

当前 Lua 使用：

```text
db_name
```

维护模块内的数据库状态。

如果多个组件实例使用相同：

```yaml
db_name: "lua/tips"
```

会复用同一个已打开的数据库实例，并通过引用计数管理生命周期。

最后一个使用者退出时才关闭数据库。

这一机制主要用于减少同名 Tips 数据库被多个方案重复打开。

对于普通用户来说，不需要额外配置；保持相关方案使用同一个 `db_name` 即可。

---

## 十七、Codex 符号与 Emoji Tips

当前 `tips_show.txt` 已加入 Super Symbols / Codex 相关的中文提示数据。

例如可以出现类似：

```text
符号：⇒
表情：🍎
```

并配合中文说明帮助识别对应内容。

当前这批数据记录为：

```text
1090 条符号 Tips
341 条 Emoji Tips
合计 1431 条
```

这些数字属于当前数据快照，后续更新 Codex 或重新生成 Tips 数据后可能变化。

Super Symbols 与 Super Tips 的职责不同：

```text
Super Symbols
→ /sym、/emoji 按 Typst/Codex 名称主动检索字符

Super Tips
→ 在普通输入过程中根据编码或候选被动显示辅助提示
```

两者可以共存。

---

## 十八、移动端与前端兼容性

Super Tips 的核心输出位置是：

```text
segment.prompt
```

因此不同 Rime 前端的显示效果可能存在差异。

如果遇到：

* Prompt 不显示
* Prompt 位置与桌面端不同
* 内嵌编码模式下布局拥挤
* 某些 App 中候选窗展示方式不同

应优先检查当前前端对：

```text
Segment Prompt
Preedit
候选窗口
内嵌编码
```

的呈现方式。

这类问题不一定意味着 Tips 数据库或 Lua 查询失败。

### 临时排查

可以先按：

```text
Ctrl + t
```

切换 Super Tips。

如果关闭后输入恢复正常，再继续检查：

1. 当前前端的 Prompt 展示方式
2. `tips_key` 是否和其他按键行为冲突
3. 自定义数据格式是否正确
4. `disabled_types` 是否误过滤了需要的数据
5. Custom 修改后是否已经重新部署

---

## 十九、常见排错

### 1. 有输入，但完全没有 Tips

检查：

```text
super_tips Option 是否开启
```

可以按：

```text
Ctrl + t
```

切换一次。

### 2. 自定义 TXT 没生效

检查是否已经加入：

```yaml
super_tips/files
```

当前方案显式指定了 `tips_show.txt`，因此仅仅创建：

```text
lua/data/tips_user.txt
```

并不代表它一定会自动加载。

### 3. Tips 能看到，但按逗号不上屏

检查数据是否包含：

```text
类型：内容
```

当前直接上屏逻辑需要从 `:` 或 `：` 后提取提交文本。

如果没有冒号，只显示 Prompt，不直接提交。

### 4. 某类 Tips 消失

检查：

```yaml
super_tips/disabled_types
```

类型匹配取自提示文本冒号前的内容。

### 5. 修改数据后仍像旧内容

保存数据并重新部署。

数据库会根据文件特征判断是否需要重新构建。

---

## 二十、适合与不适合放进 Tips 的内容

### 适合

* 化学式
* 单位换算提示
* 车牌简称
* 简短翻译
* 符号
* Emoji
* 部件 / 偏旁说明
* 短文本映射
* Codex 中文提示

共同特点是：

```text
一个查询键
→ 一条明确提示
```

### 不适合

* 一个 key 对应大量候选
* 需要候选分页的数据
* 长篇文本
* 需要复杂排序的数据
* 需要上下文连续生成的内容

这些场景更适合使用 Translator、Super Replacer 或其他专用模块。

---

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>Super Tips 的定位是一条随输入变化的辅助提示：不改变原候选顺序，需要时再通过指定按键直接提交其中的有效内容。</em>
</div>
