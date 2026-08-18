import os
import re
import csv
import shutil
from typing import Dict, List, Optional

CJK_PATTERN = re.compile(r'[〇\u3400-\u4DBF\u4E00-\u9FFF\U00020000-\U000323AF]')

def tokenize_word(word: str) -> List[Dict[str, str]]:
    units = []
    buf = []
    for char in word:
        if char.isspace():
            continue
        if CJK_PATTERN.match(char):
            if buf:
                units.append({'type': 'en', 'text': ''.join(buf)})
                buf = []
            units.append({'type': 'cn', 'text': char})
        else:
            buf.append(char)
    if buf:
        units.append({'type': 'en', 'text': ''.join(buf)})
    return units

def get_alignment(units, segs, u_idx, s_idx, get_aux_fn):
    if u_idx == len(units) and s_idx == len(segs):
        return []
    if u_idx == len(units) or s_idx == len(segs):
        return None
    unit = units[u_idx]
    if unit['type'] == 'cn':
        res = get_alignment(units, segs, u_idx + 1, s_idx + 1, get_aux_fn)
        if res is not None:
            return [get_aux_fn(unit['text'])] + res
        return None
    else:
        en_text = unit['text'].lower()
        current_seg_text = ""
        for k in range(s_idx, len(segs)):
            current_seg_text += segs[k].lower()
            if current_seg_text == en_text:
                res = get_alignment(units, segs, u_idx + 1, k + 1, get_aux_fn)
                if res is not None:
                    return [''] * (k - s_idx + 1) + res
        remaining_cn = sum(1 for u in units[u_idx+1:] if u['type'] == 'cn')
        max_consume = len(segs) - s_idx - remaining_cn
        for consume_len in range(max_consume, 0, -1):
            res = get_alignment(units, segs, u_idx + 1, s_idx + consume_len, get_aux_fn)
            if res is not None:
                return [''] * consume_len + res
        return None

def get_han_chars(word: str) -> List[str]:
    """
    只提取汉字。
    β、英文、数字、符号、空格等全部忽略，不占辅助码索引。
    """
    return [ch for ch in word if CJK_PATTERN.fullmatch(ch)]

def build_aligned_aux(word: str, pinyins: List[str], get_aux_fn) -> Optional[List[str]]:
    """
    优先按“汉字索引”匹配辅助码。

    例如：
        西妥昔单抗β + 5 个拼音段
        -> 西 妥 昔 单 抗
        -> 第 1~5 个拼音段分别对应这 5 个汉字

        阿β受体 + 3 个拼音段
        -> 阿 受 体
        -> β 不占索引

        AI绘画 + 2 个拼音段
        -> 绘 画
        -> AI 不占索引

    如果拼音列仍然保留了英文/符号对应的段，
    再退回原来的智能对齐逻辑兼容旧词库。
    """
    han_chars = get_han_chars(word)

    # 新格式：拼音已经忽略非汉字，直接一一对应。
    if len(pinyins) == len(han_chars):
        return [get_aux_fn(ch) for ch in han_chars]

    # 兼容旧格式：拼音列中还可能存在 AI / 英文等非汉字段。
    units = tokenize_word(word)
    return get_alignment(units, pinyins, 0, 0, get_aux_fn)

def add_suffix_before_extensions(filename: str, suffix: str) -> str:
    if not suffix:
        return filename
    i = filename.find('.')
    return (filename + suffix) if i == -1 else (filename[:i] + suffix + filename[i:])

# ---------- CSV 加载 ----------
def parse_csv_all(csv_path: str):
    SCHEME_NAMES = [
        "wx", "moqi", "flypy", "zrm", "tiger", "wubi", "hanxin", "shouyou", "shyplus"
    ]
    scheme_aux = {name: {} for name in SCHEME_NAMES}
    scheme_chaifen = {name: {} for name in SCHEME_NAMES}

    with open(csv_path, 'r', encoding='utf-8-sig', errors='ignore') as f:
        reader = csv.DictReader(f)
        headers = [h.strip() for h in reader.fieldnames]
        print(f"列标题：{headers}")

        col_to_scheme = {}
        for idx, name in enumerate(SCHEME_NAMES):
            if idx + 1 < len(headers):
                col_to_scheme[headers[idx + 1]] = name
            else:
                print(f"警告：CSV 列数不足，缺少方案 {name}")

        for row in reader:
            han = row.get(headers[0], '').strip()
            if not han:
                continue
            for col_header, scheme_name in col_to_scheme.items():
                cell = row.get(col_header, '')
                if cell is None:
                    continue
                # 辅助码：提取连续字母块，逗号连接
                letters_blocks = re.findall(r'[a-zA-Z]+', cell)
                aux_code = ','.join(block.lower() for block in letters_blocks)
                if aux_code:
                    scheme_aux[scheme_name][han] = aux_code
                # 拆分：原样保留（去首尾空白）
                chaifen = cell.strip()
                if chaifen:
                    scheme_chaifen[scheme_name][han] = chaifen

    return scheme_aux, scheme_chaifen, SCHEME_NAMES

# ---------- 生成拆分文件到 custom/ 目录 ----------
def write_chaifen_files(scheme_chaifen, custom_dir):
    os.makedirs(custom_dir, exist_ok=True)
    for scheme_name, char_map in scheme_chaifen.items():
        if scheme_name == "wubi":
            continue          # 五笔拆分文件不生成
        out_path = os.path.join(custom_dir, f"{scheme_name}_chaifen.txt")
        with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
            for han, chaifen in char_map.items():
                f.write(f"{han}\t{chaifen}\n")
        print(f"已生成拆分文件：{out_path}")

# ---------- 处理单个词库文件 ----------
def process_dict_file(in_file, out_file, aux_map, sep=';'):
    try:
        fin = open(in_file, 'r', encoding='utf-8-sig')
    except Exception as e:
        print(f'读取失败 {in_file}: {e}')
        return
    try:
        fout = open(out_file, 'w', encoding='utf-8', newline='\n')
    except Exception as e:
        fin.close()
        print(f'写入失败 {out_file}: {e}')
        return

    passthrough_set = {"的\td\t1000", "了\tl\t999", "吗\tm\t999", "吧\tb\t999"}
    processing = False
    for line in fin:
        if not processing:
            fout.write(line)
            if '...' in line:
                processing = True
            continue

        raw = line.rstrip('\n').rstrip('\r')
        if not raw or raw.lstrip().startswith('#'):
            fout.write(raw + '\n')
            continue

        parts = raw.split('\t')
        if len(parts) == 1:
            fout.write(raw + '\n')
            continue

        han = parts[0]
        col2 = parts[1] if len(parts) > 1 else ''
        col3 = parts[2] if len(parts) > 2 else ''
        col4 = parts[3] if len(parts) > 3 else ''

        if re.fullmatch(r'\d+', col2 or ''):
            col3, col2 = col2, ''

        if raw.strip() in passthrough_set:
            fout.write(raw + '\n')
            continue

        pinyins = col2.split() if col2 else []

        def get_aux(ch):
            return aux_map.get(ch, '')

        # 核心修改：
        # 优先只按汉字索引匹配；非汉字完全不占位。
        # 仅在旧格式拼音仍包含非汉字段时退回原智能对齐。
        aligned_aux = build_aligned_aux(han, pinyins, get_aux)

        if aligned_aux is None:
            warn = f"# 警告: 拼音数与汉字数不匹配或无法对齐（{in_file}) => {raw}"
            print(warn)
            fout.write(warn + '\n')
            continue

        new_cols = []
        for i, py in enumerate(pinyins):
            aux = aligned_aux[i] if i < len(aligned_aux) else ''
            new_cols.append(py + sep + aux)

        new_col2 = ' '.join(new_cols)
        if col4:
            fout.write(f"{han}\t{new_col2}\t{col3}\t{col4}\n" if col3 else f"{han}\t{new_col2}\t\t{col4}\n")
        else:
            fout.write(f"{han}\t{new_col2}\t{col3}\n" if col3 else f"{han}\t{new_col2}\n")

    fin.close()
    fout.close()
    print(f'已处理: {os.path.basename(out_file)}')

# ---------- 批量处理所有方案 ----------
def process_all_schemes(input_dir, out_root, scheme_aux, scheme_chaifen,
                        files_blacklist=None, sep=';', output_suffix='.pro'):
    scheme_dir_map = {
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

    # 1) 将拆分文件写入 custom/ 目录（供 shell 后续使用）
    custom_dir = os.path.join(out_root, "custom")
    write_chaifen_files(scheme_chaifen, custom_dir)

    # 2) 收集需要处理的词库文件
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

    # 3) 为每个方案生成注入辅助码的词库
    for scheme_name, subdir in scheme_dir_map.items():
        aux_map = scheme_aux.get(scheme_name, {})
        out_dir = os.path.join(out_root, subdir)
        os.makedirs(out_dir, exist_ok=True)
        print(f'\n=== 方案：{scheme_name} → {subdir} ===')

        for entry in valid_files:
            in_file = entry.path
            name = entry.name
            if files_blacklist and name in files_blacklist:
                out_copy = os.path.join(out_dir, name)
                if os.path.abspath(in_file) != os.path.abspath(out_copy):
                    shutil.copy2(in_file, out_copy)
                    print(f"⏩ 跳过并原样复制: {name}")
            else:
                out_name = add_suffix_before_extensions(name, output_suffix)
                out_file = os.path.join(out_dir, out_name)
                process_dict_file(in_file, out_file, aux_map, sep=sep)

# ========== 入口 ==========
if __name__ == '__main__':
    CSV_PATH = "custom/aux_code.csv"
    INPUT_DIR = "dicts"
    OUT_ROOT = "."

    BLACKLIST_FILES = {"mixed.dict.yaml", "en.dict.yaml"}
    OUTPUT_SUFFIX = ".pro"

    scheme_aux, scheme_chaifen, _ = parse_csv_all(CSV_PATH)
    print(f"已加载辅助码/拆分数据，方案数：{len(scheme_aux)}")

    process_all_schemes(INPUT_DIR, OUT_ROOT, scheme_aux, scheme_chaifen,
                        files_blacklist=BLACKLIST_FILES, sep=';',
                        output_suffix=OUTPUT_SUFFIX)
