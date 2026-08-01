#!/bin/bash
# 打包对用方案到 zip 文件，放到 dist 目录
set -e

ROOT_DIR="$(cd "$(dirname "$0")/../../../" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
CUSTOM_DIR="$ROOT_DIR/custom"
EXCLUDE_DICT_FILES=(
  "xxx.dict.yaml"
  # "wuzhong.dict.yaml"
  # "renming.dict.yaml"
  # "wuzhong.pro.dict.yaml"
  # "renming.pro.dict.yaml"
)
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
    --exclude='wanxiang_pro.custom.yaml' \
    --exclude='wanxiang_pro.dict.yaml' \
    --exclude='wanxiang_pro.schema.yaml' \
    --exclude='wanxiang_pure.dict.yaml' \
    --exclude='wanxiang_pure.schema.yaml' \
    --exclude='wanxiang_pure.custom.yaml' \
    --include='*.yaml' --include='*.md' --include='*.jpg' --include='*.png' \
    --exclude='*' \
    "$CUSTOM_DIR/" "$OUT_DIR/custom/"

  # 2) 根目录 → $OUT_DIR（不排 dicts/），排除若干
  OUT_BASE="$(basename "$OUT_DIR")"
  rsync -av --ignore-existing \
    --exclude='/.*' \
    --exclude='/dist/' \
    --exclude='/docs/' \
    --exclude='/mkdocs.yml' \
    --exclude='/release-please-config.json' \
    --exclude='/pro-*-fuzhu-dicts' \
    --exclude='/CHANGELOG.md' \
    --exclude='.yamlfmt' \
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
  for f in en.dict.yaml "mixed.dict.yaml"; do
    if [[ -f "$ROOT_DIR/dicts/$f" ]]; then
      cp "$ROOT_DIR/dicts/$f" "$OUT_DIR/dicts/"
    fi
  done

  # 2) 复制拆分表并重命名，同时拷贝 schema
  src="$ROOT_DIR/custom/${SCHEMA_NAME}_chaifen.txt"
  dst="$OUT_DIR/lua/data/chaifen.txt"
  mkdir -p "$(dirname "$dst")"
  [[ -f "$src" ]] && cp "$src" "$dst"

  for f in \
    wanxiang_pro.dict.yaml \
    wanxiang_pro.schema.yaml
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
    --exclude='wanxiang_pro.dict.yaml' \
    --exclude='wanxiang_pro.schema.yaml' \
    --exclude='wanxiang_pure.dict.yaml' \
    --exclude='wanxiang_pure.schema.yaml' \
    --exclude='wanxiang_pure.custom.yaml' \
    --include='*.yaml' --include='*.md' --include='*.jpg' --include='*.png' \
    --exclude='*' \
    "$ROOT_DIR/custom/" "$OUT_DIR/custom/"

  # 4) 根目录 → $OUT_DIR（排除若干）
  OUT_BASE="$(basename "$OUT_DIR")"
  rsync -av --ignore-existing \
    --exclude='/.*' \
    --exclude='/dist/' \
    --exclude='/dicts' \
    --exclude='/docs/' \
    --exclude='/mkdocs.yml' \
    --exclude='.yamlfmt' \
    --exclude='release-please-config.json' \
    --exclude='pro-*-fuzhu-dicts' \
    --exclude='wanxiang_t9.schema.yaml' \
    --exclude='wanxiang_t9i.schema.yaml' \
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

package_schema_pure() {
    OUT_DIR="$DIST_DIR/rime-wanxiang-pure"
    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR/dicts"

    # 白名单词库：只复制指定的 .dict.yaml 文件
    PURE_DICT_WHITELIST=(
        "zi.dict.yaml"
        "jichu.dict.yaml"
        "lianxiang.dict.yaml"
        "cuoyin.dict.yaml"
        "duoyin.dict.yaml"
        "shici.dict.yaml"
        "diming.dict.yaml"
    )
    for dict_file in "${PURE_DICT_WHITELIST[@]}"; do
        if [[ -f "$ROOT_DIR/dicts/$dict_file" ]]; then
            cp "$ROOT_DIR/dicts/$dict_file" "$OUT_DIR/dicts/"
        else
            echo "警告: 白名单词库 $dict_file 不存在，跳过"
        fi
    done

    # 如果 wanxiang_pure.schema.yaml 或其它文件引用了 en.dict.yaml，可以取消注释：
    # if [[ -f "$ROOT_DIR/dicts/en.dict.yaml" ]]; then
    #     cp "$ROOT_DIR/dicts/en.dict.yaml" "$OUT_DIR/dicts/"
    # fi

    mkdir -p "$OUT_DIR/custom"
    rsync -av --prune-empty-dirs \
        --include='*/' \
        --exclude='wanxiang_pro.custom.yaml' \
        --exclude='wanxiang_pro.dict.yaml' \
        --exclude='wanxiang_pro.schema.yaml' \
        --exclude='wanxiang.custom.yaml' \
        --exclude='wanxiang.dict.yaml' \
        --exclude='wanxiang.schema.yaml' \
        --exclude='wanxiang_pure.schema.yaml' \
        --exclude='wanxiang_pure.dict.yaml' \
        --exclude='wanxiang_mixedcode.custom.yaml' \
        --exclude='wanxiang_english.custom.yaml' \
        --exclude='wanxiang_reverse.custom.yaml' \
        --include='*.yaml' --include='*.md' --include='*.jpg' --include='*.png' \
        --exclude='*' \
        "$CUSTOM_DIR/" "$OUT_DIR/custom/"

    cp "$CUSTOM_DIR/wanxiang_pure.schema.yaml" "$OUT_DIR/"
    cp "$CUSTOM_DIR/wanxiang_pure.dict.yaml" "$OUT_DIR/"

    rsync -av --ignore-existing \
        --exclude='/.*' \
        --exclude='/dist/' \
        --exclude='/dicts' \
        --exclude='/lua' \
        --exclude='/docs/' \
        --exclude='/mkdocs.yml' \
        --exclude='/release-please-config.json' \
        --exclude='/pro-*-fuzhu-dicts' \
        --exclude='/wanxiang.dict.yaml' \
        --exclude='/wanxiang.schema.yaml' \
        --exclude='/wanxiang_english.dict.yaml' \
        --exclude='/wanxiang_english.schema.yaml' \
        --exclude='/wanxiang_mixedcode.dict.yaml' \
        --exclude='/wanxiang_mixedcode.schema.yaml' \
        --exclude='/wanxiang_reverse.dict.yaml' \
        --exclude='/wanxiang_reverse.schema.yaml' \
        --exclude='/wanxiang_t9.schema.yaml' \
        --exclude='wanxiang_t9i.schema.yaml' \
        --exclude='/CHANGELOG.md' \
        --exclude='.yamlfmt' \
        --exclude='/custom' \
        --exclude='/LICENSE' \
        "$ROOT_DIR/" "$OUT_DIR/"

    # 6) 修改 default.yaml 默认 schema 为 wanxiang_pure
    sed -i -E 's/^([[:space:]]*)-\s*schema:\s*wanxiang\s*$/\1- schema: wanxiang_pure/' "$OUT_DIR/default.yaml"
}

package_schema() {
    SCHEMA_NAME="$1"
    echo "▶️ 开始打包方案：$SCHEMA_NAME"

    if [[ "$SCHEMA_NAME" == "base" ]]; then
        OUT_DIR="$DIST_DIR/rime-wanxiang-base"
        package_schema_base "$OUT_DIR"
    elif [[ "$SCHEMA_NAME" == "pure" ]]; then
        OUT_DIR="$DIST_DIR/rime-wanxiang-pure"
        package_schema_pure
    else
        OUT_DIR="$DIST_DIR/rime-wanxiang-$SCHEMA_NAME-fuzhu"
        package_schema_pro "$SCHEMA_NAME" "$OUT_DIR"
    fi

    # 所有方案（包括 pure）统一在这里打包
    ZIP_NAME=$(basename "$OUT_DIR").zip
    ZIP_EXCLUDE_ARGS=()
    for file in "${EXCLUDE_DICT_FILES[@]}"; do
        ZIP_EXCLUDE_ARGS+=("dicts/$file")
    done
    (cd "$OUT_DIR" && zip -r -9 -q ../"$ZIP_NAME" . -x "${ZIP_EXCLUDE_ARGS[@]}" && cd ..)
    echo "✅ 完成打包: $ZIP_NAME"
}

SCHEMA_LIST=("wx" "base" "pure" "flypy" "hanxin" "moqi" "tiger" "wubi" "zrm" "shouyou" "shyplus")

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