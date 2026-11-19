#!/usr/bin/env bash
#
# diy-part1.sh —— 在「拉完源码、还没 update feeds」时执行
# 工作目录：openwrt 源码根目录
#
set -euo pipefail

echo "==> [diy-part1] 开始处理 feeds"

# ---------------------------------------------------------------------------
# 可选：挂上游最新 PassWall
#
# 默认关闭。ImmortalWrt 自带的 luci-app-passwall 依赖全部来自同一套 feed，
# 编译成功率最高；上游版本更新更快，但偶尔会和 24.10 的依赖打架。
# 想尝鲜就在工作流里把 USE_UPSTREAM_PASSWALL 设成 1。
# ---------------------------------------------------------------------------
if [ "${USE_UPSTREAM_PASSWALL:-0}" = "1" ]; then
	echo "==> [diy-part1] 启用上游 PassWall feed"
	cat >> feeds.conf.default <<'EOF'
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main
EOF
else
	echo "==> [diy-part1] 使用 ImmortalWrt 自带 PassWall（更稳）"
fi

echo "==> [diy-part1] 当前 feeds:"
grep -v '^\s*#' feeds.conf.default | grep -v '^\s*$' | sed 's/^/    /'
