# 📊 Rime 万象拼音方案性能分析报告

该报告整体评估万象拼音输入方案的性能消耗，除了正常的词典消耗，由于万象纳入了很多lua插件，带来了一些讨论；

由于rime在客户端、内核、方案插件等多个环节都有可能造成bug，最终性能异常，但往往背锅最多的就是lua插件；

lua面对C暴露的接口，需要一定的经验才能应用好，也确实容易造成性能问题，这个在于人；

因此这里给出一些数据，避免人云亦云。

## 总体统计

- Profile 记录行数: 61,756
- 总采集按键次数: 1,997
- 触发 Compose（作文）次数: 968
- 总耗时: 35.48 秒

---

## 1. 按键延迟分布 (ProcessKey)

| 指标 | 值 |
|---|---|
| 采样次数 | 1,997 |
| 最小 | 12 µs |
| 中位数 (P50) | 479 µs |
| 平均 | 3,929 µs |
| P95 | 14,339 µs |
| P99 | 36,424 µs |
| 最大 | 67,605 µs |
| 总耗时 | 7,846.6 ms (7.8 秒) |

P50=479µs 说明大部分普通按键（空格、BackSpace 等不触发作文的键）延迟极低。  
平均 3.9ms 被触发作文的按键拉高。  
P99=36ms 的按键对应复杂场景（多候选过滤 + 用户预测）。

---

## 2. Phase 标记 — 整体耗时分解

每次触发作文的按键，时间分配：

| 阶段 | 平均 (µs) | 总计 (ms) | 占总耗时 |
|---|---|---|---|
| engine CalcSeg | 109.7 | 106.2 | 0.4% |
| engine TransSeg | 6,798.8 | 6,581.2 | 25.2% |
| engine Compose | 6,936.4 | 6,714.4 | 25.7% |
| engine ProcessKey | 3,929.2 | 7,846.6 | 30.0% |
| menu Prepare | 23.6 | 44.1 | 0.2% |

**关键结论**: TransSeg（翻译+过滤）占 Compose 的 98%，是唯一有意义的优化目标。CalcSeg（分词）和 Menu::Prepare（候选取词）可忽略。

---

## 3. 各类型组件完整统计

### 3.1 引擎阶段 (engine)
总计 21,248 ms，占总体 59.9%

| 组件 | 次数 | 平均 (µs) | 总计 (µs) | 类型 |
|---|---|---|---|---|
| Compose | 968 | 6,936.4 | 6,714,422.7 | C++ |
| TransSeg | 968 | 6,798.8 | 6,581,218.9 | C++ |
| ProcessKey | 1,997 | 3,929.2 | 7,846,568.6 | C++ |
| CalcSeg | 968 | 109.7 | 106,218.5 | C++ |

### 3.2 处理器 (Processor)
总计 7,649 ms，占总体 21.6%

| 组件 | 次数 | 平均 (µs) | 总计 (µs) | 类型 |
|---|---|---|---|---|
| processor (speller/switcher) | 10,113 | 603.3 | 6,101,160.1 | C++ |
| *wanxiang.super_sequence*P | 1,844 | 338.6 | 624,371.9 | Lua |
| *wanxiang.super_processor | 1,963 | 240.7 | 472,541.4 | Lua |
| recognizer | 1,837 | 124.3 | 228,427.9 | C++ |
| *wanxiang.force_upper_aux | 1,964 | 57.4 | 112,793.7 | Lua |
| *wanxiang.key_binder | 1,791 | 23.5 | 42,040.5 | Lua |
| *wanxiang.user_predict*P | 1,963 | 17.7 | 34,690.0 | Lua |
| *wanxiang.super_tips | 1,838 | 10.3 | 18,918.8 | Lua |
| *wanxiang.partial_commit | 1,844 | 5.3 | 9,849.9 | Lua |
| (匿名 switcher) | 1,998 | 2.1 | 4,208.3 | C++ |

> **注意**: C++ `processor` 条目 (6,101ms) 包含 speller 内部触发 Compose 的嵌套时间。  
> 剔除膨胀后，真实 Processor 开销约 **232ms**（匿名 4.2ms + recognizer 228ms）。  
> 剩余约 5,869ms 来自嵌套的 Compose / TransSeg 时间。

### 3.3 翻译器 (Translator)
总计 4,060 ms，占总体 11.4%，但T阶段的只有在调用的时候才会产生性能消耗，不输入相应指令消耗等价于0

| 组件 | 次数 | 平均 (µs) | 总计 (µs) | 类型 |
|---|---|---|---|---|
| translator (script_translator) | 1,626 | 1,396.8 | 2,271,162.4 | C++ |
| user_dict_set | 813 | 976.5 | 793,858.9 | C++ |
| *wanxiang.shijian | 813 | 330.2 | 268,425.8 | Lua |
| *wanxiang.unicode | 813 | 135.0 | 109,734.3 | Lua |
| *wanxiang.input_statistics | 813 | 134.0 | 108,913.6 | Lua |
| *wanxiang.user_predict*T | 813 | 122.5 | 99,581.1 | Lua |
| *wanxiang.number_translator | 813 | 113.8 | 92,481.9 | Lua |
| wanxiang_english | 813 | 108.5 | 88,181.4 | C++ |
| *wanxiang.version_display | 813 | 93.7 | 76,178.8 | Lua |
| *wanxiang.super_calculator | 813 | 77.2 | 62,794.5 | Lua |
| *wanxiang.set_schema | 813 | 43.2 | 35,156.7 | Lua |
| add_user_dict | 813 | 25.9 | 21,067.5 | C++ |
| wanxiang_mixedcode | 813 | 24.0 | 19,491.9 | C++ |
| custom_phrase | 813 | 12.3 | 10,017.7 | C++ |
| wanxiang_reverse | 813 | 4.0 | 3,272.9 | C++ |

### 3.4 过滤器 (Filter)
总计 2,398 ms，占总体 6.8%

| 组件 | 次数 | 平均 (µs) | 总计 (µs) | 类型 |
|---|---|---|---|---|
| *wanxiang.super_filter | 813 | 1,279.6 | 1,040,322.1 | Lua |
| *wanxiang.super_sequence*F | 813 | 843.8 | 686,000.6 | Lua |
| *wanxiang.super_replacer | 813 | 337.9 | 274,723.2 | Lua |
| *wanxiang.super_comment_preedit | 813 | 120.5 | 98,001.5 | Lua |
| *wanxiang.super_lookup | 813 | 115.6 | 94,009.4 | Lua |
| *wanxiang.charset_filter | 813 | 84.0 | 68,317.1 | Lua |
| *wanxiang.super_english | 813 | 71.5 | 58,145.1 | Lua |
| *wanxiang.auto_phrase | 813 | 55.7 | 45,310.7 | Lua |
| *wanxiang.user_predict*F | 813 | 39.3 | 31,956.7 | Lua |
| filter (uniquifier/simplifier) | 813 | 2.0 | 1,636.6 | C++ |

### 3.5 分词器 (Segmentor)
总计 79 ms，占总体 0.2%

| 组件 | 次数 | 平均 (µs) | 总计 (µs) | 类型 |
|---|---|---|---|---|
| segmentor (abc/affix/fallback) | 3,183 | 20.4 | 65,036.7 | C++ |
| recognizer | 813 | 15.8 | 12,853.9 | C++ |
| wanxiang_reverse | 813 | 1.3 | 1,092.8 | C++ |
| add_user_dict | 806 | 0.3 | 281.7 | C++ |

### 3.6 菜单 (Menu)
总计 44 ms，占总体 0.1%

| 组件 | 次数 | 平均 (µs) | 总计 (µs) | 类型 |
|---|---|---|---|---|
| Prepare | 1,871 | 23.6 | 44,089.9 | C++ |

### 3.7 后处理器 (Post Processor)
总计 1 ms，占总体 0.0%

| 组件 | 次数 | 平均 (µs) | 总计 (µs) | 类型 |
|---|---|---|---|---|
| (匿名 shape_processor) | 987 | 0.9 | 934.5 | C++ |

### 3.8 格式化器 (Formatter)
总计 0 ms，占总体 0.0%

| 组件 | 次数 | 平均 (µs) | 总计 (µs) | 类型 |
|---|---|---|---|---|
| (匿名 shape_formatter) | 89 | 1.0 | 90.9 | C++ |

---

## 4. Lua vs C++ 组件开销对比

### 按类型分解

| 类别 | Lua 总计 (ms) | C++ 总计 (ms) | Lua 占比 |
|---|---|---|---|
| processor | 1,315.2 | 6,333.8 | 17% |
| segmentor | 0.0 | 79.3 | 0% |
| translator | 853.3 | 3,207.1 | 21% |
| filter | 2,396.8 | 1.6 | 100% |
| **组件合计** | **4,565.3** | **9,621.8** | **32%** |

> 注：C++ processor 总计 6,333.8ms 中有约 6,101ms 为嵌套 Compose 膨胀（见 3.2 节注释）。

### 扣除处理器膨胀后的真实对比

| 类别 | 总计 (ms) | 占比 |
|---|---|---|
| Lua 组件 | 4,565 | 16% |
| C++ 组件 (不含 processor 膨胀) | 24,814 | 84% |
| **合计** | **29,379** | |

### 各 Lua 组件开销排名

| 组件 | 总计 (µs) | 次数 | 平均 (µs) |
|---|---|---|---|
| *wanxiang.super_filter | 1,040,322 | 813 | 1,279.6 |
| *wanxiang.super_sequence*F | 686,001 | 813 | 843.8 |
| *wanxiang.super_sequence*P | 624,372 | 1,844 | 338.6 |
| *wanxiang.super_processor | 472,541 | 1,963 | 240.7 |
| *wanxiang.super_replacer | 274,723 | 813 | 337.9 |
| *wanxiang.shijian | 268,426 | 813 | 330.2 |
| *wanxiang.force_upper_aux | 112,794 | 1,964 | 57.4 |
| *wanxiang.unicode | 109,734 | 813 | 135.0 |
| *wanxiang.input_statistics | 108,914 | 813 | 134.0 |
| *wanxiang.user_predict*T | 99,581 | 813 | 122.5 |
| *wanxiang.super_comment_preedit | 98,002 | 813 | 120.5 |
| *wanxiang.super_lookup | 94,009 | 813 | 115.6 |
| *wanxiang.number_translator | 92,482 | 813 | 113.8 |
| *wanxiang.version_display | 76,179 | 813 | 93.7 |
| *wanxiang.charset_filter | 68,317 | 813 | 84.0 |
| *wanxiang.super_calculator | 62,795 | 813 | 77.2 |
| *wanxiang.super_english | 58,145 | 813 | 71.5 |
| *wanxiang.auto_phrase | 45,311 | 813 | 55.7 |
| *wanxiang.key_binder | 42,040 | 1,791 | 23.5 |
| *wanxiang.set_schema | 35,157 | 813 | 43.2 |
| *wanxiang.user_predict*P | 34,690 | 1,963 | 17.7 |
| *wanxiang.user_predict*F | 31,957 | 813 | 39.3 |
| *wanxiang.super_tips | 18,919 | 1,838 | 10.3 |
| *wanxiang.partial_commit | 9,850 | 1,844 | 5.3 |

### C++ 组件开销排名 (Top 10)

| 组件 | 总计 (µs) | 次数 | 平均 (µs) |
|---|---|---|---|
| translator (script_translator) | 2,271,162 | 1,626 | 1,396.8 |
| user_dict_set | 793,859 | 813 | 976.5 |
| recognizer | 228,428 | 1,837 | 124.3 |
| wanxiang_english | 88,181 | 813 | 108.5 |
| segmentor | 65,037 | 3,183 | 20.4 |
| add_user_dict | 21,068 | 813 | 25.9 |
| wanxiang_mixedcode | 19,492 | 813 | 24.0 |
| recognizer (segmentor) | 12,854 | 813 | 15.8 |
| custom_phrase | 10,018 | 813 | 12.3 |

---

## 5. 典型按键时间线分解

以一次触发作文的按键为例（约 7.7ms），时间分配如下：

```
ProcessKey                                       7,739 µs  (100%)
├── processor 循环 (11个)                          239 µs   ( 3%)  按键分发
├── engine CalcSeg                                 55 µs   ( 1%)  分词
├── engine TransSeg                             5,871 µs   (76%)  翻译+过滤
│   ├── script_translator (C++)                 1,747 µs   (23%)  字典查词
│   ├── *wanxiang.user_predict*T (Lua)          1,067 µs   (14%)  用户预测
│   ├── *wanxiang.super_filter (Lua)            1,729 µs   (22%)  候选过滤
│   ├── *wanxiang.super_replacer (Lua)            336 µs   ( 4%)  替换
│   ├── *wanxiang.super_comment_preedit (Lua)     138 µs   ( 2%)
│   └── 其余 (英语/混合码/auto_phrase 等)        ~854 µs   (11%)
├── engine Compose                              5,931 µs   (CalcSeg + TransSeg)
├── processor                                                                  (speller 收尾)    269 µs   ( 3%)
└── menu Prepare                                   56 µs   ( 1%)
```

---

## 6. 延迟尖峰分析 (P99 > 36ms 的按键)

P99 延迟约 36ms，超过部分由偶发尖峰拉高。Top 10 尖峰均为 >49ms。

这些高延迟按键的共同特征：均触发完整 Compose + TransSeg，主翻译器字典查询耗时（script_translator 3-4ms）和 user_predict*T 偶发 >1.5ms 尖峰叠加。同时存在 `set_schema` 偶发尖峰（见 line 432 出现 2505µs，是正常 43µs 的 58 倍）。

---

## 7. 结论与建议

### 瓶颈排序

| 优先级 | 组件 | 平均延迟 | 类型 | 优化空间 |
|---|---|---|---|---|
| 1 | script_translator (字典查词) | 1,397 µs | C++ LevelDB I/O | 无法在代码层面优化 |
| 2 | super_filter | 1,280 µs | Lua + FFI | 值 2% |
| 3 | user_dict_set | 977 µs | C++ LevelDB | 无法优化 |
| 4 | super_sequence*F | 844 µs | Lua | 需检查 Lua 源码 |
| 5 | super_sequence*P | 339 µs | Lua | 需检查 Lua 源码 |
| 6 | super_replacer | 338 µs | Lua | 需检查 Lua 源码 |

### 可操作建议

1. **Lua filter 链长度优化** — 9 个 Lua filter 串行处理每轮候选。`super_filter` (1,280µs) 排最前面，其 yield 等待后续 8 个 filter 完成才继续。考虑合并 `super_sequence*F` (844µs) 和 `super_replacer` (338µs) 入 `super_filter`。
2. **`super_filter.lua:538` os.date 缓存** — 同一按键内不重复调用系统时间。
3. **`set_schema` 偶发尖峰排查** — line 432 出现 2,505µs 异常值（正常均值 43µs），可能是配置读取出错重试。
4. **user_predict*T 偶发尖峰** — 正常均值 122µs，但出现过 >1.6ms，可能是用户词库大规模查重。

### Lua vs C++ 最终结论

- **Lua 调用开销**: 简单 processor（key_binder, partial_commit）为 5-58 µs，是等效 C++ 的 10-50 倍，但绝对值小，不影响体验。
- **Lua 业务逻辑**: `super_filter` (1,280µs) 是大头，主要来自 FFI 调用累计（`get_genuine`、`Candidate()`、`clone_candidate`）和 10 个候选的两轮遍历。
- **C++ 字典 I/O**: `script_translator` (1,397µs) 和 `user_dict_set` (977µs) 是最大单项，纯 I/O 瓶颈，无法在 Lua 侧优化。
- **整体 Lua 占比**: 扣除 processor 膨胀后，Lua 组件占真实组件时间的 **16%**。整体方案的瓶颈不在 Lua，而在 C++ 字典查词（84%）。
