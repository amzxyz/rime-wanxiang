#!/bin/bash
# 打包对用方案到 zip 文件，放到 dist 目录
set -e

ROOT_DIR="$(cd "$(dirname "$0")/../../../" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
CUSTOM_DIR="$ROOT_DIR/custom"

# 成成 PRO 分包文件
echo "▶️ PRO 分包开始"
python3 "$ROOT_DIR/.github/workflows/scripts/aux_go.py"
echo "✅ PRO 分包完毕"
echo

package_schema_base() {
  OUT_DIR=$1
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"

  # 1) custom/：仅拷贝 yaml/md/jpg/png，排除指定文件（保留目录结构）
  mkdir -p "$OUT_DIR/custom"
  rsync -av --prune-empty-dirs \
    --include='*/' \
    --exclude='wanxiang_chaifen_*.dict.yaml' \
    --exclude='wanxiang_chaifen.schema.yaml' \
    --exclude='wanxiang_pro.custom.yaml' \
    --exclude='wanxiang_pro.dict.yaml' \
    --exclude='wanxiang_pro.schema.yaml' \
    --include='*.yaml' --include='*.md' --include='*.jpg' --include='*.png' \
    --exclude='*' \
    "$CUSTOM_DIR/" "$OUT_DIR/custom/"

  # 2) 根目录 → $OUT_DIR（不排 dicts/），排除若干
  OUT_BASE="$(basename "$OUT_DIR")"
  rsync -av --ignore-existing \
    --exclude='/.*' \
    --exclude='/dist/' \
    --exclude='/release-please-config.json' \
    --exclude='/pro-*-fuzhu-dicts' \
    --exclude='/chaifen' \
    --exclude='/CHANGELOG.md' \
    --exclude='/custom' \
    --exclude='/LICENSE' \
    --exclude="/$OUT_BASE" \
    "$ROOT_DIR/" "$OUT_DIR/"
}

package_schema_pro() {
  SCHEMA_NAME="$1"
  OUT_DIR="$2"
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"

  # 1) 移动分包后的 dicts
  if [[ -d "$ROOT_DIR/pro-$SCHEMA_NAME-fuzhu-dicts" ]]; then
    mv "$ROOT_DIR/pro-$SCHEMA_NAME-fuzhu-dicts" "$OUT_DIR/dicts"
  fi
  # 1.1) 补充必要的附加文件
  for f in en.dict.yaml "cn&en.dict.yaml" chengyu.txt; do
    if [[ -f "$ROOT_DIR/dicts/$f" ]]; then
      cp "$ROOT_DIR/dicts/$f" "$OUT_DIR/dicts/"
    fi
  done

  # 2) 复制拆分表并重命名，同时拷贝 schema
  src="$ROOT_DIR/custom/wanxiang_chaifen_${SCHEMA_NAME}.dict.yaml"
  dst="$OUT_DIR/wanxiang_chaifen.dict.yaml"
  [[ -f "$src" ]] && cp "$src" "$dst"

  for f in \
    wanxiang_pro.dict.yaml \
    wanxiang_pro.schema.yaml \
    wanxiang_chaifen.schema.yaml
  do
    src="$ROOT_DIR/custom/$f"
    dst="$OUT_DIR/$f"
    [[ -f "$src" ]] && cp "$src" "$dst"
  done

  # 3) custom/：仅拷贝 yaml/md/jpg/png，排除若干（保留目录结构）
  mkdir -p "$OUT_DIR/custom"
  rsync -av --prune-empty-dirs \
    --include='*/' \
    --exclude='wanxiang.custom*' \
    --exclude='wanxiang_chaifen_*.dict.yaml' \
    --exclude='wanxiang_chaifen.schema.yaml' \
    --exclude='wanxiang_pro.dict.yaml' \
    --exclude='wanxiang_pro.schema.yaml' \
    --include='*.yaml' --include='*.md' --include='*.jpg' --include='*.png' \
    --exclude='*' \
    "$ROOT_DIR/custom/" "$OUT_DIR/custom/"

  # 4) 根目录 → $OUT_DIR（排除若干）
  OUT_BASE="$(basename "$OUT_DIR")"
  rsync -av --ignore-existing \
    --exclude='/.*' \
    --exclude='/dist/' \
    --exclude='/dicts' \
    --exclude='release-please-config.json' \
    --exclude='pro-*-fuzhu-dicts' \
    --exclude='wanxiang_t9.schema.yaml' \
    --exclude='CHANGELOG.md' \
    --exclude='wanxiang.dict.yaml' \
    --exclude='wanxiang.schema.yaml' \
    --exclude='custom' \
    --exclude='LICENSE' \
    --exclude="/$OUT_BASE" \
    "$ROOT_DIR/" "$OUT_DIR/"

  # 5) default.yaml:  - schema: wanxiang  ->  - schema: wanxiang_pro
  sed -i -E 's/^([[:space:]]*)-\s*schema:\s*wanxiang\s*$/\1- schema: wanxiang_pro/' "$OUT_DIR/default.yaml"
}



package_schema() {
    SCHEMA_NAME="$1"
    echo "▶️ 开始打包方案：$SCHEMA_NAME"

    if [[ "$SCHEMA_NAME" == "base" ]]; then
        OUT_DIR="$DIST_DIR/rime-wanxiang-base"
        package_schema_base "$OUT_DIR"

        ZIP_NAME=rime-wanxiang-"$SCHEMA_NAME".zip
    else
        OUT_DIR="$DIST_DIR/rime-wanxiang-$SCHEMA_NAME-fuzhu"
        package_schema_pro "$SCHEMA_NAME" "$OUT_DIR"

    fi

    ZIP_NAME=$(basename "$OUT_DIR").zip
    (cd "$OUT_DIR" && zip -r -9 -q ../"$ZIP_NAME" . && cd ..)
    echo "✅ 完成打包: $ZIP_NAME"
    echo
}

SCHEMA_LIST=("base" "flypy" "hanxin" "moqi" "tiger" "wubi" "zrm")

# 如果没有传入参数，则循环 package 所有的
if [[ -z "$SCHEMA_NAME" ]]; then
    for name in "${SCHEMA_LIST[@]}"; do
        package_schema "$name"
    done
    exit 0
fi

if [[ ! " ${SCHEMA_LIST[*]} " =~ ${SCHEMA_NAME} ]]; then
    echo "参数错误: 只支持 ${SCHEMA_LIST[*]}" >&2
    exit 1
fi

package_schema "$SCHEMA_NAME"