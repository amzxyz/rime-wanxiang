# ⚙️ 从“命名空间”详解 Rime 设计逻辑与配置哲学

**前言：**
当我们刚拿到一个 Rime 配置文件时，往往会一头雾水，不知道那些密密麻麻的代码在描述什么。于是我们努力去找官方文档，却发现文档里说的名词还是看不懂。
造成这一现象的根本原因，是我们很难在短时间内将这些零散的内容组织起来，建立起对 Rime 底层运行逻辑的系统感知。

本文将帮你从认知层理清 Rime 的设计哲学，带你搭起思维框架。看懂了这篇文章，你再去看文档就不会那么吃力了。

---

## 📦 一、方案基础信息与挂接 (Dependencies)

首先，我们拿到一个方案文件，比如 `wanxiang.schema.yaml`。打开后，最先看到的是方案的基础信息：名称、ID、版本、作者、描述，以及一个极其重要的段落——**挂接引用的方案 (`dependencies`)**。

```yaml
# 方案说明
schema:
  schema_id: wanxiang
  name: 万象拼音
  version: "LTS"
  author:
    - amzxyz
  description: |
    请勾选【万象拼音】以启用，万象拼音标准版本，带声调的词库，支持语法模型，全拼、简拼、整句、声调辅助筛选，拥有超越大厂的输入体验！
    【文本框输入：/pinyin全拼，/zrm自然码,/flypy小鹤，/mspy,/sogou,/pyjj等，详见README.md】
  dependencies:
    - wanxiang_mixedcode    # 混合编码
    - wanxiang_reverse      # 部件拆字，反查及辅码
    - wanxiang_english      # 英文
```

**💡 核心理解：**
`dependencies` 的作用是什么？如果将其他子方案挂接到这里，那么在部署时，这些子方案就会跟随主方案一起被编译。
这意味着，你不需要把这些子方案单独写进 `default.yaml` 的 `schema_list`（方案选择列表）里。因为主方案最终需要引用的，是这些挂接方案**生成的词库数据**，而不是让用户去单独切换到那个方案本身。

---

## 🎛️ 二、状态机与开关组 (Switches)

接着往下看，我们会遇到 `switches` 段落。这是用来建立一个**显性开关列表**的地方。
当按下 ```Ctrl+` ``` 打开万象的状态面板时，中间折叠的那些关于当前方案的开关项，就是与 `switches` 的配置一一对应的。

> **隐性开关**：除了这里配置的可见开关，你还可以在 `key_binder`（快捷键绑定）段落里配置快捷键，直接发送 `toggle` 状态进行隐性的布尔值（开/关）切换。

### 1. 单一布尔开关
```yaml
switches:
  - name: ascii_mode                    # 中英输入状态
    states: [ 中文, 英文 ]
    #reset: 1                           # reset 是一个可选项
  - name: ascii_punct                   # 中英标点状态
    states: [ 中标, 英标 ]
```

* `name`: 定义了开关的内部 ID。  
* `states`: 用数组罗列了开/关（false/true）状态在面板上显示的文字描述。  
* `reset`: 每次初始化时重置状态。`reset: 1` 即重置为开启 (true)，`reset: 0` 重置为关闭 (false)。如果不写，通常前端应用会记忆上一次的状态。由于不同的宿主软件（如 QQ 和文本文档）状态不互通，为了统一体验，我们常常会用到它。  

### 2. 循环互斥开关 (Options)
除了单一的开关，还有包含多个选项的循环开关组，这里用 `options` 取代了 `name`：

```yaml
  - options: [ s2s, s2t, s2hk, s2tw ]
    states: [ 简体, 通繁, 港繁, 臺繁 ]
```
在状态面板中点击其中一个，该项即设为 `true`，其他自动变为 `false`（互斥）。在设置快捷键时，我们一般绑定组内的第一个名称，多次按下快捷键即可在组内循环切换。

> **优雅的状态机**：开关在日常使用中扮演着重要角色。例如中英互译、简繁转换等功能，我们平时关闭，用到时一键开启。这种设计为功能的实时性提供了重要保证，免去了修改配置和重新部署的麻烦。

---

### 🛠️ 附：如何通过 Custom Patch 修改开关参数？

在 YAML 语法中，以 `-`（短横线）开头的列表我们称之为数组，**数组的索引是从 `0` 开始计数的**。
如果你想改变上述配置中 `ascii_punct`（第二个开关组）的 `reset` 状态，你需要数清楚它是第 1 个数组（0 是第一个，1 是第二个）。

在 `wanxiang.custom.yaml` 中的写法如下：

```yaml
patch:
  switches/@1/reset: 1   # @1 代表在 switches 的第二组里加入 reset: 1 参数
```

---

## 🏭 三、核心流水线：Engine (引擎) 与 四大组件


接下来是重头戏：`engine`。这是 Rime 运作逻辑的完美体现，Rime 本质上就是一条严密的字符处理流水线。

流水线分为四个车间（阶段）：  
1.  **`processors` (处理器)**：处理按键事件（如快捷键拦截、标点上屏、回车退格等）。  
2.  **`segmentors` (分段器)**：对输入码进行切词分段，打上对应的标签 (tag)。  
3.  **`translators` (翻译器)**：核心组件！负责将拼音/形码等输入码翻译查询，生成候选词。  
4.  **`filters` (滤镜/过滤器)**：后处理加工厂。负责对生成的候选词进行增、删、改、排序、转换（如简繁转换、Emoji替换）。  

```yaml
# 输入引擎
engine:
  processors:
    - lua_processor@*wanxiang.super_processor            #KP小键盘、字母选词、符号快打、超强分词、重复限制、退格限制、声调回退、以词定字
    - lua_processor@*wanxiang.user_predict*P             #靠自己养的专属预测联想处理器，不再依赖前端插件以及固定数据
    - lua_processor@*wanxiang.partial_commit             #通过ctrl+1~0局部提交10个字以内的句子的前几个字（一般为正确的前几个）使用时要遵循合理的分词结构能促进后续编码打出正确的词汇
    - lua_processor@*wanxiang.super_tips                 #超级提示模块：表情、简码、翻译、化学式、等等靠你想象
    - lua_processor@*wanxiang.super_sequence*P           #手动排序，高亮候选 ctrl+j左移动 ctrl+k 右移动 ctrl+l 移除位移  ctrl+p 置顶
    - ascii_composer                                     #处理英文模式及中英文切换
    - recognizer                                         #与 matcher 搭配，处理符合特定规则的输入码，如网址、反查等 tags
    - key_binder                                         #在特定条件下将按键绑定到其他按键，如重定义逗号、句号为候选翻页、开关快捷键等
    - lua_processor@*wanxiang.key_binder                 #绑定按键扩展能力，支持正则扩展将按键生效情景更加细化
    - speller                                   #拼写处理器，接受字符按键，编辑输入
    - punctuator                                #符号处理器，将单个字符按键直接映射为标点符号或文字
    - selector                                  #选字处理器，处理数字选字键〔可以换成别的哦〕、上、下候选定位、换页
    - navigator                                 #处理输入栏内的光标移动
    - express_editor                            #编辑器，处理空格、回车上屏、回退键
  segmentors:
    - ascii_segmentor                           #标识英文段落〔譬如在英文模式下〕字母直接上屛
    - matcher                                   #配合 recognizer 标识符合特定规则的段落，如网址、反查等，加上特定 tag
    - abc_segmentor                             #标识常规的文字段落，加上 abc 这个 tag
    - affix_segmentor@wanxiang_reverse          #反查 tag
    - affix_segmentor@add_user_dict             #自造词tag
    - punct_segmentor                           #标识符号段落〔键入标点符号用〕加上 punct 这个 tag
    - fallback_segmentor                        #标识其他未标识段落，必须放在最后帮助tag模式切换后回退重新处理
  translators:
    - punct_translator                     #配合 punct_segmentor 转换标点符号
    - script_translator                    #脚本翻译器，用于拼音、粤拼等基于音节表的输入方案
    - lua_translator@*wanxiang.user_predict*T       #靠自己养的专属预测联想处理器，不再依赖前端插件以及固定数据
    - lua_translator@*wanxiang.version_display      #输入'/wx'，显示万象项目网址和当前版本号
    - lua_translator@*wanxiang.set_schema           #输入'/zrm'，快速切换为自然码双拼， /flypy→小鹤双拼 /mspy→微软双拼 /zrm→自然码 /sogou→搜狗双拼 /abc→智能ABC /ziguang→紫光双拼 /pyjj→拼音加加 /gbpy→国标双拼 /lxsq→乱序17 /pinyin→全拼
    - lua_translator@*wanxiang.shijian              #农历、日期、节气、节日、时间、周、问候模板等等，触发清单看下文
    - lua_translator@*wanxiang.unicode              #通过输入大写U引导，并输入Unicode编码获得汉字输出
    - lua_translator@*wanxiang.number_translator    #数字、金额大写，通过输入大写R1234获得候选输出
    - lua_translator@*wanxiang.super_calculator     #超级计算器，Lua内查看高级用法
    - lua_translator@*wanxiang.input_statistics     #一个输入统计的脚本，以日、周、月、年等维度的统计
    - table_translator@custom_phrase       #自定义短语 custom_phrase.txt，用于置顶自定义编码候选词
    - table_translator@wanxiang_english    #英文词汇表导入
    - table_translator@wanxiang_mixedcode  #混合编码词汇表导入
    - reverse_lookup_translator@wanxiang_reverse    #挂接部件组字和笔画反查
    - script_translator@add_user_dict      #按需自造词
    - script_translator@user_dict_set      #使用自造词
  filters:
    - lua_filter@*wanxiang.auto_phrase              #无感造词,英文造词
    - lua_filter@*wanxiang.super_lookup             #字词输入中反查辅助筛选
    - lua_filter@*wanxiang.super_english            #放replacer前面,单词变大写后应该能在替换中命中数据,负责英文方案及中英混输中英文单词格式化，语句流，自动加空格等策略
    - lua_filter@*wanxiang.charset_filter           #放replacer前面,全方位自定义的字符集过滤器，支持繁体字符集开放
    - lua_filter@*wanxiang.super_comment_preedit    #放其他需要注释处理器后面,会有清空注释的操作,超级注释模块，支持错词提示、辅助码显示，部件组字读音注释，支持个性化配置和关闭相应的功能，详情搜索super_comment进行详细配置
    - lua_filter@*wanxiang.super_replacer           #OpenCC替代器，更灵活的处理方式，更自由的自定义方式，支持简繁转换、简码模式、支持候选替换、注释替换、候选派生等等
    - lua_filter@*wanxiang.super_filter             #先进行字符过滤后简繁转换，这样能繁体继承简体权重。本质功能相关功能见Lua文件
    - lua_filter@*wanxiang.super_sequence*F         #放去重前,接管排序索引固定,手动排序，对高亮候选 ctrl+j左移动 ctrl+k 右移动 ctrl+0 移除位移
    - lua_filter@*wanxiang.user_predict*F           #用于输入编码后的上下文调频
    - uniquifier                                    #去重,必须在最后
```
*(注：为演示清晰，上述代码省略了部分万象特有的 Lua 脚本，实际以方案文件为准。)*

---

## 🏷️ 四、解密：“命名空间”的设计逻辑

了解了流水线，我们终于迎来了最核心的概念——**命名空间 (Namespace)**。

在 `engine` 阶段挂载了那么多组件，它们的具体参数在哪设置呢？答案就是“命名空间”。Rime 的套路是：**细节配置参数写在顶层的同名 Key 下，处理器读到后就会覆盖默认设置。**

### 场景 1：单例组件的命名空间
例如我们在 `processors` 引入了 `speller`，那么它的配置只需在顶层新建一个 `speller:` 即可：

```yaml
engine:
  processors:
    - speller

# 这里就是 speller 的命名空间
speller:
  alphabet: zyxwvutsrqponmlkjihgfedcba
  delimiter: " '"
```

### 场景 2：多例组件（带 `@`）的命名空间
当我们需要挂载多个同类组件（比如好几个词典翻译器）时，就会用到 `@` 符号。`@` 后面的名字，就是它的专属命名空间。

例如，我们挂载了自定义短语翻译器 `table_translator@custom_phrase`：

```yaml
engine:
  translators:
    - table_translator@custom_phrase

# 这里的 custom_phrase 就是这个具体组件的命名空间
custom_phrase:
  dictionary: ""
  user_dict: custom_phrase
  db_class: stabledb
```

> **⚠️ 特例注意：**
> Lua 编写的脚本（如 `lua_translator@...`）不一定会完全遵守这套隐式规则。Lua 脚本可能会在代码内部指定自己要去读取哪个名字的配置块。遇到复杂的 Lua 组件，可以打开脚本文件观察其读取配置的变量名来寻找线索。

---

## 结语

理解了这一层层叠叠的设计，你的脑海里就搭起了一个清晰的思维框架：**这个方案用了什么组件（流水线） -> 它的命名空间是什么（去哪找配置） -> 是否需要暴露到方案中，还是不设置采用默认值。**

在这样的框架下，面对再复杂的 Rime 配置文档，我们只需要顺藤摸瓜，各个击破即可！