import os
import json
import subprocess
import sys

def process_opencc():
    # 获取路径参数
    input_folder = sys.argv[1] if len(sys.argv) > 1 else "./opencc"
    if not os.path.exists(input_folder):
        print(f"跳过：路径 {input_folder} 不存在")
        return

    for filename in os.listdir(input_folder):
        file_path = os.path.join(input_folder, filename)

        # 1. 处理 TXT -> OCD2
        if filename.endswith(".txt"):
            ocd2_filename = filename.replace(".txt", ".ocd2")
            ocd2_path = os.path.join(input_folder, ocd2_filename)
            cmd = f'opencc_dict -i "{file_path}" -o "{ocd2_path}" -f text -t ocd2'
            try:
                subprocess.run(cmd, shell=True, check=True)
                print(f"✅ 转换完成: {ocd2_filename}")
                os.remove(file_path) 
            except Exception as e:
                print(f"❌ 转换失败: {filename}, {e}")

        # 2. 修改 JSON
        elif filename.endswith(".json"):
            with open(file_path, "r", encoding="utf-8") as f:
                try:
                    data = json.load(f)
                except: continue

            state = {"modified": False}
            def update_json(obj):
                if isinstance(obj, dict):
                    if "type" in obj and obj["type"] == "text":
                        obj["type"] = "ocd2"
                        state["modified"] = True
                    if "file" in obj and obj["file"].endswith(".txt"):
                        obj["file"] = obj["file"].replace(".txt", ".ocd2")
                        state["modified"] = True
                    for key in obj: update_json(obj[key])
                elif isinstance(obj, list):
                    for item in obj: update_json(item)

            update_json(data)
            if state["modified"]:
                with open(file_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                print(f"📝 已更新 JSON: {filename}")

if __name__ == "__main__":
    process_opencc()