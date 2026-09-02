# ByPassWrt —— 旁路由定制固件

基于 **ImmortalWrt 24.10** 的 x86_64 固件构建工程，专门按**旁路由（单臂路由）**场景调好了默认配置。
不需要本地装编译环境，在 GitHub Actions 上点一下就能出固件。

和"随便勾一堆插件"的固件不同，这里的重点是**插件里面的内容也配好了**：网络、DHCP、防火墙、
DNS 分流链路、PassWall 的分流与远程 DNS，刷完开机就是能用的状态。

---

## 一分钟上手

1. Fork 或直接使用本仓库
2. 仓库页面 → **Actions** → 左侧 **构建旁路由固件** → **Run workflow**
3. 等 1.5～3 小时（第一次最慢，工具链要从头编）
4. 从 **Artifacts** 或 **Releases** 下载固件

| 想要什么 | 下载哪个文件 |
| --- | --- |
| 物理机，2015 年后的机器 | `*-squashfs-combined-efi.img.gz`（UEFI） |
| 物理机，老机器 / 传统 BIOS | `*-squashfs-combined.img.gz` |
| PVE / ESXi / VirtualBox | `*.vmdk` |
| 想以后随便扩容分区 | 选 `ext4` 版而不是 `squashfs` 版 |

刷机和接入方法见 **[docs/旁路由部署指南.md](docs/旁路由部署指南.md)**。

---

## 出厂就配好的东西

### 网络（旁路由核心）

| 项 | 默认值 | 说明 |
| --- | --- | --- |
| 本机地址 | `192.168.1.2` | 与主路由同网段 |
| 网关 | `192.168.1.1` | 指向主路由 |
| DHCP 服务 | **关闭** | 避免和主路由抢着发地址 |
| WAN 口 | **已删除** | 单臂旁路由不需要 |
| 所有物理网口 | 全并入 `br-lan` | 单网口、多网口机器都能插哪个口都通 |
| 硬件/软件流量分载 | **关闭** | 开着会让数据包绕过 netfilter，透明代理直接失效 |
| BBR + fq | 已开启 | 见 `/etc/sysctl.d/99-bypass-router.conf` |

### DNS 链路

```
客户端 → dnsmasq:53 → SmartDNS:6053 ┬→ 默认组：阿里/腾讯/百度 DNS（测速优选）
                                     └→ opendns 组：OpenDNS
                                        · 208.67.222.222 / 220.220（UDP 5353、TCP 443）
                                        · https://doh.opendns.com/dns-query
                                        · 2620:119:35::35 / 2620:119:53::53
```

- 境外常用域名（Google / GitHub / OpenAI / Netflix …）已经用 `nameserver` 规则指到 **opendns 组**
- 国内大厂域名强制走默认组，避免误判绕远路
- 顺手屏蔽了一批广告和遥测域名
- 规则文件：[`files/etc/smartdns/custom.conf`](files/etc/smartdns/custom.conf)，直接改就行

> 为什么用 5353 / TCP 443 而不是 53？OpenDNS 在 53 端口容易被污染，
> 5353 和 443 是官方提供的备用端口，干净很多。DoH 通道则需要配合代理才通。

### PassWall（已预置，**默认未启用**）

| 配置项 | 值 |
| --- | --- |
| 远程 DNS | `https://doh.opendns.com/dns-query`（带 bootstrap IP） |
| 直连 DNS | `223.5.5.5` |
| 转发方式 | TProxy + nftables（24.10 的 firewall4 就是 nftables） |
| 代理端口 | TCP/UDP 全端口 `1:65535` |
| 分流列表 | 直连/代理/屏蔽/GFW 名单全开，国内 IP 直连 |
| 内核 | Xray、Sing-Box、Hysteria、Shadowsocks-Rust、SSR、ShadowTLS、TUIC… |

**默认不启用是故意的**：没配节点就打开会直接把网络打断。加好节点后再到
「服务 → PassWall → 基本设置」里勾选启用。

### 其他插件

OpenClash（备用代理）、SmartDNS、ttyd 网页终端、DDNS、UPnP、网络唤醒、流量监控 nlbwmon、
IP/MAC 绑定、eQoS 限速、KMS 激活、frpc 内网穿透、ZeroTier、网易云解锁、定时重启、
磁盘管理 DiskMan、Samba4、Aria2 + AriaNg、WireGuard / OpenVPN 协议支持、Argon 主题（中文）。

x86 网卡驱动一把梭：Intel `e1000e/igb/igc(i225/i226 2.5G)/ixgbe/i40e`、Realtek `r8169/r8125`、
Broadcom、Mellanox，以及 ESXi / PVE / Hyper-V / VirtualBox 的虚拟网卡。

---

## 改成自己的配置

### 改 IP / 主机名 / 要不要接管 DHCP

只有一处需要改：[`files/etc/uci-defaults/99-bypass-router`](files/etc/uci-defaults/99-bypass-router) 顶部。

```sh
LAN_IP="192.168.1.2"        # 旁路由自己的 IP
MAIN_ROUTER="192.168.1.1"   # 主路由 IP
HOSTNAME="ByPassWrt"
SERVE_DHCP="0"              # 改成 1 = 旁路由接管 DHCP，客户端自动指向旁路由
```

改完重新跑一次构建即可。构建脚本会自动把 `LAN_IP` 同步到固件的出厂默认地址，
不用担心两处对不上。

> 主路由不是 `192.168.1.1` 网段的（比如 `192.168.31.1` 小米、`192.168.2.1` 华硕），
> 记得两个值一起改。

### 加减插件

编辑 [`configs/x86_64.config`](configs/x86_64.config)。文件末尾有「可选加料区」，
把想要的行前面的 `# ` 去掉就行：Docker、PassWall2、SSR-Plus、netdata、SQM、mwan3。

不存在的包不会让编译失败——`make defconfig` 会静默丢弃它们，而构建日志里的
**「核对配置」** 步骤会明确列出哪些包没编进去，不用等刷完机才发现。

### 用上游最新版 PassWall

跑 workflow 时把 **「用上游最新 PassWall」** 勾上。

默认用的是 ImmortalWrt 自带的 PassWall（25.x），依赖和主线同源，编译成功率最高；
上游版本（26.x）更新更快，但偶尔会和 24.10 的依赖打架。先用默认的把流程跑通，再考虑尝鲜。

---

## 仓库结构

```
.github/workflows/build-openwrt.yml   构建工作流（手动触发，可选开启每周自动构建）
configs/x86_64.config                 种子配置：目标平台 + 插件清单
scripts/diy-part1.sh                  拉完源码、update feeds 之前执行（挂第三方 feed）
scripts/diy-part2.sh                  feeds 装完、defconfig 之前执行（同步 IP、覆盖安装）
scripts/check-config.sh               核对哪些包被 defconfig 丢弃了
scripts/depends-ubuntu.txt            Ubuntu 22.04 编译依赖清单
files/                                原样打包进固件的文件
  etc/uci-defaults/99-bypass-router     首次开机自动执行的旁路由配置脚本
  etc/smartdns/custom.conf              SmartDNS 分流规则（OpenDNS 分组）
  etc/profile.d/99-bypass-tips.sh       SSH 登录提示
docs/旁路由部署指南.md                  刷机、接入、排障
```

## 安全提醒

固件沿用 OpenWrt 出厂设定：**root 密码为空**。同一局域网内任何人都能直接 SSH 进来。
本仓库刻意不预置默认密码（写死在公开仓库里的密码等于没有），**首次登录后请立刻 `passwd`**。
SSH 登录时如果密码还是空的，会有一行红色提醒。

## 授权

构建脚本与配置以 MIT 授权。固件本体、各插件分别遵循 OpenWrt / ImmortalWrt / 各插件自己的
许可证（多数为 GPL-2.0 / GPL-3.0）。
