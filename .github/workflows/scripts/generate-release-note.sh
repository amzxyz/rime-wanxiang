#!/bin/bash
set -e

# 顺序数组（控制 Pro 横向输出的顺序）
types_order=("zrm" "flypy" "wx" "shouyou" "shyplus" "tiger" "moqi" "wubi" "hanxin")

# 声明辅助码显示名
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

# 获取 changelog
CHANGES=$(
  gh release view --json body -t "{{.body}}" "${TAG_VERSION}" | sed '1d; /./,$!d'
)

{
  echo "## 更新日志"
  echo ""
  echo "${CHANGES}"
  echo ""
  echo "---"
  echo ""
  echo "## 下载与选型指南"
  echo ""
  
  # 1. Base 区域
  echo "* **标准版 (Base)**：[下载方案](${DOWNLOAD_URL}/rime-wanxiang-base.zip)"
  echo "  * *适用人群*：纯全拼、纯双拼用户。"
  echo ""
  # 2. Pure 区域
  echo "* **精简版 (Pure)**：[下载方案](${DOWNLOAD_URL}/rime-wanxiang-pure.zip)"
  echo "  * *适用人群*：追求最小词库、仅需基础功能的用户。"
  echo "  * *适用场景*：Win7,fcitx4等低版本，不能使用lua插件的系统。"
  echo ""
  # 3. Pro 区域
  echo "* **双拼辅助码增强版 (Pro)**：均为独立完整配置包，含词库，支持任意双拼挂载，下载包等于选辅助码类型。"
  echo "  * *适用人群*：双拼+辅助码用户。"
  # 横向拼接 Pro 下载链接列表
  pro_links=""
  for type in "${types_order[@]}"; do
    name="${display_names[$type]}"
    link="[${name}辅助](${DOWNLOAD_URL}/rime-wanxiang-${type}-fuzhu.zip)"
    if [ -z "$pro_links" ]; then
      pro_links="$link"
    else
      pro_links="$pro_links | $link"
    fi
  done
  echo "  * *版本选择*：${pro_links}"
  echo ""
  
  # 4. 语法模型（并列同层级，强调必下）
  echo "* **大模型语法包 (必装组件)**：[点击下载语法模型](https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram)"
  echo "  * *使用说明*：**所有版本（Base/Pro）用户均必须下载此文件**。下载后直接放入输入法用户目录根目录（与方案文件放一起），无需任何额外配置。"
  echo ""
  
  echo "---"
  echo ""
  echo "## 分发渠道与周边生态"
  echo ""
  echo "* **Linux 仓库**："
  echo "  * *Arch Linux*：启用 [Arch Linux CN 仓库](https://www.archlinuxcn.org/archlinux-cn-repo-and-mirror/) 安装。基础版：\`rime-wanxiang-[方案名]\`；增强版：\`rime-wanxiang-pro-[方案名]\`"
  echo "  * *deepin 25*：已并入官方系统仓库，支持 \`apt install\` 部署"
  echo "* **周边生态**："
  echo "  * [仓输入法皮肤推荐](https://github.com/BlackCCCat/ResourceforHamster/tree/main/Skin_Keyboard/) | [高级版本管理更新脚本](https://github.com/rimeinn/rime-wanxiang-update-tools) | [万象 CNB 国内镜像源](https://cnb.cool/amzxyz/rime-wanxiang)"
} > release_notes.md