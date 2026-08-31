#!/bin/bash
# 打包对应方案到 zip 文件，放到 dist 目录
set -e

ROOT_DIR="$(cd "$(dirname "$0")/../../../" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
CUSTOM_DIR="$ROOT_DIR/custom"
PURE_FUZHU="zrm"  # Pure 默认使用哪套 Pro 辅助码词库；只影响打包时默认词库

EXCLUDE_DICT_FILES=(
  "xxx.dict.yaml"
  # "wuzhong.dict.yaml"
  # "renming.dict.yaml"
  # "wuzhong.pro.dict.yaml"
  # "renming.pro.dict.yaml"
)

# 生成 PRO 分包文件
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

package_schema_lite() {
  OUT_DIR="$DIST_DIR/rime-wanxiang-lite"
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"

  # 1) Lite 自己的 schema / dict 从 custom/ 复制到分包根目录
  for f in \
    wanxiang_lite.dict.yaml \
    wanxiang_lite.schema.yaml
  do
    src="$CUSTOM_DIR/$f"
    dst="$OUT_DIR/$f"
    [[ -f "$src" ]] && cp "$src" "$dst"
  done

  # 2) custom/：复制通用配置，排除其他主方案入口文件
  mkdir -p "$OUT_DIR/custom"
  rsync -av --prune-empty-dirs \
    --include='*/' \
    --exclude='wanxiang_pro.custom.yaml' \
    --exclude='wanxiang_pro.dict.yaml' \
    --exclude='wanxiang_pro.schema.yaml' \
    --exclude='wanxiang_pure.dict.yaml' \
    --exclude='wanxiang_pure.schema.yaml' \
    --exclude='wanxiang_pure.custom.yaml' \
    --exclude='wanxiang.custom.yaml' \
    --exclude='wanxiang_lite.dict.yaml' \
    --exclude='wanxiang_lite.schema.yaml' \
    --include='*.yaml' --include='*.md' --include='*.jpg' --include='*.png' \
    --exclude='*' \
    "$CUSTOM_DIR/" "$OUT_DIR/custom/"

  # 3) 根目录 → Lite，保持与 Base 相同的完整基础文件
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
    --exclude='/wanxiang.dict.yaml' \
    --exclude='/wanxiang.schema.yaml' \
    --exclude='/wanxiang_lite.dict.yaml' \
    --exclude='/wanxiang_lite.schema.yaml' \
    --exclude="/$OUT_BASE" \
    "$ROOT_DIR/" "$OUT_DIR/"

  # 3.1) Lite 内的 T9/T9i：三态开关组裁成两态布尔开关
  python3 - \
    "$OUT_DIR/wanxiang_t9.schema.yaml" \
    "$OUT_DIR/wanxiang_t9i.schema.yaml" <<'PY'
from pathlib import Path
import re
import sys

for file_name in sys.argv[1:]:
    path = Path(file_name)

    if not path.is_file():
        raise SystemExit(f"错误: T9/T9i schema 不存在: {path}")

    text = path.read_text(encoding="utf-8")

    # 预编辑：三态互斥组 -> full_pinyin 单布尔开关
    pattern = re.compile(
        r'(?m)^(\s*)-\s*options:\s*\[raw_input,\s*tone_display,\s*full_pinyin\].*\n'
        r'\1\s*states:\s*\[原编码,\s*有声调,\s*无声调\]\s*\n'
        r'\1\s*reset:\s*2\b.*$'
    )
    text, count = pattern.subn(
        lambda m: (
            f"{m.group(1)}- name: full_pinyin  # T9/T9i：原编码 / 转全拼\n"
            f"{m.group(1)}  states: [原编码, 转全拼]\n"
            f"{m.group(1)}  reset: 1"
        ),
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit(
            f"错误: {path.name} 未唯一匹配预编辑开关组: {count}"
        )

    # 候选注释：三态互斥组 -> toneless_hint 单布尔开关
    pattern = re.compile(
        r'(?m)^(\s*)-\s*options:\s*\[comment_off,\s*tone_hint,\s*toneless_hint\].*\n'
        r'\1\s*states:\s*\[注释关,\s*有声调,\s*无声调\]\s*$'
    )
    text, count = pattern.subn(
        lambda m: (
            f"{m.group(1)}- name: toneless_hint  # T9/T9i：注释关 / 注释开\n"
            f"{m.group(1)}  states: [注释关, 注释开]"
        ),
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit(
            f"错误: {path.name} 未唯一匹配注释开关组: {count}"
        )

    path.write_text(text, encoding="utf-8")
PY

  # 4) 只裁剪 Lite 不需要的 Lua 模块和 data 文件
  rm -f \
    "$OUT_DIR/lua/wanxiang/super_sequence.lua" \
    "$OUT_DIR/lua/wanxiang/auto_phrase.lua" \
    "$OUT_DIR/lua/wanxiang/charset_filter.lua" \
    "$OUT_DIR/lua/wanxiang/super_symbols.lua" \
    "$OUT_DIR/lua/wanxiang/force_upper_aux.lua" \
    "$OUT_DIR/lua/wanxiang/partial_commit.lua"

  rm -f \
    "$OUT_DIR/lua/data/codex_emoji.txt" \
    "$OUT_DIR/lua/data/codex_sym.txt" \
    "$OUT_DIR/lua/data/charset.reverse.bin"

  # 5) Lite 词库第二列去声调并改为 *.lite.dict.yaml；en.dict.yaml / mixed.dict.yaml 原样保留
  python3 - "$OUT_DIR/dicts" "$OUT_DIR/wanxiang_lite.dict.yaml" <<'PY'
from pathlib import Path
import os
import sys

tone_map = str.maketrans({
    "ā": "a", "á": "a", "ǎ": "a", "à": "a",
    "ē": "e", "é": "e", "ě": "e", "è": "e",
    "ī": "i", "í": "i", "ǐ": "i", "ì": "i", "ḿ": "me",
    "ō": "o", "ó": "o", "ǒ": "o", "ò": "o", "ň": "en",
    "ū": "u", "ú": "u", "ǔ": "u", "ù": "u", "ǹ": "en",
    "ǖ": "v", "ǘ": "v", "ǚ": "v", "ǜ": "v", "ü": "v", "ń": "en",
})

def strip_tone(text):
    return text.replace("m̀", "me").translate(tone_map)

dict_dir = Path(sys.argv[1])
main_dict = Path(sys.argv[2])
renamed = {}

if dict_dir.is_dir():
    paths = [
        path for path in dict_dir.rglob("*.dict.yaml")
        if path.name not in {"en.dict.yaml", "mixed.dict.yaml"}
        and not path.name.endswith(".lite.dict.yaml")
    ]

    for path in paths:
        relative = path.relative_to(dict_dir).as_posix()
        old_table = "dicts/" + relative[:-len(".dict.yaml")]

        new_path = path.with_name(
            path.name[:-len(".dict.yaml")] + ".lite.dict.yaml"
        )
        new_relative = new_path.relative_to(dict_dir).as_posix()
        new_table = "dicts/" + new_relative[:-len(".dict.yaml")]
        renamed[old_table] = new_table

        new_name = new_path.name[:-len(".dict.yaml")]
        temp = path.with_name(path.name + ".tmp")
        name_done = False

        with path.open("r", encoding="utf-8", newline="") as src, \
             temp.open("w", encoding="utf-8", newline="") as dst:
            for line in src:
                stripped = line.lstrip()

                if not name_done and stripped.startswith("name:"):
                    eol = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
                    indent = line[:len(line) - len(stripped)]
                    dst.write(f"{indent}name: {new_name}{eol}")
                    name_done = True
                    continue

                first_tab = line.find("\t")
                if first_tab < 0:
                    dst.write(line)
                    continue

                second_tab = line.find("\t", first_tab + 1)
                if second_tab < 0:
                    dst.write(
                        line[:first_tab + 1]
                        + strip_tone(line[first_tab + 1:])
                    )
                else:
                    dst.write(
                        line[:first_tab + 1]
                        + strip_tone(line[first_tab + 1:second_tab])
                        + line[second_tab:]
                    )

        os.replace(temp, new_path)
        path.unlink()


def rewrite_imports(path):
    if not path.is_file():
        return

    temp = path.with_name(path.name + ".tmp")
    changed = False

    with path.open("r", encoding="utf-8", newline="") as src, \
         temp.open("w", encoding="utf-8", newline="") as dst:
        for line in src:
            stripped = line.lstrip()
            if stripped.startswith("- "):
                rest = stripped[2:]
                table = rest.split(None, 1)[0] if rest else ""
                replacement = renamed.get(table)
                if replacement:
                    line = line.replace(table, replacement, 1)
                    changed = True
            dst.write(line)

    if changed:
        os.replace(temp, path)
    else:
        temp.unlink()


rewrite_imports(main_dict)

if dict_dir.is_dir():
    for path in dict_dir.rglob("*.lite.dict.yaml"):
        rewrite_imports(path)
PY

  # 6) Lite 分包默认方案
  sed -i -E 's/^([[:space:]]*)-\s*schema:\s*wanxiang\s*$/\1- schema: wanxiang_lite/' "$OUT_DIR/default.yaml"
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

  # 5) default.yaml: - schema: wanxiang -> - schema: wanxiang_pro
  sed -i -E 's/^([[:space:]]*)-\s*schema:\s*wanxiang\s*$/\1- schema: wanxiang_pro/' "$OUT_DIR/default.yaml"
}

package_schema_pure() {
  OUT_DIR="$DIST_DIR/rime-wanxiang-pure"
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR/dicts"

  # 1) Pure 使用 aux_go.py 生成的整套 Pro 辅助码词库。
  #    默认取自然码 zrm；用户若想换其他辅助码，直接替换 dicts/ 下的 *.pro.dict.yaml 即可。
  PURE_DICT_SOURCE="$ROOT_DIR/pro-$PURE_FUZHU-fuzhu-dicts"
  if [[ ! -d "$PURE_DICT_SOURCE" && -d "$DIST_DIR/rime-wanxiang-$PURE_FUZHU-fuzhu/dicts" ]]; then
    PURE_DICT_SOURCE="$DIST_DIR/rime-wanxiang-$PURE_FUZHU-fuzhu/dicts"
  fi
  if [[ ! -d "$PURE_DICT_SOURCE" ]]; then
    echo "错误: Pure 默认词库不存在: $PURE_DICT_SOURCE" >&2
    exit 1
  fi

  # 不设白名单：复制该 Pro 分包中的全部 *.pro.dict.yaml。
  shopt -s nullglob
  PRO_DICT_FILES=("$PURE_DICT_SOURCE"/*.pro.dict.yaml)
  shopt -u nullglob

  if [[ ${#PRO_DICT_FILES[@]} -eq 0 ]]; then
    echo "错误: $PURE_FUZHU Pro 词库目录中没有 *.pro.dict.yaml: $PURE_DICT_SOURCE" >&2
    exit 1
  fi

  cp "${PRO_DICT_FILES[@]}" "$OUT_DIR/dicts/"

  # 2) custom/：保留 Pure 所需的通用配置，排除其他主方案文件
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

  # 3) Pure 自己的 schema / dict 入口直接复制原文件
  cp "$CUSTOM_DIR/wanxiang_pure.schema.yaml" "$OUT_DIR/"
  cp "$CUSTOM_DIR/wanxiang_pure.dict.yaml" "$OUT_DIR/"

  # 4) 根目录 → Pure；仍然不携带 Lua，保持 Pure 的轻量方案结构
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

  # 5) 修改 default.yaml 默认 schema 为 wanxiang_pure
  sed -i -E 's/^([[:space:]]*)-\s*schema:\s*wanxiang\s*$/\1- schema: wanxiang_pure/' "$OUT_DIR/default.yaml"
}

package_schema() {
  SCHEMA_NAME="$1"
  echo "▶️ 开始打包方案：$SCHEMA_NAME"

  if [[ "$SCHEMA_NAME" == "base" ]]; then
    OUT_DIR="$DIST_DIR/rime-wanxiang-base"
    package_schema_base "$OUT_DIR"
  elif [[ "$SCHEMA_NAME" == "lite" ]]; then
    OUT_DIR="$DIST_DIR/rime-wanxiang-lite"
    package_schema_lite
  elif [[ "$SCHEMA_NAME" == "pure" ]]; then
    OUT_DIR="$DIST_DIR/rime-wanxiang-pure"
    package_schema_pure
  else
    OUT_DIR="$DIST_DIR/rime-wanxiang-$SCHEMA_NAME-fuzhu"
    package_schema_pro "$SCHEMA_NAME" "$OUT_DIR"
  fi

  # 所有方案统一在这里打包
  ZIP_NAME=$(basename "$OUT_DIR").zip
  ZIP_EXCLUDE_ARGS=()
  for file in "${EXCLUDE_DICT_FILES[@]}"; do
    ZIP_EXCLUDE_ARGS+=("dicts/$file")
  done
  (cd "$OUT_DIR" && zip -r -9 -q ../"$ZIP_NAME" . -x "${ZIP_EXCLUDE_ARGS[@]}" && cd ..)
  echo "✅ 完成打包: $ZIP_NAME"
}

SCHEMA_LIST=("wx" "base" "lite" "pure" "flypy" "hanxin" "moqi" "tiger" "wubi" "zrm" "shouyou" "shyplus")

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
