<div align="center">

# 🌳 万象拼音

**重塑 Rime 生态，带来极致的输入体验。**

[![快速上手](https://img.shields.io/badge/🚀_快速上手-探索文档-4CAF50?style=for-the-badge)](https://amzxyz.github.io/)
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
        <a href="https://amzxyz.github.io/doc/intro"><strong>➡️ 立即安装</strong></a>
      </div>
    </td>
    <td width="50%" valign="top">
      <div style="border: 1px solid #546e7a4d; border-radius: 12px; padding: 20px;">
        <h3>⌨️ 核心输入体系</h3>
        <p>深入解析万象独特的“带调拼音标注”、强大的辅码系统（小鹤、自然码等）以及中英混输机制。</p>
        <a href="https://amzxyz.github.io/doc/aux_code"><strong>➡️ 了解核心</strong></a>
      </div>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <div style="border: 1px solid #546e7a4d; border-radius: 12px; padding: 20px;">
        <h3>🪄 Lua 魔法扩展</h3>
        <p>计算器、超级注释、符号包裹、动态时间戳... 探索让 Rime 拥有“超能力”的数十种微创新脚本。</p>
        <a href="https://amzxyz.github.io/doc/shijian"><strong>➡️ 探索魔法</strong></a>
      </div>
    </td>
    <td width="50%" valign="top">
      <div style="border: 1px solid #546e7a4d; border-radius: 12px; padding: 20px;">
        <h3>⚙️ 词库与模型</h3>
        <p>深度解析万象的现代数据工程。算一笔隐形的“时间账”，彻底告别低效的候选翻页，让输入如呼吸般自然。</p>
        <a href="https://amzxyz.github.io/doc/dict_gram"><strong>➡️ 揭秘底层逻辑</strong></a>
      </div>
    </td>
  </tr>
</table>

---

## 💎 标准版 vs 增强版

万象提供两个主要版本，请根据您的输入习惯选择。为了获得最佳体验，**请务必了解您所选版本的特性**：


| 特性对比 <img width="180" style="display:none;" /> | 🟢 标准版 (Base) <img width="340" style="display:none;" /> | 🔵 增强版 (Pro) <img width="340" style="display:none;" /> |
| :--- | :--- | :--- |
| **适用人群** | 新手、全拼用户、追求省心的双拼用户 | 硬核双拼用户、重度辅码与造词需求者 |
| **方案文件** | `wanxiang.schema.yaml` | `wanxiang_pro.schema.yaml` |
| **支持类型** | 全拼、任意双拼 | **仅支持双拼** |
| **自动调频** | 默认开启 | **默认关闭** (精准控制) |
| **用户词记录** | 自动记录，无差别积累 | 手动/无感造词，词库绝对可控 |
| **辅助码支持** | 仅基于声调的辅助 | **8 种辅助码可选** + 声调辅助 |
| **全场景辅筛** | 支持两分、多分、笔画、声调 | 全面支持 + 专属辅助码筛选 |

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
        <strong>☕ 感谢您的赞赏与支持</strong>
    </p>
    <p style="margin-top: 0.5rem; opacity: 0.8;">
        <i>用更现代的数据，接管你的候选词。</i>
    </p>
</div>