import argparse
import csv
import os
import re
import shutil
from contextlib import ExitStack
from functools import lru_cache
from typing import Dict, List, Optional, Sequence, Tuple

CJK_PATTERN = re.compile(
    r'[〇\u2E80-\u2EFF\u2F00-\u2FDF\u3400-\u4DBF\u4E00-\u9FFF\U00020000-\U0003347F]'
)
LETTERS_PATTERN = re.compile(r'[a-zA-Z]+')
DIGITS_PATTERN = re.compile(r'\d+')

SCHEME_NAMES = [
    "wx", "moqi", "flypy", "zrm", "tiger", "wubi", "hanxin", "shouyou", "shyplus"
]

SCHEME_DIR_MAP = {
    "wx":       "pro-wx-fuzhu-dicts",
    "moqi":     "pro-moqi-fuzhu-dicts",
    "flypy":    "pro-flypy-fuzhu-dicts",
    "zrm":      "pro-zrm-fuzhu-dicts",
    "tiger":    "pro-tiger-fuzhu-dicts",
    "wubi":     "pro-wubi-fuzhu-dicts",
    "hanxin":   "pro-hanxin-fuzhu-dicts",
    "shouyou":  "pro-shouyou-fuzhu-dicts",
    "shyplus":  "pro-shyplus-fuzhu-dicts",
}

PASSTHROUGH_SET = {"的\td\t1000", "了\tl\t999", "吗\tm\t999", "吧\tb\t999"}

# 非汉字到汉字的映射（数字等）
NON_HAN_TO_HAN = {
    '0': '零', '1': '一', '2': '二', '3': '三', '4': '四',
    '5': '五', '6': '六', '7': '七', '8': '八', '9': '九',
    # 可扩展英文字母等
    # 'a': '诶', 'b': '比', ...
}


def tokenize_word(word: str) -> List[Tuple[str, str]]:
    units: List[Tuple[str, str]] = []
    buf: List[str] = []
    for char in word:
        if char.isspace():
            continue
        if CJK_PATTERN.match(char):
            if buf:
                units.append(('en', ''.join(buf)))
                buf = []
            units.append(('cn', char))
        else:
            buf.append(char)
    if buf:
        units.append(('en', ''.join(buf)))
    return units


def get_han_chars(word: str) -> List[str]:
    return [ch for ch in word if CJK_PATTERN.fullmatch(ch)]


def build_alignment_keys(word: str, pinyins: Sequence[str]) -> Optional[List[Optional[str]]]:
    """
    只计算“每个拼音位置对应哪个汉字”。

    原实现对每套辅助码都重复做一次同样的词条/拼音对齐；实际上
    对齐路径与具体辅助码内容无关，因此这里先算一次，随后九套方案复用。
    返回值中的 None 表示该拼音位置没有可查的汉字辅助码。
    """
    han_chars = get_han_chars(word)

    # 保持原逻辑：新格式中拼音已经忽略非汉字时，直接按汉字一一对应。
    if len(pinyins) == len(han_chars):
        return han_chars

    units = tuple(tokenize_word(word))
    segs = tuple(pinyins)

    @lru_cache(maxsize=None)
    def solve(u_idx: int, s_idx: int) -> Optional[Tuple[Optional[str], ...]]:
        if u_idx == len(units) and s_idx == len(segs):
            return ()
        if u_idx == len(units) or s_idx == len(segs):
            return None

        unit_type, unit_text = units[u_idx]

        if unit_type == 'cn':
            res = solve(u_idx + 1, s_idx + 1)
            if res is not None:
                return (unit_text,) + res
            return None

        en_text = unit_text.lower()
        current_seg_text = ""
        mapped_han = NON_HAN_TO_HAN.get(unit_text)

        # 保持原有优先顺序：先尝试把连续拼音片段精确拼成非汉字文本。
        for k in range(s_idx, len(segs)):
            current_seg_text += segs[k].lower()
            if current_seg_text == en_text:
                res = solve(u_idx + 1, k + 1)
                if res is not None:
                    return (mapped_han,) + (None,) * (k - s_idx) + res

        # 保持原有回退顺序：从最多可消费的拼音段开始向下尝试。
        remaining_cn = sum(1 for kind, _ in units[u_idx + 1:] if kind == 'cn')
        max_consume = len(segs) - s_idx - remaining_cn
        for consume_len in range(max_consume, 0, -1):
            res = solve(u_idx + 1, s_idx + consume_len)
            if res is not None:
                return (mapped_han,) + (None,) * (consume_len - 1) + res

        return None

    result = solve(0, 0)
    return list(result) if result is not None else None


def add_suffix_before_extensions(filename: str, suffix: str) -> str:
    if not suffix:
        return filename
    i = filename.find('.')
    return (filename + suffix) if i == -1 else (filename[:i] + suffix + filename[i:])


# ---------- CSV 加载 ----------
def parse_csv_all(csv_path: str, selected_schemes: Sequence[str]):
    selected = set(selected_schemes)
    scheme_aux = {name: {} for name in SCHEME_NAMES if name in selected}
    scheme_chaifen = {name: {} for name in SCHEME_NAMES if name in selected}

    with open(csv_path, 'r', encoding='utf-8-sig', errors='ignore') as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise ValueError(f"CSV 没有表头: {csv_path}")

        headers = [h.strip() for h in reader.fieldnames]
        print(f"列标题：{headers}")

        # 保持原文件的规则：按列位置映射到固定方案名，而不是按表头文字判断。
        col_to_scheme = {}
        for idx, name in enumerate(SCHEME_NAMES):
            if idx + 1 < len(headers):
                if name in selected:
                    col_to_scheme[headers[idx + 1]] = name
            elif name in selected:
                print(f"警告：CSV 列数不足，缺少方案 {name}")

        for row in reader:
            han = row.get(headers[0], '').strip()
            if not han:
                continue

            for col_header, scheme_name in col_to_scheme.items():
                cell = row.get(col_header, '')
                if cell is None:
                    continue

                letters_blocks = LETTERS_PATTERN.findall(cell)
                aux_code = ','.join(block.lower() for block in letters_blocks)
                if aux_code:
                    scheme_aux[scheme_name][han] = aux_code

                chaifen = cell.strip()
                if chaifen:
                    scheme_chaifen[scheme_name][han] = chaifen

    return scheme_aux, scheme_chaifen


# ---------- 生成拆分文件到 custom/ 目录 ----------
def write_chaifen_files(scheme_chaifen, custom_dir):
    os.makedirs(custom_dir, exist_ok=True)
    for scheme_name, char_map in scheme_chaifen.items():
        # 保持原行为：五笔拆分文件不是这里生成。
        if scheme_name == "wubi":
            continue
        out_path = os.path.join(custom_dir, f"{scheme_name}_chaifen.txt")
        with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
            for han, chaifen in char_map.items():
                f.write(f"{han}\t{chaifen}\n")
        print(f"已生成拆分文件：{out_path}")


def _format_output_line(
    han: str,
    pinyins: Sequence[str],
    col3: str,
    col4: str,
    alignment_keys: Sequence[Optional[str]],
    aux_map: Dict[str, str],
    sep: str,
) -> str:
    new_cols = []
    for i, py in enumerate(pinyins):
        key = alignment_keys[i] if i < len(alignment_keys) else None
        aux = aux_map.get(key, '') if key else ''
        new_cols.append(py + sep + aux)

    new_col2 = ' '.join(new_cols)
    if col4:
        return f"{han}\t{new_col2}\t{col3}\t{col4}\n" if col3 else f"{han}\t{new_col2}\t\t{col4}\n"
    return f"{han}\t{new_col2}\t{col3}\n" if col3 else f"{han}\t{new_col2}\n"


# ---------- 一个词库文件一次读取，同时生成全部所选方案 ----------
def process_dict_file_all_schemes(
    in_file: str,
    outputs: Dict[str, str],
    scheme_aux: Dict[str, Dict[str, str]],
    sep: str = ';',
):
    try:
        fin = open(in_file, 'r', encoding='utf-8-sig')
    except Exception as e:
        print(f'读取失败 {in_file}: {e}')
        return

    with fin, ExitStack() as stack:
        writers = {}
        for scheme_name, out_file in outputs.items():
            try:
                writers[scheme_name] = stack.enter_context(
                    open(out_file, 'w', encoding='utf-8', newline='\n')
                )
            except Exception as e:
                print(f'写入失败 {out_file}: {e}')
                return

        processing = False

        for line in fin:
            if not processing:
                for fout in writers.values():
                    fout.write(line)
                if '...' in line:
                    processing = True
                continue

            raw = line.rstrip('\n').rstrip('\r')

            if not raw or raw.lstrip().startswith('#'):
                out_line = raw + '\n'
                for fout in writers.values():
                    fout.write(out_line)
                continue

            parts = raw.split('\t')
            if len(parts) == 1:
                out_line = raw + '\n'
                for fout in writers.values():
                    fout.write(out_line)
                continue

            han = parts[0]
            col2 = parts[1] if len(parts) > 1 else ''
            col3 = parts[2] if len(parts) > 2 else ''
            col4 = parts[3] if len(parts) > 3 else ''

            if DIGITS_PATTERN.fullmatch(col2 or ''):
                col3, col2 = col2, ''

            if raw.strip() in PASSTHROUGH_SET:
                out_line = raw + '\n'
                for fout in writers.values():
                    fout.write(out_line)
                continue

            pinyins = col2.split() if col2 else []
            alignment_keys = build_alignment_keys(han, pinyins)

            if alignment_keys is None:
                # 原实现会因九套方案重复处理而打印九遍同一警告；现在只打印一次。
                print(f"# 警告: 拼音数与汉字数不匹配或无法对齐（{in_file}) => {raw}")
                out_line = raw + '\n'
                for fout in writers.values():
                    fout.write(out_line)
                continue

            for scheme_name, fout in writers.items():
                fout.write(
                    _format_output_line(
                        han,
                        pinyins,
                        col3,
                        col4,
                        alignment_keys,
                        scheme_aux[scheme_name],
                        sep,
                    )
                )

    print(f"已处理一次并生成 {len(outputs)} 套: {os.path.basename(in_file)}")


# ---------- 批量处理所有方案 ----------
def process_all_schemes(
    input_dir,
    out_root,
    scheme_aux,
    scheme_chaifen,
    selected_schemes,
    files_blacklist=None,
    sep=';',
    output_suffix='.pro',
    write_chaifen=True,
):
    if write_chaifen:
        custom_dir = os.path.join(out_root, "custom")
        write_chaifen_files(scheme_chaifen, custom_dir)

    valid_files = []
    for entry in os.scandir(input_dir):
        if not entry.is_file():
            continue
        name = entry.name
        if name.endswith('.yaml') or name.endswith('.yml') or name.endswith('.txt'):
            valid_files.append(entry)

    if not valid_files:
        print("输入目录内没有匹配的文件。")
        return

    out_dirs = {}
    for scheme_name in selected_schemes:
        subdir = SCHEME_DIR_MAP[scheme_name]
        out_dir = os.path.join(out_root, subdir)
        os.makedirs(out_dir, exist_ok=True)
        out_dirs[scheme_name] = out_dir
        print(f"准备方案：{scheme_name} → {subdir}")

    for entry in valid_files:
        in_file = entry.path
        name = entry.name

        if files_blacklist and name in files_blacklist:
            for scheme_name, out_dir in out_dirs.items():
                out_copy = os.path.join(out_dir, name)
                if os.path.abspath(in_file) != os.path.abspath(out_copy):
                    shutil.copy2(in_file, out_copy)
            print(f"⏩ 原样复制到 {len(out_dirs)} 套方案: {name}")
            continue

        outputs = {
            scheme_name: os.path.join(
                out_dir,
                add_suffix_before_extensions(name, output_suffix),
            )
            for scheme_name, out_dir in out_dirs.items()
        }
        process_dict_file_all_schemes(in_file, outputs, scheme_aux, sep=sep)


def parse_args():
    parser = argparse.ArgumentParser(
        description="为万象 Pro 词库注入辅助码；无参数运行时保持原脚本行为，生成全部方案。"
    )
    parser.add_argument(
        "--schemes",
        nargs='+',
        choices=SCHEME_NAMES,
        default=SCHEME_NAMES,
        help="只生成指定辅助码方案；默认全部。",
    )
    parser.add_argument("--csv", default="custom/aux_code.csv")
    parser.add_argument("--input-dir", default="dicts")
    parser.add_argument("--out-root", default=".")
    parser.add_argument(
        "--no-chaifen",
        action="store_true",
        help="不生成 *_chaifen.txt；Pure 单独构建时可用。",
    )
    return parser.parse_args()


# ========== 入口 ==========
if __name__ == '__main__':
    args = parse_args()

    # 去重且保持 SCHEME_NAMES 的固定顺序，避免命令行顺序改变产物布局/日志。
    requested = set(args.schemes)
    selected_schemes = [name for name in SCHEME_NAMES if name in requested]

    BLACKLIST_FILES = {"mixed.dict.yaml", "en.dict.yaml", "abbrev.dict.yaml", "t9_abbrev.dict.yaml"}
    OUTPUT_SUFFIX = ".pro"

    scheme_aux, scheme_chaifen = parse_csv_all(args.csv, selected_schemes)
    print(f"已加载辅助码/拆分数据，方案数：{len(scheme_aux)}")

    process_all_schemes(
        args.input_dir,
        args.out_root,
        scheme_aux,
        scheme_chaifen,
        selected_schemes,
        files_blacklist=BLACKLIST_FILES,
        sep=';',
        output_suffix=OUTPUT_SUFFIX,
        write_chaifen=not args.no_chaifen,
    )
