#!/bin/bash
set -e

# 声明辅助码 zip 包类型显示名
declare -A display_names=(
  [wx]="万象"
  [zrm]="自然码"
  [moqi]="墨奇"
  [flypy]="小鹤"
  [hanxin]="汉心"
  [wubi]="五笔前2"
  [tiger]="虎码首末"
  [shouyou]="首右"
  [shyplus]="首右+"
)

# 仓库和下载地址定义
REPO_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}
DOWNLOAD_URL=${REPO_URL}/releases/download/${TAG_VERSION}

# 获取 changelog（标题相同的 commit 合并链接）
CHANGES=$(
  gh release view --json body -t "{{.body}}" "${TAG_VERSION}" | sed '1d; /./,$!d'
)

{
  echo "## 📝 更新日志"
  echo ""
  echo "${CHANGES}"
  echo ""
  echo "## 🚀 下载引导"
  echo ""
  echo "### 1. 标准版输入方案(Base)"
  echo ""
  echo "✨**适用类型：** 支持全拼、各种双拼"
  echo ""
  echo "✨**下载地址：** [rime-wanxiang-base.zip](${DOWNLOAD_URL}/rime-wanxiang-base.zip)"
  echo ""
  echo "### 2. 双拼辅助码增强版输入方案(Pro)"
  echo ""
  echo "✨**适用类型：** 支持各种双拼+辅助码的自由组合"

  for type in "${!display_names[@]}"; do
    name="${display_names[$type]}"
    echo "   - **${name}辅助版本：** [rime-wanxiang-${type}-fuzhu.zip](${DOWNLOAD_URL}/rime-wanxiang-${type}-fuzhu.zip)"
  done

  echo ""
  echo "### 3. 语法模型"
  echo ""
  echo "✨**适用类型：** 所有版本皆可用"
  echo ""
  echo "✨**下载地址：** [wanxiang-lts-zh-hans.gram](https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram)"
  echo ""
  echo "### 4. 预测数据库"
  echo ""
  echo "✨**新版已经基于lua构建的预测联想处理器，基于自训练的方式不再需要预设的数据，每个人都有自己的风格"
  echo ""
  echo "## 📘 使用说明(QQ群：11033572/11631066 参与讨论)"
  echo ""
  echo "1. **不使用辅助码的用户：**"
  echo ""
  echo "   请直接下载标准版，按仓库中的 [README.md](${REPO_URL}/blob/wanxiang/README.md) 配置使用。"
  echo ""
  echo "2. **使用增强版的用户：**"
  echo "   - PRO 每一个 zip 是**完整独立配置包**，其差异仅在于词库是否带有特定辅助码。"
  echo '   - zrm 仅表示“词库中包含zrm辅助码”，并**不代表这是自然码双拼方案，万象支持任意双拼与任意辅助码组合使用**。'
  echo "   - 若已有目标辅助码类型，只需下载对应 zip，解压后根据 README 中提示修改表头（例如双拼方案）即可使用。"
  echo ""
  echo "3. **语法模型需单独下载**，并放入输入法用户目录根目录（与方案文件放一起），**无需配置**。"
  echo ""
  echo "4. **可采用万象提供的更新器完成更新操作[点击跳转下载](https://github.com/amzxyz/RIME-LMDG/releases/tag/tool)**"
  echo ""
  echo "5. 💾 飞机盘下载地址（最快更新）：[点击访问](https://share.feijipan.com/s/xiGvXdKz)"
  echo ""
  echo "6. Arch Linux 用户 [启用 Arch Linux CN 仓库](https://www.archlinuxcn.org/archlinux-cn-repo-and-mirror/) 后安装。"
  echo "   - 基础版包名：\`rime-wanxiang-[拼写方案名]\`，如：自然码方案：\`rime-wanxiang-zrm\`"
  echo "   - 双拼辅助码增强版包名：\`rime-wanxiang-pro-[拼写方案名]\`，如：自然码方案：\`rime-wanxiang-pro-zrm\`"
  echo "7. deepin 25 用户亦可以通过仓库进行安装。"
  echo "### 4. 周边推荐"
  echo " - [高度适配万象拼音的仓输入法皮肤](https://github.com/BlackCCCat/ResourceforHamster/tree/main/Skin_Keyboard/)"
  echo ""
  echo " - [好用的更新脚本，助你优雅管理版本](https://github.com/rimeinn/rime-wanxiang-update-tools)"
  echo ""
  echo " - [万象cnb仓库，无需梯子的类GitHub仓库国内平台](https://cnb.cool/amzxyz/rime-wanxiang)"
} >release_notes.md
