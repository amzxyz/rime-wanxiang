# Changelog

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
