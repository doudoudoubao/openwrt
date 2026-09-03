#!/usr/bin/env bash
#
# gen-packages.sh —— 从源码构建树的 .config 生成 ImageBuilder 用的软件包清单
#
# 为什么需要这一步：
#   .config 里的 CONFIG_PACKAGE_* 并非全是真实包名，其中混有编译期子选项
#   （如 dnsmasq_full_ipset、luci-app-passwall_INCLUDE_Xray、TAR_ZSTD）。
#   这些符号在源码构建里有意义，但 ImageBuilder 只认真实包名，直接喂进去会
#   报 "Package not found" 而整个构建失败。
#   这里用构建树自己生成的包索引 tmp/.packageinfo 做白名单过滤。
#
# 用法：
#   scripts/gen-packages.sh <openwrt源码树> [输出文件]
#   例：scripts/gen-packages.sh /home/user/build/openwrt configs/x86_64.packages
#
set -euo pipefail

TREE="${1:?用法: gen-packages.sh <openwrt源码树> [输出文件]}"
OUT="${2:-configs/x86_64.packages}"

[ -f "$TREE/.config" ]           || { echo "找不到 $TREE/.config（先跑 make defconfig）"; exit 1; }
[ -f "$TREE/tmp/.packageinfo" ]  || { echo "找不到 $TREE/tmp/.packageinfo（先跑 make defconfig）"; exit 1; }

python3 - "$TREE" "$OUT" <<'PY'
import re, sys
tree, out = sys.argv[1], sys.argv[2]

real = set()
for line in open(f'{tree}/tmp/.packageinfo'):
    if line.startswith('Package: '):
        real.add(line[9:].strip())

kept, dropped = [], []
for line in open(f'{tree}/.config'):
    m = re.match(r'^CONFIG_PACKAGE_([A-Za-z0-9_.+-]+)=y$', line.strip())
    if not m:
        continue
    p = m.group(1)
    (kept if p in real else dropped).append(p)

# 源码构建里由 PassWall 的 INCLUDE_* 隐式带入的组件，ImageBuilder 必须显式声明。
# 这些都是预编译包，加进来不增加构建时间。
EXTRA = [
    'simple-obfs-client',   # Shadowsocks 混淆插件
    'shadow-tls',           # Shadow-TLS 协议
    'tuic-client',          # TUIC 协议
]
kept.extend(x for x in EXTRA if x in real)

missing = [x for x in EXTRA if x not in real]
kept = sorted(set(kept))

with open(out, 'w') as f:
    f.write("# ImageBuilder 软件包清单 —— 由 scripts/gen-packages.sh 生成，请勿手工编辑\n")
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
