# Changelog

## [15.2.0](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.11...v15.2.0) (2026-03-11)


### ✨ 新特性

* 新增联想输入时空格打断联想并上屏空格对齐大厂，默认开启 ([e585912](https://github.com/amzxyz/rime_wanxiang/commit/e58591228df015f80dde2988b4590926ecc05c40))

## [15.1.11](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.10...v15.1.11) (2026-03-10)


### 🐛 Bug 修复

* release页面预测数据库下载指引 ([858b490](https://github.com/amzxyz/rime_wanxiang/commit/858b490c0c88173492ad6af0404d805482c822de))
* 修复若干bug ([d3c880a](https://github.com/amzxyz/rime_wanxiang/commit/d3c880a310bba8ee05e1afb5668ecfa04ebab283))

## [15.1.10](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.9...v15.1.10) (2026-03-10)


### 🐛 Bug 修复

* 句号在特殊情况下不应被占用 ([4712c5e](https://github.com/amzxyz/rime_wanxiang/commit/4712c5e396e067c1ce2d39838c51602c8484f139))
* 英文lua加上user_table这个类型后可以都显示不受英文词组数量过滤逻辑干扰 ([27f9f6b](https://github.com/amzxyz/rime_wanxiang/commit/27f9f6b728763c1bbff209a049e671b9ef5d0e4a))

## [15.1.9](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.8...v15.1.9) (2026-03-10)


### 🐛 Bug 修复

* 修复时辰计算的若干bug，按键处理器全方位暴露出设置项功能启用开关，以词定字等功能配置也归并到一起 ([f6e21e7](https://github.com/amzxyz/rime_wanxiang/commit/f6e21e7a37fcb1b4d7396b800d30c33ee7470b15))
* 增加了简码的tag配置，反查出现简码的加上[abc] ([c516436](https://github.com/amzxyz/rime_wanxiang/commit/c5164366c9a2a4b33690846f48a4ea3c83ee9acc))

## [15.1.8](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.7...v15.1.8) (2026-03-09)


### 🐛 Bug 修复

* 一直以来有人问我繁体字转换出问题，没有人描述清楚，今天我终于洞察到他们发生了什么，首先是开启大字集这个动作的本质上是关闭了过滤，其实这个线条就不工作了，s2t开启，则他只过滤显示繁体字，简体字就没了，这就是为啥东西没了的缘故，原本我希望正常使用通规范围，到了s2t求个并集，通规字参与过滤又会转换回来繁体字从而得到留存，现在我为你s2t 等也加上了a的范围，这样s2t开启后就是fa的范围，在后续被超级替换刷过以后就变成了全繁体 ([f2b88e0](https://github.com/amzxyz/rime_wanxiang/commit/f2b88e06e1e1b27f7104ae2ce7f957e4fe15b8c4))

## [15.1.7](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.6...v15.1.7) (2026-03-09)


### 🐛 Bug 修复

* 混合编码还是恢复到单独的方案，能用但会干扰正常单字母派生，这可能是rime底层逻辑的一些限制没办法 ([8015ccc](https://github.com/amzxyz/rime_wanxiang/commit/8015ccc29fd251033579908e93762eb8f1dca575))

## [15.1.6](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.5...v15.1.6) (2026-03-09)


### 📚 词库更新

* 词库调整 ([a8c8c40](https://github.com/amzxyz/rime_wanxiang/commit/a8c8c409f8d8f3a83293e28fdc8972a881b27039))
* 调整3字词频 ([65663d6](https://github.com/amzxyz/rime_wanxiang/commit/65663d69bf315031b02c3be94ce620061722bd5a))


### 🐛 Bug 修复

* 1、取消英文在非句子中的无候选兜底，干扰中文是否唯一的判定2、超级替换支持剩余编码匹配简码3、超级注释的部分逻辑调整 ([5349353](https://github.com/amzxyz/rime_wanxiang/commit/534935331931a8f8e97fcd229deba282f11819a5))
* 九键设置简化了，不在暴露外部转换参数，而是用一个t9优化替代，他能将维护的字母编码存入数据库时候变成数字，并把原编码储存起来用于修改preedit ([59a0910](https://github.com/amzxyz/rime_wanxiang/commit/59a091082652be07742760cb9c9593a03403f9bf))
* 九键输入数字编码打时间现在可以看到正确的编码了 ([ddb3c2c](https://github.com/amzxyz/rime_wanxiang/commit/ddb3c2ca084538efe67f3bfb623f06a77456147f))
* 规范化shijian.lua的cand.type参数 ([098aa64](https://github.com/amzxyz/rime_wanxiang/commit/098aa646a8af8f1267c1c8b2a9d1e6029395909e))

## [15.1.5](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.4...v15.1.5) (2026-03-07)


### 🐛 Bug 修复

* 恢复几个脚本 ([60a8dd1](https://github.com/amzxyz/rime_wanxiang/commit/60a8dd17135d2863d2b1cc6e24bc00d4f47b9684))

## [15.1.4](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.3...v15.1.4) (2026-03-07)


### 🐛 Bug 修复

* 修复一处转写 ([6c40df9](https://github.com/amzxyz/rime_wanxiang/commit/6c40df94e07eb96d06dd1bd90af155bf967d8684))
* 恢复lookup脚本 ([3166d9b](https://github.com/amzxyz/rime_wanxiang/commit/3166d9bcc738820a34c02b550ba66461fc6b8519))

## [15.1.3](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.2...v15.1.3) (2026-03-07)


### 🐛 Bug 修复

* 修复一处转写 ([5421cb8](https://github.com/amzxyz/rime_wanxiang/commit/5421cb8fced15e0dbf0630561ff3d7cefd259e12))
* 修复一处遗漏 ([466a253](https://github.com/amzxyz/rime_wanxiang/commit/466a253c9d4bd3229f6967ba27bc74f48983435d))

## [15.1.2](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.1...v15.1.2) (2026-03-07)


### 🐛 Bug 修复

* 兜底行为统一type=fallback ([c14b965](https://github.com/amzxyz/rime_wanxiang/commit/c14b965f4d97c5411b77b80b2f459ec259d3c28f))
* 定义为万象状态面板 ([6c739f1](https://github.com/amzxyz/rime_wanxiang/commit/6c739f15a8459673ac9064e0e9bc3be50bed1e6f))
* 部分混合编码迁移到固定词库参与组句 ([bf31afb](https://github.com/amzxyz/rime_wanxiang/commit/bf31afb6d51f3f3d9ba3c37c449bec6c6ea0bf4b))
* 针对字符切分整体lua做uft-8优化 ([c72a36c](https://github.com/amzxyz/rime_wanxiang/commit/c72a36c983a82909ca1723dd34f1ad4084e473b2))

## [15.1.1](https://github.com/amzxyz/rime_wanxiang/compare/v15.1.0...v15.1.1) (2026-03-06)


### 🐛 Bug 修复

* 遗漏了开关名称 ([629954d](https://github.com/amzxyz/rime_wanxiang/commit/629954d86757dd46bdd1be570b1b1460e647421d))

## [15.1.0](https://github.com/amzxyz/rime_wanxiang/compare/v15.0.3...v15.1.0) (2026-03-06)


### ✨ 新特性

* 出简这个配置重构了一下,数据维护层回归到abbrev.txt一个文件,同时开关也只留一个简码开关,逻辑层我们可以定义置顶几个词、置顶到什么位置,同时将空出简变成了一个常态化兜底动作。同时这个特性让九键也能合理使用简码,有系统词可以置顶适当位置补充1-2个简码，没有多显示几个简码，逻辑非常自洽⚠️本次更新后用户请自行修改custom文件和预设文件super_plcaer相关段落一样否则出简码功能将会异常,请知悉 ([3fe782e](https://github.com/amzxyz/rime_wanxiang/commit/3fe782e1c769fe6a5e57b3dc0393becb99ba2a61))
* 新增总出简码支持设置置顶位置了,次选三选随便写,同时这个特性让九键也能合理使用简码,⚠️本次更新后用户请自行修改custom文件和预设文件super_plcaer相关段落一样否则总出简码功能等于没有,请知悉 ([93f4670](https://github.com/amzxyz/rime_wanxiang/commit/93f467074244b35877105c20d78c020117c2956d))


### 📚 词库更新

* AI精炼移除无用词条 ([aa03b91](https://github.com/amzxyz/rime_wanxiang/commit/aa03b91b774b2a29b2b863dac33ece9cdd795804))
* AI精炼移除无用词条/调整词频 ([54e913e](https://github.com/amzxyz/rime_wanxiang/commit/54e913ef3868fb26d5f936c4d72c06ceb2399271))


### 🐛 Bug 修复

* 优化英文脚本与超级滤镜在使用\时的一些逻辑细节，从而不干扰用户造词 ([52c14be](https://github.com/amzxyz/rime_wanxiang/commit/52c14beb5425e6416a47bb12160dd74c232de9ac))
* 成语一同移动到简码db数据库跟随简码前置的位置一起处理 ([335b230](https://github.com/amzxyz/rime_wanxiang/commit/335b2300d7d72ed4678ad53a0047778ae1635dfd))
* 成语也一并并入了简码库，复杂滤镜这一层不再负责简码前置的相关逻辑了，交还给replacer直接处理简码数据与逻辑，更加集中，因此精简这个滤镜的复杂代码提升性能 ([f357cfc](https://github.com/amzxyz/rime_wanxiang/commit/f357cfc2d5891be4c9c40d716abbbeb34c7470f9))


### 🏡 杂项

* 添加说明 ([065c7bd](https://github.com/amzxyz/rime_wanxiang/commit/065c7bdfa6c1bbe84dca9c6e70da64c30ba851f2))

## [15.0.3](https://github.com/amzxyz/rime_wanxiang/compare/v15.0.2...v15.0.3) (2026-03-04)


### 📚 词库更新

* 词库调整 ([6ac0b25](https://github.com/amzxyz/rime_wanxiang/commit/6ac0b2528aca84965fda9698c6062c7764c80209))
* 调整词频 ([32c9c5a](https://github.com/amzxyz/rime_wanxiang/commit/32c9c5afb1d5b8d2c6578fcfa7bcad4ce19ef28f))


### 🐛 Bug 修复

* 移除元叔内置文件 ([ac460a5](https://github.com/amzxyz/rime_wanxiang/commit/ac460a5b7b369107efa48e058a8b318ef8a85968))

## [15.0.2](https://github.com/amzxyz/rime_wanxiang/compare/v15.0.1...v15.0.2) (2026-03-04)


### 🐛 Bug 修复

* **super_english:** 限制候选数时用户词不占用数量配额有多少显示多少 ([ea36231](https://github.com/amzxyz/rime_wanxiang/commit/ea36231aaa9a9a0b928a70f8b24f327d95008057))
* **super_replacer:** 修复总出简应该出现在根目录置顶词之后 ([57323cd](https://github.com/amzxyz/rime_wanxiang/commit/57323cd34cfb04cd37e1e04d99026f197efb7c45))
* **super_replacer:** 简码拆分为两个文件,空出简码和总出简码分别提供不同的数据库 ([582f41e](https://github.com/amzxyz/rime_wanxiang/commit/582f41e050e5a4be2e6d922e8f44efe935ed3d64))

## [15.0.1](https://github.com/amzxyz/rime_wanxiang/compare/v15.0.0...v15.0.1) (2026-03-03)


### 🐛 Bug 修复

* **super_replacer:** 修复了一个大量积累用户词导致的空出简异常([#843](https://github.com/amzxyz/rime_wanxiang/issues/843)) ([3760876](https://github.com/amzxyz/rime_wanxiang/commit/376087671b19967ed4d629813feae5477b63b7a4))


### 🏡 杂项

* 修改说明 ([45d95a7](https://github.com/amzxyz/rime_wanxiang/commit/45d95a7a010580bcfa870523db7744943e621bfa))

## [15.0.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.9.0...v15.0.0) (2026-03-03)


### 💅 重构

* 新增独立的字符集过滤，重构lua文件放在wanxiang文件夹下，兼容多方案共存,新增英文候选限制 ([f2bbb39](https://github.com/amzxyz/rime_wanxiang/commit/f2bbb39916982b6c5b63e9a275a62220566fa733))


### 🏡 杂项

* release 15.0.0 ([a99f006](https://github.com/amzxyz/rime_wanxiang/commit/a99f006e0ed3a77dfadf5daa15a2c67f945c475b))

## [14.9.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.8...v14.9.0) (2026-03-02)


### ✨ 新特性

* 新增独立的字符集过滤，重构lua文件放在wanxiang文件夹下，兼容多方案共存 ([1123f4f](https://github.com/amzxyz/rime_wanxiang/commit/1123f4fdab367cbcbd59cc3675adb83d3ed16d48))


### 📚 词库更新

* AI甄选移除3字词条片段3万,词库精炼持续进行中... ([8deb95a](https://github.com/amzxyz/rime_wanxiang/commit/8deb95af530b543085686a49399430d8aad00f9d))
* AI精炼移除13000词条 ([373fe90](https://github.com/amzxyz/rime_wanxiang/commit/373fe90936ff5ceb4da91dd53e74d1e6baf126f0))
* AI精炼移除3000词条 ([4d47ef9](https://github.com/amzxyz/rime_wanxiang/commit/4d47ef9cf878498e5799a383278eabd6e1d1bc82))
* AI精炼移除6000词条 ([6cd7cb1](https://github.com/amzxyz/rime_wanxiang/commit/6cd7cb1c1488a42a592b0466dcf1dd717de80991))
* AI精炼移除8000词条 ([6360af1](https://github.com/amzxyz/rime_wanxiang/commit/6360af17e8fef1c8410bf374f090decf54819994))
* 词库调整 ([6b5aa0b](https://github.com/amzxyz/rime_wanxiang/commit/6b5aa0b4641ae1fcff11ae49540ad51a322feddb))


### 🐛 Bug 修复

* 修改自动化 ([6b0d9bb](https://github.com/amzxyz/rime_wanxiang/commit/6b0d9bb395ad3dd22c3e8cd4218670d80891f7eb))

## [14.8.8](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.7...v14.8.8) (2026-03-01)


### 🐛 Bug 修复

* 恢复无候选的fallback ([725bfee](https://github.com/amzxyz/rime_wanxiang/commit/725bfeee2fd4ced1c9d30a1682d872ec93fd3883))

## [14.8.7](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.6...v14.8.7) (2026-03-01)


### 🐛 Bug 修复

* 优化几个脚本细节 ([c0d3a24](https://github.com/amzxyz/rime_wanxiang/commit/c0d3a248c76827460a4e79052d8b7450b9f3d35f))
* 改进刷辅助码脚本 ([49783f9](https://github.com/amzxyz/rime_wanxiang/commit/49783f90d8d1837a168d946809037defdb4b439f))
* 滤镜几个组件功能上出现了顺序冲突做了一下深度调整 ([de8619d](https://github.com/amzxyz/rime_wanxiang/commit/de8619d5a0f26220b26cfa0651587aeb36e84e4e))

## [14.8.6](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.5...v14.8.6) (2026-02-27)


### 🐛 Bug 修复

* 修改反查滤镜名称获取方式 ([10d631b](https://github.com/amzxyz/rime_wanxiang/commit/10d631b61efd50b671741f103b2eff333f0c4aae))
* 移除无关代码 ([e82e598](https://github.com/amzxyz/rime_wanxiang/commit/e82e598e332fa43140aa03c73fd045efb70b42ee))
* 英文派生大写后单词可参与替换，因此英文lua放在超级替换前面 ([5d8c7c4](https://github.com/amzxyz/rime_wanxiang/commit/5d8c7c4f672b7b326fcdfb80bfe862bb9d5bbb65))
* 过滤器交换顺序后英文lua不能在中文方案中删除太极符号了，这会导致后面的滤镜无法删除中文方案中的无效的英文句子 ([8f286a7](https://github.com/amzxyz/rime_wanxiang/commit/8f286a7c1bd81dca32950f8a9564392dea45ce88))

## [14.8.5](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.4...v14.8.5) (2026-02-27)


### 📚 词库更新

* 词库调整 ([22f3646](https://github.com/amzxyz/rime_wanxiang/commit/22f3646f588d13b45b3c4038cfc8328c1e17c08f))

## [14.8.4](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.3...v14.8.4) (2026-02-27)


### 📚 词库更新

* 词库调整 ([c539605](https://github.com/amzxyz/rime_wanxiang/commit/c539605c58a966c84ebf0cba403d8640916070e9))


### 🐛 Bug 修复

* 多种tag模式下不启用按键锁定 ([62050ea](https://github.com/amzxyz/rime_wanxiang/commit/62050ea7f514e1814412abeeee5e2bd752a22b2a))

## [14.8.3](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.2...v14.8.3) (2026-02-26)


### 🐛 Bug 修复

* **force_upper_aux:** 智能选择反查数据库 ([756d168](https://github.com/amzxyz/rime_wanxiang/commit/756d168458f7956b6d3d894b18215c7d73f384e5))
* 交换lua顺序以被超级注释接管 ([b43e4ca](https://github.com/amzxyz/rime_wanxiang/commit/b43e4ca7a2d15561871cdba6af23b096ab7e895d))
* 符号下面有一些生僻康熙部首不应该被字符集过滤 ([daef812](https://github.com/amzxyz/rime_wanxiang/commit/daef812d4de36ea4dc5c712225bb057ccdb1f2ce))

## [14.8.2](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.1...v14.8.2) (2026-02-26)


### 🐛 Bug 修复

* 新增cand.type类型外显设置能力，可以在super_comment参数进行设置([#824](https://github.com/amzxyz/rime_wanxiang/issues/824)) ([9599fef](https://github.com/amzxyz/rime_wanxiang/commit/9599fef3a060499859084bbc1c1a9018d498efe5))

## [14.8.1](https://github.com/amzxyz/rime_wanxiang/compare/v14.8.0...v14.8.1) (2026-02-26)


### 🐛 Bug 修复

* 利用自动补全N-1双大写辅助码的方法固定前面明确的语句，循环按句号能在N-1个字最早的候选(不加任何辅助码时的状态)和N字候选当前进行循环，类似写文档想起来点下保存，不好理解在输入句子后点点句号感受一下，其次再次向使用句号逗号翻页的宝宝们说一声麻烦自己改一下按键，因为真的手机上一个逗号一个句号分配至tips、这个固定候选的功能非常好用，电脑上也一样 ([74b5015](https://github.com/amzxyz/rime_wanxiang/commit/74b5015c6403b3be9ee0b2969f58433e14ec4e6e))

## [14.8.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.7.7...v14.8.0) (2026-02-26)


### ✨ 新特性

* 新增一个利用自动补全N-1双大写辅助码的方法固定前面明确的语句，类似写文档想起来点下保存 ([6e847d3](https://github.com/amzxyz/rime_wanxiang/commit/6e847d3a5b408e672f8108b9b18614ca74f430fa))

## [14.7.7](https://github.com/amzxyz/rime_wanxiang/compare/v14.7.6...v14.7.7) (2026-02-25)


### 📚 词库更新

* 词库调整 ([65936a2](https://github.com/amzxyz/rime_wanxiang/commit/65936a27b3766ceb56580fde809781c7365c33cb))


### 🐛 Bug 修复

* symbol表兼容uiv双拼用法 ([1e3109a](https://github.com/amzxyz/rime_wanxiang/commit/1e3109a260c9d036cd690e1faf46a140c22eff96))
* 修复bug ([f912676](https://github.com/amzxyz/rime_wanxiang/commit/f9126766cf1fdd06387b006d85451411411932c6))

## [14.7.6](https://github.com/amzxyz/rime_wanxiang/compare/v14.7.5...v14.7.6) (2026-02-25)


### 📚 词库更新

* 词库调整 ([4606f8a](https://github.com/amzxyz/rime_wanxiang/commit/4606f8a67d1b4138715f0a3cbde3508ae84a0ad4))
* 词库调整 ([9fd5e9f](https://github.com/amzxyz/rime_wanxiang/commit/9fd5e9f73a960729ac725aa1878a4f642ce3e3e2))


### 🐛 Bug 修复

* **super_lookup:** 移除词组中残留的笔画编码([#821](https://github.com/amzxyz/rime_wanxiang/issues/821)) ([95cfc9e](https://github.com/amzxyz/rime_wanxiang/commit/95cfc9e3b6bbe230f787ae00176738cd33f5f55e))
* 现在手动排序的内容也能被符号包裹了 ([e28a687](https://github.com/amzxyz/rime_wanxiang/commit/e28a687a1b19f2190429b8f607b166b0c92e7595))
* 符号包裹现在可以包裹前置的成语简码 ([b5c7ad8](https://github.com/amzxyz/rime_wanxiang/commit/b5c7ad8d9766a777c1c61d8c5413fe5a9c002e8d))

## [14.7.5](https://github.com/amzxyz/rime_wanxiang/compare/v14.7.4...v14.7.5) (2026-02-22)


### 📚 词库更新

* 词库调整 ([f487b51](https://github.com/amzxyz/rime_wanxiang/commit/f487b519f54d9d2c670c7d6ca8c5e70fc9a0e17f))


### 🐛 Bug 修复

* fmm数据库匹配缓存机制，在输入框生命周期内减少数据库的查询 ([0a4084c](https://github.com/amzxyz/rime_wanxiang/commit/0a4084c3852e60e14d444e9fd41e281b999f9a86))
* 修正转写正则错误 ([285b044](https://github.com/amzxyz/rime_wanxiang/commit/285b044e4da2ccb332fec079b46be408b2b86733))
* 移除不需要的文件 ([ca11775](https://github.com/amzxyz/rime_wanxiang/commit/ca1177580b17bf2026e71b640a0b85353bcdbf55))

## [14.7.4](https://github.com/amzxyz/rime_wanxiang/compare/v14.7.3...v14.7.4) (2026-02-20)


### 🐛 Bug 修复

* 九键恢复lua脚本处理，增加无声调注释，这样适应元书同时可适应其他前端 ([ba864a0](https://github.com/amzxyz/rime_wanxiang/commit/ba864a06a7765c2f677f49b264d6e917b40ef223))

## [14.7.3](https://github.com/amzxyz/rime_wanxiang/compare/v14.7.2...v14.7.3) (2026-02-20)


### 📚 词库更新

* 词库调整 ([ee9f7bc](https://github.com/amzxyz/rime_wanxiang/commit/ee9f7bcd012f604320aa2525bf6d1ad1652dc9fa))
* 词库调整 ([663026a](https://github.com/amzxyz/rime_wanxiang/commit/663026a879eda746cf9c61c342554755a003be7b))
* 词库调整 ([c2e668d](https://github.com/amzxyz/rime_wanxiang/commit/c2e668d4ea1cd9cd618fe661055603c9d361a311))
* 词库调整 ([7f5afed](https://github.com/amzxyz/rime_wanxiang/commit/7f5afed1cd855ac39759ac0529e7a494193aa595))
* 词库调整 ([159a98d](https://github.com/amzxyz/rime_wanxiang/commit/159a98dce23d5c0d9f69db44598460a5d2bc9b85))
* 词库调整 ([3ff8406](https://github.com/amzxyz/rime_wanxiang/commit/3ff84068a61dd96dc657097133026365aa389bcd))
* 词库调整 ([efe19c5](https://github.com/amzxyz/rime_wanxiang/commit/efe19c56cfff839818caad81c6d88ba0bbc26868))


### 🐛 Bug 修复

* **super_lookup:** 现已支持``造词模式进行lookup反查筛选 ([17753dd](https://github.com/amzxyz/rime_wanxiang/commit/17753dd070457ec1a1facd6d1d0cde1a20675aba))
* **super_replacer:** 优化算法，减少数据库访问，优化数据重新加载逻辑 ([c36cf2c](https://github.com/amzxyz/rime_wanxiang/commit/c36cf2c1077163f1b06cd006dea9df23e994113a))
* **super_tips:** 优化数据重新加载逻辑 ([0d16059](https://github.com/amzxyz/rime_wanxiang/commit/0d160597bdf8839d466907bcf1cf4bd06b616067))
* 删除多余代码 ([1a4f960](https://github.com/amzxyz/rime_wanxiang/commit/1a4f960261b959ef40e2d0e299ab36b60cec3adb))
* 小狼毫字体默认修改为13 ([ecc6fab](https://github.com/amzxyz/rime_wanxiang/commit/ecc6fabc56043d34e14f7be3f71c5e4ffd30bc96))


### 🏡 杂项

* 修改说明 ([a2532a0](https://github.com/amzxyz/rime_wanxiang/commit/a2532a0233acf4f0876e7fcbc9ba0e5a6c9285e8))

## [14.7.2](https://github.com/amzxyz/rime_wanxiang/compare/v14.7.1...v14.7.2) (2026-02-16)


### 🐛 Bug 修复

* input长度为5最后一个字符是/开启临时大字集 ([948f15b](https://github.com/amzxyz/rime_wanxiang/commit/948f15bd1f5dce738a9be7d5f25446146e457b14))
* 辅助码处理的位置也要增加一个豁免不清空太极注释，这样开启辅助的时候也能干掉英文句子 ([ac7e81f](https://github.com/amzxyz/rime_wanxiang/commit/ac7e81ffcc1555e745519d306c1169ba8ab2a9c2))

## [14.7.1](https://github.com/amzxyz/rime_wanxiang/compare/v14.7.0...v14.7.1) (2026-02-16)


### 📚 词库更新

* dict update ([523391b](https://github.com/amzxyz/rime_wanxiang/commit/523391bbf45c23090c7121f13755302e94341624))
* 词库更新 ([71ada10](https://github.com/amzxyz/rime_wanxiang/commit/71ada10f6385c3e28a84d873fb1b0d18774b575e))
* 词库调整 ([85e3dab](https://github.com/amzxyz/rime_wanxiang/commit/85e3dab1243e90deb87b98d4bd49ac5dd0da79cd))
* 词库调整 ([30033ce](https://github.com/amzxyz/rime_wanxiang/commit/30033ce0b07073662cfde02ce4e40fdcebb6e6fb))
* 词库调整 ([0ff83ce](https://github.com/amzxyz/rime_wanxiang/commit/0ff83ce22b58fe0515001ef5c9813b1783661b10))


### 🐛 Bug 修复

* 优化字符集范围数据库 ([40d6729](https://github.com/amzxyz/rime_wanxiang/commit/40d67293653614b2cfbdf4a42278c9466dd79c91))
* 支持[#810](https://github.com/amzxyz/rime_wanxiang/issues/810)提到的无感造词可通过反查筛选来选字进而完成造词 ([af90f4f](https://github.com/amzxyz/rime_wanxiang/commit/af90f4f46c594223db32b0dd44379f04671a7183))


### 🏡 杂项

* fix doc ([43c3636](https://github.com/amzxyz/rime_wanxiang/commit/43c363628b3b684dff64858490fd8f9edf6aab74))

## [14.7.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.12...v14.7.0) (2026-02-12)


### ✨ 新特性

* **super_replace:** 新增自定义置顶编码转换逻辑，适用于九键拼音维护用字母，加载到数据库变成数字的场景，简化手动维护难度，更利于数据迁移 ([ad82f95](https://github.com/amzxyz/rime_wanxiang/commit/ad82f95ecff4f5fb6db0a55d37d960d026d46df6))


### 📚 词库更新

* 词库更新 ([417e5cb](https://github.com/amzxyz/rime_wanxiang/commit/417e5cb53ec3c45e5f0daad2078a5f118d4c1e92))
* 词库调整 ([eeeb5f7](https://github.com/amzxyz/rime_wanxiang/commit/eeeb5f71fa3661e0a6cb47a05a050340b77d5bea))


### 🐛 Bug 修复

* 拓宽模型生效范围 ([efaaf93](https://github.com/amzxyz/rime_wanxiang/commit/efaaf9343d4345842a46aa6adab6cd5932a7f126))

## [14.6.12](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.11...v14.6.12) (2026-02-11)


### 🐛 Bug 修复

* 反查模式不过滤 ([e92cb86](https://github.com/amzxyz/rime_wanxiang/commit/e92cb86563abc71fb279c6fc636bc4601343d270))

## [14.6.11](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.10...v14.6.11) (2026-02-11)


### 📚 词库更新

* update dicts ([e01c7e1](https://github.com/amzxyz/rime_wanxiang/commit/e01c7e1c23482326a37e654da6c8175e294d9141))
* 词库调整 ([f1cacfc](https://github.com/amzxyz/rime_wanxiang/commit/f1cacfcfa83592cc3b65b94379d9d64d0dca3297))


### 🐛 Bug 修复

* [Unicode模式]添加屏蔽代理区字符的逻辑以阻止输入法崩溃 ([1647bc1](https://github.com/amzxyz/rime_wanxiang/commit/1647bc17854980bcb82d9937f04b890c38e1c0aa))
* 反查模式也纳入命令模式 ([9cff3cb](https://github.com/amzxyz/rime_wanxiang/commit/9cff3cb99804b1a69ac36bd5f1d06e287cbab87b))
* 恢复按下左右移动编码字符为默认，先前librime将跳转音节设为了默认 ([69e84aa](https://github.com/amzxyz/rime_wanxiang/commit/69e84aa1d21fe3753adfbf31c6a5223fc6bc51cf))
* 文本格式化新增\A转义代表上午下午晚上等 ([56db8b1](https://github.com/amzxyz/rime_wanxiang/commit/56db8b1b92a92d3163d0dd6edbb141cfd1afeda8))
* 超集替换改为重新初始化不关闭数据库 ([543ff6b](https://github.com/amzxyz/rime_wanxiang/commit/543ff6bcdc0379c2a1b14c238e9bd25f71652b94))

## [14.6.10](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.9...v14.6.10) (2026-02-04)


### ✨ 新特性

* **lua:** 万能滤镜在原来简繁转换表情派生的情况下，另新增了简码模块，该模块同样可以基于配置进行模块化配置来取消和新增这样的模块，这个简码有三种模式，关闭、为空时填充、总是填充，这样的设计可以适用于任何拼音编码方案，默认的为空时填充巧妙的利用了候选为空或者英文时，我们更有意愿被简码填充，不会干扰已有的输入能力，对于体验是极大的提升，未来用户可以灵活的定义自己的数据库，实现自己想要的置顶数据简码，且数据是活的可受开关控制的，这是第一个版本，我们将在后续的数据维护中逐步完善体验。需要说明的是这个属于公共简码部分即他不包含辅助码，如果你定义了复杂的编码形态还是要基于根目录的txt来实现，但本次是对pro没简码，t9简码卡顿的一个战略性优化，使其拥有更好的体验 ([8bb1b17](https://github.com/amzxyz/rime_wanxiang/commit/8bb1b170a2ceccca07491aafc3ac7d78ebaf8c42))
* **seq:** 新增按下Ctrl的时候显示数据库中“被动过”的词条标记，你可以根据这个信息洞察做出决策 ([589f1ee](https://github.com/amzxyz/rime_wanxiang/commit/589f1ee4f5e9f2c2c49cf4e17aab81927b0036b1))
* **super_filter:** 新增英文智能空格，前所未有的体验 ([049b0ba](https://github.com/amzxyz/rime_wanxiang/commit/049b0ba8ae67e9608d423451eb7724de4c58b293))
* 全面移除OpenCC组件的引用，使用lua重构，现在将拥有更为灵活的转换策略，使用数据库常态化工作，自定义码表更简单，不用担心键值对的重复空格的敏感等问题 ([e41805e](https://github.com/amzxyz/rime_wanxiang/commit/e41805ea21e299df434c805d6b301491d1a25d67))
* 合并8个按键处理器lua为一个，KP小键盘、字母选词、符号快打、超强分词、重复限制、退格限制、声调回退、以词定字 ([6baaef0](https://github.com/amzxyz/rime_wanxiang/commit/6baaef085f4991a7971308f0c75f5c2edd11f4dc))
* 字符集过滤现已全面升级，具体阅读方案中配置段落的说明，现在可以兼容字符集过滤与简繁转换的冲突问题 ([581c594](https://github.com/amzxyz/rime_wanxiang/commit/581c5940e09682f41d2e8432f48fdf72d245b478))
* 新增alt+字母跳转对应编码后面，但asdt等字母有被rime屏蔽，其他快捷键有不同程度占用，先发布 ([555ece6](https://github.com/amzxyz/rime_wanxiang/commit/555ece61fcbb764e6f0eff27a0c044628124d740))
* 新增yaml正则转义lua正则模块，数字键处理逻辑将直接读取状态 ([0417d9d](https://github.com/amzxyz/rime_wanxiang/commit/0417d9dfdbcbfe92ddb1194fb7aa5aabfe731924))
* 新增仅英文模式下支持输入英文句子，三元开关组的快捷键也修改为常态化Shift+space不用非要在输入中切换 ([06b8620](https://github.com/amzxyz/rime_wanxiang/commit/06b86205dbc160fac8ee37ec2859f96e9cc0083b))
* 新增前两页可以被符号包裹 ([e939f81](https://github.com/amzxyz/rime_wanxiang/commit/e939f81a20302642f8f02e6ed8bb8f888702f157))
* 统计新增数据库储存方式，全新的格式化样式，多数据维度 ([5b8e378](https://github.com/amzxyz/rime_wanxiang/commit/5b8e37855d9890b57f4a3d4340523fa86914f685))
* 英文造词现在支持按源编码结构写入一份，全小写写入一份，我们很多时候有一些大小写约定结构的词汇 ([0dc4796](https://github.com/amzxyz/rime_wanxiang/commit/0dc479690a1e586e80a503aa33116c2afdf7f362))


### 📚 词库更新

* add dicts ([007a852](https://github.com/amzxyz/rime_wanxiang/commit/007a8525af03cfb90002a77ee7ef28bbe20fa221))
* **sym:** 符号表新增元素周期表、希腊粗体等多种字符表 ([c6f9986](https://github.com/amzxyz/rime_wanxiang/commit/c6f9986f1fb4721331b191db266f5d6d2ba29315))
* update dicts ([30a50d4](https://github.com/amzxyz/rime_wanxiang/commit/30a50d42ae3d6313b24bab6ba92980722856e550))
* update dicts ([3dc45a2](https://github.com/amzxyz/rime_wanxiang/commit/3dc45a27041fcc2b81aac7d7c016230f4fc710f1))
* 九键新增成语简码 ([ede14bb](https://github.com/amzxyz/rime_wanxiang/commit/ede14bb2f74edd59615e92503c5858d37df02491))
* 扩展成语简码 ([dc3855b](https://github.com/amzxyz/rime_wanxiang/commit/dc3855b37297686c15da1806947dbcc22d12cd29))
* 自然码辅助删除部分兼容 ([e5305cf](https://github.com/amzxyz/rime_wanxiang/commit/e5305cf7226a35c6414bd967603a12cf4d8ba066))
* 补充英文词库 ([6a8925c](https://github.com/amzxyz/rime_wanxiang/commit/6a8925cb22bc2ca3455a2ec889186a5bbdd0df22))
* 词库调整 ([314c5d6](https://github.com/amzxyz/rime_wanxiang/commit/314c5d6c13d1771f2ccc6e70e2efa0540a1df470))
* 词库调整 ([81f8a8a](https://github.com/amzxyz/rime_wanxiang/commit/81f8a8aa5e658292768877c5ce08fd49c72c4910))
* 词库调整 ([7be4781](https://github.com/amzxyz/rime_wanxiang/commit/7be47813512ae4994bd14623f5adf942d56c5de2))
* 词库调整 ([9632fb1](https://github.com/amzxyz/rime_wanxiang/commit/9632fb1e18315fc81d742a35978b3640ea5b05dd))
* 词库调整 ([937e7bb](https://github.com/amzxyz/rime_wanxiang/commit/937e7bbf617328c8916ca8cb585f9b6f6f957c4e))
* 词库调整 ([c200321](https://github.com/amzxyz/rime_wanxiang/commit/c200321cf4afc95d7f3ffe610e37b98a31d223bd))
* 词库调整 ([82dd994](https://github.com/amzxyz/rime_wanxiang/commit/82dd9947e3fe2761a8614eea9cc18eaf8240d80e))
* 词库调整 ([e4b2c19](https://github.com/amzxyz/rime_wanxiang/commit/e4b2c1953079c41b0ac74e3e131c57a47ab5dcc7))
* 词库调整 ([abe58a1](https://github.com/amzxyz/rime_wanxiang/commit/abe58a1d7cb25b779f89fef85fc1d180c1c34222))
* 词库调整 ([d484bb3](https://github.com/amzxyz/rime_wanxiang/commit/d484bb3fa946e5d8ba6fb863a2fba85cfde4d31e))
* 词库调整 ([36acd0a](https://github.com/amzxyz/rime_wanxiang/commit/36acd0a9cf077c4c1d8b5c4af3627db74244863d))
* 词库调整 ([0198fce](https://github.com/amzxyz/rime_wanxiang/commit/0198fcec278612b2f2bc21c11be50aa5d8a399b7))
* 词库调整 ([d8245d8](https://github.com/amzxyz/rime_wanxiang/commit/d8245d8e17b5f7a09675c24d86dfa7acb5694b78))
* 词库调整 ([ddbc746](https://github.com/amzxyz/rime_wanxiang/commit/ddbc74692140ebcefdc0df3b23960ccb99439f00))
* 词库调整 ([8fef555](https://github.com/amzxyz/rime_wanxiang/commit/8fef55521dbabb938b401b530e4f22a3cd6d5db1))
* 词库调整 ([1b14ee9](https://github.com/amzxyz/rime_wanxiang/commit/1b14ee9c81a5c4e0847d6b1882ffbfc4df78a93c))
* 词库调整 ([069d01d](https://github.com/amzxyz/rime_wanxiang/commit/069d01dbfd6cf60a14ab4bacb1c6f47394537fe1))
* 词库调整 ([7a03017](https://github.com/amzxyz/rime_wanxiang/commit/7a030177a72d61c6a65d669fd06267a780d2f920))
* 词库调整 ([5336095](https://github.com/amzxyz/rime_wanxiang/commit/53360958dbd084eb9e57b8dc0f9889477518631d))
* 词库调整 ([03b786c](https://github.com/amzxyz/rime_wanxiang/commit/03b786c65a666ac9bc7c94073153cdb29a87a9be))
* 词库调整 ([21a5cdc](https://github.com/amzxyz/rime_wanxiang/commit/21a5cdce38e9722e4399d92c755e80b8a1490745))
* 词库调整 ([d3b1240](https://github.com/amzxyz/rime_wanxiang/commit/d3b1240e0ab4d7233f67278da809c5f1089ea0fb))
* 词库调整 ([c17427f](https://github.com/amzxyz/rime_wanxiang/commit/c17427f0f15721ccd46a7d317a3678508aa52007))
* 词库调整 ([369812d](https://github.com/amzxyz/rime_wanxiang/commit/369812d689a82c575c76527fbc9a098dc479b6b7))
* 词库调整 ([c01656c](https://github.com/amzxyz/rime_wanxiang/commit/c01656c8bf2fb3aecf622ba606b049d7f7fc4bd4))
* 词库调整 ([49a06fb](https://github.com/amzxyz/rime_wanxiang/commit/49a06fb93cd2e6ead81e23fd25f87ee0f226a4c7))
* 词库调整 ([7ef7e71](https://github.com/amzxyz/rime_wanxiang/commit/7ef7e71020c1e8372d8632f8ec011788ee628048))
* 词库调整 ([da8e394](https://github.com/amzxyz/rime_wanxiang/commit/da8e39435495a755f95002eb62b09ee7a81809d1))
* 词库调整 ([60de548](https://github.com/amzxyz/rime_wanxiang/commit/60de548545547c289c50a3a3145c9d79b33a1af1))
* 词库调整 ([bc1f82a](https://github.com/amzxyz/rime_wanxiang/commit/bc1f82ac63a915390937df22cda1facaf2a23f5b))
* 词库调整 ([e3bc798](https://github.com/amzxyz/rime_wanxiang/commit/e3bc798d2129b5b380ee0b6a98fdbfa486747601))
* 词库调整 ([875e2f5](https://github.com/amzxyz/rime_wanxiang/commit/875e2f56315c3912f3ab2a61ecb79eef08260615))
* 词库调整 ([b9c37cb](https://github.com/amzxyz/rime_wanxiang/commit/b9c37cbd89211980314d1c39dde3518cae8987db))
* 词库调整 ([cbff4f6](https://github.com/amzxyz/rime_wanxiang/commit/cbff4f69e03fd78a4521ee44d0ae32c648a7b0ed))
* 词库调整 ([593fc04](https://github.com/amzxyz/rime_wanxiang/commit/593fc04dbdb331a645f12b681bc7f5f7b6536cf6))
* 词库调整 ([9362805](https://github.com/amzxyz/rime_wanxiang/commit/9362805672edcd91d07cae7293ee73840c208465))
* 词库调整 ([7677e88](https://github.com/amzxyz/rime_wanxiang/commit/7677e88c61bacec6d42acf0877a844be4762ce5d))
* 词库调整 ([3749dde](https://github.com/amzxyz/rime_wanxiang/commit/3749dded72dc82f0456a117d1859b05754fc11d6))
* 词库调整 ([529a944](https://github.com/amzxyz/rime_wanxiang/commit/529a944eba79fdcc5cddbcf48fc5a5707cd097b1))
* 词库调整 ([f6b0a8b](https://github.com/amzxyz/rime_wanxiang/commit/f6b0a8b0a25d8563856ab8261f979721352e8273))
* 词库调整 ([055ae13](https://github.com/amzxyz/rime_wanxiang/commit/055ae13ffcd6203a112733922f3c1d4914e20c7d))
* 词库调整 ([9e2fe30](https://github.com/amzxyz/rime_wanxiang/commit/9e2fe304603038f172eaaf28950b1ec4102f1fce))
* 词库调整 ([126009e](https://github.com/amzxyz/rime_wanxiang/commit/126009e07b4b74f13954412082b2cfa1d60d6ae0))
* 词库调整 ([49ee4fe](https://github.com/amzxyz/rime_wanxiang/commit/49ee4fe747640aae873b7c8ba17603054820ea04))
* 词库调整 ([41834a1](https://github.com/amzxyz/rime_wanxiang/commit/41834a100caa58f9a1a67788ee228fbf87f64414))
* 词库调整 ([079a936](https://github.com/amzxyz/rime_wanxiang/commit/079a936a94382fa1568cc13b2f3445b6a6abfbe0))
* 词库调整 ([fdcf1e9](https://github.com/amzxyz/rime_wanxiang/commit/fdcf1e90f83bb171fed01923dc96a4649de9e171))
* 词库调整 ([5133ea0](https://github.com/amzxyz/rime_wanxiang/commit/5133ea092b855b52f90081aecb8197346adb759c))
* 词库调整 ([7381d8f](https://github.com/amzxyz/rime_wanxiang/commit/7381d8f214d22548e259593ec292dfaa6cbf04ad))
* 词库调整 ([f7c9d7c](https://github.com/amzxyz/rime_wanxiang/commit/f7c9d7c20722955bfa2f3e564e61d7d6c3f555be))
* 词库调整 ([bdee159](https://github.com/amzxyz/rime_wanxiang/commit/bdee15954628f8b5c00fdc70c1f4dd5581b9ae3e))
* 词库调整 ([83afaef](https://github.com/amzxyz/rime_wanxiang/commit/83afaef06fc99b968f07ed37355be70ff4fe8fe0))
* 词库调整 ([5a38390](https://github.com/amzxyz/rime_wanxiang/commit/5a3839013c9ee106c565e43a46504f4ef98d02a2))
* 词库调整 ([41f8ae6](https://github.com/amzxyz/rime_wanxiang/commit/41f8ae60a46e8c24bc724dae58213bfa49b716c9))
* 词库调整 ([398723e](https://github.com/amzxyz/rime_wanxiang/commit/398723e5485c75fb68316e9242984a431adfe320))
* 词库调整 ([87c1d41](https://github.com/amzxyz/rime_wanxiang/commit/87c1d4147f3199916ca5abc7a15369b02b4feb7d))
* 词库调整 ([5f02215](https://github.com/amzxyz/rime_wanxiang/commit/5f022150861b142a723c47dca2871e4541f579da))
* 词库调整 ([33b2d10](https://github.com/amzxyz/rime_wanxiang/commit/33b2d10e2b437653132311617ee758ca62be247d))
* 词库调整 ([526f967](https://github.com/amzxyz/rime_wanxiang/commit/526f96713d6e85429b83248d75251439a996a42a))
* 词库调整 ([eb952a4](https://github.com/amzxyz/rime_wanxiang/commit/eb952a4cd0e99e028cb6e7de885aab57c85a9d3f))
* 词库调整 ([3947589](https://github.com/amzxyz/rime_wanxiang/commit/3947589ba1e231ec7c2607fc0324c436eb6844c1))
* 词库调整 ([2de76de](https://github.com/amzxyz/rime_wanxiang/commit/2de76de2bbabe7da0ecf45326e5486b515c9a497))
* 词库调整 ([ec7ef6f](https://github.com/amzxyz/rime_wanxiang/commit/ec7ef6fc7bc193a5f92a9d5a0e01ba1c534b920c))
* 词库调整 ([e63b000](https://github.com/amzxyz/rime_wanxiang/commit/e63b00023b125da9a3f28955fc0e6abd3e3da745))
* 词库调整 ([3ef6afa](https://github.com/amzxyz/rime_wanxiang/commit/3ef6afacae8f1cd586d6f251896456ebcf803e1a))
* 词库调整 ([f7f4f36](https://github.com/amzxyz/rime_wanxiang/commit/f7f4f36cded1185cbeb619e85f45de0ce9879ef9))
* 词库调整 ([c1b162e](https://github.com/amzxyz/rime_wanxiang/commit/c1b162e5125ff6054f3fd0ae87bddf986104f89f))
* 词库调整 ([7d24ea6](https://github.com/amzxyz/rime_wanxiang/commit/7d24ea6fb55eabbd8755f13425e096eb2ed2dfd0))
* 词库调整 ([faf555f](https://github.com/amzxyz/rime_wanxiang/commit/faf555f45af60178cb17c0187aea57f16556e861))
* 词库调整 ([30cdfde](https://github.com/amzxyz/rime_wanxiang/commit/30cdfdecba8c7c99d790d0b9f03bf9d11f5522f2))
* 词库调整 ([35a641b](https://github.com/amzxyz/rime_wanxiang/commit/35a641b855089e9bcf981c10061d613925ba929e))
* 词库调整 ([1e5e0fc](https://github.com/amzxyz/rime_wanxiang/commit/1e5e0fcf6e8b9ae2aad145e7accc135a0aa60aa3))
* 词库调整 ([1f0f255](https://github.com/amzxyz/rime_wanxiang/commit/1f0f255d021155cddfdf830e37f5b908907bd7fe))
* 词库调整 ([1ff9183](https://github.com/amzxyz/rime_wanxiang/commit/1ff9183ad1c131d232337c0ec7245034aa866e11))
* 词库调整 ([ad076bd](https://github.com/amzxyz/rime_wanxiang/commit/ad076bd3d083cefbbc8b2ff164cb18bab2be26c1))
* 词库调整 ([8e1beaf](https://github.com/amzxyz/rime_wanxiang/commit/8e1beafdc7c8928d3cbc82fd5d0b6ce9fea07e53))
* 词库调整 ([4c548d8](https://github.com/amzxyz/rime_wanxiang/commit/4c548d8a36663a277f6bcff53d36491e612a8b74))
* 词库调整 ([91f84d1](https://github.com/amzxyz/rime_wanxiang/commit/91f84d15ce45b630428a204a8a0f0dd0d68caac0))
* 词库调整 ([ee2ae6c](https://github.com/amzxyz/rime_wanxiang/commit/ee2ae6cb1ebbee95d14cb95acb449c07f656048c))
* 词库调整 ([7477fea](https://github.com/amzxyz/rime_wanxiang/commit/7477fea095505f92336a2bd2b0cb80c298cbd79c))
* 词库调整 ([83483b0](https://github.com/amzxyz/rime_wanxiang/commit/83483b04714986a8c08669848391de628553db6a))
* 词库调整 ([a24c9d1](https://github.com/amzxyz/rime_wanxiang/commit/a24c9d12b330299014d38643e21365b5bf5fd640))
* 调整他她它 ([8337bdb](https://github.com/amzxyz/rime_wanxiang/commit/8337bdb8588ee3301f4277df42df0dcc6d82520d))


### 🐛 Bug 修复

* [符号表]重新核对元素周期表数据并更正 ([1dc6ef3](https://github.com/amzxyz/rime_wanxiang/commit/1dc6ef362d43d634b3fd61d7076c783e2c6a77e6))
* /命令模式不派生候选 ([0a08cbe](https://github.com/amzxyz/rime_wanxiang/commit/0a08cbed18913a22a2e8660d4b077388472e71d8))
* default不跟随东风破脚本 ([44fe305](https://github.com/amzxyz/rime_wanxiang/commit/44fe305bc56a458c43b82d64f54caeaeff3a5ad9))
* lookup反查策略变更，更简约，同时修复笔画变更编码导致的无法查询 ([a274584](https://github.com/amzxyz/rime_wanxiang/commit/a274584f0e77be5785a43c56fdc11f852f21a090))
* **lua:** 修复小键盘数字在commit_text时导致PSReadLine的bug ([2088f70](https://github.com/amzxyz/rime_wanxiang/commit/2088f701e9e5e6efd973a94881ecebe892cc41be))
* **lua:** 快符匹配时不转换大小写 ([1a78e90](https://github.com/amzxyz/rime_wanxiang/commit/1a78e90f83d9f61313fef6b21e7ac92f43a4652c))
* ng输入“嗯”时以缩写形式提供，这样可与ng下面派生简拼词汇一起出现 ([d660eb1](https://github.com/amzxyz/rime_wanxiang/commit/d660eb161f6bdf16b4aad848df3c919833bb537d))
* **replacer:** 发现新问题，通过权重构建扎实地根目录指定优先、程序补充简码滞后等恰当的逻辑 ([d378948](https://github.com/amzxyz/rime_wanxiang/commit/d378948cb3fd287cf353474cd37dcfc279992bfa))
* **replacer:** 置顶词出现在根目录user_table置顶词后面 ([7dc7b95](https://github.com/amzxyz/rime_wanxiang/commit/7dc7b951a7ee47ccc7cc4b8df2f8c53773a42bcf))
* **shijian.lua:** 新增/rc日期差模式，可通过/rc\d+[-=+op]来生成当前时间从前与未来的日期，=+p都代表未来，-o都代表从前。同时还支持/utc热门世界时钟查询 ([a1e849c](https://github.com/amzxyz/rime_wanxiang/commit/a1e849caea31c93ef286e42dcc093f812caceeec))
* **super_lookup:** 反查现已支持声调，与字母任意位置输入即可，词组根据输入的个数来从第一个汉字依次来匹配，输入位置也是随意的 ([5a47c9d](https://github.com/amzxyz/rime_wanxiang/commit/5a47c9d492ead59c577ff8bb9a1aa78131dcc32b))
* **super_lookup:** 采用全新的词组匹配算法，支持有序模糊，词组匹配不再需要复杂的设计对应到某个字就像单字那样按序输入即可，pro支持词库辅助码数据，两类数据可方案中配置启用类型，支持两类顺序优先进而候选排序优先 ([8e2f103](https://github.com/amzxyz/rime_wanxiang/commit/8e2f103b1ba34e6376fd05bdfa3b5d59fab7599c))
* **tips:** 翻页后不再匹配输入编码，释放翻页返回按键 ([6626142](https://github.com/amzxyz/rime_wanxiang/commit/662614238d4cabb4f2ffec79395dbb73e53406dc))
* 九宫格注释掉简拼 ([1ee350d](https://github.com/amzxyz/rime_wanxiang/commit/1ee350d9a7e8e2ff81ad5625a83c5fe31f8ae943))
* 人名物种不打包到zip中 ([ff710b3](https://github.com/amzxyz/rime_wanxiang/commit/ff710b3186d311f61840ece12c2b377ab4fc9f2b))
* 优化在空候选的时候中文候选的派生逻辑，如果上一个字是汉字，且三码为空码的时候自动派生上一个字加~注释如：ckl可以派生 操~ 而ctrl+g开启大字集就会恢复原本的输出 䎭，这在视觉上弥补了空码带来的顿挫感，以及派生出英文的不合理性 ([b7e4f6a](https://github.com/amzxyz/rime_wanxiang/commit/b7e4f6a878b308ee37e15c7ecd2d9aed1457c05e))
* 优化模糊音写法 ([0892edd](https://github.com/amzxyz/rime_wanxiang/commit/0892edda859192b350f87e6ea471ee48cdfcb338))
* 修复N模式正则错写 ([afca1e2](https://github.com/amzxyz/rime_wanxiang/commit/afca1e28baf675a85ab6a5bd771d9f4806f272eb))
* 修复一个时间lua中上午下午变量的逻辑问题 ([8951eca](https://github.com/amzxyz/rime_wanxiang/commit/8951eca4d260a0fe5565792b50d59442b0b04051))
* 修复了换行等没有被纳入转义保护的问题 ([a1cfa0c](https://github.com/amzxyz/rime_wanxiang/commit/a1cfa0cfa229eb977e40114e2f863a6895d8f89d))
* 修复了自定义短语与出简逻辑的冲突问题 ([eff333f](https://github.com/amzxyz/rime_wanxiang/commit/eff333f8bec8e795621459c653c8614fa089a5c9))
* 修复句中反查对双拼编码的提取策略 ([fcf4bef](https://github.com/amzxyz/rime_wanxiang/commit/fcf4bef63b317395a60ccf9fdcd3d2dbf3ea2bf8))
* 修复句中反查时英文派生策略导致的提交内容异常包含了英文的问题，修复英文造词问题 ([1696a63](https://github.com/amzxyz/rime_wanxiang/commit/1696a6375f3ebd177babae1aef4c3e6cf205444c))
* 修复当根目录的置顶包含英文的时候导致replacer简码也会出现的问题 ([530d82c](https://github.com/amzxyz/rime_wanxiang/commit/530d82cd68d0c57cb7ac13b794da79aa4da6f00a))
* 修复拼音加加基础版转写 ([adfaccf](https://github.com/amzxyz/rime_wanxiang/commit/adfaccff743ce429b496adcdd4efac57d6c5f6c1))
* 修复智能ABC+汉心转写中的bug ([0a41bc9](https://github.com/amzxyz/rime_wanxiang/commit/0a41bc92f44e15c2f056915502a1492c5378e6c8))
* 修复替换处理器直接写true被认为是字符串的问题 ([5968d27](https://github.com/amzxyz/rime_wanxiang/commit/5968d27a2c322657ddd670cf36cbe91c6ec15b2b))
* 修复空码回溯功能 ([d971547](https://github.com/amzxyz/rime_wanxiang/commit/d971547cf9339f29d50d977c69ec9d74797cab75))
* 修复统计数据格式化错误 ([e4d4000](https://github.com/amzxyz/rime_wanxiang/commit/e4d40007abaa29f3bce42de27d9d21bb848f61e4))
* 修复英文派生单字母干扰置顶词的问题，同时提升性能 ([1992b86](https://github.com/amzxyz/rime_wanxiang/commit/1992b865258740f520c946ba49ed425544555b90))
* 修改基础版紫光转写 ([ab6d2c9](https://github.com/amzxyz/rime_wanxiang/commit/ab6d2c9a1183e6edc96ce7639e63da56b67580a4))
* 修改英文转写 ([f51f76c](https://github.com/amzxyz/rime_wanxiang/commit/f51f76cfd33b94a157365283440dc223e538ab96))
* 修改说明 ([042a080](https://github.com/amzxyz/rime_wanxiang/commit/042a0806ca04d3c5f91efb56eb463ff1605235db))
* 修补若干bug ([bbfc9b2](https://github.com/amzxyz/rime_wanxiang/commit/bbfc9b2272ebf2da9cfd09d45c1c24182b1122de))
* 候选格式化新增更多时间相关占位符，任何能产生候选的表都可以写入占位符，试着输入：此时此刻 ([c63a855](https://github.com/amzxyz/rime_wanxiang/commit/c63a8554a17aac6c7f0f9f33ba0afe859ab3ab75))
* 全拼状态下将bun拼音下置顶一个“不能，避免生僻字兺干扰喜欢派生输入的习惯” ([68acdb8](https://github.com/amzxyz/rime_wanxiang/commit/68acdb8614b229b0cdc6b62c86505fcf3823841c))
* 再次调整英文处理器 ([73484df](https://github.com/amzxyz/rime_wanxiang/commit/73484df7db3630364c9539ebfe89734e3011bc5f))
* 删除多余传参 ([893bc61](https://github.com/amzxyz/rime_wanxiang/commit/893bc618517c3a4f20a4b2c1e6445017bdb0e24a))
* 删除无效代码 ([3dd2ac1](https://github.com/amzxyz/rime_wanxiang/commit/3dd2ac1984c68859d7cb33207d4d88b51aace846))
* 反查模式不派生 ([7180974](https://github.com/amzxyz/rime_wanxiang/commit/71809740c38391ef6856d7d8a893c99f06d916b2))
* 变更Lua引入顺序解决OpenCC繁体字被字符集过滤的问题 ([865f464](https://github.com/amzxyz/rime_wanxiang/commit/865f464f987fcf1279acd76def7f63df785726a4))
* 变更模型参数 ([780b2b1](https://github.com/amzxyz/rime_wanxiang/commit/780b2b198d20a888eef563bb55006aafa9fe5ff1))
* 句中反查修复了两个bug ([7cf7997](https://github.com/amzxyz/rime_wanxiang/commit/7cf7997a411fe51842e8a95f57990e4e67d398e1))
* 同文皮肤加回来14、18键，custom也加了可引用的转写，这些内容将打包到app ([2d64e28](https://github.com/amzxyz/rime_wanxiang/commit/2d64e28d43d9d67ebb0099f63f2f75869c01542d))
* 增加仓、元数统计中的命名 ([db4cd91](https://github.com/amzxyz/rime_wanxiang/commit/db4cd912ce130f71a5caabd4c00ec086165af8dd))
* 增加对号叉号/ch,/dh序列 ([8f8e986](https://github.com/amzxyz/rime_wanxiang/commit/8f8e986347046cddb36104fe7ca57021fa13b93b))
* 增加校验规避在[#579](https://github.com/amzxyz/rime_wanxiang/issues/579)提到的Lua更在内容不变的情况下更新时间戳导致同步软件认为变更，进而频繁同步的问题 ([4998aa9](https://github.com/amzxyz/rime_wanxiang/commit/4998aa96bb4153b0de834e0d8293ae19a185b03a))
* 完善全拼反查辅筛模式下，两分首字母(声母)的提取策略 ([1bf8336](https://github.com/amzxyz/rime_wanxiang/commit/1bf833660c78ee9e7b239860c6e827a474cab71d))
* 小键盘Lua优化 ([88ab10c](https://github.com/amzxyz/rime_wanxiang/commit/88ab10c6f0cac9abe1911baea10af348772cf03d))
* 当'作为分隔符又与it's重合，不在插入空格导致其分开 ([94639c1](https://github.com/amzxyz/rime_wanxiang/commit/94639c1e5eded765fb545302cc738fabf1e0f136))
* 当按下修饰键的时候数字处理器交还给系统 ([470509f](https://github.com/amzxyz/rime_wanxiang/commit/470509ff92800aba00db7b48728a33c401226ac2))
* 很多被大厂惯坏的用户认为设置成9个能让自己不用翻页，我再多宠爱一下，现在你可以按下0上屏第10个候选 ([8d4e432](https://github.com/amzxyz/rime_wanxiang/commit/8d4e432d47b6084d1b711f8c551afdae603562a8))
* 微调统计格式结构 ([b35e28c](https://github.com/amzxyz/rime_wanxiang/commit/b35e28cbe19f21ae4e7ec6f3f40160aa1af7f89a))
* 微调英文自动加空格策略 ([e3db46b](https://github.com/amzxyz/rime_wanxiang/commit/e3db46beb2136e8c00f0c9cdad6de7f574b6cc97))
* 恢复缩进 ([b9f071d](https://github.com/amzxyz/rime_wanxiang/commit/b9f071d62edfab1613146a299d31707545b8fd34))
* 成语简码默认设为0即不前置，有需要的朋友请自行重新patch前置位置，在自定义路上又前进一步 ([0b0adc7](https://github.com/amzxyz/rime_wanxiang/commit/0b0adc7d3e3e86d53c3e0ce75417d6d7fbf5bf4e))
* 打包时间改成中国时区 ([81fcc40](https://github.com/amzxyz/rime_wanxiang/commit/81fcc405e3bb448bdf455302fe70c32364cbab08))
* 拍扁共键运算 ([2d9a6b8](https://github.com/amzxyz/rime_wanxiang/commit/2d9a6b8f56dd43477beb9236c54094a175f0a30d))
* 指令设置英文custom ([b39e4f3](https://github.com/amzxyz/rime_wanxiang/commit/b39e4f363e243f0a7166fbcb8fa8da35458b79c0))
* 挽救一次失誤 ([ccc9fae](https://github.com/amzxyz/rime_wanxiang/commit/ccc9faed5e335cc444ae7e8f7db4b68d6ba708da))
* 新增自动化apk打包 ([f36be04](https://github.com/amzxyz/rime_wanxiang/commit/f36be0481fc22682d5ba7d71d7bcbeb1ebb3eaa4))
* 新增自动化apk打包 ([beb088d](https://github.com/amzxyz/rime_wanxiang/commit/beb088dafefa2b079e66e8b87f3b46a0e934a231))
* 新增自动化apk打包 ([fa455a6](https://github.com/amzxyz/rime_wanxiang/commit/fa455a65a1a70e1445705edf7462831f46445b5a))
* 更新custom示例 ([9ea3462](https://github.com/amzxyz/rime_wanxiang/commit/9ea34625409b4c5ac597b8f36955b7b45b206b2b))
* 更新tips ([1027db6](https://github.com/amzxyz/rime_wanxiang/commit/1027db652e35e678312e382943778f5faa33a6f4))
* 更新符号表 ([22527f4](https://github.com/amzxyz/rime_wanxiang/commit/22527f46f4bb3af960e3ebd92d123695fa92e1c0))
* 更新首右拆分 ([135da73](https://github.com/amzxyz/rime_wanxiang/commit/135da737a3e457b5e08279fca00a5e2308b5d2d8))
* 更新首右辅助码 ([57b940c](https://github.com/amzxyz/rime_wanxiang/commit/57b940cc0e4c01458596854afd62ba43f68601bf))
* 混合编码为固定码表 ([d0a1030](https://github.com/amzxyz/rime_wanxiang/commit/d0a10307f94685323796915fea19c41be1ebd2a4))
* 混合编码候选下-空出简状态下，也能出现简码 ([48798e2](https://github.com/amzxyz/rime_wanxiang/commit/48798e2b86588b3f3af89b17f8438e93c15def8d))
* 由于性能问题，由滤镜构建的中英文切换现在去掉，改为通过切换方案来实现中英文切换，快捷键还是shift+space,但不再有仅中文的模式，有需求的用户可以通过patch去掉英文表的挂载 ([789e377](https://github.com/amzxyz/rime_wanxiang/commit/789e3776de2a5487751678a78214ca92b97010d2))
* 直接辅助支持大写辅助 ([1562635](https://github.com/amzxyz/rime_wanxiang/commit/15626355c21a5614c0ddc2124e6207a42c00b577))
* 移动设备小键盘逻辑同主键盘 ([e17ead7](https://github.com/amzxyz/rime_wanxiang/commit/e17ead7a2ee7495983e3b0a60df83f0cd0af54cc))
* 移除alt跳转存在多平台不一致的多种问题，移除龙三 ([03bac03](https://github.com/amzxyz/rime_wanxiang/commit/03bac03c16c30e0b7264f740d25acddca8c8e4b7))
* 移除声调回退中多余的字符 ([b90dabd](https://github.com/amzxyz/rime_wanxiang/commit/b90dabd84774c63a6559c52864a06181c2f0ea5b))
* 移除多余声明 ([0673f3f](https://github.com/amzxyz/rime_wanxiang/commit/0673f3fab2c82e4c81c0062822ffe814315d8ee1))
* 移除标志符号注释提示 ([79f5778](https://github.com/amzxyz/rime_wanxiang/commit/79f5778316763ca0197bb91c58af875e66e74eba))
* 简化配置层级 ([4c80136](https://github.com/amzxyz/rime_wanxiang/commit/4c80136e575bd654ec80ea728d731ef57d88f2a3))
* 简单调整oday格式 ([a6d2b41](https://github.com/amzxyz/rime_wanxiang/commit/a6d2b415f67b48c09bae075255d54684d00aa694))
* 简纯主题数字行高度对齐每夜版本 ([5788514](https://github.com/amzxyz/rime_wanxiang/commit/578851440282d4cd572bb247317f49e38060f7a7))
* 紧急调整，正则依赖更新导致全角字符不能按.匹配 ([8506cba](https://github.com/amzxyz/rime_wanxiang/commit/8506cba815a6c384874444b9c762ba4fc7bde2ce))
* 自动化测试 ([0c8a5e1](https://github.com/amzxyz/rime_wanxiang/commit/0c8a5e1b52898fe7c00bd1b7eeeffe9a8da97b05))
* 自动化测试 ([be384f1](https://github.com/amzxyz/rime_wanxiang/commit/be384f16f2cdf264c3c3db8077c8e6933e4b469c))
* 自动造词的非确定性优化 ([a42fa3d](https://github.com/amzxyz/rime_wanxiang/commit/a42fa3dadad1dbd5a4597190dfd8ab25b6720c95))
* 英文lua派生单字母按照输入什么什么优先，且不干扰置顶的单词，置顶优先 ([7cb2c03](https://github.com/amzxyz/rime_wanxiang/commit/7cb2c03c2784366defd3c98438ba86517af63365))
* 英文后符号,.!?后面输入也能自动加空格 ([3765afb](https://github.com/amzxyz/rime_wanxiang/commit/3765afb7c84d3b73643d077de11f6f76282100d5))
* 英文自动空格支持延时销毁加空格的状态 ([4a584ca](https://github.com/amzxyz/rime_wanxiang/commit/4a584ca6eec55075ab8353be6ab74f29dd3d3119))
* 英文造词或者叫首选强制英文统一为\\双击 ([2d39c8f](https://github.com/amzxyz/rime_wanxiang/commit/2d39c8fc737a9f0704e34a22b4e3432975fccf25))
* 补齐九键遗漏的开关 ([e52a7a3](https://github.com/amzxyz/rime_wanxiang/commit/e52a7a359f4a7bb0e7ed385d65ff800032841f29))
* 补齐忘记修改的部分 ([847a1aa](https://github.com/amzxyz/rime_wanxiang/commit/847a1aa543c80775aebbd686badd0417bdf5cb23))
* 补齐缺失正则 ([2f9e0bf](https://github.com/amzxyz/rime_wanxiang/commit/2f9e0bfc20f9fe45fb8bf2557926138e7df9777a))
* 解决候选格式化换行与月冲突的问题，并新增星期的占位符 ([344f3b4](https://github.com/amzxyz/rime_wanxiang/commit/344f3b452b9a85611a1bff808c77d2b720c4adbb))
* 词库调整 ([b0d320a](https://github.com/amzxyz/rime_wanxiang/commit/b0d320a8d6493bac42614cb8638718f5c90e2311))
* 调整反查接入方式 ([c6cc66b](https://github.com/amzxyz/rime_wanxiang/commit/c6cc66b6c0deaad0decb2fb8fc512e6ed7a661d9))
* 调整模型参数 ([a0bf298](https://github.com/amzxyz/rime_wanxiang/commit/a0bf298e3c9b2a9014eb019508b404cd40513549))
* 调整自动化策略 ([cdcd26e](https://github.com/amzxyz/rime_wanxiang/commit/cdcd26e1f21e639e4f8d0219f03d3cf2a1f9f128))
* 调整英文方案 ([a3a3a69](https://github.com/amzxyz/rime_wanxiang/commit/a3a3a69d8664f0eb951331270dd60c49475f0e8f))
* 调整路径获取 ([9ffd6c4](https://github.com/amzxyz/rime_wanxiang/commit/9ffd6c414808baf79c85c6b82ba35c427000b3c2))
* 超级注释放开末尾~，他代表单词未完全输入完成的尾部视觉提示 ([092104f](https://github.com/amzxyz/rime_wanxiang/commit/092104f1f97e9894bc2f038e52676af26aef67dd))
* 超级注释添加CJK区域显示 ([be8a076](https://github.com/amzxyz/rime_wanxiang/commit/be8a076bb12b497dff46f508279d9ac20baade63))
* 输入中持续保持英文加空格的记录状态，哪怕你输入的慢点 ([873fc34](https://github.com/amzxyz/rime_wanxiang/commit/873fc3491cf35198df4b8f08dfb8c8075c8e19ae))
* 适配元书的九宫格处理器 ([45124a2](https://github.com/amzxyz/rime_wanxiang/commit/45124a26f8d36dd5a7a8dae61541ad480f75f57b))
* 重新排序英文 ([b9dd08d](https://github.com/amzxyz/rime_wanxiang/commit/b9dd08d2220964b4e1aad509cf8d30752febd537))
* 重新排序英文 ([a8b3f67](https://github.com/amzxyz/rime_wanxiang/commit/a8b3f6775c5bf3eddade636ccadcd810e6ef6b8b))
* 间接辅助模式增加直接大写 ([4c3db21](https://github.com/amzxyz/rime_wanxiang/commit/4c3db21cb87bfb494eed7bfc43c98ff91b63d06b))
* 集中修复三个lua bug，为替换器增加FMM分词算法补齐句子转换功能 ([e3bdffa](https://github.com/amzxyz/rime_wanxiang/commit/e3bdffad2919515a74d7dd7fe7880ad93e0e9f5b))
* 首选格式化支持连续字符的简写 ([8071a14](https://github.com/amzxyz/rime_wanxiang/commit/8071a14e22b392102852a381ec52b53b3b6330cc))
* 首选英文不回退声调 ([e49b3e1](https://github.com/amzxyz/rime_wanxiang/commit/e49b3e1558c8805f71c37babeb8177f58d8149d2))


### 💅 重构

* **english:** 全新的英文方案与配套整句体验 ([aec548e](https://github.com/amzxyz/rime_wanxiang/commit/aec548ed8a7ee6d27637a7ce2833b04ffcb65068))


### 📖 文档

* AUR 包将删除 ([f0b57ff](https://github.com/amzxyz/rime_wanxiang/commit/f0b57ffe85e23bb588558f817d746e132b900163))


### 🏡 杂项

* release 13.9.1 ([aa133e2](https://github.com/amzxyz/rime_wanxiang/commit/aa133e21f7e9334446aff11b5869661cc0c92336))
* release 13.9.1 ([c521b1d](https://github.com/amzxyz/rime_wanxiang/commit/c521b1d678adfe610c7babe66e94e29d8097b37d))
* release 13.9.1 ([c521b1d](https://github.com/amzxyz/rime_wanxiang/commit/c521b1d678adfe610c7babe66e94e29d8097b37d))
* release 14.0.0 ([10f0468](https://github.com/amzxyz/rime_wanxiang/commit/10f0468af6f5ec8b43529b4b828089a345d9a90e))
* release 14.4.3 ([78b3e87](https://github.com/amzxyz/rime_wanxiang/commit/78b3e878bff2b323903422efb87a0b527368b714))
* release 14.6.10 ([29db716](https://github.com/amzxyz/rime_wanxiang/commit/29db7165d652ccf48816c6a3886294fecc4767bc))
* release 14.6.9 ([cabf3dc](https://github.com/amzxyz/rime_wanxiang/commit/cabf3dc0cc63754164fff0453454ae5923e7489b))
* **wanxiang:** release 13.10.0 ([31c783d](https://github.com/amzxyz/rime_wanxiang/commit/31c783d1819b15cecfacc7976a66066375a9b1ce))
* **wanxiang:** release 13.11.0 ([a739fd7](https://github.com/amzxyz/rime_wanxiang/commit/a739fd7473cf776c6a88f6667809033b0298b477))
* **wanxiang:** release 13.11.1 ([7036eac](https://github.com/amzxyz/rime_wanxiang/commit/7036eacd0ad02b1373fd8093b6476278e159883c))
* **wanxiang:** release 13.12.0 ([f6e7dbb](https://github.com/amzxyz/rime_wanxiang/commit/f6e7dbbc4b5f6ff932d73bd705e1675be09b1fa5))
* **wanxiang:** release 13.12.1 ([6e3c1d9](https://github.com/amzxyz/rime_wanxiang/commit/6e3c1d97282956927ee646fdba717cd5957acaba))
* **wanxiang:** release 13.6.4 ([f251388](https://github.com/amzxyz/rime_wanxiang/commit/f251388a515f0e8eff437d7b482fa9aa11eda766))
* **wanxiang:** release 13.6.5 ([dfebe18](https://github.com/amzxyz/rime_wanxiang/commit/dfebe18ab80c06254c6f3d5cb0cd54d6abec7b4e))
* **wanxiang:** release 13.7.0 ([6f5cb0a](https://github.com/amzxyz/rime_wanxiang/commit/6f5cb0a1c687d8c43a045da4538a341e141f938c))
* **wanxiang:** release 13.7.1 ([38752b6](https://github.com/amzxyz/rime_wanxiang/commit/38752b639bdf70708176c47f7eaef783a45db849))
* **wanxiang:** release 13.7.2 ([74e2532](https://github.com/amzxyz/rime_wanxiang/commit/74e253253baea891e671a01f588892945f2ea509))
* **wanxiang:** release 13.8.0 ([325ecd5](https://github.com/amzxyz/rime_wanxiang/commit/325ecd5515bd38e37bff769d94c0052d9c8347d7))
* **wanxiang:** release 13.8.1 ([0491139](https://github.com/amzxyz/rime_wanxiang/commit/04911395cf62821553a1023c766332d156926595))
* **wanxiang:** release 13.8.2 ([7491f70](https://github.com/amzxyz/rime_wanxiang/commit/7491f70668254f8c83655103c478f75fa2aecf57))
* **wanxiang:** release 13.8.3 ([8df0c8e](https://github.com/amzxyz/rime_wanxiang/commit/8df0c8ea99381ad9adad6953f46c4b64bc3d4c1e))
* **wanxiang:** release 13.8.4 ([f2d0927](https://github.com/amzxyz/rime_wanxiang/commit/f2d0927b3b78f137833e87774479d1bf7d98f0bb))
* **wanxiang:** release 13.8.5 ([e271570](https://github.com/amzxyz/rime_wanxiang/commit/e2715709f836423374d92d79f23060d67665d417))
* **wanxiang:** release 13.8.6 ([dd95631](https://github.com/amzxyz/rime_wanxiang/commit/dd9563130eec9d738ac98d3b424e348f25980e0c))
* **wanxiang:** release 13.8.7 ([b8833fa](https://github.com/amzxyz/rime_wanxiang/commit/b8833fa108ba3547f7ef2edf495c2e2eedfa6a49))
* **wanxiang:** release 13.8.8 ([b868d03](https://github.com/amzxyz/rime_wanxiang/commit/b868d032d8799650e08616d1d7b19770f4ff7386))
* **wanxiang:** release 13.9.1 ([751890a](https://github.com/amzxyz/rime_wanxiang/commit/751890a862d190138aa397cce34b07685f194bd4))
* **wanxiang:** release 13.9.2 ([6b7b616](https://github.com/amzxyz/rime_wanxiang/commit/6b7b6161ccb198f6d9d43e8c5a525b8d907815e2))
* **wanxiang:** release 13.9.3 ([ada6de0](https://github.com/amzxyz/rime_wanxiang/commit/ada6de0e1909b598062532dd1f4b1fbb4a22c9e3))
* **wanxiang:** release 13.9.4 ([145bfdd](https://github.com/amzxyz/rime_wanxiang/commit/145bfdd971509ab80d0ade7934447ce95bc17120))
* **wanxiang:** release 13.9.5 ([f2af8f5](https://github.com/amzxyz/rime_wanxiang/commit/f2af8f5e1625612674e2710a4d7dad51ef34b87b))
* **wanxiang:** release 14.0.0 ([2857ba2](https://github.com/amzxyz/rime_wanxiang/commit/2857ba2dc747da6666dd7c9683eb76f6938c297e))
* **wanxiang:** release 14.0.1 ([558ed78](https://github.com/amzxyz/rime_wanxiang/commit/558ed789123f7b2eccbc5d2f66099f7b32a2be6b))
* **wanxiang:** release 14.0.2 ([b54815d](https://github.com/amzxyz/rime_wanxiang/commit/b54815d91e0586b08a1fe799720de725a95cfde0))
* **wanxiang:** release 14.0.3 ([9b0402d](https://github.com/amzxyz/rime_wanxiang/commit/9b0402de04ef79e106f932d0738e8194fa390b5a))
* **wanxiang:** release 14.0.4 ([b4856f6](https://github.com/amzxyz/rime_wanxiang/commit/b4856f63b1b9940148658750fc299a15cdc26357))
* **wanxiang:** release 14.0.5 ([8bd6da5](https://github.com/amzxyz/rime_wanxiang/commit/8bd6da5036eacc5952ea2477def401ef103c69b6))
* **wanxiang:** release 14.0.6 ([be21abc](https://github.com/amzxyz/rime_wanxiang/commit/be21abc4d376d748a08a6d53d5b7c0f0f5dedf56))
* **wanxiang:** release 14.1.0 ([5147f61](https://github.com/amzxyz/rime_wanxiang/commit/5147f61d07ac6fc56e6765d5110a1db47a13d3e8))
* **wanxiang:** release 14.1.1 ([0e3982b](https://github.com/amzxyz/rime_wanxiang/commit/0e3982b3bf8183c54c4970e35fff608574b5bb08))
* **wanxiang:** release 14.1.2 ([90ba7f2](https://github.com/amzxyz/rime_wanxiang/commit/90ba7f2513809989c6c5d59a5489ef1a9567176c))
* **wanxiang:** release 14.1.3 ([b18e38b](https://github.com/amzxyz/rime_wanxiang/commit/b18e38b539e0f1b88751115741d408e19db452c2))
* **wanxiang:** release 14.1.4 ([9c1b879](https://github.com/amzxyz/rime_wanxiang/commit/9c1b8796595b7cfa6bbc14b50fb5c8e38e31bc12))
* **wanxiang:** release 14.1.5 ([64dd3a8](https://github.com/amzxyz/rime_wanxiang/commit/64dd3a8e6ce4e270971633f454101c681cfe10cc))
* **wanxiang:** release 14.1.6 ([e9da433](https://github.com/amzxyz/rime_wanxiang/commit/e9da433fb6c350ddcbaa9341609ab19b2b11b7e2))
* **wanxiang:** release 14.1.7 ([4c7e6c4](https://github.com/amzxyz/rime_wanxiang/commit/4c7e6c4be1fbf20180ae4a336ccc558213d1e476))
* **wanxiang:** release 14.1.8 ([f4e85a1](https://github.com/amzxyz/rime_wanxiang/commit/f4e85a1b39d14c943440129552ae2bd6fcf221b3))
* **wanxiang:** release 14.2.0 ([8d03ab3](https://github.com/amzxyz/rime_wanxiang/commit/8d03ab3506c9a7e8f32f1f108c4bfbfcb96febe5))
* **wanxiang:** release 14.2.1 ([681139d](https://github.com/amzxyz/rime_wanxiang/commit/681139de087099327b7ae5609e419dacde99101b))
* **wanxiang:** release 14.2.2 ([ed31e0e](https://github.com/amzxyz/rime_wanxiang/commit/ed31e0e34616ee20a77bcff3a909045136c7a7a8))
* **wanxiang:** release 14.2.3 ([bbf3157](https://github.com/amzxyz/rime_wanxiang/commit/bbf3157c2660676290b6216aff16ce6e11c8697d))
* **wanxiang:** release 14.2.4 ([91c7b9b](https://github.com/amzxyz/rime_wanxiang/commit/91c7b9b52ddc3b5cf011b84b169941f12c50cb36))
* **wanxiang:** release 14.2.5 ([9f40ce0](https://github.com/amzxyz/rime_wanxiang/commit/9f40ce0887636b368738d5f52fb71d54d94a9cec))
* **wanxiang:** release 14.2.6 ([f37591b](https://github.com/amzxyz/rime_wanxiang/commit/f37591b9e350d960c7a086febbfb5a3b58cd201e))
* **wanxiang:** release 14.3.0 ([245f073](https://github.com/amzxyz/rime_wanxiang/commit/245f073eecb7575609a8d2a834b73c1b70711665))
* **wanxiang:** release 14.3.1 ([9f8551b](https://github.com/amzxyz/rime_wanxiang/commit/9f8551b3f0e44265a17defd1c07e31b9c2fdfae3))
* **wanxiang:** release 14.3.2 ([ba8f41d](https://github.com/amzxyz/rime_wanxiang/commit/ba8f41d71ea325c93d464c7f1590a417c9e63f37))
* **wanxiang:** release 14.3.3 ([d341962](https://github.com/amzxyz/rime_wanxiang/commit/d34196229402bdf93c67e96f129f520f5b7b39e5))
* **wanxiang:** release 14.3.4 ([1d8c61d](https://github.com/amzxyz/rime_wanxiang/commit/1d8c61d71bd5a3756ae0cbe05140b7caf79c0f93))
* **wanxiang:** release 14.4.0 ([3a7396d](https://github.com/amzxyz/rime_wanxiang/commit/3a7396d01d496167a870aa99ad8c943d8f0b61a4))
* **wanxiang:** release 14.4.1 ([18b95e6](https://github.com/amzxyz/rime_wanxiang/commit/18b95e6b1962a525cd9dd04f6c0e6dc04ebc8894))
* **wanxiang:** release 14.4.3 ([8097213](https://github.com/amzxyz/rime_wanxiang/commit/809721387c838c08259ce401312287d2b239d51c))
* **wanxiang:** release 14.5.0 ([a988418](https://github.com/amzxyz/rime_wanxiang/commit/a988418941e4582ade6388a3cbe4b441ace25149))
* **wanxiang:** release 14.6.0 ([f36cd81](https://github.com/amzxyz/rime_wanxiang/commit/f36cd81230140a20c1f392ae2c9c9d28f5ab55c5))
* **wanxiang:** release 14.6.1 ([26ddf13](https://github.com/amzxyz/rime_wanxiang/commit/26ddf13ec9759c81339ec02a944eb7723c3edb11))
* **wanxiang:** release 14.6.2 ([d172b80](https://github.com/amzxyz/rime_wanxiang/commit/d172b8065832c440aecf928835d8e2501e540905))
* **wanxiang:** release 14.6.3 ([1d92a7a](https://github.com/amzxyz/rime_wanxiang/commit/1d92a7a95f9735bfd5a534416469188023a15e69))
* **wanxiang:** release 14.6.4 ([2d1a3c1](https://github.com/amzxyz/rime_wanxiang/commit/2d1a3c1d053a545475d4d922870e0eead55c7ee9))
* **wanxiang:** release 14.6.5 ([b99ccc4](https://github.com/amzxyz/rime_wanxiang/commit/b99ccc4dbf5548facdb390d39f6ec6fec58a6b10))
* **wanxiang:** release 14.6.6 ([b0ef567](https://github.com/amzxyz/rime_wanxiang/commit/b0ef56764de41b161fd45c8673207addf628a588))
* **wanxiang:** release 14.6.7 ([169e62d](https://github.com/amzxyz/rime_wanxiang/commit/169e62d6233fdd3f2709f4042cc131c5c542a46f))
* **wanxiang:** release 14.6.8 ([08278a2](https://github.com/amzxyz/rime_wanxiang/commit/08278a2a4934060587d51642374a3b541c127509))
* **wanxiang:** release 14.6.9 ([e4f8c52](https://github.com/amzxyz/rime_wanxiang/commit/e4f8c528ded295a74193b82975cae3d5a6a0ff5e))
* 修改说明 ([a13dda4](https://github.com/amzxyz/rime_wanxiang/commit/a13dda464ea95df1854df2924ad3641be746e70b))
* 修改说明 ([39aee7e](https://github.com/amzxyz/rime_wanxiang/commit/39aee7e5f0f680d57fe87749d360dcc8a4b0c22e))
* 修改说明 ([3bd3b7c](https://github.com/amzxyz/rime_wanxiang/commit/3bd3b7cd798bb5651f22dac894dbe098a0e9052e))
* 修改说明 ([32132ee](https://github.com/amzxyz/rime_wanxiang/commit/32132eee03041f618ce9f64d47dc0ae4d32d7fb0))
* 修改说明 ([342328f](https://github.com/amzxyz/rime_wanxiang/commit/342328f0003d8dedb59971dcda5081f8c61be64d))
* 修改说明 ([e421a5c](https://github.com/amzxyz/rime_wanxiang/commit/e421a5c78ad626eb5bcfa2a21cb3b21d060a547a))
* 修改说明 ([b377e9b](https://github.com/amzxyz/rime_wanxiang/commit/b377e9b5980e057301aaf07c76229a9588bfea78))
* 修改说明 ([16964d4](https://github.com/amzxyz/rime_wanxiang/commit/16964d4b526cf400d758057015dbfc6c22ef8dde))
* 修改说明 ([9650e11](https://github.com/amzxyz/rime_wanxiang/commit/9650e1126bfde38eb518a8878db47a7e73b72bed))
* 变更说明 ([2f9efa6](https://github.com/amzxyz/rime_wanxiang/commit/2f9efa6a826df2c1622149bccec61d7bc901bd32))
* 变更说明 ([1fa9d9a](https://github.com/amzxyz/rime_wanxiang/commit/1fa9d9afc63a45e76abca6682f8ddf25bea36743))
* 调整说明 ([f3d9b99](https://github.com/amzxyz/rime_wanxiang/commit/f3d9b991ad9f331fc6c1e739e510ac422824b5bc))
* 调整说明 ([de2148d](https://github.com/amzxyz/rime_wanxiang/commit/de2148d0c34c52713c95a14abb92ac1cd8fef098))

## [14.6.9](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.8...v14.6.9) (2026-02-03)


### 🐛 Bug 修复

* 更新首右拆分 ([135da73](https://github.com/amzxyz/rime_wanxiang/commit/135da737a3e457b5e08279fca00a5e2308b5d2d8))
* 更新首右辅助码 ([57b940c](https://github.com/amzxyz/rime_wanxiang/commit/57b940cc0e4c01458596854afd62ba43f68601bf))


### 🏡 杂项

* release 14.6.9 ([cabf3dc](https://github.com/amzxyz/rime_wanxiang/commit/cabf3dc0cc63754164fff0453454ae5923e7489b))

## [14.6.8](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.7...v14.6.8) (2026-02-03)


### 📚 词库更新

* update dicts ([3dc45a2](https://github.com/amzxyz/rime_wanxiang/commit/3dc45a27041fcc2b81aac7d7c016230f4fc710f1))
* 词库调整 ([314c5d6](https://github.com/amzxyz/rime_wanxiang/commit/314c5d6c13d1771f2ccc6e70e2efa0540a1df470))
* 词库调整 ([81f8a8a](https://github.com/amzxyz/rime_wanxiang/commit/81f8a8aa5e658292768877c5ce08fd49c72c4910))


### 🐛 Bug 修复

* 修复一个时间lua中上午下午变量的逻辑问题 ([8951eca](https://github.com/amzxyz/rime_wanxiang/commit/8951eca4d260a0fe5565792b50d59442b0b04051))
* 修复拼音加加基础版转写 ([adfaccf](https://github.com/amzxyz/rime_wanxiang/commit/adfaccff743ce429b496adcdd4efac57d6c5f6c1))
* 解决候选格式化换行与月冲突的问题，并新增星期的占位符 ([344f3b4](https://github.com/amzxyz/rime_wanxiang/commit/344f3b452b9a85611a1bff808c77d2b720c4adbb))

## [14.6.7](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.6...v14.6.7) (2026-02-02)


### 📚 词库更新

* 九键新增成语简码 ([ede14bb](https://github.com/amzxyz/rime_wanxiang/commit/ede14bb2f74edd59615e92503c5858d37df02491))
* 词库调整 ([7be4781](https://github.com/amzxyz/rime_wanxiang/commit/7be47813512ae4994bd14623f5adf942d56c5de2))


### 🐛 Bug 修复

* 人名物种不打包到zip中 ([ff710b3](https://github.com/amzxyz/rime_wanxiang/commit/ff710b3186d311f61840ece12c2b377ab4fc9f2b))
* 候选格式化新增更多时间相关占位符，任何能产生候选的表都可以写入占位符，试着输入：此时此刻 ([c63a855](https://github.com/amzxyz/rime_wanxiang/commit/c63a8554a17aac6c7f0f9f33ba0afe859ab3ab75))
* 成语简码默认设为0即不前置，有需要的朋友请自行重新patch前置位置，在自定义路上又前进一步 ([0b0adc7](https://github.com/amzxyz/rime_wanxiang/commit/0b0adc7d3e3e86d53c3e0ce75417d6d7fbf5bf4e))

## [14.6.6](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.5...v14.6.6) (2026-02-02)


### 🐛 Bug 修复

* **replacer:** 发现新问题，通过权重构建扎实地根目录指定优先、程序补充简码滞后等恰当的逻辑 ([d378948](https://github.com/amzxyz/rime_wanxiang/commit/d378948cb3fd287cf353474cd37dcfc279992bfa))

## [14.6.5](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.4...v14.6.5) (2026-02-01)


### 📚 词库更新

* 词库调整 ([9632fb1](https://github.com/amzxyz/rime_wanxiang/commit/9632fb1e18315fc81d742a35978b3640ea5b05dd))


### 🐛 Bug 修复

* **replacer:** 置顶词出现在根目录user_table置顶词后面 ([7dc7b95](https://github.com/amzxyz/rime_wanxiang/commit/7dc7b951a7ee47ccc7cc4b8df2f8c53773a42bcf))
* 修改英文转写 ([f51f76c](https://github.com/amzxyz/rime_wanxiang/commit/f51f76cfd33b94a157365283440dc223e538ab96))
* 打包时间改成中国时区 ([81fcc40](https://github.com/amzxyz/rime_wanxiang/commit/81fcc405e3bb448bdf455302fe70c32364cbab08))

## [14.6.4](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.3...v14.6.4) (2026-01-30)


### 📚 词库更新

* 词库调整 ([937e7bb](https://github.com/amzxyz/rime_wanxiang/commit/937e7bbf617328c8916ca8cb585f9b6f6f957c4e))


### 🐛 Bug 修复

* 修复当根目录的置顶包含英文的时候导致replacer简码也会出现的问题 ([530d82c](https://github.com/amzxyz/rime_wanxiang/commit/530d82cd68d0c57cb7ac13b794da79aa4da6f00a))
* 修复空码回溯功能 ([d971547](https://github.com/amzxyz/rime_wanxiang/commit/d971547cf9339f29d50d977c69ec9d74797cab75))

## [14.6.3](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.2...v14.6.3) (2026-01-30)


### 🐛 Bug 修复

* 恢复缩进 ([b9f071d](https://github.com/amzxyz/rime_wanxiang/commit/b9f071d62edfab1613146a299d31707545b8fd34))

## [14.6.2](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.1...v14.6.2) (2026-01-30)


### 🐛 Bug 修复

* 补齐九键遗漏的开关 ([e52a7a3](https://github.com/amzxyz/rime_wanxiang/commit/e52a7a359f4a7bb0e7ed385d65ff800032841f29))

## [14.6.1](https://github.com/amzxyz/rime_wanxiang/compare/v14.6.0...v14.6.1) (2026-01-30)


### 📚 词库更新

* 词库调整 ([c200321](https://github.com/amzxyz/rime_wanxiang/commit/c200321cf4afc95d7f3ffe610e37b98a31d223bd))
* 词库调整 ([82dd994](https://github.com/amzxyz/rime_wanxiang/commit/82dd9947e3fe2761a8614eea9cc18eaf8240d80e))
* 词库调整 ([e4b2c19](https://github.com/amzxyz/rime_wanxiang/commit/e4b2c1953079c41b0ac74e3e131c57a47ab5dcc7))


### 🐛 Bug 修复

* 混合编码候选下-空出简状态下，也能出现简码 ([48798e2](https://github.com/amzxyz/rime_wanxiang/commit/48798e2b86588b3f3af89b17f8438e93c15def8d))


### 🏡 杂项

* 修改说明 ([a13dda4](https://github.com/amzxyz/rime_wanxiang/commit/a13dda464ea95df1854df2924ad3641be746e70b))

## [14.6.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.5.0...v14.6.0) (2026-01-29)


### ✨ 新特性

* **lua:** 万能滤镜在原来简繁转换表情派生的情况下，另新增了简码模块，该模块同样可以基于配置进行模块化配置来取消和新增这样的模块，这个简码有三种模式，关闭、为空时填充、总是填充，这样的设计可以适用于任何拼音编码方案，默认的为空时填充巧妙的利用了候选为空或者英文时，我们更有意愿被简码填充，不会干扰已有的输入能力，对于体验是极大的提升，未来用户可以灵活的定义自己的数据库，实现自己想要的置顶数据简码，且数据是活的可受开关控制的，这是第一个版本，我们将在后续的数据维护中逐步完善体验。需要说明的是这个属于公共简码部分即他不包含辅助码，如果你定义了复杂的编码形态还是要基于根目录的txt来实现，但本次是对pro没简码，t9简码卡顿的一个战略性优化，使其拥有更好的体验 ([8bb1b17](https://github.com/amzxyz/rime_wanxiang/commit/8bb1b170a2ceccca07491aafc3ac7d78ebaf8c42))


### 📚 词库更新

* 词库调整 ([abe58a1](https://github.com/amzxyz/rime_wanxiang/commit/abe58a1d7cb25b779f89fef85fc1d180c1c34222))


### 🐛 Bug 修复

* [符号表]重新核对元素周期表数据并更正 ([1dc6ef3](https://github.com/amzxyz/rime_wanxiang/commit/1dc6ef362d43d634b3fd61d7076c783e2c6a77e6))
* ng输入“嗯”时以缩写形式提供，这样可与ng下面派生简拼词汇一起出现 ([d660eb1](https://github.com/amzxyz/rime_wanxiang/commit/d660eb161f6bdf16b4aad848df3c919833bb537d))


### 🏡 杂项

* 修改说明 ([39aee7e](https://github.com/amzxyz/rime_wanxiang/commit/39aee7e5f0f680d57fe87749d360dcc8a4b0c22e))

## [14.5.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.4.3...v14.5.0) (2026-01-28)


### ✨ 新特性

* 新增前两页可以被符号包裹 ([e939f81](https://github.com/amzxyz/rime_wanxiang/commit/e939f81a20302642f8f02e6ed8bb8f888702f157))


### 📚 词库更新

* **sym:** 符号表新增元素周期表、希腊粗体等多种字符表 ([c6f9986](https://github.com/amzxyz/rime_wanxiang/commit/c6f9986f1fb4721331b191db266f5d6d2ba29315))
* 词库调整 ([d484bb3](https://github.com/amzxyz/rime_wanxiang/commit/d484bb3fa946e5d8ba6fb863a2fba85cfde4d31e))
* 词库调整 ([36acd0a](https://github.com/amzxyz/rime_wanxiang/commit/36acd0a9cf077c4c1d8b5c4af3627db74244863d))
* 词库调整 ([0198fce](https://github.com/amzxyz/rime_wanxiang/commit/0198fcec278612b2f2bc21c11be50aa5d8a399b7))
* 词库调整 ([d8245d8](https://github.com/amzxyz/rime_wanxiang/commit/d8245d8e17b5f7a09675c24d86dfa7acb5694b78))
* 词库调整 ([ddbc746](https://github.com/amzxyz/rime_wanxiang/commit/ddbc74692140ebcefdc0df3b23960ccb99439f00))
* 词库调整 ([8fef555](https://github.com/amzxyz/rime_wanxiang/commit/8fef55521dbabb938b401b530e4f22a3cd6d5db1))
* 词库调整 ([1b14ee9](https://github.com/amzxyz/rime_wanxiang/commit/1b14ee9c81a5c4e0847d6b1882ffbfc4df78a93c))
* 词库调整 ([069d01d](https://github.com/amzxyz/rime_wanxiang/commit/069d01dbfd6cf60a14ab4bacb1c6f47394537fe1))
* 词库调整 ([7a03017](https://github.com/amzxyz/rime_wanxiang/commit/7a030177a72d61c6a65d669fd06267a780d2f920))
* 词库调整 ([5336095](https://github.com/amzxyz/rime_wanxiang/commit/53360958dbd084eb9e57b8dc0f9889477518631d))
* 调整他她它 ([8337bdb](https://github.com/amzxyz/rime_wanxiang/commit/8337bdb8588ee3301f4277df42df0dcc6d82520d))


### 🐛 Bug 修复

* **lua:** 快符匹配时不转换大小写 ([1a78e90](https://github.com/amzxyz/rime_wanxiang/commit/1a78e90f83d9f61313fef6b21e7ac92f43a4652c))
* 更新tips ([1027db6](https://github.com/amzxyz/rime_wanxiang/commit/1027db652e35e678312e382943778f5faa33a6f4))
* 更新符号表 ([22527f4](https://github.com/amzxyz/rime_wanxiang/commit/22527f46f4bb3af960e3ebd92d123695fa92e1c0))


### 🏡 杂项

* 变更说明 ([2f9efa6](https://github.com/amzxyz/rime_wanxiang/commit/2f9efa6a826df2c1622149bccec61d7bc901bd32))
* 变更说明 ([1fa9d9a](https://github.com/amzxyz/rime_wanxiang/commit/1fa9d9afc63a45e76abca6682f8ddf25bea36743))

## [14.4.3](https://github.com/amzxyz/rime_wanxiang/compare/v14.4.1...v14.4.3) (2026-01-23)

### 🐛 Bug 修复

* /命令模式不派生候选 ([0a08cbe](https://github.com/amzxyz/rime_wanxiang/commit/0a08cbed18913a22a2e8660d4b077388472e71d8))
* **tips:** 翻页后不再匹配输入编码，释放翻页返回按键 ([6626142](https://github.com/amzxyz/rime_wanxiang/commit/662614238d4cabb4f2ffec79395dbb73e53406dc))
* 九宫格注释掉简拼 ([1ee350d](https://github.com/amzxyz/rime_wanxiang/commit/1ee350d9a7e8e2ff81ad5625a83c5fe31f8ae943))

## [14.4.1](https://github.com/amzxyz/rime_wanxiang/compare/v14.4.0...v14.4.1) (2026-01-21)


### 📚 词库更新

* 词库调整 ([83d54a1](https://github.com/amzxyz/rime_wanxiang/commit/83d54a129e2a012a13ca7a42c1c88938b736991b))
* 词库调整 ([e76e28f](https://github.com/amzxyz/rime_wanxiang/commit/e76e28f1a531e35e07ed2bd495f1521449973084))
* 词库调整 ([c5a90d3](https://github.com/amzxyz/rime_wanxiang/commit/c5a90d39824ae1f49d95a9549579bba4bce0d43a))
* 词库调整 ([7e49d42](https://github.com/amzxyz/rime_wanxiang/commit/7e49d42f523e26f1a3c89685019ea28ed2155f62))


### 🐛 Bug 修复

* 反查模式不派生 ([e35351b](https://github.com/amzxyz/rime_wanxiang/commit/e35351b7919c909f55d94378d8142117817fa296))
* 调整反查接入方式 ([fc43f67](https://github.com/amzxyz/rime_wanxiang/commit/fc43f67c6922a01894c1b5d748e275dd71803fb8))

## [14.4.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.3.4...v14.4.0) (2026-01-20)


### ✨ 新特性

* 合并8个按键处理器lua为一个，KP小键盘、字母选词、符号快打、超强分词、重复限制、退格限制、声调回退、以词定字 ([f8cab70](https://github.com/amzxyz/rime_wanxiang/commit/f8cab704341e7cf8860e2947c75bd32b552a7bd6))


### 📚 词库更新

* 词库调整 ([f9daf75](https://github.com/amzxyz/rime_wanxiang/commit/f9daf75b48f47f8b8292e7a81567d88bb9fa4d44))


### 🐛 Bug 修复

* 修补若干bug ([ba961f1](https://github.com/amzxyz/rime_wanxiang/commit/ba961f1b3a8f39aeb112a0418aa9e82da4f783fd))

## [14.3.4](https://github.com/amzxyz/rime_wanxiang/compare/v14.3.3...v14.3.4) (2026-01-19)


### 🐛 Bug 修复

* 再次调整英文处理器 ([7b89edb](https://github.com/amzxyz/rime_wanxiang/commit/7b89edb4f614618d8f3544f74964924219712555))


### 🏡 杂项

* 修改说明 ([7599b4a](https://github.com/amzxyz/rime_wanxiang/commit/7599b4a03dcd6b66cced5529b2e5c3896b8de78d))

## [14.3.3](https://github.com/amzxyz/rime_wanxiang/compare/v14.3.2...v14.3.3) (2026-01-19)


### 🐛 Bug 修复

* 移除标志符号注释提示 ([6ef5360](https://github.com/amzxyz/rime_wanxiang/commit/6ef5360f6cdb05919e77d569322de1279b51c8bd))

## [14.3.2](https://github.com/amzxyz/rime_wanxiang/compare/v14.3.1...v14.3.2) (2026-01-19)


### 📚 词库更新

* 词库调整 ([4a85c14](https://github.com/amzxyz/rime_wanxiang/commit/4a85c14e262037945059b9da0c3dec8c71f5511d))


### 🐛 Bug 修复

* 修复英文派生单字母干扰置顶词的问题，同时提升性能 ([e4288ff](https://github.com/amzxyz/rime_wanxiang/commit/e4288ffe9733472155a23926e7037283940e3e5a))
* 由于性能问题，由滤镜构建的中英文切换现在去掉，改为通过切换方案来实现中英文切换，快捷键还是shift+space,但不再有仅中文的模式，有需求的用户可以通过patch去掉英文表的挂载 ([70c86c6](https://github.com/amzxyz/rime_wanxiang/commit/70c86c67bd65e905b62d03410cfc9b1ee2804f84))

## [14.3.1](https://github.com/amzxyz/rime_wanxiang/compare/v14.3.0...v14.3.1) (2026-01-18)


### 🐛 Bug 修复

* 补齐忘记修改的部分 ([5feeb4c](https://github.com/amzxyz/rime_wanxiang/commit/5feeb4c919a0bd5cfdfe2101e1fef05140db171f))

## [14.3.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.2.6...v14.3.0) (2026-01-18)


### ✨ 新特性

* 字符集过滤现已全面升级，具体阅读方案中配置段落的说明，现在可以兼容字符集过滤与简繁转换的冲突问题 ([8b391f7](https://github.com/amzxyz/rime_wanxiang/commit/8b391f7278d344cb0ba9b5e26152677aa7b7d5ba))


### 🐛 Bug 修复

* 超级注释添加CJK区域显示 ([98e9077](https://github.com/amzxyz/rime_wanxiang/commit/98e90775c297f71a72681ffe60e0765c04826210))

## [14.2.6](https://github.com/amzxyz/rime_wanxiang/compare/v14.2.5...v14.2.6) (2026-01-17)


### 📚 词库更新

* 词库调整 ([1f96a5d](https://github.com/amzxyz/rime_wanxiang/commit/1f96a5d22502acfa59b1834967ea3e4b32dc837f))
* 词库调整 ([5f9a0ad](https://github.com/amzxyz/rime_wanxiang/commit/5f9a0ad770f527a6ec4a1a8dd8e2dda3e6b78fed))
* 词库调整 ([48d49ab](https://github.com/amzxyz/rime_wanxiang/commit/48d49abc7a44e103db3fb0e43fa1143393caf717))


### 🐛 Bug 修复

* **lua:** 修复小键盘数字在commit_text时导致PSReadLine的bug ([2b04a6a](https://github.com/amzxyz/rime_wanxiang/commit/2b04a6abcd8ac9cd1502e72ef44157e66102cbc1))

## [14.2.5](https://github.com/amzxyz/rime_wanxiang/compare/v14.2.4...v14.2.5) (2026-01-16)


### 📚 词库更新

* 词库调整 ([a4f96ec](https://github.com/amzxyz/rime_wanxiang/commit/a4f96ec92061838adb98a713bb7105235459fcfe))

## [14.2.4](https://github.com/amzxyz/rime_wanxiang/compare/v14.2.3...v14.2.4) (2026-01-16)


### 📚 词库更新

* 词库调整 ([7472d78](https://github.com/amzxyz/rime_wanxiang/commit/7472d78fcb31ccad3f540c3ce9bfa06e355947ea))


### 🐛 Bug 修复

* 调整英文方案 ([04edb36](https://github.com/amzxyz/rime_wanxiang/commit/04edb3684a14ccffa3f30897d593cb595be2b2ca))

## [14.2.3](https://github.com/amzxyz/rime_wanxiang/compare/v14.2.2...v14.2.3) (2026-01-16)


### 📚 词库更新

* 词库调整 ([89602f5](https://github.com/amzxyz/rime_wanxiang/commit/89602f519617de22533b74cecfc57405ed8eea25))
* 词库调整 ([5e7a4e0](https://github.com/amzxyz/rime_wanxiang/commit/5e7a4e0d64e7fb3c23eb5971bd1883f79f1a3cea))
* 词库调整 ([cb3595c](https://github.com/amzxyz/rime_wanxiang/commit/cb3595cef84306e7e16c22ff89803ab0866d01c8))


### 🐛 Bug 修复

* 修复替换处理器直接写true被认为是字符串的问题 ([7a88f92](https://github.com/amzxyz/rime_wanxiang/commit/7a88f9246bd3e2b1c9a4635db6d7bfd84e9b26e2))

## [14.2.2](https://github.com/amzxyz/rime_wanxiang/compare/v14.2.1...v14.2.2) (2026-01-14)


### 🐛 Bug 修复

* 挽救一次失誤 ([f21e42f](https://github.com/amzxyz/rime_wanxiang/commit/f21e42f700f4aa61b2c8349a16b4acd5109c2846))


### 🏡 杂项

* 修改说明 ([e550639](https://github.com/amzxyz/rime_wanxiang/commit/e550639decf4ba2d107b7cb94fe0f84e3cb14f00))

## [14.2.1](https://github.com/amzxyz/rime_wanxiang/compare/v14.2.0...v14.2.1) (2026-01-14)


### 🐛 Bug 修复

* 集中修复三个lua bug，为替换器增加FMM分词算法补齐句子转换功能 ([1e9bbe3](https://github.com/amzxyz/rime_wanxiang/commit/1e9bbe392082144126fa8aaa9c77843917b5c05a))

## [14.2.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.8...v14.2.0) (2026-01-14)


### ✨ 新特性

* 全面移除OpenCC组件的引用，使用lua重构，现在将拥有更为灵活的转换策略，使用数据库常态化工作，自定义码表更简单，不用担心键值对的重复空格的敏感等问题 ([ff8be68](https://github.com/amzxyz/rime_wanxiang/commit/ff8be6866994c831628afb7d638917566484ea16))


### 📚 词库更新

* 词库调整 ([091851b](https://github.com/amzxyz/rime_wanxiang/commit/091851b9b3fa0a4f19bc959864e91e8bdc842c03))
* 词库调整 ([c53bccf](https://github.com/amzxyz/rime_wanxiang/commit/c53bccf626e8bc2bc064369b23483b592e48d0ad))

## [14.1.8](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.7...v14.1.8) (2026-01-12)


### 📚 词库更新

* 词库调整 ([b9b5e02](https://github.com/amzxyz/rime_wanxiang/commit/b9b5e029fa73c03d30858e5b30681c236649ba1f))
* 词库调整 ([3d7f1ea](https://github.com/amzxyz/rime_wanxiang/commit/3d7f1ea72dbf6e544cfa128ba1329ccc8cb516b2))


### 🐛 Bug 修复

* **super_lookup:** 反查现已支持声调，与字母任意位置输入即可，词组根据输入的个数来从第一个汉字依次来匹配，输入位置也是随意的 ([e20e114](https://github.com/amzxyz/rime_wanxiang/commit/e20e114d0646e5e0498c6bf394593e307dd1bf1f))
* 删除无效代码 ([8b11674](https://github.com/amzxyz/rime_wanxiang/commit/8b11674a84678291a4ce14ced16c69c3567eb5b4))
* 简纯主题数字行高度对齐每夜版本 ([3d2a1f8](https://github.com/amzxyz/rime_wanxiang/commit/3d2a1f88d3d35e570c970336d7e5534f89b9a9c6))
* 首选格式化支持连续字符的简写 ([ff10425](https://github.com/amzxyz/rime_wanxiang/commit/ff104253407cbc6e89229814e1aecdd0799f37f0))


### 🏡 杂项

* 修改说明 ([ed54f97](https://github.com/amzxyz/rime_wanxiang/commit/ed54f97b8dfd1f29dc686caa56b5a2e07277223f))

## [14.1.7](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.6...v14.1.7) (2026-01-11)


### 📚 词库更新

* 词库调整 ([dc8a54d](https://github.com/amzxyz/rime_wanxiang/commit/dc8a54d2d2f8fb171a8504a06d40886f35b3d943))


### 🐛 Bug 修复

* 全拼状态下将bun拼音下置顶一个“不能，避免生僻字兺干扰喜欢派生输入的习惯” ([7aac6a4](https://github.com/amzxyz/rime_wanxiang/commit/7aac6a489a39380483ffe698217d62cfde25e727))

## [14.1.6](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.5...v14.1.6) (2026-01-10)


### 🐛 Bug 修复

* 移除多余声明 ([e1744fb](https://github.com/amzxyz/rime_wanxiang/commit/e1744fba02f7079d046a9efe44d2ae3b82c63287))
* 适配元书的九宫格处理器 ([da82c9e](https://github.com/amzxyz/rime_wanxiang/commit/da82c9eb254d45b45d44fb29ece0f582b3282e72))

## [14.1.5](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.4...v14.1.5) (2026-01-10)


### 📚 词库更新

* 补充英文词库 ([ebc42be](https://github.com/amzxyz/rime_wanxiang/commit/ebc42be99c82448c296d084888ce70a20c4fdb74))
* 词库调整 ([cc15b24](https://github.com/amzxyz/rime_wanxiang/commit/cc15b24b3b1e3757f03307f99d1b07fa73152a4c))
* 词库调整 ([5bcf2d9](https://github.com/amzxyz/rime_wanxiang/commit/5bcf2d9307da7f727bc5de1b163bf4f18a76b249))
* 词库调整 ([9445c8b](https://github.com/amzxyz/rime_wanxiang/commit/9445c8b64105e69dce95525b9b4dbefa67c6506a))


### 🐛 Bug 修复

* 修改说明 ([762de75](https://github.com/amzxyz/rime_wanxiang/commit/762de758a923c50a95941dd198adf8c158b948fd))
* 当'作为分隔符又与it's重合，不在插入空格导致其分开 ([ad842c7](https://github.com/amzxyz/rime_wanxiang/commit/ad842c7b975ebae437ba07330e126bce63b9f717))
* 自动造词的非确定性优化 ([de074ae](https://github.com/amzxyz/rime_wanxiang/commit/de074aef6e23dab0012dfc5a2097194d2e1951a2))

## [14.1.4](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.3...v14.1.4) (2026-01-07)


### 📚 词库更新

* 词库调整 ([4bb0db4](https://github.com/amzxyz/rime_wanxiang/commit/4bb0db4873c70b2646ce46a01fc15809850e59e7))


### 🐛 Bug 修复

* /命令模式不派生候选 ([797994f](https://github.com/amzxyz/rime_wanxiang/commit/797994fa72fb68d65fb4c79a731b5651914c3621))
* 微调英文自动加空格策略 ([800ccb5](https://github.com/amzxyz/rime_wanxiang/commit/800ccb581a1be43807ee5b1ed1419866a6bb016a))


### 🏡 杂项

* 调整说明 ([1a299ff](https://github.com/amzxyz/rime_wanxiang/commit/1a299ff7c439759e55d9c381bbe2a0fa5d14ce2a))

## [14.1.3](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.2...v14.1.3) (2026-01-06)


### 🐛 Bug 修复

* 优化在空候选的时候中文候选的派生逻辑，如果上一个字是汉字，且三码为空码的时候自动派生上一个字加~注释如：ckl可以派生 操~ 而ctrl+g开启大字集就会恢复原本的输出 䎭，这在视觉上弥补了空码带来的顿挫感，以及派生出英文的不合理性 ([0a514b2](https://github.com/amzxyz/rime_wanxiang/commit/0a514b214961d276bf8300806adfd5dd237f461d))
* 调整路径获取 ([325817c](https://github.com/amzxyz/rime_wanxiang/commit/325817cfc910b3033d6fdfff734fb3d48cb9552b))

## [14.1.2](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.1...v14.1.2) (2026-01-06)


### 📚 词库更新

* 词库调整 ([c604c63](https://github.com/amzxyz/rime_wanxiang/commit/c604c632e490562c70e8377ef42a6be617aeb30f))


### 🐛 Bug 修复

* 修复智能ABC+汉心转写中的bug ([fa60a9c](https://github.com/amzxyz/rime_wanxiang/commit/fa60a9c925c837842b1823aa8c96d11778546e05))

## [14.1.1](https://github.com/amzxyz/rime_wanxiang/compare/v14.1.0...v14.1.1) (2026-01-05)


### 📚 词库更新

* 词库调整 ([14bdf2f](https://github.com/amzxyz/rime_wanxiang/commit/14bdf2fa35ce1a5a9a2abdcefc1d3c93b2b0422f))


### 🐛 Bug 修复

* 修改基础版紫光转写 ([12370f1](https://github.com/amzxyz/rime_wanxiang/commit/12370f1bf7f394fe6cc8b7ac2c4c52f100f9bda0))
* 输入中持续保持英文加空格的记录状态，哪怕你输入的慢点 ([e5b1d37](https://github.com/amzxyz/rime_wanxiang/commit/e5b1d37fedd803a5f8e4b163fea49f5619813bdf))

## [14.1.0](https://github.com/amzxyz/rime_wanxiang/compare/v14.0.6...v14.1.0) (2026-01-05)


### ✨ 新特性

* 新增yaml正则转义lua正则模块，数字键处理逻辑将直接读取状态 ([67f40b6](https://github.com/amzxyz/rime_wanxiang/commit/67f40b64d8843664fbb05bc04313221ca4dfe398))


### 🐛 Bug 修复

* 简化配置层级 ([0b6a880](https://github.com/amzxyz/rime_wanxiang/commit/0b6a880f205833c948a8fe3cc20ef10f3ffca382))
* 英文lua派生单字母按照输入什么什么优先，且不干扰置顶的单词，置顶优先 ([00ca0f3](https://github.com/amzxyz/rime_wanxiang/commit/00ca0f323fe91313b5c7c2d2c790ffdc7cfb1a12))

## [14.0.6](https://github.com/amzxyz/rime_wanxiang/compare/v14.0.5...v14.0.6) (2026-01-04)


### 🐛 Bug 修复

* 删除多余传参 ([4ae30b9](https://github.com/amzxyz/rime_wanxiang/commit/4ae30b9f6595ceeb7c28d1d404274a643d3829e9))
* 句中反查修复了两个bug ([76c3099](https://github.com/amzxyz/rime_wanxiang/commit/76c3099675342eaab94fe8bc25e05a7e68b8e5f3))
* 当按下修饰键的时候数字处理器交还给系统 ([31fb8aa](https://github.com/amzxyz/rime_wanxiang/commit/31fb8aa37c59e16b746960df07c965dec2be0fcd))
* 指令设置英文custom ([4b599a0](https://github.com/amzxyz/rime_wanxiang/commit/4b599a04be741a213a1dd2d5f9a249cc932d7c3b))

## [14.0.5](https://github.com/amzxyz/rime_wanxiang/compare/v14.0.4...v14.0.5) (2026-01-04)


### 📚 词库更新

* 词库调整 ([f39f29f](https://github.com/amzxyz/rime_wanxiang/commit/f39f29f77a5310f09e0aa6683d38f9c00560b6c4))
* 词库调整 ([269a0d3](https://github.com/amzxyz/rime_wanxiang/commit/269a0d38754954c637a7a754ccc8cce20355f2a5))


### 🐛 Bug 修复

* 修复句中反查对双拼编码的提取策略 ([2e12667](https://github.com/amzxyz/rime_wanxiang/commit/2e12667ef86b72a173aa05e9afa3cff851a64e6f))
* 修复句中反查时英文派生策略导致的提交内容异常包含了英文的问题，修复英文造词问题 ([12c5f6c](https://github.com/amzxyz/rime_wanxiang/commit/12c5f6ca7c1fb5699cd49898ca65fd327f19d96c))

## [14.0.4](https://github.com/amzxyz/rime_wanxiang/compare/v14.0.3...v14.0.4) (2026-01-03)


### 📚 词库更新

* 词库调整 ([5a99fd0](https://github.com/amzxyz/rime_wanxiang/commit/5a99fd0da8da002318035efb13dc5f292685286a))

## [14.0.3](https://github.com/amzxyz/rime_wanxiang/compare/v14.0.2...v14.0.3) (2026-01-03)


### 📚 词库更新

* 词库调整 ([3026476](https://github.com/amzxyz/rime_wanxiang/commit/302647626f5ab6761d8e5b640720fc8b956ecd1a))


### 🐛 Bug 修复

* 英文自动空格支持延时销毁加空格的状态 ([dbe140b](https://github.com/amzxyz/rime_wanxiang/commit/dbe140bfec48ae678023fa3b655e9c3328e2e3cf))
* 重新排序英文 ([04bcd39](https://github.com/amzxyz/rime_wanxiang/commit/04bcd39a28779766775f575c05b4e2f5207cd0dc))
* 重新排序英文 ([e41d99a](https://github.com/amzxyz/rime_wanxiang/commit/e41d99a5f3c036ab29683b17214e34d1ac47e774))


### 🏡 杂项

* 调整说明 ([26e87cd](https://github.com/amzxyz/rime_wanxiang/commit/26e87cd11a2bb061866717c02ad546e7f834bbe4))

## [14.0.2](https://github.com/amzxyz/rime_wanxiang/compare/v14.0.1...v14.0.2) (2026-01-03)


### 🐛 Bug 修复

* 混合编码为固定码表 ([a76be86](https://github.com/amzxyz/rime_wanxiang/commit/a76be862c90bf0c57bff399731536aa89fcd7360))

## [14.0.1](https://github.com/amzxyz/rime_wanxiang/compare/v14.0.0...v14.0.1) (2026-01-03)


### 🐛 Bug 修复

* 超级注释放开末尾~，他代表单词未完全输入完成的尾部视觉提示 ([cec8cc5](https://github.com/amzxyz/rime_wanxiang/commit/cec8cc518c6aaf41bb31a07bcf157be1f9550715))

## [14.0.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.12.1...v14.0.0) (2026-01-03)


### 💅 重构

* **english:** 全新的英文方案与配套整句体验 ([d59a373](https://github.com/amzxyz/rime_wanxiang/commit/d59a373b3cb675297016cc167de32d9ee1f808b8))


### 🏡 杂项

* release 14.0.0 ([c9a47d7](https://github.com/amzxyz/rime_wanxiang/commit/c9a47d71cf4e0fa7993ef236c6f8d2184d2c325b))

## [13.12.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.12.0...v13.12.1) (2026-01-02)


### 🐛 Bug 修复

* 调整模型参数 ([fc5367c](https://github.com/amzxyz/rime_wanxiang/commit/fc5367cf3e0700d9f7713a057e48fee029bc25db))

## [13.12.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.11.1...v13.12.0) (2026-01-02)


### ✨ 新特性

* 新增仅英文模式下支持输入英文句子，三元开关组的快捷键也修改为常态化Shift+space不用非要在输入中切换 ([b6ce63c](https://github.com/amzxyz/rime_wanxiang/commit/b6ce63c5a6a5ccc3e9184d53861180120c17b8c8))


### 🐛 Bug 修复

* default不跟随东风破脚本 ([05a6f40](https://github.com/amzxyz/rime_wanxiang/commit/05a6f40bf649a666fd45d885a849d930614eed28))

## [13.11.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.11.0...v13.11.1) (2025-12-31)


### 🐛 Bug 修复

* 英文后符号,.!?后面输入也能自动加空格 ([85243e0](https://github.com/amzxyz/rime_wanxiang/commit/85243e0caee3b47d332102b1aaf5c3cb03bb5739))


### 🏡 杂项

* 修改说明 ([0c29da6](https://github.com/amzxyz/rime_wanxiang/commit/0c29da68f1a19eb1c6fae9b817b6c242393e99a4))

## [13.11.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.10.0...v13.11.0) (2025-12-31)


### ✨ 新特性

* **super_filter:** 新增英文智能空格，前所未有的体验 ([01b1735](https://github.com/amzxyz/rime_wanxiang/commit/01b1735cb2dca525a4fc8daee7cc864fd86d972a))


### 🐛 Bug 修复

* 调整自动化策略 ([79c6a2f](https://github.com/amzxyz/rime_wanxiang/commit/79c6a2f71940d8c65cb2f2ad59433aa57ee78be4))

## [13.10.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.9.5...v13.10.0) (2025-12-31)


### ✨ 新特性

* **seq:** 新增按下Ctrl的时候显示数据库中“被动过”的词条标记，你可以根据这个信息洞察做出决策 ([fd71f4a](https://github.com/amzxyz/rime_wanxiang/commit/fd71f4a96663467022a5a8589510cfde3445f990))


### 📚 词库更新

* 词库调整 ([6b73223](https://github.com/amzxyz/rime_wanxiang/commit/6b7322307fae79b527c70f4e739aa8f0c8389733))


### 🐛 Bug 修复

* 简单调整oday格式 ([91aa62b](https://github.com/amzxyz/rime_wanxiang/commit/91aa62b4719d62ac0bb50fcfdbf917222aa49a5b))
* 词库调整 ([39028a8](https://github.com/amzxyz/rime_wanxiang/commit/39028a8334d549801e8636f01df71fa0dd810bce))

## [13.9.5](https://github.com/amzxyz/rime_wanxiang/compare/v13.9.4...v13.9.5) (2025-12-28)


### 📚 词库更新

* 扩展成语简码 ([be9f100](https://github.com/amzxyz/rime_wanxiang/commit/be9f10058f87a7a955604c77ad30a4068c92d01c))
* 词库调整 ([8409d60](https://github.com/amzxyz/rime_wanxiang/commit/8409d603f4cfdd140146140433f9dfb7fa32823a))
* 词库调整 ([2f93913](https://github.com/amzxyz/rime_wanxiang/commit/2f939138fe2fa41d858373a1c189c54cc21d047a))


### 🐛 Bug 修复

* 变更模型参数 ([c8e3d38](https://github.com/amzxyz/rime_wanxiang/commit/c8e3d380e592021aa1e9cf8ba7e1af64c92bae36))

## [13.9.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.9.3...v13.9.4) (2025-12-25)


### 📚 词库更新

* 词库调整 ([f3f01c1](https://github.com/amzxyz/rime_wanxiang/commit/f3f01c126cde479ead085c581bc5263a37483c74))
* 词库调整 ([c5393ed](https://github.com/amzxyz/rime_wanxiang/commit/c5393ed4b41cb371d771055e1d124d6910e865d1))
* 词库调整 ([c283011](https://github.com/amzxyz/rime_wanxiang/commit/c2830114f4efb39faec053f65f8acc25bce280d0))


### 🐛 Bug 修复

* 完善全拼反查辅筛模式下，两分首字母(声母)的提取策略 ([ab33660](https://github.com/amzxyz/rime_wanxiang/commit/ab3366013883261e2638f7a21cc12815212e2c24))
* 很多被大厂惯坏的用户认为设置成9个能让自己不用翻页，我再多宠爱一下，现在你可以按下0上屏第10个候选 ([6cd1d5e](https://github.com/amzxyz/rime_wanxiang/commit/6cd1d5e87cff3787eab3a482c1e2a13ac4038541))

## [13.9.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.9.2...v13.9.3) (2025-12-24)


### 📚 词库更新

* 词库调整 ([3526d71](https://github.com/amzxyz/rime_wanxiang/commit/3526d7106531100dcc83311a0eade7127f84803f))
* 词库调整 ([e3dd5fa](https://github.com/amzxyz/rime_wanxiang/commit/e3dd5fa4135bf997a2669f811e5beb40aa986e7b))


### 🐛 Bug 修复

* 补齐缺失正则 ([8df3a32](https://github.com/amzxyz/rime_wanxiang/commit/8df3a32cc3b6439a01a1252f33b39a84d24fd6fd))

## [13.9.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.9.1...v13.9.2) (2025-12-24)


### 🐛 Bug 修复

* **shijian.lua:** 新增/rc日期差模式，可通过/rc\d+[-=+op]来生成当前时间从前与未来的日期，=+p都代表未来，-o都代表从前。同时还支持/utc热门世界时钟查询 ([4cf1d23](https://github.com/amzxyz/rime_wanxiang/commit/4cf1d2379dfc92371263a3d4eb9e4d8b1efaedca))


### 🏡 杂项

* 修改说明 ([fbe1697](https://github.com/amzxyz/rime_wanxiang/commit/fbe16976eddf9259707be0077e8eb58a84fe7293))

## [13.9.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.8...v13.9.1) (2025-12-23)


### ✨ 新特性

* 英文造词现在支持按源编码结构写入一份，全小写写入一份，我们很多时候有一些大小写约定结构的词汇 ([bf0affc](https://github.com/amzxyz/rime_wanxiang/commit/bf0affcffd364674413516fd926e43e8f1e21517))


### 📚 词库更新

* add dicts ([e096851](https://github.com/amzxyz/rime_wanxiang/commit/e096851068228a0118b5051c124a6773801d6909))
* 词库调整 ([875c66c](https://github.com/amzxyz/rime_wanxiang/commit/875c66c015be6f83b1bec40c731824eaaf3886db))
* 词库调整 ([8bd56cb](https://github.com/amzxyz/rime_wanxiang/commit/8bd56cbb33ae4ae3c541441fef8ffa7614dc5510))


### 🐛 Bug 修复

* 变更Lua引入顺序解决OpenCC繁体字被字符集过滤的问题 ([29ad19f](https://github.com/amzxyz/rime_wanxiang/commit/29ad19f33fb821954654972a2988ff6a0821c288))
* 同文皮肤加回来14、18键，custom也加了可引用的转写，这些内容将打包到app ([357e51b](https://github.com/amzxyz/rime_wanxiang/commit/357e51b8a625f09a056c967486d3bfd4c5399c79))
* 增加校验规避在[#579](https://github.com/amzxyz/rime_wanxiang/issues/579)提到的Lua更在内容不变的情况下更新时间戳导致同步软件认为变更，进而频繁同步的问题 ([264136e](https://github.com/amzxyz/rime_wanxiang/commit/264136e53fb6a22b839208429502878f2b2869d9))
* 拍扁共键运算 ([8ab48ae](https://github.com/amzxyz/rime_wanxiang/commit/8ab48aecf5663f987f7d9013c27d325e4012ea62))
* 移除声调回退中多余的字符 ([aed63fb](https://github.com/amzxyz/rime_wanxiang/commit/aed63fb7dd4673cf247801cd60ede8d284abbbb8))
* 自动化测试 ([de6a0bf](https://github.com/amzxyz/rime_wanxiang/commit/de6a0bfb0c2c844a1aa6c50145b55eda61be4665))
* 自动化测试 ([1e445fb](https://github.com/amzxyz/rime_wanxiang/commit/1e445fbffa04236737458aa5864ba7807aaeca46))
* 英文造词或者叫首选强制英文统一为\\双击 ([39e39eb](https://github.com/amzxyz/rime_wanxiang/commit/39e39eb030743f71909aa98ffa8c8325e08a49ca))


### 🏡 杂项

* release 13.9.1 ([b59cf1f](https://github.com/amzxyz/rime_wanxiang/commit/b59cf1f642e352310082adfdea6f444b3e143f12))
* release 13.9.1 ([f7749c4](https://github.com/amzxyz/rime_wanxiang/commit/f7749c473e6cd1d6e9dc37b4a27625e867476118))
* release 13.9.1 ([f7749c4](https://github.com/amzxyz/rime_wanxiang/commit/f7749c473e6cd1d6e9dc37b4a27625e867476118))

## [13.8.8](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.7...v13.8.8) (2025-12-20)


### 🐛 Bug 修复

* 间接辅助模式增加直接大写 ([05205a9](https://github.com/amzxyz/rime_wanxiang/commit/05205a9f0a5aa5acbd572dc5f140a198849327c8))

## [13.8.7](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.6...v13.8.7) (2025-12-19)


### 📚 词库更新

* 词库调整 ([13649d3](https://github.com/amzxyz/rime_wanxiang/commit/13649d3e387f26fb0b9844b00bcf4d77357282eb))
* 词库调整 ([b65cd42](https://github.com/amzxyz/rime_wanxiang/commit/b65cd42cf19a109bb1f6f7c6dec4e71b08cd32c7))
* 词库调整 ([e266c1b](https://github.com/amzxyz/rime_wanxiang/commit/e266c1ba435aa77a416aa8301bdca60c04e7762c))


### 🐛 Bug 修复

* 新增自动化apk打包 ([2546d14](https://github.com/amzxyz/rime_wanxiang/commit/2546d14e788f9e03d25b0f74694f6053ae097d8a))
* 新增自动化apk打包 ([7afc840](https://github.com/amzxyz/rime_wanxiang/commit/7afc8404d8bcb5b18adf4b3f3a888f01d02b3adc))
* 新增自动化apk打包 ([65a4a3f](https://github.com/amzxyz/rime_wanxiang/commit/65a4a3f665431c7e8a5a219b9865088ea52b7c1e))

## [13.8.6](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.5...v13.8.6) (2025-12-15)


### 📚 词库更新

* 词库调整 ([fd659c9](https://github.com/amzxyz/rime_wanxiang/commit/fd659c984c2ad9dbb9050334714fa877a32a0165))
* 词库调整 ([dd2150c](https://github.com/amzxyz/rime_wanxiang/commit/dd2150c28f93f06b7d7bef2864eeaf72b3248282))


### 🐛 Bug 修复

* **super_lookup:** 采用全新的词组匹配算法，支持有序模糊，词组匹配不再需要复杂的设计对应到某个字就像单字那样按序输入即可，pro支持词库辅助码数据，两类数据可方案中配置启用类型，支持两类顺序优先进而候选排序优先 ([b42985a](https://github.com/amzxyz/rime_wanxiang/commit/b42985ad1d0630ffeec86c6d40bdfa8c2cfcef64))
* 增加仓、元数统计中的命名 ([455309c](https://github.com/amzxyz/rime_wanxiang/commit/455309c3cc222a2ab4898262cc5cd512d584582d))


### 🏡 杂项

* 修改说明 ([46bd670](https://github.com/amzxyz/rime_wanxiang/commit/46bd670e04d65ed83d1a9c5fa9b079e01e48a3cb))

## [13.8.5](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.4...v13.8.5) (2025-12-11)


### 📚 词库更新

* 词库调整 ([385d764](https://github.com/amzxyz/rime_wanxiang/commit/385d764930c2438c73e9d596cd8202869bbd51ae))


### 🐛 Bug 修复

* 微调统计格式结构 ([97596ef](https://github.com/amzxyz/rime_wanxiang/commit/97596efed3f5073ae5f029ec37c08e44e2a90b33))

## [13.8.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.3...v13.8.4) (2025-12-11)


### 🐛 Bug 修复

* 小键盘Lua优化 ([0ceeb87](https://github.com/amzxyz/rime_wanxiang/commit/0ceeb87b8e425afd9617bb337babbe87a9c65196))


### 🏡 杂项

* 修改说明 ([0049d92](https://github.com/amzxyz/rime_wanxiang/commit/0049d926fb596df79506be7dce96bf8a6c960de7))

## [13.8.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.2...v13.8.3) (2025-12-11)


### 📚 词库更新

* 词库调整 ([4c0572f](https://github.com/amzxyz/rime_wanxiang/commit/4c0572f9d7c4ec44b45e65e2e8f29673e3cb901e))


### 🐛 Bug 修复

* 紧急调整，正则依赖更新导致全角字符不能按.匹配 ([c96afbd](https://github.com/amzxyz/rime_wanxiang/commit/c96afbd59cd032f204b48e576faaeed8be5b66b3))

## [13.8.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.1...v13.8.2) (2025-12-11)


### 🐛 Bug 修复

* 优化模糊音写法 ([71e9742](https://github.com/amzxyz/rime_wanxiang/commit/71e9742bce96ac41e85d53e24a98bb9189f6ed7c))
* 移动设备小键盘逻辑同主键盘 ([f3a9bb4](https://github.com/amzxyz/rime_wanxiang/commit/f3a9bb49858a09a0650b4ed27606f8cccdfcb172))

## [13.8.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.8.0...v13.8.1) (2025-12-11)


### 🐛 Bug 修复

* 修复统计数据格式化错误 ([c28793d](https://github.com/amzxyz/rime_wanxiang/commit/c28793d87e05d25913f4836be200b4d470bfe3bf))
* 直接辅助支持大写辅助 ([6108845](https://github.com/amzxyz/rime_wanxiang/commit/6108845d0e2c19ec0b6e3648364fd532507c496b))


### 🏡 杂项

* 更新版本 ([5232b97](https://github.com/amzxyz/rime_wanxiang/commit/5232b97e0b0ff6662cf195c466ecf53536da65e4))

## [13.8.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.7.2...v13.8.0) (2025-12-10)


### ✨ 新特性

* 统计新增数据库储存方式，全新的格式化样式，多数据维度 ([3d21e84](https://github.com/amzxyz/rime_wanxiang/commit/3d21e84609895595b902596ef05a79750fa5f18d))


### 📚 词库更新

* 词库调整 ([71fa958](https://github.com/amzxyz/rime_wanxiang/commit/71fa9583d8a8d545d523564c694007f688f81f01))
* 词库调整 ([986f2e2](https://github.com/amzxyz/rime_wanxiang/commit/986f2e293a9354e4487c80036b9b455939a5aa78))

## [13.7.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.7.1...v13.7.2) (2025-12-10)


### 📚 词库更新

* 自然码辅助删除部分兼容 ([641d352](https://github.com/amzxyz/rime_wanxiang/commit/641d352084164b2c3846ed1772bcaa0f4ff575e1))
* 词库调整 ([dccd8cc](https://github.com/amzxyz/rime_wanxiang/commit/dccd8cc387bfa4da3c5f7b46852355a439bc059b))
* 词库调整 ([04a6c87](https://github.com/amzxyz/rime_wanxiang/commit/04a6c87e9bda4ad52de622652816d1726ac2ee61))
* 词库调整 ([bf4d252](https://github.com/amzxyz/rime_wanxiang/commit/bf4d2523e9ef9dc8fab9d0496196bbcf66c98c0c))
* 词库调整 ([966f732](https://github.com/amzxyz/rime_wanxiang/commit/966f732fa25b2356250edb1173fd90227dbdf9bc))
* 词库调整 ([88805d2](https://github.com/amzxyz/rime_wanxiang/commit/88805d29024b9991d311154a5287835a1d895da1))
* 词库调整 ([3276e30](https://github.com/amzxyz/rime_wanxiang/commit/3276e30ea178876538e1daf6363b9cf49fbd7390))


### 🐛 Bug 修复

* lookup反查策略变更，更简约，同时修复笔画变更编码导致的无法查询 ([39f08e5](https://github.com/amzxyz/rime_wanxiang/commit/39f08e5b2ada2ae858ca18752fad12e133719ebf))
* 增加对号叉号/ch,/dh序列 ([b3256f2](https://github.com/amzxyz/rime_wanxiang/commit/b3256f28b91b33bce19a92d5800882b9de91a301))


### 📖 文档

* AUR 包将删除 ([c366647](https://github.com/amzxyz/rime_wanxiang/commit/c36664787ce3e5b95a253264008e8f341c0b87ff))

## [13.7.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.7.0...v13.7.1) (2025-12-06)


### 📚 词库更新

* 词库调整 ([8b306f0](https://github.com/amzxyz/rime_wanxiang/commit/8b306f0ba8c465fb21f3635baff55dca61461bf3))


### 🐛 Bug 修复

* 移除alt跳转存在多平台不一致的多种问题，移除龙三 ([974ca2d](https://github.com/amzxyz/rime_wanxiang/commit/974ca2da176076225216c1e968d9a57fe3d33e9b))

## [13.7.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.6.5...v13.7.0) (2025-12-05)


### ✨ 新特性

* 新增alt+字母跳转对应编码后面，但asdt等字母有被rime屏蔽，其他快捷键有不同程度占用，先发布 ([f129585](https://github.com/amzxyz/rime_wanxiang/commit/f1295850ee7dad64a7c7ec4791f77d381c2944a8))


### 📚 词库更新

* 词库调整 ([3ec0c32](https://github.com/amzxyz/rime_wanxiang/commit/3ec0c32b053093245cab286108a5f00faab0edb7))


### 🐛 Bug 修复

* 修复N模式正则错写 ([8c601c4](https://github.com/amzxyz/rime_wanxiang/commit/8c601c4774193ed20a56cdceea08b340e127581b))

## [13.6.5](https://github.com/amzxyz/rime_wanxiang/compare/v13.6.4...v13.6.5) (2025-12-04)


### 📚 词库更新

* 词库调整 ([84d0f75](https://github.com/amzxyz/rime_wanxiang/commit/84d0f755c5295e5a1533b4ebec9ec88ae8012373))
* 词库调整 ([6110ca4](https://github.com/amzxyz/rime_wanxiang/commit/6110ca4e2fdf3615233550f1907eafaab421be4b))
* 词库调整 ([acad858](https://github.com/amzxyz/rime_wanxiang/commit/acad858d999ed5aed19e37280c95aef49641490a))

## [13.6.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.6.3...v13.6.4) (2025-12-03)


### 📚 词库更新

* 词库调整 ([6aea67c](https://github.com/amzxyz/rime_wanxiang/commit/6aea67ce88741f37e3dd769ed7209fdb542dd308))
* 词库调整 ([54bdcca](https://github.com/amzxyz/rime_wanxiang/commit/54bdcca658c9c7234f0f990df39bc1b0462d1152))
* 词库调整 ([dab8fca](https://github.com/amzxyz/rime_wanxiang/commit/dab8fca8fd27cea088a9ad4aa8e683908876df01))


### 🐛 Bug 修复

* 增加一些细化的场景 ([d3ef1f5](https://github.com/amzxyz/rime_wanxiang/commit/d3ef1f51835fce3a84c8e6a066d4537c2a040996))
* 改进转写 ([9934fc6](https://github.com/amzxyz/rime_wanxiang/commit/9934fc64e090f12b4e392edbbb6d97690adf4fdd))

## [13.6.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.6.2...v13.6.3) (2025-12-02)


### 🐛 Bug 修复

* 移除手机端判断 ([937ae6d](https://github.com/amzxyz/rime_wanxiang/commit/937ae6d220bd75f8e7977333bab51898376da562))

## [13.6.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.6.1...v13.6.2) (2025-12-02)


### 🐛 Bug 修复

* 回复误删除函数 ([ce406eb](https://github.com/amzxyz/rime_wanxiang/commit/ce406eb8e1d262f381d073f3f865186bf2bd3799))

## [13.6.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.6.0...v13.6.1) (2025-12-02)


### 🐛 Bug 修复

* 让小狼毫不检测路径直接使用相对路径 ([f953655](https://github.com/amzxyz/rime_wanxiang/commit/f953655cbe718543e5840e2040ba7403eff17cf5))

## [13.6.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.5.5...v13.6.0) (2025-12-02)


### ✨ 新特性

* 新增小键盘双模式策略 ([c016b07](https://github.com/amzxyz/rime_wanxiang/commit/c016b075338013ecbec8272222c5e2aba064ecaf))


### 📚 词库更新

* 词库调整 ([97143ee](https://github.com/amzxyz/rime_wanxiang/commit/97143eea3c5b139b7918ad2c08a6464847f9b3bd))
* 词库调整 ([d3eba76](https://github.com/amzxyz/rime_wanxiang/commit/d3eba7614308102b7e5f1668bb46d77c9a42000e))


### 🐛 Bug 修复

* **lua:** get_filename_with_fallback 用户目录使用传入路径 ([3ad1378](https://github.com/amzxyz/rime_wanxiang/commit/3ad137822c812365c8d1cfd119e6a2f7b2aba44c))
* 为配合小键盘输入，preedit转换数字两个以上挨着的不转换,保持编码大小一致性 ([551a51d](https://github.com/amzxyz/rime_wanxiang/commit/551a51dba843e257ef0b9ee3aa0af281dc4cc76d))
* 主键盘策略要在需要数字作为编码的情况下去掉上屏动作维持输入状态 ([9142f4e](https://github.com/amzxyz/rime_wanxiang/commit/9142f4e299b23dd1f7bcbcf6e22d208ecb44450c))
* 修复上屏提交算法 ([de7f0bc](https://github.com/amzxyz/rime_wanxiang/commit/de7f0bc05de0643b796909a8956a11f9d65df198))
* 修复不能再中间补充分隔符的问题 ([2077b92](https://github.com/amzxyz/rime_wanxiang/commit/2077b92ba8340b2920f1e0f6bece59d07515eca5))
* 修正主键盘逻辑 ([3eb65b0](https://github.com/amzxyz/rime_wanxiang/commit/3eb65b02b3575f284146d9676fd6fec9823d6dce))
* 原本没有候编码后按下\可创建首选英文词，现在支持有候选的时候按两下\\创建英文候选词，两种状态下创建的候选都能被记录到en.userdb ([621d5de](https://github.com/amzxyz/rime_wanxiang/commit/621d5dee1954c00c81395ba1a26639c09a6f6f70))
* 更新 ([5de6db6](https://github.com/amzxyz/rime_wanxiang/commit/5de6db66656d1b088698d9474acb2e796e3d7271))
* 由于新增小键盘输入中功能逻辑，现在将声调回退功能做限制，只有主键盘的7890才触发回退 ([714bc8b](https://github.com/amzxyz/rime_wanxiang/commit/714bc8b73866e43362e4a1323b35118078912a94))
* 细化N模式正则，提供恰到好处地数字键上屏体验 ([2839dd4](https://github.com/amzxyz/rime_wanxiang/commit/2839dd4b17eee7c9a3bf7b7ba0c57a2596897bf3))
* 自动化变更 ([c041b7b](https://github.com/amzxyz/rime_wanxiang/commit/c041b7bc8be0d9d81c52c31a2e4edb1d22160c59))
* 自动化变更 ([f4126e1](https://github.com/amzxyz/rime_wanxiang/commit/f4126e1b541854a5c536f18d7b76c77e13bd81e5))
* 调整Utag ([ea6ab26](https://github.com/amzxyz/rime_wanxiang/commit/ea6ab2660be3e9550c156a1fdd0057950de4052f))
* 键盘上屏还是输入的策略以正则组的形式提供 ([ab89afb](https://github.com/amzxyz/rime_wanxiang/commit/ab89afb601c2c8f9d4081015080cd67c87f4cb8e))


### 🏡 杂项

* 修改说明 ([76a39f2](https://github.com/amzxyz/rime_wanxiang/commit/76a39f23c38c8fe2e8715f414ac5ea6d657117f5))
* 修改说明 ([8f6b8e8](https://github.com/amzxyz/rime_wanxiang/commit/8f6b8e82c19c2df6b404165c306a23a0fe37832e))
* 修改说明 ([5fcf6eb](https://github.com/amzxyz/rime_wanxiang/commit/5fcf6ebcd30d1c898f79ab386079db134887a62d))

## [13.5.5](https://github.com/amzxyz/rime_wanxiang/compare/v13.5.4...v13.5.5) (2025-11-30)


### 🐛 Bug 修复

* 有时英文候选输入会同时派生一些生僻字在次选，比较碍眼，做了一点逻辑规避 ([f20c483](https://github.com/amzxyz/rime_wanxiang/commit/f20c48346c1d5f11262503a0a0fbc29c4d047e9f))

## [13.5.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.5.3...v13.5.4) (2025-11-30)


### 🐛 Bug 修复

* 恢复不小心去掉的lookup ([33616f7](https://github.com/amzxyz/rime_wanxiang/commit/33616f742e9d7948d31960e19458a9a4a75e39ee))
* 自动化变更 ([cf8f8d8](https://github.com/amzxyz/rime_wanxiang/commit/cf8f8d8b96cd7a470b10a60b2f6bef20201a2850))
* 自动化变更 ([7dfd990](https://github.com/amzxyz/rime_wanxiang/commit/7dfd990412dbc9d804be5e66081d689a818e4e21))


### 🏡 杂项

* 修改说明 ([cb92b45](https://github.com/amzxyz/rime_wanxiang/commit/cb92b45d0b7c61f2d935ca768b0f7af44384ade1))

## [13.5.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.5.2...v13.5.3) (2025-11-30)


### 🐛 Bug 修复

* **super_filter:** 字符集数据路径兼容系统目录 ([fe2f7da](https://github.com/amzxyz/rime_wanxiang/commit/fe2f7dabc216ad2238f4c3ab7039c71ae5f31f47))

## [13.5.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.5.1...v13.5.2) (2025-11-29)


### 🐛 Bug 修复

* 字符集过滤仅限单字 ([ebf255b](https://github.com/amzxyz/rime_wanxiang/commit/ebf255b4c486cd8186228b7d78c957fbbcc1f49d))

## [13.5.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.5.0...v13.5.1) (2025-11-29)


### 📚 词库更新

* 词库调整 ([7a955f7](https://github.com/amzxyz/rime_wanxiang/commit/7a955f7b116c4a627ea29b4ea303e678e8ad4c6e))


### 🐛 Bug 修复

* 修复preedit转换声调的bug ([2f567ee](https://github.com/amzxyz/rime_wanxiang/commit/2f567eead5b93538e1ca83aed0e2eb12162a8843))

## [13.5.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.12...v13.5.0) (2025-11-29)


### ✨ 新特性

* 合并字符集过滤功能滤镜，并采用全新方式给用户留出自定义空间，从而可以放心移除了charset方案和词库文件，进一步完成了功能的垂直整合，方案文件结构更加紧密 ([c35f63d](https://github.com/amzxyz/rime_wanxiang/commit/c35f63db8b32dcd790b081beff0ccc0db77c6083))


### 📚 词库更新

* 词库调整 ([44afdae](https://github.com/amzxyz/rime_wanxiang/commit/44afdae8ce86732161f528061b9d39e8819942dc))

## [13.4.12](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.11...v13.4.12) (2025-11-29)


### 📚 词库更新

* 词库调整 ([f39e32a](https://github.com/amzxyz/rime_wanxiang/commit/f39e32a9e8ebb77f299921d475995663a3d3e984))


### 🐛 Bug 修复

* 调整快捷键 ([c38854d](https://github.com/amzxyz/rime_wanxiang/commit/c38854d8f0f0edcd0eada90e8bb722f09caa0081))

## [13.4.11](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.10...v13.4.11) (2025-11-28)


### 🐛 Bug 修复

* 调整Lua顺序 ([da4ebce](https://github.com/amzxyz/rime_wanxiang/commit/da4ebcee58253ec892ce703987d6be64a97e664b))


### 🏡 杂项

* 修改说明 ([a2e2d8a](https://github.com/amzxyz/rime_wanxiang/commit/a2e2d8ab4cc124650d55b2805bb4187035db01a4))

## [13.4.10](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.9...v13.4.10) (2025-11-28)


### 📚 词库更新

* 归类-物化生医药-地矿-基础 ([8b46c98](https://github.com/amzxyz/rime_wanxiang/commit/8b46c988a0aa4da2537ea0df3b6ad0cdcf0eb3c7))
* 归类物化生、物种词库 ([2c580a5](https://github.com/amzxyz/rime_wanxiang/commit/2c580a5260725532ae4119c6a9494d28172c6206))
* 归类物化生医药 ([7a8e512](https://github.com/amzxyz/rime_wanxiang/commit/7a8e5127a3d5ed0fcd2293759cd5996c5d584850))
* 归类物种、物化生医药词库 ([7303774](https://github.com/amzxyz/rime_wanxiang/commit/7303774690e9cd9f3c68551086755e9e93ad02e9))
* 归类至地矿、物化生医药、联想、基础 ([5779c45](https://github.com/amzxyz/rime_wanxiang/commit/5779c450b294cb431855e846bf2fc783ae824d33))
* 归类至物种、物化生医药 ([285ac5e](https://github.com/amzxyz/rime_wanxiang/commit/285ac5e5b61ad608018e8d48e6703a356d3016b7))
* 词库调整 ([8db858b](https://github.com/amzxyz/rime_wanxiang/commit/8db858b2f1e6c86c9dbde3f239b8d2990339fb0a))
* 词库调整 ([8732ec7](https://github.com/amzxyz/rime_wanxiang/commit/8732ec7e8b9d6aaff5c1f4735cb29742494924d6))
* 词库调整 ([7a0a451](https://github.com/amzxyz/rime_wanxiang/commit/7a0a451a6af83c444d7db6472d6c292626ae9fb4))
* 词库调整 ([8a5d757](https://github.com/amzxyz/rime_wanxiang/commit/8a5d757a908237a5b9fdf41aa2b3abbc63ac41ad))
* 词库调整 ([9e1f6ba](https://github.com/amzxyz/rime_wanxiang/commit/9e1f6baba817cbed9db1bb3d4e52337743932ca3))
* 词库调整 ([5a70301](https://github.com/amzxyz/rime_wanxiang/commit/5a70301340ebf1d16124d305e0836bc62d870de7))
* 词库调整 ([9ed0a78](https://github.com/amzxyz/rime_wanxiang/commit/9ed0a78f3665276c1cb11e2b7d51ccee9c184c2c))
* 词库调整 ([1bfa673](https://github.com/amzxyz/rime_wanxiang/commit/1bfa6733d4df387db0ffe1b6c8a8b1e769ad5823))
* 词库调整 ([d76f773](https://github.com/amzxyz/rime_wanxiang/commit/d76f77375d830def8ae6d58e80243bc6e752fdaf))
* 词库调整 ([f874428](https://github.com/amzxyz/rime_wanxiang/commit/f87442870fedc349ce8f26a9ccfe2dada930a183))
* 词库调整 ([99569e6](https://github.com/amzxyz/rime_wanxiang/commit/99569e633119dee92593273217122016d7f25f36))
* 词库调整 ([1a008f6](https://github.com/amzxyz/rime_wanxiang/commit/1a008f6388b2cb4a5d36778896f78b1715bb9e92))
* 调整九键转写 ([95d6a5e](https://github.com/amzxyz/rime_wanxiang/commit/95d6a5e1dabc7068374a5455339587e2288b6f6d))

## [13.4.9](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.8...v13.4.9) (2025-11-27)


### 📚 词库更新

* 细化细胞词库 ([c30450c](https://github.com/amzxyz/rime_wanxiang/commit/c30450c42818e475b69c8bdb17f79531ffc69ccd))
* 默认注释掉两个细胞词库 ([09d1594](https://github.com/amzxyz/rime_wanxiang/commit/09d1594157de71e16ea72e38e940ec3dcacea721))

## [13.4.8](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.7...v13.4.8) (2025-11-25)


### 🐛 Bug 修复

* 修正opencc数据重复导致的无法工作 ([7337e1c](https://github.com/amzxyz/rime_wanxiang/commit/7337e1cdf0bca8373d521636a45deac3e5f55b05))

## [13.4.7](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.6...v13.4.7) (2025-11-24)


### 📚 词库更新

* 归类《三字经》词条 ([ac766c3](https://github.com/amzxyz/rime_wanxiang/commit/ac766c3afa9a2c758351188076eb13c82e49ea95))
* 词库调整 ([f804c61](https://github.com/amzxyz/rime_wanxiang/commit/f804c610845035d1c2fa5b860b763e7aa1a3f611))
* 词库调整 ([009f8f9](https://github.com/amzxyz/rime_wanxiang/commit/009f8f9c210e9b40a6ef439c024a7e9850177b9b))
* 词库调整 ([31135e6](https://github.com/amzxyz/rime_wanxiang/commit/31135e691ec72b9d128a1afc2649b3392939c0bc))
* 词库调整 ([caf175e](https://github.com/amzxyz/rime_wanxiang/commit/caf175e7f5872e0663639e51d62d6371da3d898c))
* 词库调整 ([bbe5e6e](https://github.com/amzxyz/rime_wanxiang/commit/bbe5e6ef60f10ad6ef790239dd847050c5bdc670))
* 词库调整 ([565547d](https://github.com/amzxyz/rime_wanxiang/commit/565547d1331bd2f3e6cce56b90596faf5e7ad84b))


### 🐛 Bug 修复

* **lua:** tips高亮相关上游更新移除相关代码[#260](https://github.com/amzxyz/rime_wanxiang/issues/260) ([c83c217](https://github.com/amzxyz/rime_wanxiang/commit/c83c217d2d72252eb132cad438f400511b40a9e6))
* 调整模型测试参数 ([d5e6501](https://github.com/amzxyz/rime_wanxiang/commit/d5e6501179404fa3c2322fde22b454439f0ae861))

## [13.4.6](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.5...v13.4.6) (2025-11-21)


### 🐛 Bug 修复

* 处理脚本导致的错误 ([57c6877](https://github.com/amzxyz/rime_wanxiang/commit/57c6877dbeb7f72bd46b6937fa083b79a95652b8))

## [13.4.5](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.4...v13.4.5) (2025-11-21)


### 📚 词库更新

* 词库调整 ([c5839c3](https://github.com/amzxyz/rime_wanxiang/commit/c5839c3aadfb771d453ea117beb37cd98eea6a89))


### 🐛 Bug 修复

* 由于windows系统utf-8问题文件名变更为采用拼音命名 ([8f87a91](https://github.com/amzxyz/rime_wanxiang/commit/8f87a91fde6a59a7d0250242c4eef57db4448e48))

## [13.4.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.3...v13.4.4) (2025-11-21)


### 📚 词库更新

* 词库调整 ([75b83b1](https://github.com/amzxyz/rime_wanxiang/commit/75b83b1807cf5c6f26757061dd2dc2ee4769b66b))
* 调整生物词库 ([6c4c60c](https://github.com/amzxyz/rime_wanxiang/commit/6c4c60c3f79e979bde8b1e0f3281a8feeebc4736))

## [13.4.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.2...v13.4.3) (2025-11-20)


### 📚 词库更新

* 词库调整 ([e5d7cb6](https://github.com/amzxyz/rime_wanxiang/commit/e5d7cb652254d4eb0b46e9f3f1ded9b5bc1f35b4))
* 词库调整 ([16d2ede](https://github.com/amzxyz/rime_wanxiang/commit/16d2edecc84e935cc957d8d0fd40e4fbb410c39a))
* 词库调整 ([69ab8d0](https://github.com/amzxyz/rime_wanxiang/commit/69ab8d04006dd809ed643ee820b3effa81ed3c92))


### 🐛 Bug 修复

* 九宫格转写调整 ([2efbc50](https://github.com/amzxyz/rime_wanxiang/commit/2efbc50c5f1883ff1808055870c016a4cebd6593))
* 九宫格转写调整 ([bcee91d](https://github.com/amzxyz/rime_wanxiang/commit/bcee91db15953d483dd63b530d78171ed5db41f7))

## [13.4.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.1...v13.4.2) (2025-11-20)


### 📚 词库更新

* 词库使用中文名称 ([073d067](https://github.com/amzxyz/rime_wanxiang/commit/073d0673e29713c1184eaa04e2143095f09b39d7))
* 词库调整 ([d120230](https://github.com/amzxyz/rime_wanxiang/commit/d120230b529945eb361677b9497d12aa866979a4))
* 词库调整 ([a985000](https://github.com/amzxyz/rime_wanxiang/commit/a9850005011597c7448e5d4c12dd501ba5ee4422))
* 词库调整 ([76544e6](https://github.com/amzxyz/rime_wanxiang/commit/76544e6ee12c57012a130a82a0c3a4a3c3124f1e))


### 🐛 Bug 修复

* 若干调整 ([c5b845c](https://github.com/amzxyz/rime_wanxiang/commit/c5b845cf236fbce57178bcd90859041a7bd32c86))

## [13.4.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.4.0...v13.4.1) (2025-11-18)


### 🐛 Bug 修复

* 调整转写 ([fc49fca](https://github.com/amzxyz/rime_wanxiang/commit/fc49fca599eb3fe74d19f3a91605a151c2b0333c))

## [13.4.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.17...v13.4.0) (2025-11-18)


### ✨ 新特性

* 新增万象双拼 ([5cc99fb](https://github.com/amzxyz/rime_wanxiang/commit/5cc99fbbff726ffa1843f9feeef5eb9db35dba04))


### 📚 词库更新

* 词库调整 ([c112067](https://github.com/amzxyz/rime_wanxiang/commit/c1120671a447a26cf8124d77fc7862346a277aa7))


### 🐛 Bug 修复

* NUM contamination (https://github.com/amzxyz/rime_wanxiang/issues/555) ([10167b2](https://github.com/amzxyz/rime_wanxiang/commit/10167b2e60c7a2f578f5d7ae2e9b33b002d91bee))
* 修复拼音加加拼写运算的问题 ([6f148a7](https://github.com/amzxyz/rime_wanxiang/commit/6f148a713fb80dedc4fda8aef5ab1c4b85d43d4c))

## [13.3.17](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.16...v13.3.17) (2025-11-17)


### 📚 词库更新

* 词库调整 ([b716a01](https://github.com/amzxyz/rime_wanxiang/commit/b716a01a1b68e2d989cc03189463aacf65e14c0d))

## [13.3.16](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.15...v13.3.16) (2025-11-17)


### 📚 词库更新

* 词库调整 ([48d9ba3](https://github.com/amzxyz/rime_wanxiang/commit/48d9ba3c6fba706e8e2ed236125f23f2cf94966f))
* 词库调整 ([76acc1d](https://github.com/amzxyz/rime_wanxiang/commit/76acc1d622baf20ce5f70884a4250e567e346367))

## [13.3.15](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.14...v13.3.15) (2025-11-16)


### 📚 词库更新

* 词库调整 ([7e7cdbf](https://github.com/amzxyz/rime_wanxiang/commit/7e7cdbf6cc3eeb997f6ae3d01c3714725ff51921))

## [13.3.14](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.13...v13.3.14) (2025-11-16)


### 📚 词库更新

* 生物词库整理 ([57eaa3b](https://github.com/amzxyz/rime_wanxiang/commit/57eaa3bd76e2f638d6953bba1ba820bd71577da8))


### 🐛 Bug 修复

* 同步首右的辅助码更新 ([70d7793](https://github.com/amzxyz/rime_wanxiang/commit/70d7793f2f86870b32350a6eb80e951820d6420e))
* 自然码辅助删减兼容 ([352d5a0](https://github.com/amzxyz/rime_wanxiang/commit/352d5a0e38a4653b8161a0b4d9ba9ca7085d13a3))
* 调整模型参数以匹配新的模型数据 ([a552813](https://github.com/amzxyz/rime_wanxiang/commit/a5528130c786ad3ac6eef7a83058ce45a8e81b1c))
* 调整若干细节 ([2871b21](https://github.com/amzxyz/rime_wanxiang/commit/2871b21d9840cf45d320628c503cf9415a8d42bf))


### 🏡 杂项

* 修改说明 ([d109f95](https://github.com/amzxyz/rime_wanxiang/commit/d109f95b48e2c747e82249af7579de04ffef0a9d))

## [13.3.13](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.12...v13.3.13) (2025-11-14)


### 📚 词库更新

* 整理生物学词库 ([66cf587](https://github.com/amzxyz/rime_wanxiang/commit/66cf587a7cbcb3f3305abe15c025a1b14ec3a1b2))
* 整理生物学词库 ([23ee04c](https://github.com/amzxyz/rime_wanxiang/commit/23ee04ca377d835f1a4d1f8c8765dd3b533d02ef))
* 词库调整 ([4d6ab58](https://github.com/amzxyz/rime_wanxiang/commit/4d6ab58366abaaa6d2fbc6196c6b535e0a47e918))
* 词库调整 ([621a326](https://github.com/amzxyz/rime_wanxiang/commit/621a3260a9a33233296a1b37e59beb58bc0b107c))
* 词库调整 ([c982719](https://github.com/amzxyz/rime_wanxiang/commit/c982719107b475b97bccf592365c88babf1ba944))
* 词库调整 ([d79bef1](https://github.com/amzxyz/rime_wanxiang/commit/d79bef1094d60958eb85e6f20e78a17c2e869add))
* 词库调整 ([5d42e87](https://github.com/amzxyz/rime_wanxiang/commit/5d42e8708dab35be12c7fc941b7df46eedded1e3))
* 词库调整 ([db69ba3](https://github.com/amzxyz/rime_wanxiang/commit/db69ba34953859770f7d72d4b62f715afbc5cd60))


### 🐛 Bug 修复

* **lua:** 修复ctrl+数字上屏功能中，光标不在末尾补充编码时导致整段input与光标前preedit组合成的上下文信息，致使消耗编码错位的问题 ([f2f8c72](https://github.com/amzxyz/rime_wanxiang/commit/f2f8c72fa22bd628825d26c1ba4bcb4718afd390))
* **lua:** 限制上下文变量范围 ([8910c74](https://github.com/amzxyz/rime_wanxiang/commit/8910c745c32764745d7c4cde0c7381a9c2ef87ba))


### 🏡 杂项

* 更新 README.md ([69a7907](https://github.com/amzxyz/rime_wanxiang/commit/69a79077de7f762e4002c7397d00197b4e4053e6))

## [13.3.12](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.11...v13.3.12) (2025-11-08)


### 📚 词库更新

* 词库调整 ([2096a37](https://github.com/amzxyz/rime_wanxiang/commit/2096a370ad99467328f3cd3f378fcc10dbc0a7ee))


### 🐛 Bug 修复

* 修复日期格式化错误 ([8796b16](https://github.com/amzxyz/rime_wanxiang/commit/8796b1637bd980369603b7cf613ee11c9a0ed9a9))

## [13.3.11](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.10...v13.3.11) (2025-11-08)


### 📚 词库更新

* 调整生物学词库 ([25d2c0e](https://github.com/amzxyz/rime_wanxiang/commit/25d2c0e3a78f4d6505b7921d6c36a46ebbbc4684))


### 🐛 Bug 修复

* 修复日期格式化错误 ([56955d7](https://github.com/amzxyz/rime_wanxiang/commit/56955d7a0381045187b181dd4ea273e8ae8c00d9))

## [13.3.10](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.9...v13.3.10) (2025-11-08)


### 📚 词库更新

* 词库调整 ([ee91f52](https://github.com/amzxyz/rime_wanxiang/commit/ee91f52c778053cd9f185fe489e47ad0af7c1e8f))


### 🐛 Bug 修复

* 修复N模式qwert错误的导致上屏问题，并新增/dt,/sj的自定义能力，结合之前的/sj,N0101整个能力更加完整 ([dd16f49](https://github.com/amzxyz/rime_wanxiang/commit/dd16f4961d2766ba45da488a0fb9685b97dc93ef))
* 修复自定义的preedit转换逻辑 ([b1f0db1](https://github.com/amzxyz/rime_wanxiang/commit/b1f0db119eb8840e65283b3a6701797e49113c10))

## [13.3.9](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.8...v13.3.9) (2025-11-07)


### 🐛 Bug 修复

* 修复国标、加加base版本转写 ([d885ed2](https://github.com/amzxyz/rime_wanxiang/commit/d885ed2414a36882bf64b7083dc45feafa246a46))
* 修复声调拼音状态下ctrl+数字上屏不可用的问题 ([df4003a](https://github.com/amzxyz/rime_wanxiang/commit/df4003aeadc3c1692a9e2349140164be683ab481))
* 关闭Lua日志 ([0cb0ac1](https://github.com/amzxyz/rime_wanxiang/commit/0cb0ac17c9f0f2740a053b9df83d9bf55dc1b3ec))

## [13.3.8](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.7...v13.3.8) (2025-11-07)


### 🐛 Bug 修复

* 新增NR开头的模式下使用qwertyuio替代数字来选词上屏 ([1ed9e44](https://github.com/amzxyz/rime_wanxiang/commit/1ed9e44fc2eb498839df1faf9536a9359d8c69c6))

## [13.3.7](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.6...v13.3.7) (2025-11-07)


### 🐛 Bug 修复

* 句子局部提交改用Lua实现，这与按键定义中ctrl+1~0冲突，请大家更新后删除custom文件中相关引用段落 ([d4153e2](https://github.com/amzxyz/rime_wanxiang/commit/d4153e2e55df45e16f9db284c3e4f15208a3f709))

## [13.3.6](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.5...v13.3.6) (2025-11-07)


### 🐛 Bug 修复

* 句子局部提交改用Lua实现，这与按键定义中ctrl+1~0冲突，请大家更新后删除custom文件中相关引用段落 ([ca7975d](https://github.com/amzxyz/rime_wanxiang/commit/ca7975d9acbd231eb5a7ad07bf971509a47250ca))

## [13.3.5](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.4...v13.3.5) (2025-11-06)


### 📚 词库更新

* 词库调整 ([d250e72](https://github.com/amzxyz/rime_wanxiang/commit/d250e725f048c7d2f9a25517b2ce3a3b8c9a50d3))


### 🐛 Bug 修复

* 为了解决大家不会用的问题，位于custom预设了两种ctrl+数字跳转对应音节并提交前半部分，此举可能会造成通过行数patch其他功能的用户参数不正确，请大家手工做出调整 ([9d7a25c](https://github.com/amzxyz/rime_wanxiang/commit/9d7a25c3055400e8a54e326eeeab4e33a26fb5ee))
* 补齐首右拆分数据 ([b2dc5c2](https://github.com/amzxyz/rime_wanxiang/commit/b2dc5c2a6a3d9278e9fd9f3dc6b5972359b56838))
* 调整预设快捷键的代码顺序，使得经常可能自定义替换行的这种写法居于靠前的位置这样更稳定，减少因新增内容导致的失效 ([da5615d](https://github.com/amzxyz/rime_wanxiang/commit/da5615dbb5d2c3539077d4e2964158d44f9a3214))

## [13.3.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.3...v13.3.4) (2025-11-05)


### 📚 词库更新

* 整理生物学词库 ([e16553f](https://github.com/amzxyz/rime_wanxiang/commit/e16553fb31b154f4c46d0ab89cb488a28d74a5ea))
* 整理生物学词库 ([e16553f](https://github.com/amzxyz/rime_wanxiang/commit/e16553fb31b154f4c46d0ab89cb488a28d74a5ea))
* 词库调整 ([d109b39](https://github.com/amzxyz/rime_wanxiang/commit/d109b39426468dc449b91c5f09f7d13445ed2750))
* 词库调整 ([1a15f24](https://github.com/amzxyz/rime_wanxiang/commit/1a15f240ae4e00d0a651b1cf9a0ee4a309711a55))


### 🐛 Bug 修复

* 修复汉心龙转写 ([7b7cadd](https://github.com/amzxyz/rime_wanxiang/commit/7b7cadd2d310277bac7dda42be3b56471ded4aae))

## [13.3.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.2...v13.3.3) (2025-11-05)


### 📚 词库更新

* 词库调整 ([61da66a](https://github.com/amzxyz/rime_wanxiang/commit/61da66a127528ff8d7d5acb33a498f11b4a5e04a))
* 词库调整 ([2278a82](https://github.com/amzxyz/rime_wanxiang/commit/2278a82bcab7918a154f6e166c133481ddbd93c8))
* 词库调整 ([03bf959](https://github.com/amzxyz/rime_wanxiang/commit/03bf9598cdc80516cb8d5c01c88f1ec9f32c8dac))
* 词库调整 ([803c68a](https://github.com/amzxyz/rime_wanxiang/commit/803c68a9ad13a78aca64b6a389048c93b2d82efc))
* 词库调整 ([0403b43](https://github.com/amzxyz/rime_wanxiang/commit/0403b432cedc3e91b17bdbe326725b84dbedd03f))
* 词库调整 ([601c930](https://github.com/amzxyz/rime_wanxiang/commit/601c93044f82936772f9dd38480b4bc6af3765fc))

## [13.3.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.1...v13.3.2) (2025-11-03)


### 🐛 Bug 修复

* 添加首右拆分预备文件 ([15d76a4](https://github.com/amzxyz/rime_wanxiang/commit/15d76a4e12a56717f9d3dbc85c08316d93234fc6))

## [13.3.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.3.0...v13.3.1) (2025-11-03)


### 📚 词库更新

* 词库调整 ([f51bd49](https://github.com/amzxyz/rime_wanxiang/commit/f51bd491942b076e201b5b04a6a5fdde624ba341))
* 词库调整 ([efed2e8](https://github.com/amzxyz/rime_wanxiang/commit/efed2e874270d664deea223e6786a842a97d2809))


### 🐛 Bug 修复

* 添加首右辅助码 ([3403284](https://github.com/amzxyz/rime_wanxiang/commit/3403284c3e0c3876fcc6578badcaa055a3d5d057))


### 🏡 杂项

* 修改说明 ([3029775](https://github.com/amzxyz/rime_wanxiang/commit/3029775cc1bd15a3703c54318a5d919f13543504))

## [13.3.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.2.4...v13.3.0) (2025-11-02)


### ✨ 新特性

* 移除经调研无人使用的生日功能，新增基于方案自定义的N20250101模式下和/rq模式下，日期类型、顺序进行完全的自定义能力，简单到爆 ([2eeda09](https://github.com/amzxyz/rime_wanxiang/commit/2eeda09143e8f40fd39cdc3941177a72e201d7d1))


### 📚 词库更新

* 词库删减 ([12a2618](https://github.com/amzxyz/rime_wanxiang/commit/12a2618b753a4e37c5639c184069242782b97fb2))
* 词库调整 ([d25450a](https://github.com/amzxyz/rime_wanxiang/commit/d25450a87cd06c5654024530abe63de66714fd2b))
* 词库调整 ([9c4dbb8](https://github.com/amzxyz/rime_wanxiang/commit/9c4dbb81ff6382d15bbaf31a083be645d2f8859c))
* 词库调整 ([d46348e](https://github.com/amzxyz/rime_wanxiang/commit/d46348e4610b7582b18e065a2de923ea7f749f78))


### 🐛 Bug 修复

* 移除多于函数 ([f2b0b91](https://github.com/amzxyz/rime_wanxiang/commit/f2b0b91dd1aa2ed3a25fb5766a0d026e48e62f32))
* 调整一些细节 ([0e38eab](https://github.com/amzxyz/rime_wanxiang/commit/0e38eab00d2a75d70faa4748c279f69c6bae9320))


### 🏡 杂项

* 修改说明 ([fec9cba](https://github.com/amzxyz/rime_wanxiang/commit/fec9cba9e62bbe366c15f4438a1772da575e6ebe))

## [13.2.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.2.3...v13.2.4) (2025-10-31)


### 📚 词库更新

* 词库调整 ([b826c81](https://github.com/amzxyz/rime_wanxiang/commit/b826c810ac1c2068a5d7010f4f3984811f0c9fe5))
* 词库调整 ([8f221b4](https://github.com/amzxyz/rime_wanxiang/commit/8f221b4a2f9c5f13bf03f185447e82c5b90e8ab9))
* 词库调整 ([4efea35](https://github.com/amzxyz/rime_wanxiang/commit/4efea3547c9c5e53a46c3233f6383267b68b9fd0))
* 词库调整 ([1027981](https://github.com/amzxyz/rime_wanxiang/commit/10279815c6f3e1d74ed4de33fc4f334a3d3c7298))


### 🐛 Bug 修复

* 人名模式测试失败,后续不再提供 ([4f5f952](https://github.com/amzxyz/rime_wanxiang/commit/4f5f952bae7a0a1c10c4c59372548ebfb241a9f7))

## [13.2.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.2.2...v13.2.3) (2025-10-29)


### 📚 词库更新

* 移动地名 ([727ba58](https://github.com/amzxyz/rime_wanxiang/commit/727ba58eddb3986f97ba75a9af3db2fabae3b5f3))
* 词库调整 ([24c9a3c](https://github.com/amzxyz/rime_wanxiang/commit/24c9a3cbb330b0941d9f9898ddafb619686b2f0a))
* 词库调整 ([0ff93ab](https://github.com/amzxyz/rime_wanxiang/commit/0ff93ab1859e7bb10298af28c80d5be4c524d94a))
* 调整人名词库 ([3380cd9](https://github.com/amzxyz/rime_wanxiang/commit/3380cd909de02e1ef9464582b4379399da1b620e))


### 🐛 Bug 修复

* **lua:** shijian新增节日 ([0a58acd](https://github.com/amzxyz/rime_wanxiang/commit/0a58acde5b78ef073fa885406e34733b6773db81))
* 小修改 ([922eca0](https://github.com/amzxyz/rime_wanxiang/commit/922eca07d0c45b5fcdd36216de65bc43b68386e5))

## [13.2.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.2.1...v13.2.2) (2025-10-28)


### 🐛 Bug 修复

* 修改转写 ([b2dbe7f](https://github.com/amzxyz/rime_wanxiang/commit/b2dbe7f6c62cf4cf8c0027f0a475574ca5cf1fb6))

## [13.2.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.2.0...v13.2.1) (2025-10-28)


### 🐛 Bug 修复

* 补全失误造成的逗号缺失 ([34fd2f6](https://github.com/amzxyz/rime_wanxiang/commit/34fd2f688edf0d18036983bbc94ec5f19bd7e7ec))

## [13.2.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.11...v13.2.0) (2025-10-28)

### ✨ 新特性

* 新增人名模式，pro新增拼音加加 ([9db1e9a](https://github.com/amzxyz/rime_wanxiang/commit/9db1e9a768fa718c3958cfbfe12fc2b4178bb66d))

### 🐛 Bug 修复

* 修改转写 ([dfc1c50](https://github.com/amzxyz/rime_wanxiang/commit/dfc1c50295a5ca7488b4147f1ef2d44e148f9060))


### 🏡 杂项

* 修改说明 ([2932c43](https://github.com/amzxyz/rime_wanxiang/commit/2932c4391666332f0da0560832fbf3c7515043e1))

## [13.1.9](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.7...v13.1.9) (2025-10-22)

* 词库更新 ([303aa64](https://github.com/amzxyz/rime_wanxiang/commit/303aa6487845ed7e63e626794df13a1bbf846763))
* 词库更新 ([6314d7b](https://github.com/amzxyz/rime_wanxiang/commit/6314d7bada38b91422880ed55a3148e7de047ad4))
* 词库更新 ([75a91f5](https://github.com/amzxyz/rime_wanxiang/commit/75a91f5731f40716b2783e6fe5b84c6ede9a27a4))

## [13.1.7](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.6...v13.1.7) (2025-10-21)


### 📚 词库更新

* fix ([1850071](https://github.com/amzxyz/rime_wanxiang/commit/1850071a8ba6b15907954e1acde881e643228b98))
* ic t ([ef525f2](https://github.com/amzxyz/rime_wanxiang/commit/ef525f2454639ca7462169f79f829a6e4fa2fa86))
* 词库更新 ([5e9c888](https://github.com/amzxyz/rime_wanxiang/commit/5e9c8886fef31407e52631dabe8884f26d727ab3))
* 词库更新 ([cf34898](https://github.com/amzxyz/rime_wanxiang/commit/cf34898dbec62063af233b2c4b80009ae347b2c9))
* 词库调整 ([9e33d0a](https://github.com/amzxyz/rime_wanxiang/commit/9e33d0a59857931f80d45eeecc08a17fb013675b))
* 词库调整 ([dcac3a9](https://github.com/amzxyz/rime_wanxiang/commit/dcac3a9df7af4757a7d6a63f305ae18a7bd7662a))
* 词库调整 ([7db0bce](https://github.com/amzxyz/rime_wanxiang/commit/7db0bcebd49cdd857c518aad2752b08f237ce1a8))
* 词库调整 ([00cf691](https://github.com/amzxyz/rime_wanxiang/commit/00cf69119cea5f6a02fe46be2bce222a2e44b62b))
* 词库调整 ([30e304e](https://github.com/amzxyz/rime_wanxiang/commit/30e304e4e14f57588f8d15ee26a91f364d9e09d0))


### 🐛 Bug 修复

* 微调翻译器权重 ([92b0f43](https://github.com/amzxyz/rime_wanxiang/commit/92b0f43ccace8607efcad79e6df6c6fc55c925d3))
* 成对符号包裹现已支持|作为分隔符,以此扩展许多md文档用法 ([3c2eeaa](https://github.com/amzxyz/rime_wanxiang/commit/3c2eeaa5ab0746f200f9b59783a2afb27859204d))
* 调整一些细节 ([af07c07](https://github.com/amzxyz/rime_wanxiang/commit/af07c07fa5c5dbb08e8716b97f7668a75dcb3d73))


### 🏡 杂项

* 修改说明 ([c5dab7b](https://github.com/amzxyz/rime_wanxiang/commit/c5dab7b9fe29b75a86e4f922c9b44a83e6b318b1))
* 修改说明 ([7821664](https://github.com/amzxyz/rime_wanxiang/commit/7821664c4bb77a3619da35b6cfca32bb8d8c6f7e))

## [13.1.6](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.5...v13.1.6) (2025-10-18)


### 📚 词库更新

* 词库调整 ([2acd9e4](https://github.com/amzxyz/rime_wanxiang/commit/2acd9e4e01aa4745bd61690d6ccdb4a847b47f60))

## [13.1.5](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.4...v13.1.5) (2025-10-17)


### 📚 词库更新

* 词库调整 ([ec9cb75](https://github.com/amzxyz/rime_wanxiang/commit/ec9cb75e8ea00cc3f9f9502c8592fd853bf5cb35))
* 词库调整 ([5804cfc](https://github.com/amzxyz/rime_wanxiang/commit/5804cfc19293859673ac72a12f738fb9b2f62e00))
* 词库调整 ([7d9c291](https://github.com/amzxyz/rime_wanxiang/commit/7d9c2910ae4bfff951ed07972244709061ef3364))
* 词库调整 ([8c9ad2a](https://github.com/amzxyz/rime_wanxiang/commit/8c9ad2ac59b642cf86b88eb80f251392eb6c5613))
* 词库调整 ([5276236](https://github.com/amzxyz/rime_wanxiang/commit/5276236320fd33fa24308359f79e01a1e1958edd))


### 🐛 Bug 修复

* 呣呒放到me编码下 ([1fcd59f](https://github.com/amzxyz/rime_wanxiang/commit/1fcd59fe6ae014a9b430747fec1b57d2511e1ede))
* 手动排序Lua将不再支持单小写字母,时间复杂度过高容易卡顿,对单字母有固定需求的,请使用根目录custom_phrase.txt,具有良好的效果 ([60e5e38](https://github.com/amzxyz/rime_wanxiang/commit/60e5e38e43310aa7b6b60203c5366cde6b372b48))


### 🏡 杂项

* 修改说明 ([0291272](https://github.com/amzxyz/rime_wanxiang/commit/0291272aa106c40db48e5936729af3d3e6934928))

## [13.1.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.3...v13.1.4) (2025-10-13)


### 📚 词库更新

* 词库调整 ([2868e4c](https://github.com/amzxyz/rime_wanxiang/commit/2868e4cf00e5a621997b1fa383c791d388ab112d))
* 词库调整 ([f264f7b](https://github.com/amzxyz/rime_wanxiang/commit/f264f7bac0d7c1f4e7c7eb8be2a1d6da3e14833a))
* 辅助码3变2词汇权重调整 ([08f4148](https://github.com/amzxyz/rime_wanxiang/commit/08f4148d7c8051fea07f64cffdc0f049e48819b7))


### 🐛 Bug 修复

* 修复手动排序windows路径处理bug ([1c66ea5](https://github.com/amzxyz/rime_wanxiang/commit/1c66ea58073511e87d04479448a0316d7ab0e6d5))

## [13.1.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.2...v13.1.3) (2025-10-12)


### 🐛 Bug 修复

* 减少空格转换，避免emoji被异化 ([5cd9c05](https://github.com/amzxyz/rime_wanxiang/commit/5cd9c05b6bc10555968b14daf0a8d54548c7a6b0))

## [13.1.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.1...v13.1.2) (2025-10-12)


### 🐛 Bug 修复

* 移除并击处理器,避免在串击干扰反查特性 ([11c0f43](https://github.com/amzxyz/rime_wanxiang/commit/11c0f43d85e643e8c4a74f4d5a284cf37499749b))

## [13.1.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.1.0...v13.1.1) (2025-10-11)


### 📚 词库更新

* 词库调整 ([7192c27](https://github.com/amzxyz/rime_wanxiang/commit/7192c27938f5f07416663df47eb28d9fc95cf348))
* 词库调整 ([2e8f647](https://github.com/amzxyz/rime_wanxiang/commit/2e8f647532847eef7bb6072204d942e1ea9a20b5))
* 词库调整 ([c76d774](https://github.com/amzxyz/rime_wanxiang/commit/c76d7744a164a71195c6ca0912e4d2a2322b77c3))
* 词库调整 ([3dc5cd1](https://github.com/amzxyz/rime_wanxiang/commit/3dc5cd195a6a511b3c645faac1d5ca12097b12ac))


### 🐛 Bug 修复

* 调整转写 ([6456448](https://github.com/amzxyz/rime_wanxiang/commit/6456448e560dc43ad30503ea790f62e13f2ec87c))

## [13.1.0](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.9...v13.1.0) (2025-10-09)


### ✨ 新特性

* 新增通过双击分词符号触发重新分词，并在持续输入分词符号时，能在预设方式之间循环，用于应对类似自然码：必输 必须是 为相同编码导致的必输前置的问题 ([806e066](https://github.com/amzxyz/rime_wanxiang/commit/806e06653cb69789c47c5e2c837ba752123e0958))


### 📚 词库更新

* 词库调整 ([01edfb4](https://github.com/amzxyz/rime_wanxiang/commit/01edfb4de434b0f3ee6b7d3c9c252ff553c62282))
* 词库调整 ([ec4d1dd](https://github.com/amzxyz/rime_wanxiang/commit/ec4d1dde4891924e5a8b68803d6bf39708247e70))


### 🐛 Bug 修复

* 通过双击分词符号触发重新分词，并在持续输入分词符号时，能在预设方式之间循环，用于应对类似自然码：必输 必须是 为相同编码导致的必输前置的问题 ([158b0fe](https://github.com/amzxyz/rime_wanxiang/commit/158b0feab3f2a73465cfcdb1821752021c9c16cb))


### 🏡 杂项

* 调整说明 ([a3235ef](https://github.com/amzxyz/rime_wanxiang/commit/a3235efd25840a1877cdf242573c918addd7724c))

## [13.0.9](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.8...v13.0.9) (2025-10-08)


### 📚 词库更新

* 词库调整 ([4857c9c](https://github.com/amzxyz/rime_wanxiang/commit/4857c9cfb8ac214e36888028980d810d6e783639))


### 🐛 Bug 修复

* 删除残留的声调回退字符 ([6132aa8](https://github.com/amzxyz/rime_wanxiang/commit/6132aa87eb4305c3ab985a5128416283f43f9e03))

## [13.0.8](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.7...v13.0.8) (2025-10-08)


### 📚 词库更新

* 词库调整 ([7113ebc](https://github.com/amzxyz/rime_wanxiang/commit/7113ebc4a19ab7ec0dfbbc68770d5648ebaddf45))

## [13.0.7](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.6...v13.0.7) (2025-10-08)


### 📚 词库更新

* 词库调整 ([f14b1ee](https://github.com/amzxyz/rime_wanxiang/commit/f14b1ee5fca10b113afe31338bdb8dbce85f23be))
* 词库调整 ([d0706b7](https://github.com/amzxyz/rime_wanxiang/commit/d0706b793d83b4e870de7899d3bd59b15bffc584))
* 词库调整 ([268da43](https://github.com/amzxyz/rime_wanxiang/commit/268da43a08c61fd248d59e9b3bb06e322025b93a))


### 🐛 Bug 修复

* 修复方案设置为智能ABC再切换其他导致ABC残留的问题 ([e7a2db0](https://github.com/amzxyz/rime_wanxiang/commit/e7a2db015885672130ce12f2f3e4d9a80ce0a891))
* 去掉shift变分词，输入中可以按下让数字变符号 ([63aad4f](https://github.com/amzxyz/rime_wanxiang/commit/63aad4f84f7bee042f21e6148cc77140b6b8e318))
* 计算器支持大部分情况下无需括号的运算 ([ab665da](https://github.com/amzxyz/rime_wanxiang/commit/ab665dacf067516189060e3b11444111f7b2cdb2))
* 调整若干方案参数 ([325846f](https://github.com/amzxyz/rime_wanxiang/commit/325846fa9aec34324f08a5a7bd2e56b0c631b3eb))

## [13.0.6](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.5...v13.0.6) (2025-10-06)


### 📚 词库更新

* 词库调整 ([fecdb8a](https://github.com/amzxyz/rime_wanxiang/commit/fecdb8afc846f44664d1e88ff0954902af0bdd66))
* 词库调整 ([c6a7904](https://github.com/amzxyz/rime_wanxiang/commit/c6a79041283f1f3089f82ca6c1bb6f3546f10663))
* 词库调整 ([114ddc2](https://github.com/amzxyz/rime_wanxiang/commit/114ddc2afcc67255a4a3486fc1e491344518d972))
* 词库调整 ([187adb6](https://github.com/amzxyz/rime_wanxiang/commit/187adb615f7bcfeca8d2c4f2e4705660a1e97a8a))


### 🐛 Bug 修复

* 恢复emoji误删除参数 ([244fa33](https://github.com/amzxyz/rime_wanxiang/commit/244fa335a71bd503019d4e5b0e652c966e097d41))
* 恢复emoji误删除参数 ([dfa0884](https://github.com/amzxyz/rime_wanxiang/commit/dfa0884da468d338a5c2c3c560dffbe48f77b991))

## [13.0.5](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.4...v13.0.5) (2025-10-04)


### 📚 词库更新

* 词库调整 ([876a8f6](https://github.com/amzxyz/rime_wanxiang/commit/876a8f639a60df4ffa7582bf1196f310674ca777))
* 词库调整 ([61758d4](https://github.com/amzxyz/rime_wanxiang/commit/61758d4309f0beb867153210839b61d50a191b8a))

## [13.0.4](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.3...v13.0.4) (2025-10-04)


### 📚 词库更新

* 反查词库新增扩17组字与笔画 ([8108e1f](https://github.com/amzxyz/rime_wanxiang/commit/8108e1f1393cb29e98d57f21d33a9d3b48644f82))
* 词库调整 ([4a97129](https://github.com/amzxyz/rime_wanxiang/commit/4a971291cfd638d4e1fff08ef07629be4f56c3c9))
* 词库调整 ([04b3348](https://github.com/amzxyz/rime_wanxiang/commit/04b3348dd095c86a53821ed4ecfa198c51d7532d))
* 词库调整 ([cc183e7](https://github.com/amzxyz/rime_wanxiang/commit/cc183e73a16400712b9711c37209701bbd857e8b))


### 🔥 性能优化

* **lua:** text_formatting_promote.lua符号成对功能支持无候选时使用输入码作为包裹对象 ([bec5630](https://github.com/amzxyz/rime_wanxiang/commit/bec5630168a812ff7b7949c86619e7684cc9ddea))

## [13.0.3](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.2...v13.0.3) (2025-09-30)


### 🐛 Bug 修复

* 修复一个bug ([0a6eb34](https://github.com/amzxyz/rime_wanxiang/commit/0a6eb3460d60d31a403df985f9338d250a935df8))
* 现在可以通过/jjf,/zjf进行pro辅助码类型切换 ([eae853c](https://github.com/amzxyz/rime_wanxiang/commit/eae853c5f96c28df86e8d889d92e4e39533ead92))

## [13.0.2](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.1...v13.0.2) (2025-09-30)


### 📚 词库更新

* 词库调整 ([9803597](https://github.com/amzxyz/rime_wanxiang/commit/98035976d1446d3f63797538ffdef6a3e86e36ba))


### 🐛 Bug 修复

* 候选格式化新增非标空格转换为标准空格的能力，先期主要解决OpenCC字符连续所产生的候选 ([8c07306](https://github.com/amzxyz/rime_wanxiang/commit/8c0730637820302c3292b272d9f7290b6cb6b442))
* 推出过渡性set_schema ([fd9ac58](https://github.com/amzxyz/rime_wanxiang/commit/fd9ac58370c2c95c4878d0f0a3e54266b9c0532d))

## [13.0.1](https://github.com/amzxyz/rime_wanxiang/compare/v13.0.0...v13.0.1) (2025-09-29)


### 📚 词库更新

* 词库调整 ([f1e5b1b](https://github.com/amzxyz/rime_wanxiang/commit/f1e5b1bad6d7c7e9c8ab6d11e5f35df28d1072d3))


### 🐛 Bug 修复

* 优化一些细节 ([d2246c2](https://github.com/amzxyz/rime_wanxiang/commit/d2246c2220c03824ee5b4d7b8258bd1afcfe83c3))


### 🏡 杂项

* 创建日志 ([5b5cb8a](https://github.com/amzxyz/rime_wanxiang/commit/5b5cb8a509f664018a133f9ca9a1105c74e163c7))

## [13.0.0](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.13...v13.0.0) (2025-09-29)


### 📚 词库更新

* 词库调整 ([9d37d82](https://github.com/amzxyz/rime_wanxiang/commit/9d37d82c3230707419009717acc99af6e65cdc5f))
* 词库调整 ([3c614be](https://github.com/amzxyz/rime_wanxiang/commit/3c614be8d3b703f54b3e94a56beff13a69cf11cb))


### 🐛 Bug 修复

* 调整反查数据排序 ([0eddcc0](https://github.com/amzxyz/rime_wanxiang/commit/0eddcc094b9464fbcaf7bb47890ea12a9f1a24af))
* 超级注释调整，去掉辅助类型选择，削减拆分数据大小括号内容交给程序实时添加，并在配置中统一了括号加占位的形式减少之前大括号外面再加括号的困惑 ([6872786](https://github.com/amzxyz/rime_wanxiang/commit/687278648f027853e2c06b083d730ecf9f83eed5))


### 💅 重构

* 转写单独文件调用，避免交叉引用，本次更新会导致原patch失效，按照示例简单修改即可恢复 ([4955e96](https://github.com/amzxyz/rime_wanxiang/commit/4955e9667cb8919f5eaf48fafdbdf7269bfebfe4))


### 🏡 杂项

* pr ([ebf8224](https://github.com/amzxyz/rime_wanxiang/commit/ebf82243cdf6cf66199f097b296f94f8decb33a5))
* release 13.0.0 ([f77be14](https://github.com/amzxyz/rime_wanxiang/commit/f77be145f5db41dbbda3462abb0dc814c8fd7a7b))

## [12.6.13](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.12...v12.6.13) (2025-09-28)


### 📚 词库更新

* 词库调整 ([8ea6de4](https://github.com/amzxyz/rime_wanxiang/commit/8ea6de45f6ff1aaae6fe02716d11948125daf188))
* 词库调整 ([8673c01](https://github.com/amzxyz/rime_wanxiang/commit/8673c014d3277326f6f3405db52fed866ffcf84e))
* 词库调整 ([1cc30b9](https://github.com/amzxyz/rime_wanxiang/commit/1cc30b913adf1e89447f00aadfde04d54c3de556))


### 🐛 Bug 修复

* 自动化变更 ([e5ecf3c](https://github.com/amzxyz/rime_wanxiang/commit/e5ecf3c480a5c207e1f9d8c6fb83d8b74bf6ed49))

## [12.6.12](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.11...v12.6.12) (2025-09-27)


### 📚 词库更新

* 词库调整 ([c974b23](https://github.com/amzxyz/rime_wanxiang/commit/c974b23c59ae9b86ed3dfe5eb79828ef81793d8c))

## [12.6.11](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.10...v12.6.11) (2025-09-27)


### 🐛 Bug 修复

* 移除侵入性太强的编码纠错，后续想办法提供词库类型的纠错 ([ffdd368](https://github.com/amzxyz/rime_wanxiang/commit/ffdd368857e8bdbf1d594e710ef41eb2e23bf0d7))

## [12.6.10](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.9...v12.6.10) (2025-09-27)


### 📚 词库更新

* 词库更新 ([a1476c4](https://github.com/amzxyz/rime_wanxiang/commit/a1476c496e3d10d1ac3e8bacf01bdeb4f9165a35))
* 词库调整 ([3957f6e](https://github.com/amzxyz/rime_wanxiang/commit/3957f6eb3287247f97719e802d00ae06e76088fc))
* 词库调整 ([7b26836](https://github.com/amzxyz/rime_wanxiang/commit/7b268367782e48ad6f235ba37716eccb0369ee16))


### 🏡 杂项

* 创建release ([3766621](https://github.com/amzxyz/rime_wanxiang/commit/37666217e5237f81a3a7619256fa20a16d758337))

## [12.6.9](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.8...v12.6.9) (2025-09-26)


### 📚 词库更新

* 词库调整 ([7926471](https://github.com/amzxyz/rime_wanxiang/commit/79264713619f419aa99d273d4db534b0ccc17f6c))


### 🐛 Bug 修复

* 修改说明 ([7ed287b](https://github.com/amzxyz/rime_wanxiang/commit/7ed287b6ac25bcfd4b956fd95ed98555bb2bb118))
* 修改说明 ([bb0a449](https://github.com/amzxyz/rime_wanxiang/commit/bb0a449aef5dc10e07e9019f32b7392a5e283480))
* 修改说明 ([ad3f02e](https://github.com/amzxyz/rime_wanxiang/commit/ad3f02e1f8dc961c54f1da87c324c0aa73c52690))

## [12.6.8](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.7...v12.6.8) (2025-09-25)


### 🐛 Bug 修复

* 修改说明 ([0ad748d](https://github.com/amzxyz/rime_wanxiang/commit/0ad748d4df77dd794d82d364bf501f8c549c639b))

## [12.6.7](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.6...v12.6.7) (2025-09-25)


### 📚 词库更新

* 梳理otheremoji迁移到symbol ([669d39b](https://github.com/amzxyz/rime_wanxiang/commit/669d39bed612586a2171b1096ae482c3c47babdf))
* 词库调整 ([5a50395](https://github.com/amzxyz/rime_wanxiang/commit/5a50395b70eb099171381ae2e1f497356e57055c))


### 🐛 Bug 修复

* 与前端配合的考量后续default将以custom形式提供，相关功能patch请直接编辑 ([88dd034](https://github.com/amzxyz/rime_wanxiang/commit/88dd034c1b344b406b52d00fe1fc050f83adf2e5))
* 反查新增乱序17选项 ([08753f4](https://github.com/amzxyz/rime_wanxiang/commit/08753f409a13357fe07ef31ca965e5b07f8b9456))
* 梳理数据tips翻译部分在线提供不随zip打包 ([dcfbd3e](https://github.com/amzxyz/rime_wanxiang/commit/dcfbd3ec268f3f7b280ab7b7629c52cdd733e31b))
* 超级提示 disabled type 匹配由排除集合改成非贪婪模式,修复"化学式"类型无法排除的问题 ([f9fd0d7](https://github.com/amzxyz/rime_wanxiang/commit/f9fd0d730892fb3016b0e762afd3d728ab265750))


### 🏡 杂项

* 修改说明 ([8217e68](https://github.com/amzxyz/rime_wanxiang/commit/8217e6887925ae519b137135c0c7eecfa5b23e64))

## [12.6.6](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.5...v12.6.6) (2025-09-23)


### 📚 词库更新

* 词库调整 ([4fc713f](https://github.com/amzxyz/rime_wanxiang/commit/4fc713f4292f0da6d7fa6621de0d8430ec6d25db))

## [12.6.5](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.4...v12.6.5) (2025-09-22)


### 📚 词库更新

* 词库调整 ([fd507bf](https://github.com/amzxyz/rime_wanxiang/commit/fd507bf70747420aeafccd573b4abcf4b66d7a14))


### 🐛 Bug 修复

* 部分英文加括号兜底候选保证\后面时时有输出 ([8871808](https://github.com/amzxyz/rime_wanxiang/commit/8871808a65f8b6d4226309bd7e5e58650a3e0495))


### 🏡 杂项

* 说明变更 ([9145376](https://github.com/amzxyz/rime_wanxiang/commit/914537685ed357e419d70b87253871d06e1b031e))

## [12.6.4](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.3...v12.6.4) (2025-09-21)


### 📚 词库更新

* 词库调整 ([c6e88eb](https://github.com/amzxyz/rime_wanxiang/commit/c6e88eb240d92f9bf518fe0cfdeae43aa04f5969))
* 词库调整 ([8106518](https://github.com/amzxyz/rime_wanxiang/commit/81065189fda63ee9620131b2fc556bc95de65f8f))


### 🏡 杂项

* 变更说明 ([15aa83a](https://github.com/amzxyz/rime_wanxiang/commit/15aa83a75fd89f38a95e3fd2df617ff84a1eed2d))
* 变更说明 ([8663d30](https://github.com/amzxyz/rime_wanxiang/commit/8663d30a9a0146363a0e5b18673992f0e8dbacc7))

## [12.6.3](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.2...v12.6.3) (2025-09-20)


### 🐛 Bug 修复

* **lua:** 成对符号一次性解决了排序后不能被包裹、表词汇不能被包裹、不打全编码不能被包裹 ([fc6b6b0](https://github.com/amzxyz/rime_wanxiang/commit/fc6b6b0a088391add4a9a29c32c3f44be1efc04d))
* **lua:** 次选上屏消耗所有编码 ([457a6d0](https://github.com/amzxyz/rime_wanxiang/commit/457a6d02251bf9159ea3d5ca44721be6f3a225d6))
* 默认开启无感造词 ([f73bb13](https://github.com/amzxyz/rime_wanxiang/commit/f73bb134fc2777544841e1c30434ba9ce0fa76c8))

## [12.6.2](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.1...v12.6.2) (2025-09-19)


### 🐛 Bug 修复

* 修复全拼 ([aab2949](https://github.com/amzxyz/rime_wanxiang/commit/aab2949bf4b028e3c062579ff6a493a6f29b5784))

## [12.6.1](https://github.com/amzxyz/rime_wanxiang/compare/v12.6.0...v12.6.1) (2025-09-19)


### 🐛 Bug 修复

* 仓9适配新Lua ([3fc9736](https://github.com/amzxyz/rime_wanxiang/commit/3fc9736ccc3705c1c89d19c6c7a28a1038202c2a))


### 🏡 杂项

* 创建release ([95c7b58](https://github.com/amzxyz/rime_wanxiang/commit/95c7b58c65139b47c652d49e2412e848705dfde2))

## [12.6.0](https://github.com/amzxyz/rime_wanxiang/compare/v12.5.2...v12.6.0) (2025-09-18)


### ✨ 新特性

* 全新基于滤镜的反查辅助方案Lua，支持你ni`re、ni`rfer、ni`hspz...全场景辅助 ([5708a1d](https://github.com/amzxyz/rime_wanxiang/commit/5708a1d9a586db1b7bf671d9064f7abbdcc46cfe))

## [12.5.2](https://github.com/amzxyz/rime_wanxiang/compare/v12.5.1...v12.5.2) (2025-09-18)


### 🐛 Bug 修复

* 成对符号候选修复若干bug ([cf472a4](https://github.com/amzxyz/rime_wanxiang/commit/cf472a48d4f56d78a4192f2bda7ce9cb297aa33d))


### 🏡 杂项

* 创建release ([80ee7f5](https://github.com/amzxyz/rime_wanxiang/commit/80ee7f5da96ea571632dda41feb0b0b38442014b))

## [12.5.1](https://github.com/amzxyz/rime_wanxiang/compare/v12.5.0...v12.5.1) (2025-09-18)


### 📚 词库更新

* 词库调整 ([a55c91a](https://github.com/amzxyz/rime_wanxiang/commit/a55c91a0538975fb139b063c96ebfe2c17aaecc3))


### 🐛 Bug 修复

* 修复成对符号包裹时候次选异常的问题 ([5428a6e](https://github.com/amzxyz/rime_wanxiang/commit/5428a6e357a7da8cbb0909effe18185fd5783690))
* 快符同时简化为单字母加/ ([c57da1f](https://github.com/amzxyz/rime_wanxiang/commit/c57da1fd9b3def31d4543090cbbc322ed7cbb07d))

## [12.5.0](https://github.com/amzxyz/rime_wanxiang/compare/v12.4.1...v12.5.0) (2025-09-18)


### ✨ 新特性

* 滤镜文本格式化新增为第一候选加上成对符号的功能 ([dca62d3](https://github.com/amzxyz/rime_wanxiang/commit/dca62d3ea010ea0ab942bb137d0fb949274f5323))


### 📚 词库更新

* 词库调整 ([eccaf6c](https://github.com/amzxyz/rime_wanxiang/commit/eccaf6ce31b920c76d889159dff5e6e908d2314b))


### 🐛 Bug 修复

* 反斜杠加入后引导能力 ([b8f38e7](https://github.com/amzxyz/rime_wanxiang/commit/b8f38e768e3e79f614612da0eaf1efc6a03b4aea))

## [12.4.1](https://github.com/amzxyz/rime_wanxiang/compare/v12.4.0...v12.4.1) (2025-09-15)


### 📚 词库更新

* 词库调整 ([d6c3e3a](https://github.com/amzxyz/rime_wanxiang/commit/d6c3e3a70da8f6202727bff47b54cf39f5291e76))


### 🐛 Bug 修复

* 去掉编码与单词一致时前置，改为转写/加一码提权 ([d778709](https://github.com/amzxyz/rime_wanxiang/commit/d7787093e4d86b632950f30ecbbab1ee81965d51))

## [12.4.0](https://github.com/amzxyz/rime_wanxiang/compare/v12.3.4...v12.4.0) (2025-09-14)


### ✨ 新特性

* 排序Lua变更为随同步目录开启，并实现了多设备合并数据逻辑，本次更新为rc验证阶段 ([d4a0380](https://github.com/amzxyz/rime_wanxiang/commit/d4a0380e49284f4f8ab0d1231344f6729538cb63))


### 📚 词库更新

* 词库调整 ([37168c3](https://github.com/amzxyz/rime_wanxiang/commit/37168c3ca3c3056a397a8122f813d0a712aba672))


### 🐛 Bug 修复

* 修复去重高亮 ([2fe04d9](https://github.com/amzxyz/rime_wanxiang/commit/2fe04d9320b8d57c99b55cca4a5e698b83f70d2f))

## [12.3.4](https://github.com/amzxyz/rime_wanxiang/compare/v12.3.3...v12.3.4) (2025-09-13)


### 🐛 Bug 修复

* 恢复小键盘功能 ([fa5ece5](https://github.com/amzxyz/rime_wanxiang/commit/fa5ece50528834b48cb1f1d53718448f9822350d))

## [12.3.3](https://github.com/amzxyz/rime_wanxiang/compare/v12.3.2...v12.3.3) (2025-09-12)


### 📚 词库更新

* 词库调整 ([770a71e](https://github.com/amzxyz/rime_wanxiang/commit/770a71e6fe6217c67fadb300b94e6bc031737f6a))


### 🐛 Bug 修复

* 排序数据可能包含空格 ([fc58109](https://github.com/amzxyz/rime_wanxiang/commit/fc58109b55d4664ddfa71c870787f47e3b0c3992))

## [12.3.2](https://github.com/amzxyz/rime_wanxiang/compare/v12.3.1...v12.3.2) (2025-09-12)


### 🐛 Bug 修复

* 恢复以前，Mac与windows逻辑不一致 ([3936b12](https://github.com/amzxyz/rime_wanxiang/commit/3936b12e5994dbcc03273f48d2a5f65d7ac8354a))
* 恢复声调回退Lua ([1bd377e](https://github.com/amzxyz/rime_wanxiang/commit/1bd377e2a4b6e3060d8d756b331150fac0cc3c86))

## [12.3.1](https://github.com/amzxyz/rime_wanxiang/compare/v12.3.0...v12.3.1) (2025-09-12)


### 📚 词库更新

* 词库调整 ([ff101a2](https://github.com/amzxyz/rime_wanxiang/commit/ff101a2b94bd9a24f802cc5e8fe9b312e8a1856c))
* 词库调整 ([3cdedc5](https://github.com/amzxyz/rime_wanxiang/commit/3cdedc5f1de42777df4b9693bd351e99b92fdaea))
* 词库调整 ([f2459ee](https://github.com/amzxyz/rime_wanxiang/commit/f2459ee9751c1506ee8ae70c937371cf61a6d0c2))


### 🐛 Bug 修复

* 分号次选恢复send2 ([78fa572](https://github.com/amzxyz/rime_wanxiang/commit/78fa57269561116690f739edc599b46d9cded88d))
* 继续完善现在完全支持副键盘不上屏，配合输入混合验证码等场景 ([ceaa212](https://github.com/amzxyz/rime_wanxiang/commit/ceaa2120f5b94bd6e5547939eb091fb561a3e00e))

## [12.3.0](https://github.com/amzxyz/rime_wanxiang/compare/v12.2.7...v12.3.0) (2025-09-11)


### ✨ 新特性

* 无法一句话描述，见release ([bd15d38](https://github.com/amzxyz/rime_wanxiang/commit/bd15d38b817d0e08adead47fbd9b3e26821b0ffa))


### 📚 词库更新

* 词库调整 ([96ecfd6](https://github.com/amzxyz/rime_wanxiang/commit/96ecfd62348ddf558970eb4a135eb77ef6dd034c))


### 🐛 Bug 修复

* **sequence:** 排序内容可能包含空格 ([2df201c](https://github.com/amzxyz/rime_wanxiang/commit/2df201cb0c1ce8acd2a2e7a5288147b020e9b4c6)), closes [#402](https://github.com/amzxyz/rime_wanxiang/issues/402)
* 移除一个纠错数据 ([9c97ed3](https://github.com/amzxyz/rime_wanxiang/commit/9c97ed313c2fdb028f2fd1b868c591c6a0c74ec7))

## [12.2.7](https://github.com/amzxyz/rime_wanxiang/compare/v12.2.6...v12.2.7) (2025-09-10)


### 🐛 Bug 修复

* 仓t9优化 ([406cfc4](https://github.com/amzxyz/rime_wanxiang/commit/406cfc48b75a7d0044c6da4cf4c964a4cf6dd308))

## [12.2.6](https://github.com/amzxyz/rime_wanxiang/compare/v12.2.5...v12.2.6) (2025-09-10)


### 📚 词库更新

* 词库调整 ([9abc4f5](https://github.com/amzxyz/rime_wanxiang/commit/9abc4f53668520d57a8cd9043f09e816498a5484))


### 🐛 Bug 修复

* 优化性能 ([f9d0088](https://github.com/amzxyz/rime_wanxiang/commit/f9d0088503930e51708514a229d74fce5d0358c7))

## [12.2.5](https://github.com/amzxyz/rime_wanxiang/compare/v12.2.4...v12.2.5) (2025-09-10)


### 🐛 Bug 修复

* 恢复错误修改的中英混输转写 ([e5a4834](https://github.com/amzxyz/rime_wanxiang/commit/e5a4834866f57884013b6b8a384ad51eed8c88d8))

## [12.2.4](https://github.com/amzxyz/rime_wanxiang/compare/v12.2.3...v12.2.4) (2025-09-10)


### 🐛 Bug 修复

* 次选如果已经是table则不排序 ([0692dce](https://github.com/amzxyz/rime_wanxiang/commit/0692dcebca58051767a554946ab55376d12eab90))

## [12.2.3](https://github.com/amzxyz/rime_wanxiang/compare/v12.2.2...v12.2.3) (2025-09-10)


### 🐛 Bug 修复

* 调整英文转写匹配全大写筛选 ([44571d9](https://github.com/amzxyz/rime_wanxiang/commit/44571d9f9b40e40cd95e93414bc7d69fccf5973e))

## [12.2.2](https://github.com/amzxyz/rime_wanxiang/compare/v12.2.1...v12.2.2) (2025-09-10)


### 🐛 Bug 修复

* 调整策略与输入编码一样的英文优先前置 ([a81f716](https://github.com/amzxyz/rime_wanxiang/commit/a81f7161ce3f9d1612dabbb790e2095624494b99))

## [12.2.1](https://github.com/amzxyz/rime_wanxiang/compare/v12.2.0...v12.2.1) (2025-09-10)


### 📚 词库更新

* 词库调整 ([ac3af76](https://github.com/amzxyz/rime_wanxiang/commit/ac3af76c743702b8c116ccf01a69e9057de3b412))

## [12.2.0](https://github.com/amzxyz/rime_wanxiang/compare/v12.1.1...v12.2.0) (2025-09-09)


### ✨ 新特性

* 新增简码前置第二候选，并合并格式化候选，英文大写过滤 ([0183ed8](https://github.com/amzxyz/rime_wanxiang/commit/0183ed8c4f4e1bd15684aa9fce8ddac82e419208))


### 📚 词库更新

* 词库调整 ([5079228](https://github.com/amzxyz/rime_wanxiang/commit/507922849f92e0abaec0a5f9ddb86e98b5fcb184))

## [12.1.1](https://github.com/amzxyz/rime_wanxiang/compare/v12.1.0...v12.1.1) (2025-09-08)


### 📚 词库更新

* 词库更新 ([a88d545](https://github.com/amzxyz/rime_wanxiang/commit/a88d545b29f0d0e88ebf52701a53acc188966c4a))
* 词库调整 ([293fcb8](https://github.com/amzxyz/rime_wanxiang/commit/293fcb85e309bb514978000cf9757f72f3e77f59))


### 🐛 Bug 修复

* 让造词的时候显示辅助码，移除wanxiang.lua中关于add加词的tag标签 ([f683b12](https://github.com/amzxyz/rime_wanxiang/commit/f683b126956d8f9b0d1c034514c689761f02328b))


### 🏡 杂项

* 创建release ([8102c55](https://github.com/amzxyz/rime_wanxiang/commit/8102c554e6125dc17a012767c7183346a04292d5))

## [12.1.0](https://github.com/amzxyz/rime_wanxiang/compare/v12.0.3...v12.1.0) (2025-09-08)


### ✨ 新特性

* 添加自动无词频造词功能 ([0c253ae](https://github.com/amzxyz/rime_wanxiang/commit/0c253ae107fe90373efb9bb11a2513ae09ad507a))


### 🐛 Bug 修复

* 改进auto_phrase模块判断逻辑 ([69e542a](https://github.com/amzxyz/rime_wanxiang/commit/69e542a981a33f3961da7780f88f2fca1353cb0c))
* 考虑得失移除/del命令，造成众多用户丢失用户词 ([500b37e](https://github.com/amzxyz/rime_wanxiang/commit/500b37eb4239305955acc475920d205e31bad166))
* 调整设置 ([04cb136](https://github.com/amzxyz/rime_wanxiang/commit/04cb13625acc3955feae27fbb795866204659868))

## [12.0.3](https://github.com/amzxyz/rime_wanxiang/compare/v12.0.2...v12.0.3) (2025-09-07)


### 📚 词库更新

* 修复 ([b77cfc8](https://github.com/amzxyz/rime_wanxiang/commit/b77cfc892e3fde7bfd65aef8b1aaa88bf4d58abc))
* 去掉无读音单字 ([68834f7](https://github.com/amzxyz/rime_wanxiang/commit/68834f763dcee2a8bea419a7f01cbce91981d7e2))
* 词库调整 ([3dc7592](https://github.com/amzxyz/rime_wanxiang/commit/3dc75927f44de66e7bfa6f33e67ebe1c1f5c1bc7))
* 词库调整 ([7501c62](https://github.com/amzxyz/rime_wanxiang/commit/7501c62d771f0b771186e3a042e388d514144413))


### 🐛 Bug 修复

* 反查改成权重排序，便于协作维护，Lua解决与单字表不对齐导致反查太极问题，删除单字表无读音字 ([cf86172](https://github.com/amzxyz/rime_wanxiang/commit/cf861724e9c97e87e72932996ba624a710c45f9e))


### 🏡 杂项

* 变更说明 ([43015bb](https://github.com/amzxyz/rime_wanxiang/commit/43015bb3458638de1dfb072e66a1a000d8285b53))

## [12.0.2](https://github.com/amzxyz/rime_wanxiang/compare/v12.0.1...v12.0.2) (2025-09-06)


### 🐛 Bug 修复

* 恢复次翻译器置后的逻辑 ([a3b303e](https://github.com/amzxyz/rime_wanxiang/commit/a3b303e8f3a98d12bcaaeb0242e88612d7d83c3a))

## [12.0.1](https://github.com/amzxyz/rime_wanxiang/compare/v12.0.0...v12.0.1) (2025-09-06)


### 🏡 杂项

* 修改说明 ([b2b65b5](https://github.com/amzxyz/rime_wanxiang/commit/b2b65b582ea3059e9a94fb2f472e501db39fd16e))
* 创建release ([0e3cca0](https://github.com/amzxyz/rime_wanxiang/commit/0e3cca08967d8e00b3c6dc0dba6690fac3317ae8))

## [12.0.0](https://github.com/amzxyz/rime_wanxiang/compare/v11.4.4...v12.0.0) (2025-09-05)


### 🏡 杂项

* release 12.0.0 ([906c6ce](https://github.com/amzxyz/rime_wanxiang/commit/906c6ce8b6ff24ac4295b487baef2689894e844d))

## [11.4.4](https://github.com/amzxyz/rime_wanxiang/compare/v11.4.3...v11.4.4) (2025-09-05)


### 💅 重构

* 快符功能变更，释放分号占用，进一步扩展斜杠万能键，使用间接辅助的支持a/26字母的自动上屏扩展，其他支持单字母和双字母扩展a/,aa/的自动上屏快速符号或任意字符，支持值为repeat时对应按键实现重复上屏，这么做的目标是释放符号占用，并进一步无感化，不知道的不会用的会无感，使用的则在手机上也能享受输入中/的上屏，虽然放弃了10个数字但是换来了更多扩展可能，此次改动得到70%用户支持。 ([c5d0080](https://github.com/amzxyz/rime_wanxiang/commit/c5d0080627e51206072c43998bdb995e14cda5cc))

## [11.4.3](https://github.com/amzxyz/rime_wanxiang/compare/v11.4.2...v11.4.3) (2025-09-05)


### 📚 词库更新

* 词库调整 ([6c84dec](https://github.com/amzxyz/rime_wanxiang/commit/6c84dec54d8696dc8f04b3e3b26d00a9c3564522))
* 词库调整 ([e24da0e](https://github.com/amzxyz/rime_wanxiang/commit/e24da0e4e0dfdef641ba1d78a4f3391a10adbc7c))
* 词库调整 ([7769b67](https://github.com/amzxyz/rime_wanxiang/commit/7769b67d28d34e17c9c4bc3b3cd877fb82895f69))

## [11.4.2](https://github.com/amzxyz/rime_wanxiang/compare/v11.4.1...v11.4.2) (2025-09-03)


### 📚 词库更新

* 增加军用型号词汇 ([73e8978](https://github.com/amzxyz/rime_wanxiang/commit/73e89787f791fd59653f21e3960c20c38b7e7146))
* 词库更新 ([d89ae73](https://github.com/amzxyz/rime_wanxiang/commit/d89ae73e8f6ae523f6e07af7669cf162e6de1df6))
* 词库更新 ([5ce1631](https://github.com/amzxyz/rime_wanxiang/commit/5ce1631443b3b1d0a621e781af1bb8edd85636c7))

## [11.4.1](https://github.com/amzxyz/rime_wanxiang/compare/v11.4.0...v11.4.1) (2025-09-02)


### 📚 词库更新

* 剔除大量冗余词汇 ([0e72d7a](https://github.com/amzxyz/rime_wanxiang/commit/0e72d7afbf479a261d21d07bae048722372da6eb))
* 词库调整 ([1b51428](https://github.com/amzxyz/rime_wanxiang/commit/1b51428d4f85beaa6801a40b4e0a2027d5c08636))
* 词库调整 ([85f8efc](https://github.com/amzxyz/rime_wanxiang/commit/85f8efc26ace235b1eb4baa7d5e2764a3e4663dd))
* 词库调整 ([4b0f0f3](https://github.com/amzxyz/rime_wanxiang/commit/4b0f0f38f303ea08c9a0b29de79bca92c78e6510))

## [11.4.0](https://github.com/amzxyz/rime_wanxiang/compare/v11.3.3...v11.4.0) (2025-08-29)


### ✨ 新特性

* 新增仓九宫格 ([bff0b78](https://github.com/amzxyz/rime_wanxiang/commit/bff0b7899eed8ee87cdd8c0b7bb1d3c096dbf02c))
* 新增仓九宫格方案 ([d689718](https://github.com/amzxyz/rime_wanxiang/commit/d689718a482b03e317389b0acf3e83e435775685))


### 📚 词库更新

* 词库调整 ([3eb19c6](https://github.com/amzxyz/rime_wanxiang/commit/3eb19c6b9fb3e72597fae3752cda3a5a5ddeb564))
* 词库调整 ([cb0a767](https://github.com/amzxyz/rime_wanxiang/commit/cb0a767917209fcaa6926c3bba3feed5960b371f))
* 词库调整 ([5ee002c](https://github.com/amzxyz/rime_wanxiang/commit/5ee002ce89b249c1a03c3d9d8d897611931b26f6))


### 🐛 Bug 修复

* 九宫格只限基础版 ([34b509d](https://github.com/amzxyz/rime_wanxiang/commit/34b509da8d4195bf6a70c9cb8d5839e2a3bac525))


### 🏡 杂项

* pr ([ba5584f](https://github.com/amzxyz/rime_wanxiang/commit/ba5584f8ca3d09fc3207a88e221ef368724b24a5))

## [11.3.3](https://github.com/amzxyz/rime_wanxiang/compare/v11.3.2...v11.3.3) (2025-08-27)


### 📚 词库更新

* 睡前更新 ([f78e690](https://github.com/amzxyz/rime_wanxiang/commit/f78e69054aa20e49906a622e019160b88690ec37))


### 🐛 Bug 修复

* 整合comment和preedit的Lua插件 ([38caa5f](https://github.com/amzxyz/rime_wanxiang/commit/38caa5f99ed0d91a676cfe02fc95e06cadcb65c1))

## [11.3.2](https://github.com/amzxyz/rime_wanxiang/compare/v11.3.1...v11.3.2) (2025-08-26)


### 📚 词库更新

* 词库调整 ([79cefe9](https://github.com/amzxyz/rime_wanxiang/commit/79cefe9b074dd7eaf26b94e9215b4833c07258a0))
* 词库调整 ([18513ae](https://github.com/amzxyz/rime_wanxiang/commit/18513ae795f3beb892f37bbcb0926bddde216006))
* 词库调整 ([f639846](https://github.com/amzxyz/rime_wanxiang/commit/f63984613cefb88e529febc77194c4166e33bca3))
* 词库调整 ([324f6b3](https://github.com/amzxyz/rime_wanxiang/commit/324f6b3906def65fee3004fbf577d26ed1d9a81c))
* 词库调整 ([70628ae](https://github.com/amzxyz/rime_wanxiang/commit/70628aee40e9f0a05d785cdcec70bd76d82e5ae0))
* 词库调整 ([78e8ca8](https://github.com/amzxyz/rime_wanxiang/commit/78e8ca8103d6a4e8d45b0ad1a46e412ae35339b2))
* 词库调整 ([40375b5](https://github.com/amzxyz/rime_wanxiang/commit/40375b57aab935f82ab2db76c9e7a27f2f4d34f7))


### 🐛 Bug 修复

* **lua:** Windows小狼毫相关问题修复 ([87c04e9](https://github.com/amzxyz/rime_wanxiang/commit/87c04e94d9ba33d27db657bca55c60b97fe6548a))
* 优化方案配置 ([222f899](https://github.com/amzxyz/rime_wanxiang/commit/222f899a03ee2dcd444689eff957f20986008ef0))
* 全拼优化 ([28fa338](https://github.com/amzxyz/rime_wanxiang/commit/28fa338614d64a60249ceef5aceeecfa51f4d49f))
* 去掉gc ([7682cfe](https://github.com/amzxyz/rime_wanxiang/commit/7682cfeb048da77e9ed8795135811099ec568374))
* 龙码使用全拼反查 ([2dddb5e](https://github.com/amzxyz/rime_wanxiang/commit/2dddb5eedd14e506c279238934ea887d55ced616))

## [11.3.1](https://github.com/amzxyz/rime_wanxiang/compare/v11.3.0...v11.3.1) (2025-08-21)


### 📚 词库更新

* 词库调整 ([59bcee9](https://github.com/amzxyz/rime_wanxiang/commit/59bcee9a86b7661826214c35888a7a37a576d28b))
* 词库调整 ([56feae8](https://github.com/amzxyz/rime_wanxiang/commit/56feae82118ab81c1d66dbe2cb2719b98ebf0cc3))


### 🔥 性能优化

* **tips:** tips 数据初始化性能优化 ([d0b7e0e](https://github.com/amzxyz/rime_wanxiang/commit/d0b7e0e9c28fcd6bb4e8417c9dafc024653421b2))


### 🐛 Bug 修复

* 移除个别纠错异常编码 ([47cd0eb](https://github.com/amzxyz/rime_wanxiang/commit/47cd0eb64cd4ea8ea51b52ef0c71f613b359fd6c))

## [11.3.0](https://github.com/amzxyz/rime_wanxiang/compare/v11.2.1...v11.3.0) (2025-08-20)


### ✨ 新特性

* **tips:** 支持通过配置禁用特定类型tips ([b092851](https://github.com/amzxyz/rime_wanxiang/commit/b0928510342be55fd70b0222aeb0247772887162))


### 📚 词库更新

* 增加一些常用词的emoji联想 ([c0943c4](https://github.com/amzxyz/rime_wanxiang/commit/c0943c4a425c6130fcbc011017ba5beb90a7fd7f))
* 词库调整 ([d0951f8](https://github.com/amzxyz/rime_wanxiang/commit/d0951f8c88d4841cea75204babccdb10095eb490))
* 词库调整 ([b4a34e7](https://github.com/amzxyz/rime_wanxiang/commit/b4a34e7bf5e0b887b491527904e5eeaa650d1ca1))


### 🔥 性能优化

* **tips:** 使用 Lua 5.2 的 bit32 库提升哈希计算效率 ([58a01e0](https://github.com/amzxyz/rime_wanxiang/commit/58a01e05dfbbfc181bd7d4a89b03d52649fb6302))


### 💅 重构

* **tips:** 使用独立的 userdb 管理数据库连接 ([117723e](https://github.com/amzxyz/rime_wanxiang/commit/117723e2e08fec3976e0489590cc8c6506df18d0))

## [11.2.1](https://github.com/amzxyz/rime_wanxiang/compare/v11.2.0...v11.2.1) (2025-08-19)


### 🐛 Bug 修复

* 调整反查数据排序 ([406bab0](https://github.com/amzxyz/rime_wanxiang/commit/406bab0a79d92b8431ab00750b1ee4bafd2e992b))

## [11.2.0](https://github.com/amzxyz/rime_wanxiang/compare/v11.1.5...v11.2.0) (2025-08-19)


### ✨ 新特性

* 笔画反查现在支持定义hspzn/hupvd可选 ([aeb183b](https://github.com/amzxyz/rime_wanxiang/commit/aeb183b2d7fca61b1805fe6545ae5b5ae026eb13))


### 📚 词库更新

* 词库调整 ([48be535](https://github.com/amzxyz/rime_wanxiang/commit/48be535dcbc8faf139791829ff425bb1b698a7af))
* 词库调整 ([c8cc656](https://github.com/amzxyz/rime_wanxiang/commit/c8cc65693fccb81f48ba91b7d2b5c48b78af7bd0))


### 🐛 Bug 修复

* **lua:** luajit 兼容性 ([24c2c34](https://github.com/amzxyz/rime_wanxiang/commit/24c2c344e537cdc9a8a0907df17a2e37ccdaa423))
* **typo_corrector:** 切换schema时的规则更新，并优化避免重复加载 ([6557b48](https://github.com/amzxyz/rime_wanxiang/commit/6557b4879526fe1b3116fa865a5ad7d30524f7f8))

## [11.1.5](https://github.com/amzxyz/rime_wanxiang/compare/v11.1.4...v11.1.5) (2025-08-18)


### 📚 词库更新

* 词库精简 ([373ceca](https://github.com/amzxyz/rime_wanxiang/commit/373ceca7777abcfefc928a7edc38fcc4c7893124))
* 词库调整 ([2e91a29](https://github.com/amzxyz/rime_wanxiang/commit/2e91a297706a53c4ed63541c8f33729a53c6eae2))


### 🐛 Bug 修复

* 计算器修复浮点问题 ([166c922](https://github.com/amzxyz/rime_wanxiang/commit/166c922d94a67e673855e88c2eaade32efb1af8c))

## [11.1.4](https://github.com/amzxyz/rime_wanxiang/compare/v11.1.3...v11.1.4) (2025-08-17)


### 📚 词库更新

* 词库调整 ([4e03b9f](https://github.com/amzxyz/rime_wanxiang/commit/4e03b9f90ac71b7714f5c8ee4c0a16441a815570))


### 🐛 Bug 修复

* 纠错程序增加开关 ([8c91604](https://github.com/amzxyz/rime_wanxiang/commit/8c916042f7a8041c817138e190a4116d4a839c1f))

## [11.1.3](https://github.com/amzxyz/rime_wanxiang/compare/v11.1.2...v11.1.3) (2025-08-16)


### 🐛 Bug 修复

* 修复纠错程序错误以及个别数据异常 ([9b16f0d](https://github.com/amzxyz/rime_wanxiang/commit/9b16f0d5188393146f65f28733857297ff34ed81))


### 🏡 杂项

* 更新 ([364ed40](https://github.com/amzxyz/rime_wanxiang/commit/364ed40354a5d060bc5faebdfd7c103254a64e47))

## [11.1.2](https://github.com/amzxyz/rime_wanxiang/compare/v11.1.1...v11.1.2) (2025-08-16)


### 📚 词库更新

* 词库删减 ([bd4f444](https://github.com/amzxyz/rime_wanxiang/commit/bd4f4449ebef6971b62142bec17ab5ef8c2c6cdc))
* 词库调整 ([bc8f1c7](https://github.com/amzxyz/rime_wanxiang/commit/bc8f1c77e5db0672d6550b53a95448ad45c88a16))


### 🐛 Bug 修复

* 五笔画去重 ([190486a](https://github.com/amzxyz/rime_wanxiang/commit/190486a5e67a52374c45bc82bb88e45650c4bccc))


### 🏡 杂项

* 更新版本 ([42cee67](https://github.com/amzxyz/rime_wanxiang/commit/42cee672a56d4e6db4054bad100a9d6def2620e4))

## [11.1.1](https://github.com/amzxyz/rime_wanxiang/compare/v11.1.0...v11.1.1) (2025-08-16)


### 🐛 Bug 修复

* 移除部分纠错数据 ([d647ccf](https://github.com/amzxyz/rime_wanxiang/commit/d647ccfe875911a8a8be26b09531bfe2499a769d))


### 🏡 杂项

* 版本更新 ([f26dbb2](https://github.com/amzxyz/rime_wanxiang/commit/f26dbb2a26ac427038e64f50a5d8ca838f7e94d0))

## [11.1.0](https://github.com/amzxyz/rime_wanxiang/compare/v11.0.0...v11.1.0) (2025-08-16)


### ✨ 新特性

* **lua:** 新增输入类型判断 ([2f93cbe](https://github.com/amzxyz/rime_wanxiang/commit/2f93cbe87475c65f26f56ec79ebb7668d160ef35))
* 新增全拼纠错 ([e75a758](https://github.com/amzxyz/rime_wanxiang/commit/e75a7581d58a25024747e71d1bbd3c7bdc034561))


### 📚 词库更新

* 新增人世间、如愿 ([cd83cbd](https://github.com/amzxyz/rime_wanxiang/commit/cd83cbd2873892d4e213121aa4861a8c414afad8))
* 词库调整 ([35a165c](https://github.com/amzxyz/rime_wanxiang/commit/35a165cfc945402e2a3e081e85318efc7c4dc7b3))
* 词库调整 ([11f3ac8](https://github.com/amzxyz/rime_wanxiang/commit/11f3ac876c6c93655d63a50988f3d402f5ab82e6))
* 词库调整 ([b7f7e28](https://github.com/amzxyz/rime_wanxiang/commit/b7f7e28acd0ba378eff3d92ced92a4c1c486fe0b))
* 词库调整 ([433d4b1](https://github.com/amzxyz/rime_wanxiang/commit/433d4b14945451f5d7f3346d2de9982edca96b53))
* 词库调整 ([268572b](https://github.com/amzxyz/rime_wanxiang/commit/268572b5cd557a80d45477ba496cdf64445019c3))
* 调整小鹤相关辅助码 ([759451c](https://github.com/amzxyz/rime_wanxiang/commit/759451c0ef43552fbb793d95caf8d6492a772a46))


### 🐛 Bug 修复

* custom新增前置通用模糊音示例 ([da84bf7](https://github.com/amzxyz/rime_wanxiang/commit/da84bf706d51284f536527cfe02748bc956f06a3))
* 为输入类型打上标记 ([88eaa58](https://github.com/amzxyz/rime_wanxiang/commit/88eaa58d1005000ca9599e8d7ea3d629579fc2a8))
* 纠错现在可以按输入类型匹配需要加载的数据 ([c924846](https://github.com/amzxyz/rime_wanxiang/commit/c92484666589d16d66e499d1c4ffa588720b1eea))


### 🏡 杂项

* 修改说明 ([8a76468](https://github.com/amzxyz/rime_wanxiang/commit/8a76468bd5f60f80180d31617703deb6f69bddd4))

## [11.0.0](https://github.com/amzxyz/rime_wanxiang/compare/v10.1.0...v11.0.0) (2025-08-10)


### 🐛 Bug 修复

* 完善配置 ([03c81d4](https://github.com/amzxyz/rime_wanxiang/commit/03c81d4cb634b47990bb54f0f411110340c54e41))


### 💅 重构

* 移除jdh辅助码预设 ([92b7cf3](https://github.com/amzxyz/rime_wanxiang/commit/92b7cf33571c941b823aae64cbe71114c4e13088))


### 🏡 杂项

* release 11.0.0 ([8c51408](https://github.com/amzxyz/rime_wanxiang/commit/8c5140883bb13a0e473e9f967014d38b047518b0))

## [10.1.0](https://github.com/amzxyz/rime_wanxiang/compare/v10.1.0...v10.1.0) (2025-08-10)
### ✨ 新特性

* **sequence:** 手动排序支持绑定自定义快捷键 ([5879171](https://github.com/amzxyz/rime_wanxiang/commit/5879171f5b4fd7e21ce5f45509f71e8aed9a474e))
* 调整同文皮肤 ([e0bea09](https://github.com/amzxyz/rime_wanxiang/commit/e0bea0912ef0d7f75ca402c3c8d8d8bf7b2a865c))


### 📚 词库更新

* 修正忒字读音 ([b9e0435](https://github.com/amzxyz/rime_wanxiang/commit/b9e04351bea30ad60701a74d56ffe81cc96a6bd1))
* 修正部分读音 ([ad379b1](https://github.com/amzxyz/rime_wanxiang/commit/ad379b12ed4b98c943c30142516679530ab603de))
* 删减无用词条 ([59875d3](https://github.com/amzxyz/rime_wanxiang/commit/59875d3f24b19f6011322fc20d21b8d809a83f20))
* 删减词条 ([078f9bf](https://github.com/amzxyz/rime_wanxiang/commit/078f9bf31b31bf08b00f482c3233d961331ccbff))
* 增加x也没x过 ([9a8730a](https://github.com/amzxyz/rime_wanxiang/commit/9a8730a67b73486686d8dfe3ba4449bb0b2bf874))


### 🤖 持续集成

* fix ci release note use google/release-please ([48ea3aa](https://github.com/amzxyz/rime_wanxiang/commit/48ea3aa09d00a7ec0ff99716bfb92be41b8af5be))
* 打包方案时忽略 release-please 配置 ([4b64314](https://github.com/amzxyz/rime_wanxiang/commit/4b6431470aa1df4823824c74da4cc877047d9002))

## [10.1.0](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.10...v10.1.0) (2025-08-09)


### ✨ 新特性

* 新增/gongcun创建一个全拼+共存方案 ([03c7b81](https://github.com/amzxyz/rime_wanxiang/commit/03c7b8103573e6445e5d21fff6226fe4ca8c40b9))
* 调整同文皮肤 ([e0bea09](https://github.com/amzxyz/rime_wanxiang/commit/e0bea0912ef0d7f75ca402c3c8d8d8bf7b2a865c))


### 📚 词库更新

* 增加x也没x过 ([9a8730a](https://github.com/amzxyz/rime_wanxiang/commit/9a8730a67b73486686d8dfe3ba4449bb0b2bf874))
* 词库新增 ([98198ce](https://github.com/amzxyz/rime_wanxiang/commit/98198ce9a76ab2b2345dbaef318c0275ad24279f))
* 词库调整 ([bd97187](https://github.com/amzxyz/rime_wanxiang/commit/bd97187bf4f0fef6eb33f43fc47468bbe29e84d8))
* 词库调整 ([9f54b32](https://github.com/amzxyz/rime_wanxiang/commit/9f54b32cdf355d61ceb13c9e5f975982487ff4bc))

## [10.0.10](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.9...v10.0.10) (2025-08-06)


### 🐛 Bug 修复

* 修复中英混输转写逻辑 ([d961407](https://github.com/amzxyz/rime_wanxiang/commit/d961407943191de7e6e2fa1b3cfe45ef61a3c7a0))


### 🏡 杂项

* 更新版本 ([963be43](https://github.com/amzxyz/rime_wanxiang/commit/963be43f144b482b0f8f5ab142db8b51ff196b8f))

## [10.0.9](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.8...v10.0.9) (2025-08-06)


### 📚 词库更新

* 词库调整 ([b1964e0](https://github.com/amzxyz/rime_wanxiang/commit/b1964e060b21e172c43976c6c1ef0b3d56dd2ea6))


### 🐛 Bug 修复

* **lua:** 保持与 Lua 5.1 的兼容性 ([24aa137](https://github.com/amzxyz/rime_wanxiang/commit/24aa13769e56b40221e2eecd741098d3012b6ae1))
* 同文主题适配新版app ([d7ebee6](https://github.com/amzxyz/rime_wanxiang/commit/d7ebee68b2816297d4413260df53c28d9d8eca22))


### 🏡 杂项

* 变更说明 ([3754c7f](https://github.com/amzxyz/rime_wanxiang/commit/3754c7fe37c8a12116b2b27a5f8dba293ed54276))

## [10.0.8](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.7...v10.0.8) (2025-08-05)


### 📚 词库更新

* 修正忒字读音 ([b9e0435](https://github.com/amzxyz/rime_wanxiang/commit/b9e04351bea30ad60701a74d56ffe81cc96a6bd1))
* 词库调整 ([1e8ad3f](https://github.com/amzxyz/rime_wanxiang/commit/1e8ad3f75f81c9a8d7ea8bbc5eccd72753af3e2b))
* 词库调整 ([5be8c0d](https://github.com/amzxyz/rime_wanxiang/commit/5be8c0df9c483db80348abbb5d20b86981ff80ac))
* 词库调整 ([315ef5a](https://github.com/amzxyz/rime_wanxiang/commit/315ef5af5af84b4832bbbfce2c6dcb060284cf61))
* 词库调整 ([8215f39](https://github.com/amzxyz/rime_wanxiang/commit/8215f39362e32b50c9993bee9dd62420c9d17cae))


### 🐛 Bug 修复

* 分号引导快符改成双击分号上屏分号，分号+'重复上屏 ([14c0716](https://github.com/amzxyz/rime_wanxiang/commit/14c0716c750aaae2ba339a8a8e59e4b421ed0ca2))


### 🏡 杂项

* **wanxiang:** release 10.0.7 ([b0056dd](https://github.com/amzxyz/rime_wanxiang/commit/b0056dd7dc085446d8ad7bf3888937a611f985f1))
* 修正说明 ([3f8db4e](https://github.com/amzxyz/rime_wanxiang/commit/3f8db4e91e5db0d86756c39c70fdfdd04a6d0c16))

## [10.0.7](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.6...v10.0.7) (2025-07-30)


### 🐛 Bug 修复

* **sequence:** 排序位置计算错误的问题 ([fe8fe8d](https://github.com/amzxyz/rime_wanxiang/commit/fe8fe8de50abc3cb0c174166b08dc009d324a8cf))

## [10.0.6](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.5...v10.0.6) (2025-07-30)


### 📚 词库更新

* 词库调整 ([6a1e0c4](https://github.com/amzxyz/rime_wanxiang/commit/6a1e0c4f0b6f47a5b4e3e3ced01f5b2b2e6cdca4))


### 🐛 Bug 修复

* **sequence:** position out of bounds 错误 ([8741763](https://github.com/amzxyz/rime_wanxiang/commit/8741763ae0e94f10f7e5e69fa20dbc7b06854246))
* 更新自动化说明 ([1b24de1](https://github.com/amzxyz/rime_wanxiang/commit/1b24de1199c0c4340e62fa12f7bbb4ce1a28edcc))

## [10.0.5](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.4...v10.0.5) (2025-07-28)


### 🐛 Bug 修复

* 持续优化中英混输转写，如遇到问题请反馈 ([34725d6](https://github.com/amzxyz/rime_wanxiang/commit/34725d62aefd02855738ba9e3860ec4b7920eaf8))
* 移除预测功能模块，现阶段数据建设难度大，前端匹配度不高，意义不大，看后续发展 ([2066179](https://github.com/amzxyz/rime_wanxiang/commit/2066179fbe95d89c6c8a2e89c10a248c27c4c7bd))

## [10.0.4](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.3...v10.0.4) (2025-07-27)


### 📚 词库更新

* 词库调整 ([6763b87](https://github.com/amzxyz/rime_wanxiang/commit/6763b87177a0c36fb71c4740d12e1136cb0b0c80))


### 🐛 Bug 修复

* 完善两分码表 ([d31b7f7](https://github.com/amzxyz/rime_wanxiang/commit/d31b7f7e339f37fb87dc13a8b2cf3d679aa41e4a))
* 完善混合编码转写，英文词库统一首字母大写编码 ([59c5e3c](https://github.com/amzxyz/rime_wanxiang/commit/59c5e3c73b9c5e69fa615dca4313bc4c12fd8083))

## [10.0.3](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.2...v10.0.3) (2025-07-25)


### 📚 词库更新

* 词库更新 ([303aa64](https://github.com/amzxyz/rime_wanxiang/commit/303aa6487845ed7e63e626794df13a1bbf846763))
* 词库调整 ([2656ef0](https://github.com/amzxyz/rime_wanxiang/commit/2656ef0de8c75c357ce19eb4038ac93ab325b080))

## [10.0.2](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.1...v10.0.2) (2025-07-25)


### 🐛 Bug 修复

* 修复混合输入全拼转写，新增preedit有声调无声调模式 ([67c3081](https://github.com/amzxyz/rime_wanxiang/commit/67c30819a18b69a3c467a4986e68f0d5a88a7fab))
* 修复自动化 ([18d02a4](https://github.com/amzxyz/rime_wanxiang/commit/18d02a443c4efbf9c819504d5124d8e03f849b4c))
* 修正lua和cue被汉语转写匹配的情况 ([91b6fc2](https://github.com/amzxyz/rime_wanxiang/commit/91b6fc2ccb53648e5d5643d8b333882642e8cf77))
* 每夜包含英文词库 ([5562664](https://github.com/amzxyz/rime_wanxiang/commit/5562664506cb9ef8071b7c070b3074487e4441e5))
* 若干说明 ([f7c6f30](https://github.com/amzxyz/rime_wanxiang/commit/f7c6f306da7326d091620541f934c567c95b0359))

## [10.0.1](https://github.com/amzxyz/rime_wanxiang/compare/v10.0.0...v10.0.1) (2025-07-24)


### 🐛 Bug 修复

* 修正自动化 ([7135c4a](https://github.com/amzxyz/rime_wanxiang/commit/7135c4a4dee956ad39d6a1e490701ec85d0ed93f))

## [10.0.0](https://github.com/amzxyz/rime_wanxiang/compare/v9.2.2...v10.0.0) (2025-07-24)


### ⚠ BREAKING CHANGES

* 本次重构主要为了以后便于各方面维护管理，梳理逻辑线，简化文件构成，具体如下：1.合并 组字与笔画词库和方案，2.混合词库与英文合并方案共用转写1000clips，Web3.0，GPT-4o这样的词直接做编码，无需预处理，3.合并词库为dicts文件夹共同管理，4.移除简码文件夹，成语放在dicts，预留简码数据放在custom

### 🐛 Bug 修复

* 修正自动化 ([4e8c2e0](https://github.com/amzxyz/rime_wanxiang/commit/4e8c2e0d5530ce7d7b47bf5bd8b9454487d836d6))


### 💅 重构

* 本次重构主要为了以后便于各方面维护管理，梳理逻辑线，简化文件构成，具体如下：1.合并 组字与笔画词库和方案，2.混合词库与英文合并方案共用转写1000clips，Web3.0，GPT-4o这样的词直接做编码，无需预处理，3.合并词库为dicts文件夹共同管理，4.移除简码文件夹，成语放在dicts，预留简码数据放在custom ([452b05f](https://github.com/amzxyz/rime_wanxiang/commit/452b05f90e89383b6570ad2b9773e1cd670f1f51))

## [9.2.2](https://github.com/amzxyz/rime_wanxiang/compare/v9.2.1...v9.2.2) (2025-07-23)


### 📚 词库更新

* 词库调整 ([94efeff](https://github.com/amzxyz/rime_wanxiang/commit/94efeffd075b8e0373ae3458285697fc1e0e1991))


### 🐛 Bug 修复

* 修正/符号为半角输出 ([2ecac62](https://github.com/amzxyz/rime_wanxiang/commit/2ecac62d524b738169130d585034152ed9ba0902))


### 🏡 杂项

* 修改说明 ([77f9427](https://github.com/amzxyz/rime_wanxiang/commit/77f942761f97a8fcbcf949520cef8b5bcbabfe62))
* 修改说明 ([b403032](https://github.com/amzxyz/rime_wanxiang/commit/b403032acd81a45407d460b0cbf583b458ea253e))
* 调整说明 ([8ab979a](https://github.com/amzxyz/rime_wanxiang/commit/8ab979ad0cf24050022d8d2d9cc429d3d54bb457))

## [9.2.1](https://github.com/amzxyz/rime_wanxiang/compare/v9.2.0...v9.2.1) (2025-07-22)


### 📚 词库更新

* **en:** 同步雾凇英文词库并去重 ([dde7bf3](https://github.com/amzxyz/rime_wanxiang/commit/dde7bf35c2bb10eb7c9cffb55edc578b44cf147d))

## [9.2.0](https://github.com/amzxyz/rime_wanxiang/compare/v9.1.3...v9.2.0) (2025-07-22)


### ✨ 新特性

* 新增快速初始化插件set_schema.lua ([f557533](https://github.com/amzxyz/rime_wanxiang/commit/f5575330c245d24d64fac5a7553da2717c79ec30))


### 📚 词库更新

* 词库优化 ([1f41bef](https://github.com/amzxyz/rime_wanxiang/commit/1f41bef92bdcf552859251771d9646f4f56e6aec))
* 词库调整 ([26a9626](https://github.com/amzxyz/rime_wanxiang/commit/26a96268a012c2c085df02086ac80971a1baf231))


### 🐛 Bug 修复

* **sequence:** 旧排序格式的数据迁移和导入 ([4f9f90f](https://github.com/amzxyz/rime_wanxiang/commit/4f9f90f8f30208b5f019cca26d1a8a96120aaff5))


### 🏡 杂项

* 修改说明 ([2b5c837](https://github.com/amzxyz/rime_wanxiang/commit/2b5c8379d7fa36ed58ffd35cdccd32210273ec80))

## [9.1.3](https://github.com/amzxyz/rime_wanxiang/compare/v9.1.2...v9.1.3) (2025-07-21)


### 🐛 Bug 修复

* **tips:** 首选时应从输入码回退到候选词 ([e7446ec](https://github.com/amzxyz/rime_wanxiang/commit/e7446ecc196e992fa7b6b371b6665f50e292469c))
* 增加大版本类型 ([981913e](https://github.com/amzxyz/rime_wanxiang/commit/981913ea80b6ea6f11353e9c622b932081bb16c8))

## [9.1.2](https://github.com/amzxyz/rime_wanxiang/compare/v9.1.1...v9.1.2) (2025-07-21)


### 📚 词库更新

* 词库调整 ([fd0cb93](https://github.com/amzxyz/rime_wanxiang/commit/fd0cb939a8f30d9bd9e2905e3c60767b7f25be17))


### 🐛 Bug 修复

* **tips:** 仅在首选时优先使用输入码查询tips ([ef89368](https://github.com/amzxyz/rime_wanxiang/commit/ef8936827c710059a436ab66b1db46773a157052))
* 修复呣呒两个字读音m引发的m无法打出“没”等派生字，我把他们放进M大写打出来 ([6c87743](https://github.com/amzxyz/rime_wanxiang/commit/6c877436a98b2046e2dc1f665422fc944d91897b))

## [9.1.1](https://github.com/amzxyz/rime_wanxiang/compare/v9.1.0...v9.1.1) (2025-07-20)


### 📚 词库更新

* 词库更新 ([6314d7b](https://github.com/amzxyz/rime_wanxiang/commit/6314d7bada38b91422880ed55a3148e7de047ad4))
* 词库调整 ([dedae3b](https://github.com/amzxyz/rime_wanxiang/commit/dedae3ba69bb53f017604a0b43dc903488a9248d))
* 错音修改 ([8ad9971](https://github.com/amzxyz/rime_wanxiang/commit/8ad997148a089be149433064129803c0e8258696))


### 🏡 杂项

* 更新说明 ([146a90a](https://github.com/amzxyz/rime_wanxiang/commit/146a90a0079c4388744b60c2c3433de7c6838508))

## [9.1.0](https://github.com/amzxyz/rime_wanxiang/compare/v9.0.1...v9.1.0) (2025-07-19)


### ✨ 新特性

* **sequence:** 手动排序支持绑定自定义快捷键 ([5879171](https://github.com/amzxyz/rime_wanxiang/commit/5879171f5b4fd7e21ce5f45509f71e8aed9a474e))


### 📚 词库更新

* 词库更新 ([75a91f5](https://github.com/amzxyz/rime_wanxiang/commit/75a91f5731f40716b2783e6fe5b84c6ede9a27a4))
* 词库调整 ([70c2eb9](https://github.com/amzxyz/rime_wanxiang/commit/70c2eb9f78a57733e24283b9d168e9ad54086aed))
* 词库调整 ([01ab267](https://github.com/amzxyz/rime_wanxiang/commit/01ab267942d063e1c16bafb9b7ec8dde1bf1c702))
* 词库调整 ([74917c8](https://github.com/amzxyz/rime_wanxiang/commit/74917c8d9b6867c39d6c2b9619a55f60f16547b0))


### 🐛 Bug 修复

* 修复中英混合词条编码 ([a91bef2](https://github.com/amzxyz/rime_wanxiang/commit/a91bef296245dc84ba8e2bfee291b551c30ed735))
* 提高压缩率 ([cb5a0a1](https://github.com/amzxyz/rime_wanxiang/commit/cb5a0a115141e72ccfd2384a07ed833b2bb2e263))
* 新增排序快捷键自定义 ([4053803](https://github.com/amzxyz/rime_wanxiang/commit/40538032ad8910ae4f029641d8129786e7d63eb2))
* 新增排序快捷键自定义 ([76b946a](https://github.com/amzxyz/rime_wanxiang/commit/76b946a729c941d462b8e465bec4fa7471487bd6))
* 新增部分/引导符号的tips ([b5a474b](https://github.com/amzxyz/rime_wanxiang/commit/b5a474bc580c58342cd2cd38d8b5ce787e9135dc))


### 🏡 杂项

* 精简log ([c20a36a](https://github.com/amzxyz/rime_wanxiang/commit/c20a36a9b4fc9a115a86dfa5045521fba2fed4a1))

## [9.0.1](https://github.com/amzxyz/rime_wanxiang/compare/v9.0.0...v9.0.1) (2025-07-18)


### 🐛 Bug 修复

* 压缩级别设置为9尝试 ([6a822ce](https://github.com/amzxyz/rime_wanxiang/commit/6a822ce530ef4f5721d6626afc44bab1ae4bcdef))

## [9.0.0](https://github.com/amzxyz/rime_wanxiang/compare/v8.10.1...v9.0.0) (2025-07-18)


### 🔥 性能优化

* **lua:** 使用新数据结构优化排序性能 ([d81d719](https://github.com/amzxyz/rime_wanxiang/commit/d81d719d26269f7eb06e906a368734b80a078bcc))


### 🐛 Bug 修复

* **lua:** tips metafiled 保持和 rime 一致的命名逻辑 ([4a9d241](https://github.com/amzxyz/rime_wanxiang/commit/4a9d2415a49aacb6e3c94e4a3ef7f2cbf2b4b5f4))


### 💅 重构

* 为彻底解决，中英文混合、带符号词(人名)连字符等形式词库的维护难度，后续将不再采用直接table方式导入，之前的方式，多文件存放占用空间大，多种类脚本维护难度大，大小写重复记录，以及这些难度带来的词汇新增速度慢的问题。后续将采用次方案的形式，采用基础词库+转写的方式适应多种双拼方案，万象将会在次领域再此引领！ ([e0b1769](https://github.com/amzxyz/rime_wanxiang/commit/e0b1769cc451318c76210b5b99d1d078090d7eaa))

## [8.10.0](https://github.com/amzxyz/rime_wanxiang/compare/v8.9.3...v8.10.0) (2025-07-17)


### ✨ 新特性

* 新增三伏天运算，随/day展示 ([ae1ea4e](https://github.com/amzxyz/rime_wanxiang/commit/ae1ea4e5b5d93204bb98d2b7bf24b4117b843b31))
* 新增通用简码库 ([d63cb60](https://github.com/amzxyz/rime_wanxiang/commit/d63cb60bddabdcc37afe5b4bc352c77419c6ce12))
* 时间Lua新增适当的tips，取消个别首选注释 ([a83e511](https://github.com/amzxyz/rime_wanxiang/commit/a83e5114679bf0f2f5519554df72cff967accc37))


### 📚 词库更新

* 修正部分读音 ([ad379b1](https://github.com/amzxyz/rime_wanxiang/commit/ad379b12ed4b98c943c30142516679530ab603de))
* 删减无用词条 ([59875d3](https://github.com/amzxyz/rime_wanxiang/commit/59875d3f24b19f6011322fc20d21b8d809a83f20))
* 删减词条 ([078f9bf](https://github.com/amzxyz/rime_wanxiang/commit/078f9bf31b31bf08b00f482c3233d961331ccbff))


### 🔥 性能优化

* **lua:** 优化tips初始化性能 ([a1c5eca](https://github.com/amzxyz/rime_wanxiang/commit/a1c5eca184eed5da19e37873a3827bb2cdd48428))
* **lua:** 修复新版排序性能下降的问题 ([08f0b5b](https://github.com/amzxyz/rime_wanxiang/commit/08f0b5b55cf94dd3ea4f4b3cb86231bef9766a31))


### 🐛 Bug 修复

* **lua:** sequence /指令排序会影响/symbol的问题 ([88eddac](https://github.com/amzxyz/rime_wanxiang/commit/88eddac686a53bc69449949188f3007d4e28317a)), closes [#206](https://github.com/amzxyz/rime_wanxiang/issues/206)
* **lua:** sequence 规避小狼毫和仓输入法的 user_id 不正确的问题 ([1b49bf5](https://github.com/amzxyz/rime_wanxiang/commit/1b49bf5f70c3c47c1b43c583dff6255097f38abe))
* **lua:** sequence 重置操作的同步支持 ([68fee1f](https://github.com/amzxyz/rime_wanxiang/commit/68fee1fc7b8242e6bcdb4ba62cc3fcd49189ba6a))
* **lua:** tips 不应重置非 tips 设置的 prompt ([e7fc10d](https://github.com/amzxyz/rime_wanxiang/commit/e7fc10d5474ac576397c373719588258b6e25063))
* **lua:** tips 应在每次候选切换后更新 ([5aebdaa](https://github.com/amzxyz/rime_wanxiang/commit/5aebdaa91b888c78f6030b57422f53fb7dbbd16e))
* **lua:** 手动排序使用偏移量排序 ([7b254d0](https://github.com/amzxyz/rime_wanxiang/commit/7b254d01eedbf6d1aae4199f42ca55111445b28a))
* **lua:** 手动排序后会产生大量无效排序记录的问题 ([69fa3d0](https://github.com/amzxyz/rime_wanxiang/commit/69fa3d0069b77ccb242dfc2f183c4eb9e4b0b261))
* **lua:** 移除排序调试日志 ([e973986](https://github.com/amzxyz/rime_wanxiang/commit/e973986e03ef052710c51fc0e56a73f922065857))
* 中文英标模式下保证/引导可用 ([eb4718b](https://github.com/amzxyz/rime_wanxiang/commit/eb4718b31c1e2545570a2913695ea164b6b9263d))
* 修正方案 ([5e4c672](https://github.com/amzxyz/rime_wanxiang/commit/5e4c672289a7dc46aa4bbf6cab463fa49e56d3a3))
* 关闭成语联想 ([349ef6d](https://github.com/amzxyz/rime_wanxiang/commit/349ef6d2a81f953769a02f448acb66f41a72d0d1))
* 删除预设简码 ([c611a5f](https://github.com/amzxyz/rime_wanxiang/commit/c611a5f917f8e472caef7801d3f41f1765e8f354))
* 删除预设简码 ([fdc238c](https://github.com/amzxyz/rime_wanxiang/commit/fdc238c2e53f2f1f1b45461b0c5d144d172b04e6))
* 字符集过滤增加符号tag豁免 ([b3d0264](https://github.com/amzxyz/rime_wanxiang/commit/b3d0264871e47113e161d3afd3c2fe1d125a7f36))
* 更新说明 ([7d8a2d2](https://github.com/amzxyz/rime_wanxiang/commit/7d8a2d23243684f019d1749b1209a7498a5f9084))
* 词库去重 ([ae85cc0](https://github.com/amzxyz/rime_wanxiang/commit/ae85cc0864075e4d8d3970ec1fb92bc10716bec0))
* 调整同文键盘，移除其他共健键盘，等待软件进一步进化再说 ([023496e](https://github.com/amzxyz/rime_wanxiang/commit/023496e5366a973570f08550eefca8484c1acc84))
* 调整超级注释位置,避免拆分与影子注释关联 ([3072e08](https://github.com/amzxyz/rime_wanxiang/commit/3072e08cad34a119eaf642f0555477868e5a270c))
* 调整预设简码权重 ([bf9db33](https://github.com/amzxyz/rime_wanxiang/commit/bf9db33ebe75f2da4ae021c35b3a2fb6bd3ab104))
* 通用简码精简 ([42da5fd](https://github.com/amzxyz/rime_wanxiang/commit/42da5fd5975ea1623cc8987d04d9fdaec0bfe84e))
* 预设分包方案修改 ([d7d9be7](https://github.com/amzxyz/rime_wanxiang/commit/d7d9be75a46d6f01f97583e995aca5de0dc0ff53))
* 预设分包方案修改翻译器排序 ([e012730](https://github.com/amzxyz/rime_wanxiang/commit/e012730fdbbeac4b50dcbd377a8d666a4181ceb8))


### 🤖 持续集成

* fix ci release note use google/release-please ([48ea3aa](https://github.com/amzxyz/rime_wanxiang/commit/48ea3aa09d00a7ec0ff99716bfb92be41b8af5be))
* 打包方案时忽略 release-please 配置 ([4b64314](https://github.com/amzxyz/rime_wanxiang/commit/4b6431470aa1df4823824c74da4cc877047d9002))

## [8.9.3](https://github.com/amzxyz/rime_wanxiang/compare/v8.9.2...v8.9.3) (2025-07-17)


### 🐛 Bug 修复

* 更新说明 ([7d8a2d2](https://github.com/amzxyz/rime_wanxiang/commit/7d8a2d23243684f019d1749b1209a7498a5f9084))

## [8.9.2](https://github.com/amzxyz/rime_wanxiang/compare/v8.9.1...v8.9.2) (2025-07-17)


### 📚 词库更新

* 词库调整 ([3ed9897](https://github.com/amzxyz/rime_wanxiang/commit/3ed989764c4137535b2583053607d543fd64c22c))

## [8.9.1](https://github.com/amzxyz/rime_wanxiang/compare/v8.9.0...v8.9.1) (2025-07-17)


### 🐛 Bug 修复

* **lua:** tips 应在每次候选切换后更新 ([5aebdaa](https://github.com/amzxyz/rime_wanxiang/commit/5aebdaa91b888c78f6030b57422f53fb7dbbd16e))

## [8.9.0](https://github.com/amzxyz/rime_wanxiang/compare/v8.8.2...v8.9.0) (2025-07-17)


### ✨ 新特性

* 新增三伏天运算，随/day展示 ([ae1ea4e](https://github.com/amzxyz/rime_wanxiang/commit/ae1ea4e5b5d93204bb98d2b7bf24b4117b843b31))
* 新增通用简码库 ([d63cb60](https://github.com/amzxyz/rime_wanxiang/commit/d63cb60bddabdcc37afe5b4bc352c77419c6ce12))
* 时间Lua新增适当的tips，取消个别首选注释 ([a83e511](https://github.com/amzxyz/rime_wanxiang/commit/a83e5114679bf0f2f5519554df72cff967accc37))


### 📚 词库更新

* 修正部分读音 ([ad379b1](https://github.com/amzxyz/rime_wanxiang/commit/ad379b12ed4b98c943c30142516679530ab603de))
* 删减无用词条 ([59875d3](https://github.com/amzxyz/rime_wanxiang/commit/59875d3f24b19f6011322fc20d21b8d809a83f20))
* 删减词条 ([078f9bf](https://github.com/amzxyz/rime_wanxiang/commit/078f9bf31b31bf08b00f482c3233d961331ccbff))
* 精简词库 ([29981ec](https://github.com/amzxyz/rime_wanxiang/commit/29981ec946f3604738ff42d3bb4a389c044f2815))


### 🔥 性能优化

* **lua:** 优化tips初始化性能 ([a1c5eca](https://github.com/amzxyz/rime_wanxiang/commit/a1c5eca184eed5da19e37873a3827bb2cdd48428))
* **lua:** 修复新版排序性能下降的问题 ([08f0b5b](https://github.com/amzxyz/rime_wanxiang/commit/08f0b5b55cf94dd3ea4f4b3cb86231bef9766a31))


### 🐛 Bug 修复

* **lua:** sequence /指令排序会影响/symbol的问题 ([88eddac](https://github.com/amzxyz/rime_wanxiang/commit/88eddac686a53bc69449949188f3007d4e28317a)), closes [#206](https://github.com/amzxyz/rime_wanxiang/issues/206)
* **lua:** sequence 规避小狼毫和仓输入法的 user_id 不正确的问题 ([1b49bf5](https://github.com/amzxyz/rime_wanxiang/commit/1b49bf5f70c3c47c1b43c583dff6255097f38abe))
* **lua:** sequence 重置操作的同步支持 ([68fee1f](https://github.com/amzxyz/rime_wanxiang/commit/68fee1fc7b8242e6bcdb4ba62cc3fcd49189ba6a))
* **lua:** 手动排序使用偏移量排序 ([7b254d0](https://github.com/amzxyz/rime_wanxiang/commit/7b254d01eedbf6d1aae4199f42ca55111445b28a))
* **lua:** 手动排序后会产生大量无效排序记录的问题 ([69fa3d0](https://github.com/amzxyz/rime_wanxiang/commit/69fa3d0069b77ccb242dfc2f183c4eb9e4b0b261))
* **lua:** 移除排序调试日志 ([e973986](https://github.com/amzxyz/rime_wanxiang/commit/e973986e03ef052710c51fc0e56a73f922065857))
* 中文英标模式下保证/引导可用 ([eb4718b](https://github.com/amzxyz/rime_wanxiang/commit/eb4718b31c1e2545570a2913695ea164b6b9263d))
* 删除预设简码 ([c611a5f](https://github.com/amzxyz/rime_wanxiang/commit/c611a5f917f8e472caef7801d3f41f1765e8f354))
* 删除预设简码 ([fdc238c](https://github.com/amzxyz/rime_wanxiang/commit/fdc238c2e53f2f1f1b45461b0c5d144d172b04e6))
* 字符集过滤增加符号tag豁免 ([b3d0264](https://github.com/amzxyz/rime_wanxiang/commit/b3d0264871e47113e161d3afd3c2fe1d125a7f36))
* 词库去重 ([ae85cc0](https://github.com/amzxyz/rime_wanxiang/commit/ae85cc0864075e4d8d3970ec1fb92bc10716bec0))
* 调整同文键盘，移除其他共健键盘，等待软件进一步进化再说 ([023496e](https://github.com/amzxyz/rime_wanxiang/commit/023496e5366a973570f08550eefca8484c1acc84))
* 调整超级注释位置,避免拆分与影子注释关联 ([3072e08](https://github.com/amzxyz/rime_wanxiang/commit/3072e08cad34a119eaf642f0555477868e5a270c))
* 调整预设简码权重 ([bf9db33](https://github.com/amzxyz/rime_wanxiang/commit/bf9db33ebe75f2da4ae021c35b3a2fb6bd3ab104))
* 通用简码精简 ([42da5fd](https://github.com/amzxyz/rime_wanxiang/commit/42da5fd5975ea1623cc8987d04d9fdaec0bfe84e))
* 预设分包方案修改 ([d7d9be7](https://github.com/amzxyz/rime_wanxiang/commit/d7d9be75a46d6f01f97583e995aca5de0dc0ff53))
* 预设分包方案修改翻译器排序 ([e012730](https://github.com/amzxyz/rime_wanxiang/commit/e012730fdbbeac4b50dcbd377a8d666a4181ceb8))


### 🤖 持续集成

* fix ci release note use google/release-please ([48ea3aa](https://github.com/amzxyz/rime_wanxiang/commit/48ea3aa09d00a7ec0ff99716bfb92be41b8af5be))
* 打包方案时忽略 release-please 配置 ([4b64314](https://github.com/amzxyz/rime_wanxiang/commit/4b6431470aa1df4823824c74da4cc877047d9002))

## [8.8.2](https://github.com/amzxyz/rime_wanxiang/compare/v8.8.1...v8.8.2) (2025-07-17)


### 📚 词库更新

* 词库更新 ([8ad66b3](https://github.com/amzxyz/rime_wanxiang/commit/8ad66b353b2b234ecc6fbe335d63f0728ba45627))
* 词库调整 ([a4484e8](https://github.com/amzxyz/rime_wanxiang/commit/a4484e839c3dbde83e9f279bc012ac5419f2286b))


### 🔥 性能优化

* **lua:** 优化tips初始化性能 ([a1c5eca](https://github.com/amzxyz/rime_wanxiang/commit/a1c5eca184eed5da19e37873a3827bb2cdd48428))


### 🐛 Bug 修复

* **lua:** 移除排序调试日志 ([e973986](https://github.com/amzxyz/rime_wanxiang/commit/e973986e03ef052710c51fc0e56a73f922065857))
* 中文英标模式下保证/引导可用 ([eb4718b](https://github.com/amzxyz/rime_wanxiang/commit/eb4718b31c1e2545570a2913695ea164b6b9263d))
* 调整同文键盘，移除其他共健键盘，等待软件进一步进化再说 ([023496e](https://github.com/amzxyz/rime_wanxiang/commit/023496e5366a973570f08550eefca8484c1acc84))
* 调整超级注释位置,避免拆分与影子注释关联 ([3072e08](https://github.com/amzxyz/rime_wanxiang/commit/3072e08cad34a119eaf642f0555477868e5a270c))


### 🏡 杂项

* 添加显示万象项目网址和当前版本号 ([922450e](https://github.com/amzxyz/rime_wanxiang/commit/922450ea5384093cbf952e999b6911f1bcd554b7))
* 添加显示万象项目网址和当前版本号 ([46f961e](https://github.com/amzxyz/rime_wanxiang/commit/46f961e1163a008dbed2b8f0cb11f29074d3768a))
* 添加显示万象项目网址和当前版本号 ([567d556](https://github.com/amzxyz/rime_wanxiang/commit/567d556ddc78c06009d27b869f97a86f2411c057))

## [8.8.1](https://github.com/amzxyz/rime_wanxiang/compare/v8.8.0...v8.8.1) (2025-07-16)


### 📚 词库更新

* 词库精简 ([e6f26c5](https://github.com/amzxyz/rime_wanxiang/commit/e6f26c580c898f027364bc56c80ef83ed0e37c45))
* 词库精简 ([d9d8ad1](https://github.com/amzxyz/rime_wanxiang/commit/d9d8ad1b388990bdb1498dec641d3aef1e8688db))
* 词库精简 ([dd93488](https://github.com/amzxyz/rime_wanxiang/commit/dd93488c6d19f8a5fc502cdfa9ce8aa497e208e4))


### 🔥 性能优化

* **lua:** 修复新版排序性能下降的问题 ([08f0b5b](https://github.com/amzxyz/rime_wanxiang/commit/08f0b5b55cf94dd3ea4f4b3cb86231bef9766a31))


### 🏡 杂项

* **lua:** wanxiang.lua 支持获取当前版本号 ([5fc6e95](https://github.com/amzxyz/rime_wanxiang/commit/5fc6e9536b4f953969acb5de8ebfcc0181296f70))

## [8.8.0](https://github.com/amzxyz/rime_wanxiang/compare/v8.7.7...v8.8.0) (2025-07-14)


### ✨ 新特性

* 新增三伏天运算，随/day展示 ([ae1ea4e](https://github.com/amzxyz/rime_wanxiang/commit/ae1ea4e5b5d93204bb98d2b7bf24b4117b843b31))


### 📚 词库更新

* 精简词库 ([29981ec](https://github.com/amzxyz/rime_wanxiang/commit/29981ec946f3604738ff42d3bb4a389c044f2815))
* 词库调整 ([c47b395](https://github.com/amzxyz/rime_wanxiang/commit/c47b39546eddfba8d21959113812033b4f4d9547))


### 🐛 Bug 修复

* **lua:** 手动排序使用偏移量排序 ([7b254d0](https://github.com/amzxyz/rime_wanxiang/commit/7b254d01eedbf6d1aae4199f42ca55111445b28a))
* 删除预设简码 ([c611a5f](https://github.com/amzxyz/rime_wanxiang/commit/c611a5f917f8e472caef7801d3f41f1765e8f354))

## [8.7.7](https://github.com/amzxyz/rime_wanxiang/compare/v8.7.6...v8.7.7) (2025-07-13)


### 🐛 Bug 修复

* 删除预设简码 ([fdc238c](https://github.com/amzxyz/rime_wanxiang/commit/fdc238c2e53f2f1f1b45461b0c5d144d172b04e6))

## [8.7.6](https://github.com/amzxyz/rime_wanxiang/compare/v8.7.5...v8.7.6) (2025-07-13)


### 📚 词库更新

* 词库调整 ([adf742a](https://github.com/amzxyz/rime_wanxiang/commit/adf742aa0c81938c1159eeadfcb4b50f1429a5ce))
* 词库调整 ([1799f73](https://github.com/amzxyz/rime_wanxiang/commit/1799f73f16f432093a4d566757ffea1cca650b94))
* 词库调整 ([f100496](https://github.com/amzxyz/rime_wanxiang/commit/f1004960ddfab7422b8c11ec18116881ada98760))


### 🐛 Bug 修复

* **lua:** 手动排序后会产生大量无效排序记录的问题 ([69fa3d0](https://github.com/amzxyz/rime_wanxiang/commit/69fa3d0069b77ccb242dfc2f183c4eb9e4b0b261))
* 字符集过滤增加符号tag豁免 ([b3d0264](https://github.com/amzxyz/rime_wanxiang/commit/b3d0264871e47113e161d3afd3c2fe1d125a7f36))

## [8.7.5](https://github.com/amzxyz/rime_wanxiang/compare/v8.7.4...v8.7.5) (2025-07-12)


### 🐛 Bug 修复

* 预设分包方案修改翻译器排序 ([e012730](https://github.com/amzxyz/rime_wanxiang/commit/e012730fdbbeac4b50dcbd377a8d666a4181ceb8))

## [8.7.4](https://github.com/amzxyz/rime_wanxiang/compare/v8.7.3...v8.7.4) (2025-07-12)


### 📚 词库更新

* 词库调整 ([1e01ec1](https://github.com/amzxyz/rime_wanxiang/commit/1e01ec100815f615d128aad98a315c4ae852bae5))


### 📖 文档

* 发行日志中加入 Arch Linux 安装小注 ([879baf4](https://github.com/amzxyz/rime_wanxiang/commit/879baf48aaea2432b927868f09062b0d05d2f49e))

## [8.7.3](https://github.com/amzxyz/rime_wanxiang/compare/v8.7.2...v8.7.3) (2025-07-11)


### 📚 词库更新

* 修正部分读音 ([ad379b1](https://github.com/amzxyz/rime_wanxiang/commit/ad379b12ed4b98c943c30142516679530ab603de))
* 词库调整 ([a3ba5e9](https://github.com/amzxyz/rime_wanxiang/commit/a3ba5e95b042992fb28b30c8ba16252222c2231b))
* 读音修正 ([977cad1](https://github.com/amzxyz/rime_wanxiang/commit/977cad1cf47cc1f4e49d8f449b32aec73ddb0b1b))


### 🐛 Bug 修复

* 通用简码精简 ([42da5fd](https://github.com/amzxyz/rime_wanxiang/commit/42da5fd5975ea1623cc8987d04d9fdaec0bfe84e))

## [8.7.2](https://github.com/amzxyz/rime_wanxiang/compare/v8.7.1...v8.7.2) (2025-07-10)


### 🐛 Bug 修复

* 调整预设简码权重 ([bf9db33](https://github.com/amzxyz/rime_wanxiang/commit/bf9db33ebe75f2da4ae021c35b3a2fb6bd3ab104))

## [8.7.1](https://github.com/amzxyz/rime_wanxiang/compare/v8.7.0...v8.7.1) (2025-07-10)


### 🐛 Bug 修复

* 预设分包方案修改 ([d7d9be7](https://github.com/amzxyz/rime_wanxiang/commit/d7d9be75a46d6f01f97583e995aca5de0dc0ff53))

## [8.7.0](https://github.com/amzxyz/rime_wanxiang/compare/v8.6.2...v8.7.0) (2025-07-10)


### ✨ 新特性

* 新增通用简码库 ([d63cb60](https://github.com/amzxyz/rime_wanxiang/commit/d63cb60bddabdcc37afe5b4bc352c77419c6ce12))
* 时间Lua新增适当的tips，取消个别首选注释 ([a83e511](https://github.com/amzxyz/rime_wanxiang/commit/a83e5114679bf0f2f5519554df72cff967accc37))


### 📚 词库更新

* 删减词条 ([078f9bf](https://github.com/amzxyz/rime_wanxiang/commit/078f9bf31b31bf08b00f482c3233d961331ccbff))
* 词库删改 ([d495937](https://github.com/amzxyz/rime_wanxiang/commit/d495937e2d0e135ada77bf021110d198691c28db))
* 词库调整 ([76ea067](https://github.com/amzxyz/rime_wanxiang/commit/76ea067130dd5beca9992daa361ee2cad3db5605))


### 🐛 Bug 修复

* **lua:** sequence /指令排序会影响/symbol的问题 ([88eddac](https://github.com/amzxyz/rime_wanxiang/commit/88eddac686a53bc69449949188f3007d4e28317a)), closes [#206](https://github.com/amzxyz/rime_wanxiang/issues/206)
* 词库去重 ([ae85cc0](https://github.com/amzxyz/rime_wanxiang/commit/ae85cc0864075e4d8d3970ec1fb92bc10716bec0))

## [8.6.2](https://github.com/amzxyz/rime_wanxiang/compare/v8.6.1...v8.6.2) (2025-07-09)


### 📚 词库更新

* 删减无用词条 ([59875d3](https://github.com/amzxyz/rime_wanxiang/commit/59875d3f24b19f6011322fc20d21b8d809a83f20))
* 词库调整 ([768384a](https://github.com/amzxyz/rime_wanxiang/commit/768384ad89e2f802f708de199df0529d4fb9447d))
* 词库调整 ([9562e98](https://github.com/amzxyz/rime_wanxiang/commit/9562e989d634bd4c3c569fc04d1eee012960e7b8))


### 🐛 Bug 修复

* **lua:** sequence 规避小狼毫和仓输入法的 user_id 不正确的问题 ([1b49bf5](https://github.com/amzxyz/rime_wanxiang/commit/1b49bf5f70c3c47c1b43c583dff6255097f38abe))
* **lua:** sequence 重置操作的同步支持 ([68fee1f](https://github.com/amzxyz/rime_wanxiang/commit/68fee1fc7b8242e6bcdb4ba62cc3fcd49189ba6a))


### 🏡 杂项

* readme完善 ([756564f](https://github.com/amzxyz/rime_wanxiang/commit/756564f8e0b1e8476c24462a4acac19b546d2b40))
* 简码词库放入jmdict文件夹 ([bd57576](https://github.com/amzxyz/rime_wanxiang/commit/bd575765019b20f4f80045063980504ac94fcbd9))


### 🤖 持续集成

* fix ci release note use google/release-please ([48ea3aa](https://github.com/amzxyz/rime_wanxiang/commit/48ea3aa09d00a7ec0ff99716bfb92be41b8af5be))
* 打包方案时忽略 release-please 配置 ([4b64314](https://github.com/amzxyz/rime_wanxiang/commit/4b6431470aa1df4823824c74da4cc877047d9002))
