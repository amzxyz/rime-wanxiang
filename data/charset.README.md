# 原生字符集源数据

本分支通过 `build/rewrites/charset/files` 将 `data/charset.txt` 编译成
`charset.rewrite.bin`。需将完整原始字符集表放到该路径后才能部署。
数据为 UTF-8 TSV，每行一个汉字及其完整属性字符串，例如：

```text
一	Tabfghjtu
丂	fgju
```

示例不是完整字表。不要用示例替代源数据。旧二进制仅保留作为原始数据备份，
运行时不再调用旧字符集滤镜或 ReverseDb。

配置规则位于 `wanxiang.schema.yaml` 的 `charset/rules`，通过
`translator/charset` 和 `wanxiang_mixedcode/charset` 引用。
标签区分大小写，属性由源数据定义。按 Ctrl+g 切换小字集开关，
简繁开关仍参与字符集并集。多字系统词、用户词及非汉字豁免。
