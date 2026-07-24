# 东风破 (Plum) 管理器部署

如果您熟悉命令行操作，可以使用 Rime 官方的包管理器 **Plum (东风破)** 进行万象的安装和后续更新。

*(⚠️ 注意：在执行以下命令前，请确保您已经安装了小狼毫、鼠须管或 Fcitx5 等前端软件。)*

---

### 1. 运行环境要求

| 操作系统 | 环境要求 | 备注 |
| :--- | :--- | :--- |
| **macOS / Linux** | ✅ **无需处理** | 系统已内置 Bash，打开系统默认终端直接运行即可。 |
| **Windows** | 🛠️ **需要 Git Bash** | 通常随 [Git for Windows](https://git-scm.com/download/win) 自动安装。 |

!!! danger "🚫 Windows 用户核心避坑"
    Windows 系统自带的 **PowerShell** 或 **CMD (命令提示符)** 绝对无法直接运行东风破的 Shell 脚本！
    您**必须**在目标文件夹中右键选择 **"Open Git Bash here"**（或直接打开 Git Bash 终端）来执行后续的命令。

---

### 2. 获取万象定制版 Plum

请在终端中执行以下命令。这是维护在万象仓库 `plum` 分支的定制版本（去掉了繁琐的默认方案，并修改了默认路径）。您可以自行决定在哪个本地目录打开终端来存放此工具。

```bash
# 克隆定制版 Plum 到本地
git clone -b plum --depth 1 https://github.com/amzxyz/rime-wanxiang.git
# 进入目录
cd rime-wanxiang
```

---

### 3. 配置前端环境变量 (按需执行)

为了让 Plum 知道该把方案文件安装到哪里，需要配置 `rime_frontend` 变量。

!!! success "✅ 主流前端（免配置）"
    万象定制版 Plum 已经为 **小狼毫 (Weasel)**、**鼠须管 (Squirrel)** 和 **小企鹅 (Fcitx5)** 默认配置好了路径。如果您使用的是这三者之一，**请直接跳过此步，进入第 4 步。**

如果您在 Linux/Mac 上使用的是 `ibus` 或旧版 `fcitx`，则需要手动声明变量。您可以直接在终端执行，或将其写入 `~/.zshrc` / `~/.bashrc` 以永久生效：

```bash
# 适用于 ibus 前端
export rime_frontend='rime/ibus-rime'

# 适用于 fcitx (非 fcitx5) 前端
export rime_frontend='fcitx/fcitx-rime'
```

---

### 4. 执行安装与一键更新

请确保您的终端当前处于刚刚拉取下来的 `plum` 目录中。根据您的需求，在下方选择并复制对应的指令执行即可：

*(💡 **命令释义**：`full` 代表包含主方案与完整词库的全新安装；`dicts` 代表仅拉取更新词库，适合日常维护时使用，不会覆盖您自己的主配置。)*

=== "🟢 基础版 (Base)"

    **主打省心顺滑，打字体验类似主流大厂输入法。**

    * **完整安装 (首次部署)**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-base:plum/full
    ```
    * **仅更新词库 (日常维护)**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-base:plum/dicts
    ```

=== "🔵 增强辅码版 (Pro 分包)"

    **专为硬核玩家打造，请根据您使用的“辅助码类型”选择对应的命令。**

    **1. 自然码辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-zrm-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-zrm-fuzhu:plum/dicts
    ```
    
    **2. 小鹤辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-flypy-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-flypy-fuzhu:plum/dicts
    ```
    
    **3. 墨奇辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-moqi-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-moqi-fuzhu:plum/dicts
    ```
    
    **4. 虎码辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-tiger-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-tiger-fuzhu:plum/dicts
    ```
    
    **5. 五笔辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-wubi-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-wubi-fuzhu:plum/dicts
    ```
    
    **6. 汉心辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-hanxin-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-hanxin-fuzhu:plum/dicts
    ```
    
    **7. 首右辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-shouyou-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-shouyou-fuzhu:plum/dicts
    ```
    **8. 首右+辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-shyplus-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-shyplus-fuzhu:plum/dicts
    ```
    **9. 万象辅助版**
    ```bash
    bash rime-install amzxyz/rime-wanxiang@wanxiang-wx-fuzhu:plum/full
    bash rime-install amzxyz/rime-wanxiang@wanxiang-wx-fuzhu:plum/dicts
    ```