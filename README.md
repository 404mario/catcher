# catcher — 机型ID 与实际配置检查对比工具

Scan a physical server's real hardware (CPU / 内存 / 硬盘 / GPU / 网卡), build the
**机型ID** from the naming spec, and print the human-readable config. Also decodes
a given 机型ID back into a config string. Pure bash + standard tools — companion to
[`uqsm5090`](https://github.com/404mario/uqsm5090); no Docker, no extra installs.

## Usage

```bash
sudo ./catcher.bash detect          # scan -> 机型ID + 配置说明 + result/catcher_result.json
sudo ./catcher.bash id              # scan -> print only the 机型ID
./catcher.bash describe I31G82N23M65S03   # decode a 机型ID -> config description
sudo ./catcher.bash json            # scan -> machine-readable JSON only
```

> Run with **sudo**: memory DIMM layout comes from `dmidecode`, which reads the
> firmware SMBIOS tables and needs root. Everything else works unprivileged, so a
> non-root run still produces CPU/GPU/网卡/硬盘 and warns that 内存 is total-only.

## What each component reads (底层硬件如何识别)

| 部件 | 命令 | 读到的是什么 |
|------|------|--------------|
| GPU  | `nvidia-smi -L` / `--query-gpu=name,memory.total` | NVIDIA 驱动(NVML)上报的产品名+显存；PCIe/SXM、40/80G 都编码在产品名里 |
| CPU  | `lscpu` | CPUID/`/proc/cpuinfo` 自报的型号(如 `XEON GOLD 6530`)与插槽数(Socket(s)) |
| 内存 | `dmidecode -t memory` (root) | 固件 SMBIOS/DMI 表里**每根**内存条的容量+类型(DDR4/5)；`/proc/meminfo` 只有总量 |
| 硬盘 | `lsblk -dnb` | `/sys/block` 的块设备：字节数(十进制) + `ROTA`(0=SSD/NVMe,1=HDD)；按整数容量贴近营销规格 |
| 网卡 | `ip`/`ethtool`/`/sys/class/net`、`/sys/class/infiniband` | 物理口链路速率(Mb/s)；IB 口的速率+代际(HDR/NDR) 来自 `.../ports/*/rate` |

`detect` 模式用**物理实测**区分以太网卡(网卡) vs IB卡、SSD vs HDD、真实 DDR 代际；
`describe <ID>` 模式只有 ID 信息，会按规则启发式推断(DDR 由 CPU 代际推断、IB 代际按速率默认)。

## 命名规则与匹配 (naming & matching)

所有命名规范表在 `lib/catalog.sh`，按"规范键"映射到 ID：

- **CPU** `"<厂商> <SKU>|<插槽数>"` → `I*/A*`，例如 `Intel 6530|2` → `I57`
- **GPU** `"<token>|<数量>"` token 含 系列+PCIe/SXM+显存，例如 `RTX5090|8` → `G90`
- **内存** `"<容量GB>|<条数>"`，例如 `64|32` → `M65`
- **网卡** 速率分组升序合并 `"25*2+200*2"` → `N23`
- **硬盘** 容量分层升序合并 `"960G*2+3.84T*2"` → `S10`

拼接顺序为 **CPU→GPU→网卡→内存→硬盘**，例如 `I57G90N13...`。
任一部件匹配不到机型库时会输出黄色提示(`未匹配到机型库 … 请补充命名规范`)，机型ID 标记为不完整。

### 已知的规范歧义（按源表如实保留）

- `M60` 与 `M61` 同为 `64G*8`（生成时取 `M60`，`M61` 视为别名）。
- `S23` 在源表出现两次（`900G*3+1.92T*3` 和 `+2.4T*8`），同一 ID。
- `N14` 源表为空，已跳过；`N32` 源表有笔误(`200Gbos`/重复 200G)，按 `100*2+200*18` 合并。
- 硬件 RAID 逻辑盘会掩盖物理盘数（如 RAID1 的 960G*2 启动盘只显示一个 ~894GiB 卷）。
  `detect` 会提示，并按 RAID1 把单个 SSD 层翻倍后再试一次机型库（如 `960G*1+3.84T*2` → 推断 `S10`）。

## 文件结构

```
catcher.bash          # 入口：detect | id | describe | json
lib/catalog.sh        # 命名规范表(数据，便于核对)
lib/detect.sh         # 硬件探测 -> 规范键
lib/idgen.sh          # 规范键 -> ID，ID -> 配置说明
result/               # 输出 JSON (gitignored)
```

## 发布到 OSS（参考 uqsm5090 流程）

打包后用 `ossctl` 上传到公共读的 `scitix-release` 桶（凭据在发布机 `~/.ossctl/config.json`，不入库）：

```bash
tar -czf catcher.tar.gz -C ~ catcher
ossctl cp catcher.tar.gz oss/scitix-release/catcher.tar.gz          # Shanghai
# 下载(免客户端): wget https://oss-cn-shanghai.siflow.cn/scitix-release/catcher.tar.gz
```
