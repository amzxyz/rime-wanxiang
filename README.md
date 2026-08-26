<div align="center">

# 🌳 万象拼音

**重塑 Rime 生态，带来极致的输入体验。**

[![快速上手](https://img.shields.io/badge/🚀_快速上手-探索文档-4CAF50?style=for-the-badge)](https://amzxyz.github.io/rime-wanxiang/)
[![GitHub](https://img.shields.io/badge/⭐_GitHub_仓库-访问主页-2ea44f?style=for-the-badge)](https://github.com/amzxyz/rime-wanxiang)
<br>
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)
[![GitHub Release](https://img.shields.io/github/v/release/amzxyz/rime-wanxiang?filter=!nightly)](https://github.com/amzxyz/rime-wanxiang/releases/)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/amzxyz/rime-wanxiang/release.yml)](https://github.com/amzxyz/rime-wanxiang/actions/workflows/release.yml)
[![GitHub Repo stars](https://img.shields.io/github/stars/amzxyz/rime-wanxiang?style=flat&color=success)](https://github.com/amzxyz/rime-wanxiang/stargazers)

</div>

---

## 🌌 万象拼音——基于深度优化的词库和语法模型

> **💎 核心基石：** [万象词库](https://github.com/amzxyz/RIME-LMDG) 经 AI 与海量语料深度优化(目前已进入手动维护期)，是一款专为“语句流”“类大厂”打造的全方案立体词库。它将**带调拼音标注、词组构成与精准词频**作为体验基石，以日常与专业词汇为主体，结合语法模型，为您带来精准、流畅的输入体验。

* **开放生态**：支持高度自定义，鼓励通过“词库 + 转写”打造您的专属输入方案。
* **持续打磨**：我们极度重视数据准确与时效，欢迎随时反馈。
* 📝 **[万象词库问题收集反馈表](https://docs.qq.com/smartsheet/DWHZsdnZZaGh5bWJI?viewId=vUQPXH&tab=BB08J2)**


---

## ✨ 效果预览
![](https://storage.deepin.org/thread/202502200358104987_%E6%95%88%E6%9E%9C.png)

---

## 🧭 探索万象

<table width="100%" align="center" border="0" cellspacing="15" cellpadding="0">
  <tr>
    <td width="50%" valign="top">
      <div style="border: 1px solid #546e7a4d; border-radius: 12px; padding: 20px;">
        <h3>🚀 快速上手</h3>
        <p>从零开始，为您在 Windows、macOS 以及 iOS/Android 移动端部署万象。</p>
        <a href="https://amzxyz.github.io/rime-wanxiang/doc/intro"><strong>➡️ 立即安装</strong></a>
      </div>
    </td>
    <td width="50%" valign="top">
      <div style="border: 1px solid #546e7a4d; border-radius: 12px; padding: 20px;">
        <h3>⌨️ 核心输入体系</h3>
        <p>深入解析万象独特的“带调拼音标注”、强大的辅码系统（小鹤、自然码等）以及中英混输机制。</p>
        <a href="https://amzxyz.github.io/rime-wanxiang/doc/aux_code"><strong>➡️ 了解核心</strong></a>
      </div>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <div style="border: 1px solid #546e7a4d; border-radius: 12px; padding: 20px;">
        <h3>🪄 Lua 魔法扩展</h3>
        <p>计算器、超级注释、符号包裹、动态时间戳、超级符号库（按名输入数千 Unicode 符号）... 探索让 Rime 拥有“超能力”的数十种微创新脚本。</p>
        <a href="https://amzxyz.github.io/rime-wanxiang/doc/shijian"><strong>➡️ 探索魔法</strong></a>
      </div>
    </td>
    <td width="50%" valign="top">
      <div style="border: 1px solid #546e7a4d; border-radius: 12px; padding: 20px;">
        <h3>⚙️ 词库与模型</h3>
        <p>深度解析万象的现代数据工程。算一笔隐形的“时间账”，彻底告别低效的候选翻页，让输入如呼吸般自然。</p>
        <a href="https://amzxyz.github.io/rime-wanxiang/doc/dict_gram"><strong>➡️ 揭秘底层逻辑</strong></a>
      </div>
    </td>
  </tr>
</table>

---

## 💎 四种版本，怎么选？

万象目前提供 **Base / Pro / Lite / Pure** 四种发行方案。  
它们共享万象的核心数据体系，但在 **功能完整度、辅助码、Lua 扩展与运行环境** 上各有侧重。



|  | 🟢 **Base** | 🔵 **Pro** | 🟡 **Lite** | ⚪ **Pure** |
| :--- | :--- | :--- | :--- | :--- |
| **定位** | 完整标准版 | 双拼 / 辅助码增强版 | 轻量现代版 | 原生兼容版 |
| **适合谁** | 全拼、双拼及绝大多数用户 | 重度双拼、辅助码与精细控制用户 | 希望减少重型功能的日常用户 | 老系统、旧 Rime、无 Lua 环境 |
| **输入方式** | 全拼 + 双拼 | 双拼 + 多套辅助码 | 全拼 + 双拼 | 全拼 + 双拼 |
| **词库** | 完整带调万象词库 | 独立 Pro 辅助码词库 | 无声调 Lite 词库 | Pure 专用轻量入口 |
| **Lua 扩展** | ✅ 完整 | ✅ 完整增强 | 🟡 保留常用、裁剪重模块 | ❌ 不携带 Lua |
| **典型特点** | 功能全面，开箱即用 | 辅码、造词、筛选能力最强 | 更轻、更少依赖 | 最大化兼容性 |
| **主方案文件** | `wanxiang.schema.yaml` | `wanxiang_pro.schema.yaml` | `wanxiang_lite.schema.yaml` | `wanxiang_pure.schema.yaml` |

### 一句话推荐

- 🟢 **Base**：默认首选，第一次使用万象直接装它。
- 🔵 **Pro**：明确知道自己需要双拼辅助码、造词或更强筛选能力时选择。
- 🟡 **Lite**：喜欢 Base 的整体体验，但不需要预测、声调、复杂造词等重型功能。
- ⚪ **Pure**：优先考虑兼容性，适合 Win7、fcitx4-rime 或无法运行 Lua 的环境。

> 更完整的功能差异与选型说明，请查看 [万象拼音文档](https://amzxyz.github.io/rime-wanxiang/)。

---

## 生态：

[薄荷拼音](https://github.com/Mintimate/oh-my-rime) :使用万象词库的综合性方案，特别是其修改的地球拼音能够继承万象的词库声调编码。

[鸢鸣万象](https://github.com/yuanz-12/wanxiang_yoemin) :一个基于万象拼音生态融合李氏三拼与辅助码能力的手机用方案。

[万象虎](https://github.com/zhhwux/wxzhh) : 一个基于万象生态的虎码整句方案。

---

<div align="center" style="margin-top: 3rem; margin-bottom: 2rem;">
    <img alt="pay" src="./custom/赞赏.jpg" width="300" style="width: 300px !important; max-width: 300px !important;">
    <p style="margin-top: 1.2rem; font-size: 1.1em;">
         <strong>如果觉得项目好用，欢迎在 GitHub 为我们点亮 Star！</strong>
    </p>
    <p style="margin-top: 0.5rem; color: #555;">
    <p style="margin-top: 0.5rem; opacity: 0.8;">
        <i>用更优质的数据，接管你的候选词。</i>
    </p>
</div>