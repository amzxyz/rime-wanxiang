# 随机工具：UUID / ULID / 随机密码

随机工具用于快速生成 UUID、ULID 和随机密码，适合开发、测试、临时标识以及密码生成等场景。

所有功能均通过 `/` 开头的引导码触发。

---

## `/uuid`：UUID v4

输入：

```text
/uuid
```

可以生成随机 UUID v4，并同时提供三种常用表示形式：

```text
550e8400-e29b-41d4-a716-446655440000    〔UUID v4〕
550E8400-E29B-41D4-A716-446655440000    〔UUID v4 · 大写〕
550e8400e29b41d4a716446655440000        〔UUID v4 · 紧凑〕
```

三种候选表示的是同一个 UUID，仅字符串格式不同：

* **标准格式**：小写字母并保留连字符
* **大写格式**：转换为大写字母
* **紧凑格式**：去除所有连字符

适合用于程序对象 ID、测试数据、配置标识等场景。

---

## `/uuidq`：UUID v7

输入：

```text
/uuid7
```

可以生成 UUID v7。

UUID v7 在 UUID 中包含时间信息，因此与完全随机的 UUID v4 相比，更适合需要按照生成时间排序的 ID 场景。

同样提供三种表示形式：

```text
019c1234-5678-7abc-9def-0123456789ab    〔UUID v7〕
019C1234-5678-7ABC-9DEF-0123456789AB    〔UUID v7 · 大写〕
019c123456787abc9def0123456789ab        〔UUID v7 · 紧凑〕
```

分别为：

* **标准格式**
* **大写格式**
* **紧凑格式**

UUID v7 的时间部分使用 Rime 提供的毫秒时间 API 生成。

---

## `/ulid`：ULID

输入：

```text
/ulid
```

可以生成一个 ULID，例如：

```text
01K3Q8QY7M4E8X6N2P5R9T1ABC    〔ULID〕
```

ULID 固定为 **26 位字符**，使用数字和大写字母表示。

它同样包含时间信息，因此生成结果天然具有时间顺序，同时相比 UUID 更紧凑，也没有连字符。

适合用于：

* 数据记录 ID
* 日志或任务标识
* 按生成时间排列的对象编号

---

## `/mima`：随机密码

输入：

```text
/mima
```

会一次生成多种长度的随机密码。

默认提供：

```text
6 位
8 位
10 位
16 位
```

例如：

```text
Q7mK2x              〔6 位 · 字母数字〕
p8RW3zK5            〔8 位 · 字母数字〕
X4nT7qP2mK          〔10 位 · 字母数字〕
r8Qm3Kx7P2vT6Nz4    〔16 位 · 字母数字〕
```

普通密码由以下字符组成：

* 大写字母
* 小写字母
* 数字

默认会保证生成结果中包含大写字母、小写字母和数字。

为了减少肉眼识别错误，默认字符集中排除了容易混淆的字符：

```text
0 O
1 I l
```

---

## `/mimas`：含特殊字符的随机密码

输入：

```text
/mimas
```

生成方式与 `/mima` 类似，但额外加入特殊字符。

例如：

```text
Q7@mK2              〔6 位 · 含符号〕
p8#RW3zK            〔8 位 · 含符号〕
X4n!T7qP2m          〔10 位 · 含符号〕
r8Q@m3Kx7P2vT6#z    〔16 位 · 含符号〕
```

默认特殊字符为：

```text
!@#$%^&*_-+
```

生成结果会包含：

* 大写字母
* 小写字母
* 数字
* 特殊字符

其中 `/mimas` 会保证至少包含一个特殊字符。

---

## 自定义配置

随机工具可以通过 YAML 调整触发码、密码长度和字符范围：

```yaml
random_tools:
  uuid: "/uuid"
  uuid7: "/uuid7"
  ulid: "/ulid"
  password: "/mima"
  password_special: "/mimas"

  password_lengths: "6,8,10,16"

  chars:
    upper: "ABCDEFGHJKLMNPQRSTUVWXYZ"
    lower: "abcdefghijkmnopqrstuvwxyz"
    digit: "23456789"
    special: "!@#$%^&*_-+"
```

其中：

* `uuid`：UUID v4 触发码
* `uuid7`：UUID v7 触发码
* `ulid`：ULID 触发码
* `password`：普通随机密码触发码
* `password_special`：含特殊字符密码触发码
* `password_lengths`：需要生成的密码长度
* `chars/upper`：大写字母字符集
* `chars/lower`：小写字母字符集
* `chars/digit`：数字字符集
* `chars/special`：特殊字符集

例如：

```yaml
password_lengths: "8,12,16,24"
```

即可将密码候选长度调整为：

```text
8 位
12 位
16 位
24 位
```

!!! tip "快速记忆"

    ```text
    /uuid     UUID v4
    /uuidq    UUID v7
    /ulid     ULID
    /mima     字母数字密码
    /mimas    含特殊字符密码
    ```
