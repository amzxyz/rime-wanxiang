import os
import re

# ---------- 在第一个点前插入后缀（例：base.dict.yaml -> base.pro.dict.yaml） ----------
def add_suffix_before_extensions(filename: str, suffix: str) -> str:
    if not suffix:
        return filename
    i = filename.find('.')
    return (filename + suffix) if i == -1 else (filename[:i] + suffix + filename[i:])

# ========== 1) 从“单个 aux 文件”加载 字 -> 辅助码段列表 ==========
# 行格式：字<TAB>;段1;段2;... （保留空段，不偏移；段内逗号原样保留）
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
            aux_list = parts[1].split(';')   # 保留空串占位（分号才是边界）
            aux_map[ch] = aux_list
    return aux_map

# ========== 2) 区间选择（严格：第 N 段 = aux_list[N]；N 从 1 起）==========
# 不处理逗号：分号窗口原样拼接
def select_aux_segment(aux_list, start_idx, end_idx=None):
    if not aux_list:
        return ''
    s = max(1, start_idx)
    e = end_idx if end_idx is not None else len(aux_list)
    e = max(s, min(e, len(aux_list)))
    window = aux_list[s:e]  # 允许空段
    return ''.join(window) if window else ''

DIGIT_RE = re.compile(r'^\d+$')

# ========== 3) 处理单个词库（流式；空也占位“拼音;”）==========
def process_file_for_range_streaming(in_file, out_file, aux_map, start_idx, end_idx, sep=';'):
    os.makedirs(os.path.dirname(out_file), exist_ok=True)
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

        # 第二列若是频率（全数字），挪到第三列
        if DIGIT_RE.fullmatch(col2 or ''):
            col3, col2 = col2, ''

        # 特定行直通
        if raw.strip() in passthrough_set:
            fout.write(raw + '\n')
            continue

        pinyins = col2.split(' ') if col2 else []
        if len(pinyins) != len(han):
            warn = f"# 警告: 拼音数与字数不匹配（{in_file}) => {raw}"
            print(warn)
            fout.write(warn + '\n')
            continue

        _get = aux_map.get
        new_cols = []
        for i, ch in enumerate(han):
            aux_list = _get(ch)
            piece = select_aux_segment(aux_list, start_idx, end_idx) if aux_list is not None else ''
            new_cols.append(pinyins[i] + sep + piece)  # 空也占位：拼音;片段

        new_col2 = ' '.join(new_cols)
        if col4:
            fout.write(f"{han}\t{new_col2}\t{col3}\t{col4}\n" if col3 else f"{han}\t{new_col2}\t\t{col4}\n")
        else:
            fout.write(f"{han}\t{new_col2}\t{col3}\n" if col3 else f"{han}\t{new_col2}\n")

    fin.close()
    fout.close()
    print(f'已处理: {out_file}')

# ========== 4) 扫目录 + 六套区间（按白名单）==========
def process_batch(input_dir, aux_file_path, base_out_dir, index_mapping, files_whitelist=None,
                  sep=';', output_suffix=""):
    aux_map = load_aux_table(aux_file_path)
    print(f'已加载辅助码条目：{len(aux_map)}')

    # 收集要处理的文件
    to_process = []
    for entry in os.scandir(input_dir):
        if not entry.is_file():
            continue
        name = entry.name
        if files_whitelist and name not in files_whitelist:
            continue
        if not (name.endswith('.yaml') or name.endswith('.yml') or name.endswith('.txt')):
            continue
        to_process.append(entry.path)

    if not to_process:
        print("输入目录内没有匹配文件")
        return

    for s_idx, e_idx, subdir in index_mapping:
        out_dir = os.path.join(base_out_dir, subdir)
        os.makedirs(out_dir, exist_ok=True)
        print(f'\n=== 区间 ({s_idx}, {e_idx}) → {subdir} ===')
        for in_file in to_process:
            fn = os.path.basename(in_file)
            out_name = add_suffix_before_extensions(fn, output_suffix)
            out_file = os.path.join(out_dir, out_name)
            process_file_for_range_streaming(in_file, out_file, aux_map, s_idx, e_idx, sep=sep)

# ========== 5) 入口 ==========
if __name__ == '__main__':
    # 六套区间（第 N 段，从 1 起）
    index_mapping = [
        (1, 2, "pro-moqi-fuzhu-dicts"),
        (2, 3, "pro-flypy-fuzhu-dicts"),
        (3, 4, "pro-zrm-fuzhu-dicts"),
        (4, 5, "pro-tiger-fuzhu-dicts"),
        (5, 6, "pro-wubi-fuzhu-dicts"),
        (6, None, "pro-hanxin-fuzhu-dicts"),
    ]

    # 路径
    AUX_FILE = "custom/aux_code.txt"  # ← 单个 aux 文件
    INPUT_DIR = "dicts"                                               # ← 词库文件夹
    OUT_ROOT  = "."                                                      # ← 输出根目录

    # 仅处理这些文件
    FILES = [
        "correlation.dict.yaml",
        "base.dict.yaml",
        "chars.dict.yaml",
        "compatible.dict.yaml",
        "corrections.dict.yaml",
        "place.dict.yaml",
        "poetry.dict.yaml",
        "suggestion.dict.yaml",
    ]

    # 输出文件在第一个点前插这个后缀（如 ".pro"；设为空串则不加）
    OUTPUT_SUFFIX = ".pro"

    process_batch(
        INPUT_DIR, AUX_FILE, OUT_ROOT,
        index_mapping,
        files_whitelist=FILES,
        sep=';',
        output_suffix=OUTPUT_SUFFIX
    )
