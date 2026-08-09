# Rime Patch 方法论：配置修改指南

直接修改 Rime 的原始方案文件（如 `*.schema.yaml`、`default.yaml`）虽然可以立即改变配置，但这些文件可能在后续更新时被替换。对于需要长期保留的个人设置，更推荐使用对应的 `.custom.yaml` 文件，通过 Patch 对原配置进行修改。

理解 Patch，重点需要掌握两件事：

1. **找到真正需要修改的配置节点。**
2. **明确当前操作是修改单个值、替换整个节点，还是处理列表。**

只要把这两点区分清楚，大多数 Rime 配置都可以用相对稳定的方式完成。

---

## 一、先理解 Custom 与原配置的关系

### 1. Custom 不是一条简单的“全局优先级链”

不建议把 Rime 简化理解为：

`custom.yaml > schema.yaml > default.yaml`

更准确的理解是：**不同 `.custom.yaml` 分别对与自己对应的配置文件进行补丁修改。**

例如：

* `default.custom.yaml` → 修改 `default.yaml`
* `wanxiang.custom.yaml` → 修改 `wanxiang.schema.yaml`
* `weasel.custom.yaml` → 修改小狼毫相关配置
* `squirrel.custom.yaml` → 修改鼠须管相关配置

以万象主方案为例，如果要修改：

`wanxiang.schema.yaml`

就应在同一用户目录中创建或编辑：

`wanxiang.custom.yaml`

Rime 在重新部署时，会读取原始配置，并将对应 Custom 中 `patch:` 定义的修改合并进去。

> **注意**：词典文件（例如 `*.dict.yaml`）和普通 TXT 词库属于数据文件，不能简单通过创建同名 `.custom.yaml` 的方式修改其中的词条内容。

---

## 二、理解编译后的“最终配置”

阅读复杂的 Rime 方案时，经常会看到：

`__include`

`__patch`

`__append`

这些属于配置编译阶段使用的合并指令。方案源码中的结构不一定等同于 Rime 部署后得到的最终配置结构。

### 三个常用合并指令

* **`__include`**：引用其他配置文件或节点中的内容，将其引入当前位置。

* **`__patch`**：在当前内容基础上继续应用一组补丁。

* **`__append`**：用于列表型配置的追加合并，表示将指定内容追加到已有列表，而不是直接用新列表替换原列表。

下面用一个简化示例说明它们之间的关系。

---

#### 第一步：定义可复用的规则

假设 `wanxiang_algebra.yaml` 中定义了两组拼写规则：

```yaml
# 文件：wanxiang_algebra.yaml
mixed:
  通用规则:
    - erase/^xx$/             # 规则 A：删除 xx

  全拼附加规则:
    __append:
      - derive/^z/zh/         # 规则 B：z 派生 zh
```

---

#### 第二步：在方案中组合这些规则

在 `wanxiang.custom.yaml` 或其他配置节点中引用：

```yaml
# 文件：wanxiang.custom.yaml
patch:
  speller/algebra:
    __include: wanxiang_algebra:/mixed/通用规则
    __patch: wanxiang_algebra:/mixed/全拼附加规则
```

这里的处理思路是：

1. 先通过 `__include` 引入“通用规则”。
2. 再通过 `__patch` 应用“全拼附加规则”。
3. 被引用段落中的 `__append` 表示把规则继续追加到当前列表。

---

#### 第三步：查看部署后的最终结构

重新部署后，可以查看 `build/` 目录中生成的方案配置，例如：

```yaml
# 文件：build/wanxiang.schema.yaml
speller:
  algebra:
    - erase/^xx$/
    - derive/^z/zh/
```

此时更容易看出，最终需要操作的业务节点实际上是：

`speller/algebra`

而不是源码中用于组织配置的某个中间 `__include` 或 `__patch` 指令。

!!! tip "写 Patch 时优先关注最终业务节点"
    阅读复杂方案源码时，可以先查看部署后的 `build/*.schema.yaml`，确认最终节点和列表结构。

    对普通个性化修改而言，优先针对最终业务节点写 Patch，通常比依赖中间的 `__include`、`__patch` 组织结构更直观，也更容易排查问题。

---

## 三、Custom 文件中的 `patch:` 怎么写？

一个 `.custom.yaml` 文件中，通常只保留一个顶层 `patch:` 键，将需要修改的内容统一写在其中。

例如：

```yaml
patch:
  menu/page_size: 5
  translator/enable_user_dict: false
  key_binder/bindings/+:
    - { when: composing, accept: Tab, send: Page_Down }
```

!!! warning "不要重复声明同名的 patch 键"
    YAML 映射中不应重复书写多个同名的顶层 `patch:`。重复键可能导致前面的内容被后面的内容覆盖，或者产生与预期不同的解析结果。

    但这并不意味着 `.custom.yaml` 顶层只能存在 `patch:` 一个节点。

    如果方案需要定义可复用的自定义节点，例如：

    `my_fuzzy:`

    也可以将它与 `patch:` 保持同级，并放在文件其他位置。关键是不要重复定义同名的 `patch:`。

---

## 四、Patch 路径语法速查

可以把 YAML 中的层级看作路径。Patch 通过 `/` 直接定位需要修改的节点，也可以使用 `@` 和 `+` 对列表进行操作。

| 操作类型 | 语法示例 | 作用 |
| :--- | :--- | :--- |
| **修改指定节点** | `key/subkey: value` | 修改指定路径的值，不需要重写整个父节点 |
| **替换整个节点** | `key: new_value` | 直接用新的值替换该节点原有内容 |
| **列表 / 字典合并** | `key/+:` | 将新的列表或字典内容合并到原节点 |
| **替换指定列表项** | `key/@5: value` | 替换索引 `5` 的元素，即列表中的第 6 项 |
| **替换最后一项** | `key/@last: value` | 替换列表最后一个元素 |
| **指定位置前插入** | `key/@before 5: value` | 在索引 `5` 对应元素之前插入 |
| **指定位置后插入** | `key/@after 5: value` | 在索引 `5` 对应元素之后插入 |
| **追加到列表末尾** | `key/@next: value` | 在列表末尾加入一个元素 |

!!! info "关于列表索引"
    `@0` 表示第 1 项，`@1` 表示第 2 项，以此类推。

    `@before`、`@after` 等写法虽然可以精确控制位置，但它们依赖原列表的顺序。如果上游方案更新后新增、删除或调整了列表元素，原来的索引可能不再对应同一个组件。

    因此，对长期维护的 Custom 来说，不建议无必要地大量依赖固定数字索引。

---

## 五、局部修改与整个节点替换

这是写 Patch 时最容易混淆的地方之一。

假设原方案中存在：

```yaml
menu:
  page_size: 10
  settings:
    font_size: 14
    color: blue
```

### 只修改一个子节点

如果只想把候选数量从 `10` 改为 `5`，直接定位目标路径：

```yaml
patch:
  menu/page_size: 5
```

最终仍然会保留：

```yaml
menu:
  page_size: 5
  settings:
    font_size: 14
    color: blue
```

### 替换整个节点

如果直接给 `menu` 提供一份新的值：

```yaml
patch:
  menu:
    page_size: 5
```

这里操作的目标已经变成整个 `menu` 节点，而不再只是 `menu/page_size`。

因此，在不确定是否需要整体替换时，**优先使用完整路径修改具体子节点**，通常更安全，也更容易适配后续方案更新。

---

## 六、如何清空或移除配置？

Patch 对普通节点和列表的处理方式并不完全相同。

### 1. 将某个节点置空

某些配置可以通过空值达到关闭或清空效果，例如 Rime 官方定制示例中会使用空值关闭特定的识别规则：

```yaml
patch:
  recognizer/patterns/reverse_lookup:
```

类似地，如果某个组件允许对应配置为空，也可以写成：

```yaml
patch:
  custom_phrase/user_dict:
  custom_phrase/initial_quality:
```

!!! warning "空值不等于通用的删除指令"
    上面的写法本质上是将节点设置为空值，并不是从 YAML 结构中执行一次通用的“删除节点”操作。

    某个组件是否会把空值理解为“关闭”“未配置”或其他状态，取决于该配置项本身的处理逻辑。

    因此，不要把“留空”理解成适用于所有配置项的统一删除方法。

### 2. 从列表中移除某一项

Rime Patch 没有通用的 `/-:` 列表删除语法。

例如下面这种写法不要使用：

```yaml
patch:
  engine/filters/-:
    - simplifier@emoji
```

如果需要稳定地删除列表中的某个组件，比较直观的方式是**重新定义整个列表，只保留需要的项目**：

```yaml
patch:
  engine/filters:
    - lua_filter@*chars_filter
    - simplifier@emoji
    - uniquifier
```

如果目标是删除 `simplifier@emoji`，则重新列出其余项目：

```yaml
patch:
  engine/filters:
    - lua_filter@*chars_filter
    - uniquifier
```

这种方法虽然需要复制整个列表，但结果最容易确认。

---

## 七、列表顺序为什么重要？

`engine/processors`、`engine/segmentors`、`engine/translators`、`engine/filters` 等节点本质上都是按顺序执行的组件列表。

因此，修改 Engine 时不仅需要确认“有没有这个组件”，还要确认“它位于什么位置”。

### 直接追加

如果组件本身对位置不敏感，可以使用 `/+`：

```yaml
patch:
  engine/translators/+:
    - table_translator@custom_phrase
```

这会把新的翻译器合并到现有列表末尾。

但如果该组件依赖前后处理关系，仅仅追加到末尾就未必是合适的位置。

### 指定位置插入

如果已经确认目标列表结构稳定，并且必须插入到某个组件之前，可以使用 `@before`：

```yaml
patch:
  # 在索引 5 对应元素之前插入
  engine/translators/@before 5: table_translator@custom_phrase
```

使用 `@` 定位单个列表元素时，路径本身已经表示插入位置，因此后面的值直接写组件名称，不需要再加列表短横线 `-`。

!!! warning "固定索引需要留意版本变化"
    `@before 5` 的含义取决于当前 `engine/translators` 的具体排列。

    如果方案升级后调整了 Translator 顺序，第 6 个位置可能已经变成其他组件。因此，使用数字索引的 Custom 在跨版本更新后应重新检查。

    如果顺序并不重要，优先考虑 `/+`；如果顺序非常重要，则建议结合新版 `build/*.schema.yaml` 确认最终列表后再调整。

---

## 八、排查 Patch 不生效的方法

遇到 Custom 修改没有生效时，可以按照下面的顺序检查：

1. **确认文件名是否对应正确**  
   修改 `wanxiang.schema.yaml` 应使用 `wanxiang.custom.yaml`，不要写错目标方案。

2. **确认文件位于 Rime 用户目录**  
   示例模板放在其他子目录中不会自动成为当前方案的 Custom。

3. **确认 YAML 缩进和层级**  
   特别注意 `patch:` 下方的缩进，以及列表中的 `-`。

4. **确认没有重复的 `patch:` 键**  
   多段配置应合并到同一个 `patch:` 下。

5. **确认 Patch 路径指向最终存在的节点**  
   对包含大量 `__include`、`__patch` 的方案，可以查看 `build/*.schema.yaml` 辅助定位。

6. **确认列表索引没有发生变化**  
   使用 `@5`、`@before 5` 等写法时，方案升级可能改变原列表顺序。

7. **重新部署并查看日志**  
   YAML 解析错误、引用路径不存在等问题通常可以通过部署日志进一步定位。

---

## 九、几个实用原则

* **能改子节点，就不要无必要地重写整个父节点。**
* **能使用稳定路径，就尽量减少对固定列表索引的依赖。**
* **修改 Engine 列表时，同时关注组件顺序。**
* **不要把空值当成适用于所有节点的删除操作。**
* **复杂方案优先查看 `build/*.schema.yaml`，确认最终结构再写 Patch。**
* **Custom 可以长期保存，但方案发生结构性更新后仍需要检查兼容性。**

<div align="center" style="opacity: 0.5; font-size: 0.85em; margin-top: 2rem; font-style: italic;">
    <em>Patch 的关键不是记住更多语法，而是先看清最终配置结构，再用尽可能小的修改准确落到目标节点。</em>
</div>
