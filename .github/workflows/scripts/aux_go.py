import os
import re
import shutil
from typing import Dict, List, Optional

# ---------- 极广的汉字正则匹配：涵盖基础汉字、扩展区 A-H 以及 "〇" ----------
CJK_PATTERN = re.compile(r'[〇\u3400-\u4DBF\u4E00-\u9FFF\U00020000-\U000323AF]')

# ---------- 中英文本边界解析与智能对齐 ----------
def tokenize_word(word: str) -> List[Dict[str, str]]:
    """将词组按照汉字和非汉字块进行拆分"""
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

def get_alignment(units: List[Dict[str, str]], segs: List[str], u_idx: int, s_idx: int, get_aux_fn) -> Optional[List[str]]:
    """
    递归匹配：将汉字和非汉字块对齐到拼音分段。
    这里接收一个 get_aux_fn 函数，用于动态获取当前汉字对应的辅助码片段。
    """
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

# ---------- 在第一个点前插入后缀 ----------
def add_suffix_before_extensions(filename: str, suffix: str) -> str:
    if not suffix:
        return filename
    i = filename.find('.')
    return (filename + suffix) if i == -1 else (filename[:i] + suffix + filename[i:])

# ========== 1) 加载辅助码表 ==========
def load_aux_table(aux_file_path):
    if not os.path.isfile(aux_file_path):
        raise FileNotFoundError(f"aux 文件不存在：{aux_file_path}")
    aux_map = {}
    print(f'加载辅助码表文件: {os.path.basename(aux_file_path)}')
    with open(aux_file_path, 'r', encoding='utf-8') as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 2:
                continue
            ch = parts[0]
            aux_list = parts[1].split(';') 
            aux_map[ch] = aux_list
    return aux_map

def select_aux_segment(aux_list, start_idx, end_idx=None):
    if not aux_list:
        return ''
    s = max(1, start_idx)
    e = end_idx if end_idx is not None else len(aux_list)
    e = max(s, min(e, len(aux_list)))
    window = aux_list[s:e] 
    return ''.join(window) if window else ''

DIGIT_RE = re.compile(r'^\d+$')

# ========== 3) 处理单个词库 ==========
def process_file_for_range_streaming(in_file, out_file, aux_map, start_idx, end_idx, sep=';'):
    try:
        fin  = open(in_file,  'r', encoding='utf-8')
    except Exception as e:
        print(f'读取失败 {in_file}: {e}')
        return
    try:
        fout = open(out_file, 'w', encoding='utf-8')
    except Exception as e:
        fin.close()
        print(f'写入失败 {out_file}: {e}')
        return

    passthrough_set = {
        "的\td\t1000",
        "了\tl\t999",
        "吗\tm\t999",
        "吧\tb\t999",
    }

    processing = False
    for line in fin:
        if not processing:
            fout.write(line)
            if '...' in line:
                processing = True
            continue

        raw = line.rstrip('\n')
        if (not raw) or raw.lstrip().startswith('#'):
            fout.write(line)
            continue

        parts = raw.split('\t')
        if len(parts) == 1:
            fout.write(line)
            continue

        han  = parts[0]
        col2 = parts[1] if len(parts) > 1 else ''
        col3 = parts[2] if len(parts) > 2 else ''
        col4 = parts[3] if len(parts) > 3 else ''

        if DIGIT_RE.fullmatch(col2 or ''):
            col3, col2 = col2, ''

        if raw.strip() in passthrough_set:
            fout.write(raw + '\n')
            continue

        pinyins = col2.split(' ') if col2 else []
        
        def get_aux_str(ch: str) -> str:
            aux_list = aux_map.get(ch)
            return select_aux_segment(aux_list, start_idx, end_idx) if aux_list is not None else ''

        units = tokenize_word(han)
        aligned_aux = get_alignment(units, pinyins, 0, 0, get_aux_str)

        if aligned_aux is None:
            warn = f"# 警告: 拼音数与字数不匹配或无法对齐（{in_file}) => {raw}"
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

# ========== 4) 扫目录 + 黑名单 + 复制逻辑 ==========
def process_batch(input_dir, aux_file_path, base_out_dir, index_mapping, files_blacklist=None,
                  sep=';', output_suffix=""):
    aux_map = load_aux_table(aux_file_path)
    print(f'已加载辅助码条目：{len(aux_map)}')

    # 直接遍历目录即可，不再提前剔除文件，因为都要进不同文件夹
    valid_files = []
    for entry in os.scandir(input_dir):
        if not entry.is_file():
            continue
        name = entry.name
        if not (name.endswith('.yaml') or name.endswith('.yml') or name.endswith('.txt')):
            continue
        valid_files.append(entry)

    if not valid_files:
        print("输入目录内没有匹配的文件。")
        return

    for s_idx, e_idx, subdir in index_mapping:
        out_dir = os.path.join(base_out_dir, subdir)
        os.makedirs(out_dir, exist_ok=True)
        print(f'\n=== 区间 ({s_idx}, {e_idx}) → {subdir} ===')
        
        for entry in valid_files:
            in_file = entry.path
            name = entry.name

            # 判断是否在黑名单中
            if files_blacklist and name in files_blacklist:
                # 命中黑名单：原封不动复制到输出文件夹，不加任何后缀
                out_file_copy = os.path.join(out_dir, name)
                
                # 防止同文件覆盖报错（如果源和目标刚好一样）
                if os.path.abspath(in_file) != os.path.abspath(out_file_copy):
                    shutil.copy2(in_file, out_file_copy)
                    print(f"⏩ 跳过并原样复制: {name}")
            else:
                # 正常处理：执行对齐运算并写入新文件
                out_name = add_suffix_before_extensions(name, output_suffix)
                out_file = os.path.join(out_dir, out_name)
                process_file_for_range_streaming(in_file, out_file, aux_map, s_idx, e_idx, sep=sep)

# ========== 5) 入口 ==========
if __name__ == '__main__':
    index_mapping = [
        (1, 2, "pro-wx-fuzhu-dicts"),
        (2, 3, "pro-moqi-fuzhu-dicts"),
        (3, 4, "pro-flypy-fuzhu-dicts"),
        (4, 5, "pro-zrm-fuzhu-dicts"),
        (5, 6, "pro-tiger-fuzhu-dicts"),
        (6, 7, "pro-wubi-fuzhu-dicts"),
        (7, 8, "pro-hanxin-fuzhu-dicts"),
        (8, 9, "pro-shouyou-fuzhu-dicts"),
        (9, None, "pro-shyplus-fuzhu-dicts"),
    ]

    AUX_FILE = "custom/aux_code.txt"  
    INPUT_DIR = "dicts"                                               
    OUT_ROOT  = "."                                                      

    # 这里的文件只会被“原样复制”到对应目录，不进行字典打码运算
    BLACKLIST_FILES = {
        "cn&en.dict.yaml",
        "en.dict.yaml",
    }

    OUTPUT_SUFFIX = ".pro"

    process_batch(
        INPUT_DIR, AUX_FILE, OUT_ROOT,
        index_mapping,
        files_blacklist=BLACKLIST_FILES, 
        sep=';',
        output_suffix=OUTPUT_SUFFIX
    )