# AGENTS.md

# Rime 万象拼音 — Agent Guide

本文件用于指导 AI 编程代理在 `rime-wanxiang` 仓库中进行修改。

万象是基于 Rime 的中文输入方案，仓库同时包含 Rime schema、词库、Lua 扩展、辅助码数据、文档和发布构建脚本。修改时应优先保持现有输入行为、数据格式和跨平台兼容性，避免为了代码形式上的“优化”改变实际输入体验。

## Project Structure

主要目录和文件：

* `wanxiang.schema.yaml`：万象标准版主方案。
* `wanxiang.dict.yaml`：标准版词库入口。
* `wanxiang_algebra.yaml`：拼音、双拼、模糊音及相关转写规则。
* `wanxiang_english.*`：英文方案。
* `wanxiang_mixedcode.*`：中英混合编码方案。
* `wanxiang_reverse.*`：反查相关方案。
* `wanxiang_symbols.yaml`：符号配置。
* `default.yaml`：Rime 默认配置及方案列表。
* `custom/`：项目维护的自定义方案和相关配置。
* `dicts/`：词库及相关数据。
* `lua/`：librime-lua 扩展。
* `lua/wanxiang/`：万象主要 Lua 模块。
* `lua/data/`：Lua 使用的数据文件。
* `docs/`：项目文档。
* `.github/workflows/`：CI、构建和发布流程。
* `.github/workflows/scripts/`：构建辅助脚本。
* `release-please-config.json`、`.release-please-manifest.json`：版本发布自动化配置。

修改前先确认文件属于源码、配置、生成物还是发布产物。

如果某个文件由脚本生成，应优先修改生成源或生成脚本，而不是只修改最终生成文件。

## General Rules

保持修改范围最小。

不要因为“顺手优化”而重写无关代码。

不要在没有明确需求的情况下：

* 大规模格式化 YAML、Lua 或词库；
* 重排整个词库；
* 改变候选顺序；
* 改变词频；
* 改变拼音编码；
* 改变辅助码；
* 修改 schema ID；
* 修改版本号；
* 修改 CHANGELOG；
* 修改 Release 配置；
* 修改发布附件命名规则。

如果用户要求修复一个明确问题，应首先寻找最小修复方案。

修改已有逻辑时，默认要求行为兼容。

## Rime YAML Rules

所有 Rime YAML 文件保持 UTF-8。

保持现有缩进和结构，不进行无关格式化。

必须特别注意 Rime 使用的特殊配置结构，例如：

```yaml
__include:
__patch:
__append:
```

不要把这些结构当成普通 YAML 数据随意展开、合并或重新排序。

修改：

```yaml
processors:
segmentors:
translators:
filters:
recognizer:
speller:
algebra:
key_binder:
punctuator:
```

等关键流水线时，要考虑组件顺序。

Rime 的组件顺序通常具有行为意义，不得仅为了“整洁”重新排序。

修改 `recognizer/patterns` 时，要考虑输入过程中的中间状态，而不仅仅考虑最终字符串是否匹配。

修改正则表达式时，应检查：

* 单字符中间状态；
* 连续输入；
* 回退删除；
* 前缀冲突；
* 与 `punctuator`、`key_binder`、Lua processor 的交互。

## Pinyin and Algebra Rules

万象包含带声调拼音以及构建时生成的无声调版本。

不要未经明确要求：

* 全局删除声调；
* 全局把 `ü` 改成 `v`；
* 全局把 `u` 改成 `v`；
* 修改 `ju / qu / xu` 等拼音拼写；
* 修改词库第二列编码。

涉及带调和无调转换时，应确认修改属于：

1. 原始词库；
2. `algebra` 转写；
3. Lite 构建转换；
4. 辅助码生成；

中的哪一层。

不要在多个层级重复完成同一个转换。

例如，如果 Lite 构建的 `tone_map` 已经执行：

```python
"ǖ": "v",
"ǘ": "v",
"ǚ": "v",
"ǜ": "v",
"ü": "v",
```

则不要再追加无效的：

```python
.replace("üe", "ve")
```

模糊音规则需要同时考虑带声调和无声调输入。

例如：

```yaml
- derive/([ēéěèe])ng(.*)$/$1n$2
```

其中普通 `e` 用于兼容无声调编码。

## Dictionary Rules

词库属于项目核心数据，不应当作普通文本文件随意批量处理。

修改词库时：

* 保持原有字段结构；
* 保持 Tab 分隔；
* 不将 Tab 自动替换为空格；
* 不删除未知字段；
* 不自动排序整个文件；
* 不重新计算词频，除非任务明确要求；
* 不批量规范拼音，除非任务明确要求；
* 不改变文件换行风格，除非必要。

如果只修改少量词条，只修改目标词条。

涉及数万或数十万词条的批处理时，应先确认转换规则，并使用脚本完成，避免人工正则替换造成不可逆的数据污染。

## Lua Rules

万象 Lua 运行于 librime-lua 环境。

优先保持现有 librime / librime-lua 兼容性，不要为了使用新 Lua 语法而无必要提高运行环境要求。

### Lifecycle

需要创建原生资源的组件，应遵循：

rime Lua 相关API接口文档位于lua/wanxiang/librime.lua文档中，应实现阅读并理解。
在编写Lua中应当考虑Lua5.1-5.6的语法兼容性，以及LuaJIT的相关兼容性

```text
init() -> create/connect/open
fini() -> disconnect/release/clear
```

例如：

* `Memory`
* `ReverseDb`
* translator
* notifier connection
* database
* 其他 userdata

应在 `fini()` 中正确释放。

不要在普通热路径中执行完整 GC：

```lua
collectgarbage("collect")
```

仅在初始化、重建、销毁等低频路径确有必要时使用。

### env and Module State

schema 或组件实例相关状态优先放在：

```lua
env.xxx
```

避免把实例配置放在：

```lua
M.xxx
```

或其他模块级可变全局中，以免不同 schema 或组件实例互相污染。

真正需要跨组件通信的全局状态应：

* 明确用途；
* 有边界；
* 有生命周期；
* 在组件销毁时清理其内容。

不要随意引入新的 `_G` 状态。

### Candidate Handling

Candidate 可以放在单次 `func()` 调用中的局部 table 中。

不要为了规避历史版本 librime-lua 的 Candidate table 问题而把正常代码改成：

* 递归 yield；
* 大量 varargs；
* flat scalar table；
* 难以维护的手工索引结构。

局部 Candidate table 是允许的。

真正需要避免的是：

> Candidate 或其他 native userdata 被无必要地跨调用、长期、无限制持有。

如果 Candidate table 只用于一次排序、分页或当前翻译过程，可以正常使用。

如果 Candidate 被保存在 `env`、模块全局或 `_G` 中，则必须确认：

* 是否确实需要跨调用；
* 是否严格有界；
* 是否会在输入变化时清理；
* 是否会在 `fini()` 中清理。

能够长期保存纯 Lua snapshot 时，优先保存：

```lua
{
    text = ...,
    comment = ...,
    type = ...,
}
```

而不是长期保存 Candidate userdata。

### Cache Rules

不要因为“减少查询”就无条件增加永久缓存。

先区分：

```text
同一次 func 内重复查询
短时间输入递增造成的重复查询
真正不同的查询
```

同一轮重复查询应优先消除。

跨调用缓存应满足：

* 只缓存确有重复价值的数据；
* 优先缓存纯 Lua 数据；
* 有明确上限；
* 有明确失效条件；
* 不持有无必要的 Candidate、iterator 或其他 native userdata。

不要创建无限增长的缓存。

不要为了降低 Lua table 数量而牺牲可读性。

### Performance

输入法 Lua 属于高频调用路径。

特别关注：

* 每个按键执行次数；
* DB 查询次数；
* translator 查询次数；
* Candidate 构造次数；
* 字符串重复拼接；
* table 重复分配；
* notifier 是否重复连接；
* 跨调用缓存是否持续增长。

优化前优先找真正热点。

不要凭猜测加入任意 Candidate 上限、扫描上限或缓存上限。

如果现有上限是功能设计的一部分，修改前先确认其语义。

## Lua Validation

修改 Lua 后至少执行语法检查。

优先使用：

```bash
luac -p path/to/file.lua
```

如果环境没有 `luac`，但存在 `texlua`，可以使用：

```bash
texlua -e 'assert(loadfile("path/to/file.lua"))'
```

或者等价的 `loadfile()` 检查。

语法通过不代表 Rime 行为正确。

涉及 Candidate、Memory、DB、translator、notifier 或 context 的修改，需要结合实际 Rime 环境验证。

## Python and Shell Rules

修改 Python：

```bash
python3 -m py_compile path/to/file.py
```

修改 Shell：

```bash
bash -n path/to/file.sh
```

修改发布或打包脚本时，应检查：

* 相对路径；
* GitHub Actions 工作目录；
* 文件不存在时的处理；
* `set -e` 行为；
* `rsync` include/exclude 顺序；
* 临时文件覆盖；
* Release asset 命名；
* 是否会误删源文件。

涉及下载时，HTTP 请求应正确处理 4xx / 5xx。

例如使用 curl 下载重要构建资源时，通常应使用类似：

```bash
curl -fL --retry 5 --retry-all-errors ...
```

避免把 GitHub 错误 HTML 当成正常文件继续处理。

## Build and Generated Files

构建脚本可能生成：

* Lite 词库；
* Pro 辅助码词库；
* 打包目录；
* Release zip；
* 临时转换文件。

不要把临时生成结果误认为源码。

如果任务修改生成逻辑，应验证：

```text
source
   ↓
generator
   ↓
generated data
   ↓
package
```

整个链条，而不是只检查最终文件。

不要提交明显的临时构建目录、缓存或测试产物，除非仓库本身要求追踪这些文件。

## Documentation

文档主要位于 `docs/`，MkDocs 导航由 `mkdocs.yml` 管理。

新增正式文档时，检查是否需要同步加入 `mkdocs.yml`。

文档中的配置示例应与当前仓库实际配置保持一致。

不要根据旧版本 README 或历史 issue 编造当前配置。

## Release and CI

`.github/workflows/` 和 Release 流程属于高风险区域。

除非任务明确要求，不要：

* 创建 tag；
* 创建 release；
* 上传附件；
* 删除附件；
* 修改发布版本；
* 修改 release-please 状态；
* 推送 Git commit。

修改 workflow 后应仔细检查 YAML 和 shell quoting。

不要把临时 GitHub 5xx、503 或 Unicorn HTML 错误页误判为项目生成的数据。

## Validation Before Finishing

完成修改后：

1. 查看完整 diff；
2. 确认没有无关修改；
3. 运行与修改文件类型对应的语法检查；
4. 检查 `git diff --check`；
5. 对关键行为做针对性验证；
6. 明确说明哪些内容已经验证、哪些只能在真实 Rime 环境验证。

不要仅因为代码“看起来正确”就声称功能已经验证。

## Change Philosophy

万象属于输入体验高度敏感的项目。

修改优先级：

```text
正确性
> 行为兼容
> 稳定性
> 性能
> 可维护性
> 代码形式上的简洁
```

性能优化必须建立在实际热点或可解释的生命周期问题上。

不要因为某种历史经验，对 Candidate table、Lua table、cache 或 GC 进行没有证据的大规模重构。

遇到不确定的 Rime/librime-lua 行为时，先检查调用上下文和现有实现，再做最小修改。
