---
# 彻底隐藏首页的侧边菜单和右侧大纲，腾出巨幕空间
hide:
  - navigation
  - toc
---

<style>

/* =========================================
   修复：抹除全局 CSS 在首页留下的侧边栏空白，强制绝对居中
   ========================================= */
body .md-content {
  margin-left: 0 !important;
}

.md-grid {
  max-width: 60rem !important; /* 限制首页最大宽度，让巨幕更聚拢、更好看 */
}

/* 1. 强制 PC 端网格为完美的 2x2 对称布局 */
@media screen and (min-width: 60em) {
  .md-typeset .grid.cards.symmetric-2x2 {
    grid-template-columns: repeat(2, 1fr) !important;
  }
}

/* 2. 手写大厂风巨幕 (Hero) 样式 */
.custom-hero {
  text-align: center;
  padding: 4rem 1rem;
  background: linear-gradient(135deg, rgba(97, 161, 101, 0.08) 0%, rgba(77, 162, 82, 0.03) 100%);
  border-radius: 16px;
  margin-top: 1rem;
  margin-bottom: 3.5rem;
  border: 1px solid rgba(97, 161, 101, 0.15);
  box-shadow: 0 4px 20px rgba(97, 161, 101, 0.03);
}

.custom-hero h1 {
  font-size: 2.8rem !important;
  font-weight: 800 !important;
  color: #49814D !important;
  margin-bottom: 1rem !important;
  border-bottom: none !important;
  display: block !important;
}

.custom-hero p {
  font-size: 1.2rem;
  color: #555;
  max-width: 100%;
  margin: 0 auto 2rem;
  line-height: 1.6;
  white-space: nowrap;
}

.hero-buttons {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 1rem;
}

.custom-hero .md-button {
  border-radius: 8px;
  font-weight: 600;
  padding: 0.6rem 1.8rem;
  transition: all 0.3s ease;
  margin: 0 !important;
}

[data-md-color-scheme="slate"] .custom-hero {
  background: linear-gradient(135deg, rgba(97, 161, 101, 0.15) 0%, rgba(30, 40, 32, 0.5) 100%);
  border-color: rgba(97, 161, 101, 0.3);
}

[data-md-color-scheme="slate"] .custom-hero h1 {
  color: #7EBA82 !important;
}

[data-md-color-scheme="slate"] .custom-hero p {
  color: #A3B8A5;
}

@media screen and (max-width: 768px) {
  .custom-hero {
    padding: 2.5rem 0.2rem;
  }

  .custom-hero h1 {
    font-size: 2.2rem !important;
  }

  .custom-hero p {
    white-space: nowrap !important;
    font-size: clamp(0.78rem, 3.8vw, 1.15rem);
    letter-spacing: -0.6px;
    transform-origin: center;
    padding: 0;
  }

  .hero-buttons {
    flex-direction: row;
    gap: 0.5rem;
  }

  .hero-buttons .md-button {
    width: auto;
    padding: 0.5rem 1rem;
    font-size: 0.85rem;
  }
}

/* =========================================
   四版本选型区
   ========================================= */
.edition-breakout {
  width: 100%;
  margin: 2rem 0 3rem;
}

.edition-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 1rem;
}

.edition-card {
  display: flex;
  flex-direction: column;
  background: var(--md-default-bg-color);
  border: 1px solid rgba(97, 161, 101, 0.22);
  border-radius: 16px;
  padding: 1.4rem;
  min-width: 0;
  box-shadow: 0 4px 18px rgba(0, 0, 0, 0.035);
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
}

.edition-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 10px 30px rgba(97, 161, 101, 0.12);
  border-color: rgba(97, 161, 101, 0.45);
}

.edition-card.base { border-top: 4px solid #61A165; }
.edition-card.pro  { border-top: 4px solid #4F78A8; }
.edition-card.lite { border-top: 4px solid #A4B66B; }
.edition-card.pure { border-top: 4px solid #8B8B8B; }

.edition-head {
  text-align: center;
  margin-bottom: 1rem;
}

.edition-icon {
  width: 58px;
  height: 58px;
  margin: 0 auto 0.7rem;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
  background: rgba(97, 161, 101, 0.08);
  font-size: 1.8rem;
}

.edition-head h3 {
  margin: 0 !important;
  font-size: 1.35rem;
}

.edition-head p {
  margin: 0.45rem 0 0;
  color: #777;
  font-size: 0.83rem;
  line-height: 1.5;
}

.edition-badge {
  display: inline-block;
  margin-top: 0.7rem;
  padding: 0.2rem 0.65rem;
  border-radius: 999px;
  background: rgba(97, 161, 101, 0.1);
  color: #49814D;
  font-size: 0.72rem;
  font-weight: 700;
}

.edition-row {
  border-top: 1px solid rgba(127, 127, 127, 0.13);
  padding: 0.72rem 0;
  font-size: 0.84rem;
  line-height: 1.55;
}

.edition-row b {
  display: block;
  color: #777;
  font-size: 0.73rem;
  margin-bottom: 0.18rem;
}

.edition-final {
  margin-top: auto;
  padding-top: 1rem;
  text-align: center;
  font-weight: 700;
  color: #49814D;
}

[data-md-color-scheme="slate"] .edition-card {
  background: rgba(255, 255, 255, 0.025);
}

[data-md-color-scheme="slate"] .edition-head p,
[data-md-color-scheme="slate"] .edition-row b {
  color: #A3ADA4;
}

/* 普通 PC 尽量保持四列；较窄窗口 / 平板切换为 2×2 */
@media screen and (max-width: 64rem) {
  .edition-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

/* 手机单列 */
@media screen and (max-width: 44rem) {
  .edition-grid {
    grid-template-columns: 1fr;
  }
}

</style>

<div class="custom-hero">
  <h1>万象拼音</h1>
  <p>重塑 Rime 生态，带来极致的输入体验。</p>
  <div class="hero-buttons">
    <a href="doc/intro/" class="md-button md-button--primary">🚀 快速上手</a>
    <a href="https://github.com/amzxyz/rime-wanxiang" class="md-button">⭐ GitHub 仓库</a>
  </div>
</div>

## 🧭 探索万象

<div class="grid cards symmetric-2x2" markdown>

-   :material-rocket-launch: **__快速上手__**

    ---

    从零开始，为您在 Windows、macOS 以及 iOS/Android 移动端部署万象。

    [:octicons-arrow-right-24: 立即安装](doc/intro.md)

-   :material-keyboard-variant: **__核心输入体系__**

    ---

    深入解析万象独特的“带调拼音标注”、强大的辅码系统（小鹤、自然码等）以及中英混输机制。

    [:octicons-arrow-right-24: 了解核心](doc/aux_code.md)

-   :material-magic-staff: **__Lua 魔法扩展__**

    ---

    计算器、超级注释、符号包裹、动态时间戳... 探索让 Rime 拥有“超能力”的数十种微创新脚本。

    [:octicons-arrow-right-24: 探索魔法](doc/shijian.md)

-   :material-cogs: **__词库与模型__**

    ---

    深度解析万象的现代数据工程。算一笔隐形的“时间账”，彻底告别低效的候选翻页，让输入如呼吸般自然。

    [:octicons-arrow-right-24: 揭秘底层逻辑](doc/dict_gram.md)

</div>

---

## 💎 选择适合你的万象

四个版本共享万象的核心数据体系，但在 **功能完整度、辅助码、Lua 扩展与运行环境** 上各有侧重。

<div class="edition-breakout">
<div class="edition-grid">

<div class="edition-card base">
  <div class="edition-head">
    <div class="edition-icon">🟢</div>
    <h3>Base</h3>
    <p>完整、通用、开箱即用</p>
    <span class="edition-badge">大多数用户首选</span>
  </div>
  <div class="edition-row"><b>适合谁</b>全拼、普通双拼、第一次使用万象的用户</div>
  <div class="edition-row"><b>输入体系</b>全拼 + 任意双拼</div>
  <div class="edition-row"><b>词库</b>完整带调万象词库</div>
  <div class="edition-row"><b>Lua 能力</b>完整：预测、计算器、时间、符号、提示、造词等</div>
  <div class="edition-final">不知道选什么 → Base</div>
</div>

<div class="edition-card pro">
  <div class="edition-head">
    <div class="edition-icon">🔵</div>
    <h3>Pro</h3>
    <p>双拼与辅助码深度增强</p>
    <span class="edition-badge">高阶用户</span>
  </div>
  <div class="edition-row"><b>适合谁</b>双拼重度用户、辅助码用户</div>
  <div class="edition-row"><b>输入体系</b>双拼 + 多套辅助码</div>
  <div class="edition-row"><b>词库</b>独立 Pro 辅助码词库</div>
  <div class="edition-row"><b>核心特点</b>精准筛选、固定编码、造词与更强控制</div>
  <div class="edition-final">双拼 + 辅助码 → Pro</div>
</div>

<div class="edition-card lite">
  <div class="edition-head">
    <div class="edition-icon">🍃</div>
    <h3>Lite</h3>
    <p>轻量，但保留现代体验</p>
    <span class="edition-badge">轻量首选</span>
  </div>
  <div class="edition-row"><b>适合谁</b>不需要复杂预测、造词与高级模块的日常用户</div>
  <div class="edition-row"><b>输入体系</b>全拼 + 双拼</div>
  <div class="edition-row"><b>词库</b>无声调 Lite 词库</div>
  <div class="edition-row"><b>Lua 能力</b>保留常用功能，裁掉部分重模块</div>
  <div class="edition-final">想轻一点 → Lite</div>
</div>

<div class="edition-card pure">
  <div class="edition-head">
    <div class="edition-icon">❄️</div>
    <h3>Pure</h3>
    <p>原生核心，兼容性优先</p>
    <span class="edition-badge">特殊环境</span>
  </div>
  <div class="edition-row"><b>适合谁</b>老系统、旧 Rime、Lua 不可用环境</div>
  <div class="edition-row"><b>运行核心</b>Rime 原生 Processor / Translator / Filter</div>
  <div class="edition-row"><b>Lua 能力</b>不携带 Lua</div>
  <div class="edition-row"><b>典型环境</b>Win7、fcitx4-rime 等</div>
  <div class="edition-final">兼容性第一 → Pure</div>
</div>

</div>
</div>

---

<div style="margin-top: 2rem;"></div>

## 🤝 参与共建

万象是一个持续打磨的开放生态。我们极度重视数据准确与时效，欢迎您随时反馈。

* 📝 [万象词库问题收集反馈表](https://docs.qq.com/smartsheet/DWHZsdnZZaGh5bWJI?viewId=vUQPXH&tab=BB08J2)
* 🌟 如果觉得项目好用，欢迎在 GitHub 为我们点亮 **Star**！

<div align="center" style="margin-top: 2.5rem;">
  <img src="image/donate.jpg" alt="赞赏支持 AMZ" width="220" style="border-radius: 12px; box-shadow: 0 8px 24px rgba(97, 161, 101, 0.15); border: 1px solid rgba(97, 161, 101, 0.2);">
  <p style="margin-top: 1rem; color: #49814D; font-weight: 600; letter-spacing: 1px;">☕ 感谢您的赞赏与支持</p>
</div>

<br><br>

<div align="center" style="opacity: 0.6; font-size: 0.9em;">
  <i>用更现代的数据，接管你的候选词。</i>
</div>
