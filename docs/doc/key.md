# 🧭 Rime 按键映射速查表 (Key Binding Reference)

本文档整理了 Rime (中州韵输入法引擎) 的 `key_binder` 模块中支持的所有标准按键名称。在编写 `custom.yaml` 或 `schema.yaml` 时，`accept` 和 `send` 字段必须严格遵守以下大小写。

> **⚠️ 注意事项**
> 1. Rime 暂不支持 macOS 特有的 `Command` 键映射。
> 2. 映射组合键时，请使用 `+` 号连接（如 `Control+Shift+Delete`）。

---

## 1. 修饰键 (Modifiers)
用于与其他按键组合，Rime 支持区分键盘左右两侧的修饰键。

| 类别 | 按键名称 | 中文说明 |
| :--- | :--- | :--- |
| **Shift** | `Shift_L`, `Shift_R` | 左 / 右 Shift 键 |
| **Control** | `Control_L`, `Control_R` | 左 / 右 Ctrl 键 |
| **Alt / Opt** | `Alt_L`, `Alt_R` | 左 / 右 Alt 键 (macOS 为 Option) |
| **系统键** | `Super_L`, `Super_R` | 左 / 右 Win 键 |
| **锁定键** | `Caps_Lock`, `Num_Lock` | 大写锁定 / 小键盘锁定 |
| **其他** | `Shift_Lock`, `Scroll_Lock` | 上档锁定 / 滚动锁定 |
| **Meta/Hyper** | `Meta_L/R`, `Hyper_L/R` | 左/右 Meta 键, 左/右 Hyper 键 |

---

## 2. 功能与编辑键 (Function & Editing)
用于控制输入过程、翻页、光标移动及文本编辑。

| 分类 | 按键名称 | 中文说明 |
| :--- | :--- | :--- |
| **确认/取消** | `Return` <br> `space` <br> `Escape` | **回车键** (确认输入)<br> **空格键** (首选上屏)<br> **退出键** (Esc，取消输入) |
| **删除/插入** | `BackSpace` <br> `Delete` <br> `Insert` | **退格键** (向左删除)<br> **删除键** (向右删除)<br> **插入键** |
| **导航/翻页** | `Page_Up` 或 `Prior` <br> `Page_Down` 或 `Next` | **向上翻页** <br> **向下翻页** |
| **光标移动** | `Up`, `Down`, `Left`, `Right` | **上、下、左、右** 方向键 |
| **行首/行尾** | `Home` <br> `End` <br> `Begin` | **原位** (行首) <br> **末位** (行尾) <br> **始位** |
| **制表/换行** | `Tab` <br> `Linefeed` | **水平定位符** (Tab 键)<br> **换行** |
| **系统操作** | `Pause` <br> `Sys_Req` <br> `Print` <br> `Break` | 暂停 <br> 印屏 <br> 打印 <br> 中断 |
| **扩展编辑** | `Clear`, `Select`, `Execute`<br>`Undo`, `Redo`, `Menu`<br>`Find`, `Cancel`, `Help`| 清除, 选定, 运行 <br> 还原, 重做, 菜单 <br> 搜寻, 取消, 帮助 |

---

## 3. 标点符号键 (Symbols)
当需要将标点符号作为快捷键（如用分号翻页）时，必须使用以下对应的英文名称。

| 符号 | Rime 名称 | 中文说明 | 符号 | Rime 名称 | 中文说明 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| `!` | `exclam` | 叹号 | `[` | `bracketleft` | 左方括号 |
| `"` | `quotedbl` | 双引号 | `]` | `bracketright` | 右方括号 |
| `#` | `numbersign` | 井号 | `\` | `backslash` | 反斜杠 |
| `$` | `dollar` | 美元符 | `^` | `asciicircum` | 脱字符 |
| `%` | `percent` | 百分号 | `_` | `underscore` | 下划线 |
| `&` | `ampersand` | 和号 | `` ` `` | `grave` | 抑音符 |
| `'` | `apostrophe` | 单引号 | `{` | `braceleft` | 左大括号 |
| `(` | `parenleft` | 左圆括号 | `}` | `braceright` | 右大括号 |
| `)` | `parenright` | 右圆括号 | `\|` | `bar` | 竖线 |
| `*` | `asterisk` | 星号 | `~` | `asciitilde` | 波浪号 |
| `+` | `plus` | 加号 | `,` | `comma` | 逗号 |
| `-` | `minus` | 减号 | `.` | `period` | 句号 (点) |
| `/` | `slash` | 斜杠 | `:` | `colon` | 冒号 |
| `;` | `semicolon` | 分号 | `=` | `equal` | 等号 |
| `<` | `less` | 小于号 | `>` | `greater` | 大于号 |
| `?` | `question` | 问号 | `@` | `at` | At 符号 |

---

## 4. 数字小键盘 (Keypad)
如果你的键盘带有独立的数字小键盘，映射这些按键时必须加上 `KP_` 前缀。

| 分类 | 按键名称 | 中文说明 |
| :--- | :--- | :--- |
| **数字键** | `KP_0` 至 `KP_9` | 小键盘 0-9 |
| **运算符** | `KP_Add`<br>`KP_Subtract`<br>`KP_Multiply`<br>`KP_Divide`<br>`KP_Decimal` | 小键盘 **加号** (+)<br>小键盘 **减号** (-)<br>小键盘 **乘号** (*)<br>小键盘 **除号** (/)<br>小键盘 **小数点** (.) |
| **翻页键** | `KP_Page_Up` 或 `KP_Prior`<br>`KP_Page_Down` 或 `KP_Next` | 小键盘 **上翻页**<br>小键盘 **下翻页** |
| **导航键** | `KP_Up`, `KP_Down`<br>`KP_Left`, `KP_Right`<br>`KP_Home`, `KP_End`, `KP_Begin` | 小键盘 上、下<br>小键盘 左、右<br>小键盘 原位、末位、始位 |
| **功能键** | `KP_Enter`<br>`KP_Space`<br>`KP_Tab`<br>`KP_Delete`, `KP_Insert`<br>`KP_Equal` | 小键盘 **回车**<br>小键盘 **空格**<br>小键盘 **水平定位符**<br>小键盘 删除、插入<br>小键盘 等号 |

---

## 5. 配置示例

在 Rime 方案的 YAML 文件中，配置快捷键的典型用法如下：

```yaml
key_binder:
  bindings:
    # 示例 1: 组合键 - 使用 Ctrl + . 切换中英文标点
    - { accept: "Control+period", toggle: ascii_punct, when: always }
    
    # 示例 2: 符号映射 - 使用分号 (;) 进行向下翻页
    - { accept: semicolon, send: Page_Down, when: has_menu }
    
    # 示例 3: 小键盘映射 - 拦截小键盘回车，使其具有普通回车的功能
    - { accept: KP_Enter, send: Return, when: composing }