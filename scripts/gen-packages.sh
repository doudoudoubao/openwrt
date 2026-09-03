#!/usr/bin/env bash
#
# gen-packages.sh —— 生成 ImageBuilder 用的软件包清单
#
# 输入是种子配置 configs/x86_64.config（我们"显式想要"的顶层包），
# 不是构建树里那份展开后的 .config。这个区别很关键：
#
#   .config 含 500+ 个由依赖解析带出来的包，其中包括互斥变体的两端
#   （典型例子：libustream-mbedtls 和 libustream-openssl 都会出现，
#    但它们抢同一个 /lib/libustream-ssl.so，同时列出会让 opkg 直接报
#    check_data_file_clashes 而整个构建失败）。
#   把这些传递依赖全部写死，等于把"选哪个实现"的决定权从 opkg 手里抢过来，
#   必然踩冲突。只列顶层包，剩下的交给 opkg 解析，它会自己挑一个实现。
#
# 另外，种子配置里的 CONFIG_PACKAGE_* 也不全是真实包名，混有编译期子选项
# （dnsmasq_full_ipset、luci-app-passwall_INCLUDE_Xray 等）。ImageBuilder 只认
# 真实包名，因此用构建树的包索引 tmp/.packageinfo 作白名单过滤。
#
# 用法：
#   scripts/gen-packages.sh <openwrt源码树> [输出文件] [种子配置]
#   例：scripts/gen-packages.sh /home/user/build/openwrt configs/x86_64.packages
#
set -euo pipefail

TREE="${1:?用法: gen-packages.sh <openwrt源码树> [输出文件] [种子配置]}"
OUT="${2:-configs/x86_64.packages}"
SEED="${3:-configs/x86_64.config}"

[ -f "$SEED" ]                   || { echo "找不到种子配置 $SEED"; exit 1; }
[ -f "$TREE/tmp/.packageinfo" ]  || { echo "找不到 $TREE/tmp/.packageinfo（先跑 make defconfig）"; exit 1; }

python3 - "$TREE" "$OUT" "$SEED" <<'PY'
import re, sys
tree, out, seed = sys.argv[1], sys.argv[2], sys.argv[3]

real = set()
for line in open(f'{tree}/tmp/.packageinfo'):
    if line.startswith('Package: '):
        real.add(line[9:].strip())

kept, dropped = [], []
for line in open(seed):
    m = re.match(r'^CONFIG_PACKAGE_([A-Za-z0-9_.+-]+)=y$', line.strip())
    if not m:
        continue
    p = m.group(1)
    (kept if p in real else dropped).append(p)

# 源码构建里由 PassWall 的 INCLUDE_* 隐式带入的组件，ImageBuilder 必须显式声明。
# 这些都是预编译包，加进来不增加构建时间。
# 这些在源码构建里由 luci-app-passwall 的 INCLUDE_* 编译选项带入，
# 并不是它的硬依赖（DEPENDS），所以 ImageBuilder 下不会被自动拉进来，必须显式声明。
# 少了它们 PassWall 装上也没有可用的协议内核。
EXTRA = [
    'xray-core',            # Xray 内核（VMess/VLESS/Trojan/SS/Reality）
    'sing-box',             # Sing-Box 内核（同时提供 TUIC / Hysteria2 / ShadowTLS 支持）
    'hysteria',             # Hysteria 内核
    'v2ray-plugin',         # Shadowsocks 的 v2ray 插件
    'xray-plugin',          # Shadowsocks 的 xray 插件
    'simple-obfs-client',   # Shadowsocks 混淆插件
    'shadow-tls',           # Shadow-TLS 协议
    'tuic-client',          # TUIC 协议
    'haproxy',              # PassWall 的负载均衡
]
kept.extend(x for x in EXTRA if x in real)

missing = [x for x in EXTRA if x not in real]
kept = sorted(set(kept))

with open(out, 'w') as f:
    f.write("# ImageBuilder 软件包清单 —— 由 scripts/gen-packages.sh 生成，请勿手工编辑\n")
    f.write("# 只含顶层包：传递依赖交给 opkg 解析，避免把互斥变体的两端同时写死\n")
    f.write("# （如 libustream-mbedtls 与 libustream-openssl 会争同一个文件）。\n")
    f.write("# 已用构建树的真实包索引 (tmp/.packageinfo) 过滤掉编译期子选项。\n")
    f.write("# 行首 '-' 表示从默认镜像中移除该包。\n")
    f.write("-dnsmasq\n")          # 必须换成 dnsmasq-full，否则没有 ipset/nftset
    for p in kept:
        f.write(p + "\n")

print(f"写入 {out}：{len(kept)} 个包")
print(f"过滤掉 {len(set(dropped))} 个非包符号")
if missing:
    print(f"警告：索引中找不到这些附加包，已跳过：{', '.join(missing)}")
PY
