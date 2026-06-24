# catcher — 机型ID 与实际配置检查对比工具

抓取物理机真实硬件（CPU / 内存 / 硬盘 / GPU / 网卡），按命名规范**自动生成机型ID**，
并打印配置说明；也能把一个机型ID**反解析**成配置清单。纯 bash + 系统自带工具，
**无需 Docker、无需额外安装**，物理机上裸跑。是 [`uqsm5090`](https://github.com/404mario/uqsm5090) 的姊妹工具。

---

## 快速开始

```bash
# 1) 下载并解压（免客户端，公共读）
wget https://oss-cn-shanghai.siflow.cn/scitix-release/catcher.tar.gz
tar -xzf catcher.tar.gz && cd catcher

# 2) 扫描本机 -> 机型ID + 配置说明（建议 sudo，内存检测需 root）
sudo ./catcher.bash detect
```

输出示例（8×RTX5090 机器）：

```
==================== 实际硬件检测 (detected) ====================
  CPU    I57    <- INTEL(R) XEON(R) GOLD 6530 (2 socket)
  GPU    G90    <- NVIDIA GeForce RTX 5090 *8
  网卡 N13    <- 100Gbps*2
  内存 M63    <- DDR5 64G *16
  硬盘 S10    <- SSD 960G*2 + SSD 3.84T*2
----------------------------------------------------------------
机型ID: I57G90N13M63S10
----------------------------------------------------------------
配置说明 (config，来自实测):
  CPU: Intel 6530 *2
  内存: DDR5 64G *16
  系统盘: SSD 960G*2（需支持raid1）
  数据盘: SSD 3.84T*2
  GPU: 5090 *8
  网卡: 100G双口以太网卡*1
================================================================
```

---

## 运行依赖与权限

### 依赖的工具（都是发行版自带或一条命令可装）

| 工具 | 用途 | 必需性 | 缺失时 | 安装（Ubuntu/Debian · RHEL/CentOS） |
|------|------|--------|--------|--------------------------------------|
| `bash` ≥ 4 | 运行脚本（用到关联数组） | **必需** | 无法运行 | 自带（本工具在 bash 5.1 实测） |
| `lscpu` | 读 CPU 型号/插槽数 | 强烈建议 | CPU 部件留空并提示 | `util-linux`（一般自带） |
| `lsblk` | 读硬盘容量/SSD-HDD | 强烈建议 | 硬盘部件留空并提示 | `util-linux`（一般自带） |
| `dmidecode` | 读**每根**内存条容量/DDR代 | 内存检测必需 | 内存只给总量并提示需 root | `apt install dmidecode` · `yum install dmidecode` |
| `nvidia-smi` | 读 GPU 型号/显存 | GPU 机器需要 | 无 NVIDIA 驱动时跳过 GPU | 随 NVIDIA 驱动安装（无需 CUDA toolkit） |
| `ethtool` | 读以太网口链路速率 | 建议 | 改用 `/sys/.../speed`，链路 down 的口可能漏报 | `apt install ethtool` · `yum install ethtool` |
| `lspci` | 辅助识别 NIC/GPU 存在 | 可选 | 不影响主流程 | `pciutils`（一般自带） |
| `jq` | 输出更规整的 JSON | 可选 | 自动回退到内置 JSON 拼装 | `apt install jq` · `yum install jq` |

> InfiniBand 速率/代际(HDR/NDR) 直接读 `/sys/class/infiniband/`，不依赖额外命令；没有 IB 时自动跳过。

### 权限：只有内存检测需要 root

```bash
sudo ./catcher.bash detect      # 推荐：完整结果（含每根内存条）
./catcher.bash detect           # 非 root 也能跑：CPU/GPU/网卡/硬盘照常，内存只给总量并提示
```

- **为什么**：内存条逐根布局来自 `dmidecode`，它读固件 SMBIOS/DMI 表，必须 root；`/proc/meminfo`
  只有总量，区分不了 `16×64G` 和 `32×32G`。其余探测（`lscpu`/`lsblk`/`nvidia-smi`/`sysfs`）都是**普通用户只读**即可。
- **本工具只读、不改硬件、不联网**：纯粹采集 + 计算 + 写本地 `result/*.json`，可安全在生产物理机上跑。
- **非交互环境**（CI、无 TTY 的会话）里 `sudo` 会要密码而失败 —— 请在真实终端手动 `sudo` 跑一次，
  或为 `dmidecode` 配置 NOPASSWD。

---

## 四个命令

| 命令 | 作用 |
|------|------|
| `sudo ./catcher.bash detect` | 扫描硬件 → 机型ID + 配置说明 + 写 `result/catcher_result.json` |
| `sudo ./catcher.bash id` | 扫描硬件 → 只打印机型ID（适合脚本调用） |
| `./catcher.bash describe <机型ID>` | 反解析：机型ID → 配置清单（如 `describe I31G82N23M65S03`） |
| `sudo ./catcher.bash json` | 扫描 → 只输出机器可读 JSON |

> `describe` 不读硬件、无需 root；`detect`/`id`/`json` 建议 `sudo`（原因见上「运行依赖与权限」）。

---

## 它怎么认硬件（底层命令）

| 部件 | 命令 | 读到的是什么 |
|------|------|--------------|
| GPU  | `nvidia-smi -L` / `--query-gpu=name,memory.total` | NVIDIA 驱动(NVML)上报的产品名+显存；PCIe/SXM、40/80G 都编码在产品名里 |
| CPU  | `lscpu` | CPUID 自报的型号(如 `XEON GOLD 6530`) + 插槽数(Socket(s)) |
| 内存 | `dmidecode -t memory`（root） | 固件里**每根**内存条的容量+类型(DDR4/5)；`/proc/meminfo` 只有总量，区分不了 16×64G 和 32×32G |
| 硬盘 | `lsblk -dnb` | 块设备字节数(十进制) + `ROTA`(0=SSD,1=HDD)；按字节贴近营销规格(960G≈894GiB) |
| 网卡 | `ethtool`/`/sys/class/net`、`/sys/class/infiniband` | 物理口链路速率(Mb/s)；IB 口的速率+代际(HDR/NDR) 来自 `.../ports/*/rate` |

`detect` 模式用**物理实测**区分以太网卡 vs IB卡、SSD vs HDD、真实 DDR 代际，结果权威；
`describe <ID>` 模式只有 ID 信息，按规则启发式推断（DDR 由 CPU 代际推断、IB 代际按速率默认）。

---

## 命名规则与机型ID 拼接

所有命名规范表都在 `lib/catalog.sh`（关联数组，便于核对源表）。每个部件按"规范键"映射到代码：

- **CPU** `"<厂商> <SKU>|<插槽数>"` → `I*/A*`，例：`Intel 6530|2` → `I57`
- **GPU** `"<token>|<数量>"`（token 含 系列+PCIe/SXM+显存），例：`RTX5090|8` → `G90`
- **内存** `"<容量GB>|<条数>"`，例：`64|16` → `M63`
- **网卡** 速率分组升序合并 `"25*2+200*2"` → `N23`
- **硬盘** 容量分层升序合并 `"960G*2+3.84T*2"` → `S10`

机型ID 拼接顺序固定为 **CPU → GPU → 网卡 → 内存 → 硬盘**，例：`I57G90N13M63S10`。

**任一部件匹配不到机型库**时会输出黄色提示（`未匹配到机型库 … 请补充命名规范`），机型ID 标记为不完整。

> 📖 **完整匹配规则**（各部件的归一化、显存/容量阈值、就近贴桶 ±8% 容差、以太/IB 划分、
> IB 代际解析顺序、RAID1 兜底、ID 反解析，以及**如何新增机型**）见
> [`docs/MATCHING.md`](docs/MATCHING.md)。

### 已知的规范歧义（按源表如实保留）

- `M60` 与 `M61` 同为 `64G*8`（生成时取 `M60`，`M61` 视为别名）。
- `S23` 在源表出现两次（`900G*3+1.92T*3` 和 `+2.4T*8`），同一 ID。
- `N14` 源表为空，已跳过；`N32` 源表有笔误(`200Gbos`/重复 200G)，按 `100*2+200*18` 合并。
- **硬件 RAID 逻辑盘会掩盖物理盘数**（如 RAID1 的 960G×2 启动盘只显示一个 ~894GiB 卷）。
  `detect` 会提示，并按 RAID1 把单个 SSD 层翻倍后再试一次机型库（`960G*1+3.84T*2` → 推断 `S10`）。

---

## 文件结构

```
catcher.bash          # 入口：detect | id | describe | json
lib/catalog.sh        # 命名规范表（纯数据，便于核对）
lib/detect.sh         # 硬件探测 -> 规范键
lib/idgen.sh          # 规范键 -> ID，ID -> 配置说明
result/               # 输出 JSON（gitignored）
```

---

## 发布 / 更新到 OSS（维护者）

打包后用 `ossctl` 上传到公共读的 `scitix-release` 桶（凭据在发布机 `~/.ossctl/config.json`，**不入库**）：

```bash
tar -czf catcher.tar.gz -C ~ catcher           # 从家目录打包 catcher/ 整个目录
ossctl cp catcher.tar.gz oss/scitix-release/catcher.tar.gz       # 上海
ossctl cp catcher.tar.gz oss-bench/scitix-release/catcher.tar.gz # 马来西亚镜像(可选)
ossctl ls oss/scitix-release/catcher.tar.gz                      # 确认
```

下载（免客户端）：

```bash
wget https://oss-cn-shanghai.siflow.cn/scitix-release/catcher.tar.gz   # 上海
wget https://oss-ap-southeast.scitix.ai/scitix-release/catcher.tar.gz  # 马来西亚
```
