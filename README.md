<meta charset="UTF-8">

# 東風破 /plum/

Rime configuration manager and input schema repository

## Project home

[rime.im](https://rime.im)

## Introduction

**/plum/** is a configuration manager for [Rime](https://rime.im) input method engine.

/// **東風破** 是 [中州韻輸入法引擎](https://rime.im) 的配置管理工具。///

It's designed for Rime users to install and update the default configuration and a collection
of data packages maintained by [Rime Developers](https://github.com/rime).

It also works perfectly well with personal configuration hosted on GitHub and input schema packages
from third-party developers.

A **Rime input schema** (**Rime 輸入方案**) defines the rules of a specific "input method", or in technical terms
how user input sequences are interpreted by the Rime input method engine.
It consists of a configuration file named `<schema_id>.schema.yaml`, and usually an optional
**Rime dictionary** (**韻書**) file named `*.dict.yaml`.

A package may contain one or several interrelated input schemata and their affiliated Rime dictionaries.
A package is also good for publishing general configuration files and data files used by Rime.

In /plum/ terms, a re-usable piece of configuration is known as a **recipe** (**配方**), denoted by the "℞" symbol.

A data package itself can be a recipe, this is the common case.
In the future, /plum/ will support more fine-grained recipes that allow you to select what to install from a package,
or even take parameters like the target input schema to customize.

## Packages

This is an index of the packages maintained by Rime Developers as separate projects.

These packages aim to offer a sensible default configuration for most users, and support various
Chinese input methods including those based on modern dialects and historical Chinese phonology.

/// **配方一覽** ///

### Essentials

  - ℞ [`prelude`](https://github.com/rime/rime-prelude): 基礎配置 / the prelude package, providing Rime's default settings
  - ℞ [`essay`](https://github.com/rime/rime-essay): 八股文 / a shared vocabulary and language model

### Phonetic-based input methods

Modern Standard Mandarin

  - ℞ [`luna-pinyin`](https://github.com/rime/rime-luna-pinyin): 朙月拼音 / Pinyin input method for Traditional Chinese
  - ℞ [`terra-pinyin`](https://github.com/rime/rime-terra-pinyin): 地球拼音 / School-taught Pinyin, with tone marks
  - ℞ [`bopomofo`](https://github.com/rime/rime-bopomofo): 注音 / Zhuyin (aka. Bopomofo)
  - ℞ [`pinyin-simp`](https://github.com/rime/rime-pinyin-simp): 袖珍簡化字拼音

Derivatives of Pinyin

  - ℞ [`double-pinyin`](https://github.com/rime/rime-double-pinyin): 雙拼 / Double Pinyin (ZiRanMa, ABC, flyPY, MSPY, PYJJ variants)
  - ℞ [`combo-pinyin`](https://github.com/rime/rime-combo-pinyin): 宮保拼音 / [Combo Pinyin](https://github.com/rime/home/wiki/ComboPinyin), a chord-typing input method
  - ℞ [`stenotype`](https://github.com/rime/rime-stenotype): 打字速記法 / a stenographic system derived from ABC Easy Shorthand

Other modern varieties of Chinese

  - ℞ [`cantonese`](https://github.com/rime/rime-cantonese): 粵語拼音 / Cantonese
  - ℞ [`jyutping`](https://github.com/rime/rime-jyutping): 粵拼（無聲調） / Cantonese (without tones)
  - ℞ [`wugniu`](https://github.com/rime/rime-wugniu): 上海吳語 / Wu (Shanghainese)
  - ℞ [`soutzoe`](https://github.com/rime/rime-soutzoe): 蘇州吳語 / Wu (Suzhounese)

Middle Chinese

  - ℞ [`middle-chinese`](https://github.com/rime/rime-middle-chinese): 中古漢語拼音 / Middle Chinese Romanization

### Shape-based input methods

  - ℞ [`stroke`](https://github.com/rime/rime-stroke): 五筆畫 / five strokes
  - ℞ [`cangjie`](https://github.com/rime/rime-cangjie): 倉頡輸入法 / Cangjie input method
  - ℞ [`quick`](https://github.com/rime/rime-quick): 速成 / Simplified Cangjie
  - ℞ [`wubi`](https://github.com/rime/rime-wubi): 五筆字型
  - ℞ [`array`](https://github.com/rime/rime-array): 行列輸入法
  - ℞ [`scj`](https://github.com/rime/rime-scj): 快速倉頡

### Miscellaneous

  - ℞ [`emoji`](https://github.com/rime/rime-emoji): 繪文字 / input emoji with English or Chinese Pinyin keywords
  - ℞ [`ipa`](https://github.com/rime/rime-ipa): 國際音標 / International Phonetic Alphabet

## Usage

To prepare your Rime configuration for [ibus-rime](https://github.com/rime/ibus-rime),
[Squirrel](https://github.com/rime/squirrel), you can get started by running

```sh
curl -fsSL https://raw.githubusercontent.com/rime/plum/master/rime-install | bash
```

/// 用法：Linux、macOS 系統，在終端輸入以上命令行，安裝配置管理器及預設配方。 ///

Paste the command line in Linux terminal or macOS `Terminal.app` and hit enter.

The one-liner runs the `rime-install` script to download preset packages and install
source files to Rime user directory. (Yet it doesn't enable new schemas for you)

For [Weasel](https://github.com/rime/weasel), please refer to the [Windows bootstrap script](#windows) section for initial setup.

## Advanced usage

Alternatively, you can specify a configuration among `:preset`, `:extra` and `:all` (note the colon):

```sh
curl -fsSL https://raw.githubusercontent.com/rime/plum/master/rime-install | bash -s -- :preset
```

This is equivalent to cloning this repo and running the local copy of `rime-install`:

```sh
git clone --depth 1 https://github.com/rime/plum.git
cd plum
bash rime-install :preset
```

You can then add packages from all the great Rime developers on GitHub by specifying
a list of package names or refer to packages by `<user>/<repo>`:

```sh
bash rime-install jyutping lotem/rime-zhung acevery/rime-zhengma

# optionally, specific a branch by appending "@<branch-name>"
bash rime-install jyutping@master lotem/rime-zhung@master
```

Lastly, it's also possible to install other author's Rime configuration from a
`*-packages.conf` file hosted on GitHub. For example:


```sh
bash rime-install https://github.com/lotem/rime-forge/raw/master/lotem-packages.conf

# or in short form: "<user>/<repo>/<filepath>"
bash rime-install lotem/rime-forge/lotem-packages.conf

# or specify a branch: "<user>/<repo>@<branch>/<filepath>"
bash rime-install lotem/rime-forge@master/lotem-packages.conf
```

For third-party Rime distributions, specify the `rime_frontend` variable in the command line:

```sh
rime_frontend=fcitx-rime bash rime-install
```

or set `rime_dir` to Rime user directory

```sh
rime_dir="$HOME/.config/fcitx/rime" bash rime-install
```

To update /plum/ itself, run

```sh
bash rime-install plum
```

## Interactively select packages to install

Specify the `--select` flag as the first argument to `rime-install`,
then add configurations (`:preset` is the default) and/or individual packages to display in the menu.

```sh
bash rime-install --select :extra

bash rime-install --select :all lotem/rime-forge/lotem-packages.conf
```

[Screenshot](https://github.com/rime/home/raw/master/images/rime-install-select.png) of usage example

<a name="windows"></a>
## Windows bootstrap script

To get started on Windows, download the [bootstrap bundle][bootstrap-bundle],
unpack the ZIP archive and run `rime-install-bootstrap.bat` for initial setup.

It will fetch the latest installer script `rime-install.bat` an create a shortcut to it,
which can then be copied or moved anywhere for easier access.

/// Windows 用家可以通過 [小狼毫](https://rime.im/download/#windows) 0.11 以上「輸入法設定／獲取更多輸入方案」調用配置管理器。///

/// 或者下載獨立的 [啓動工具包][bootstrap-bundle]。///

  [bootstrap-bundle]: https://github.com/rime/plum-windows-bootstrap/archive/master.zip

### Use built-in ZIP package installer

You can use the installer script to download and install ZIP packages from GitHub, in a number of ways:

1. Double-click the shortcut to bring up an interactive package installer, then input package name, `<user>/<repo>` or GitHub URL for the package.

2. Run `rime-install.bat` in the command line. The command takes a list of packages to install as arguments.

```batch
rime-install :preset combo-pinyin jyutping wubi
```

3. Drag downloaded ZIP packages from GitHub onto the shortcut to do offline install.

   You can find ZIP packages downloaded by the installer script in `%TEMP%` folder (can be customized via variable `download_cache_dir`).

   To manually download ZIP package from a GitHub repository, click the button *Clone or download*, then *Download ZIP*.

### Use git for incremental updates (optional)

If [Git for Windows](https://gitforwindows.org/) is installed in the default location or is available in your `PATH`,
the script will use git-bash to install or update packages.

Use the following command to install Git for Windows, if you are new to git.

```batch
rime-install git
```

You can set more options in `rime-install-config.bat` in the same directory as `rime-install.bat`, for example:

```batch
set plum_dir=%APPDATA%\plum
set rime_dir=%APPDATA%\Rime
set use_plum=1
```

## Install as shared data

The `Makefile` builds and installs Rime data as a software on Unix systems.

For downstream packagers for the package management systems of the OS, it's recommend to create
separate packages for the /plum/ configuration manager (possibly named `rime-plum` or `rime-install`)
and the data package(s) (possibly named `rime-data`, or `rime-data-*` if separated into many)
created by the make targets.

### Build dependencies

  - git
  - librime>=1.3 (for `rime_deployer`)

### Run-time dependencies

  - librime>=1.3
  - opencc>=1.0.2

### Build and install

The default make target uses `git` command to download the latest packages from GitHub.

```sh
make
sudo make install
```

You can optionally build the by default enabled input schemas to binaries.
This saves user's time building those files on first startup.

```sh
make preset-bin
```

## License

Code in the `rime/plum` repository is licensed under **LGPLv3**.
Please refer to the `LICENSE` file in the project root directory.

**Note** that make targets provided by the `Makefile` may include files downloaded by the
configuration manager. Individual packages can be released under different licenses.
Please refer to their respective `LICENSE` files.
The license compatible with all the maintained packages is **GPLv3**.

## Credits

We are grateful to the makers of the following open source projects:

  - [Android Pinyin IME](https://source.android.com/) (Apache 2.0)
  - [Chewing / 新酷音](http://chewing.im/) (LGPL)
  - [ibus-table](https://github.com/acevery/ibus-table) (LGPL)
  - [OpenCC / 開放中文轉換](https://github.com/BYVoid/OpenCC) (Apache 2.0)
  - [moedict / 萌典](https://www.moedict.tw) (CC0 1.0)
  - [Rime 翰林院 / Rime Academy](https://github.com/rime-aca) (GPLv3)

Also to the inventors of the following input methods:

  - Cangjie / 倉頡輸入法 by 朱邦復
  - Array input method / 行列輸入法 by 廖明德
  - Wubi / 五筆字型 by 王永民
  - Scj / 快速倉頡 by 麥志洪
  - Middle Chinese Romanization / 中古漢語拼音 by 古韻

## Contributors

This software is a result of collective effort. It was set up by the following
people by contributing files, patches and pull-requests. See also the
[contributors](https://github.com/rime/plum/graphs/contributors) page for a
list of open-source collaborators.

  - [佛振](https://github.com/lotem)
  - [Kunki Chou](https://github.com/kunki)
  - [雪齋](https://github.com/LEOYoon-Tsaw)
  - [Patrick Tschang](https://github.com/Patricivs)
  - [Joseph J.C. Tang](https://github.com/jinntrance)
  - [lxk](http://101reset.com)
  - [Ye Zhou](https://github.com/zhouye)
  - Jiehong Ma
  - StarSasumi
  - 古韻
  - 寒寒豆
  - 四季的風
  - 上海閒話abc
  - 吳語越音
