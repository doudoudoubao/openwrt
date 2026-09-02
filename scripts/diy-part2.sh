#!/usr/bin/env bash
#
# diy-part2.sh —— 在「feeds 装完、配置和 files 已就位」时执行，紧接着就是 defconfig
# 工作目录：openwrt 源码根目录
#
set -euo pipefail

echo "==> [diy-part2] 开始源码级定制"

UCI_DEFAULT_FILE="files/etc/uci-defaults/99-bypass-router"

# ---------------------------------------------------------------------------
# 1. 把旁路由 IP 同步进 config_generate
#
# uci-defaults 脚本已经会设 IP 了，这里是第二道保险：万一那个脚本执行失败，
# 出厂默认 IP 也已经是旁路由地址，不至于因为地址冲突连不上机器。
# IP 只在 uci-defaults 里定义一次，这里读出来用，避免两处不一致。
# ---------------------------------------------------------------------------
if [ -f "$UCI_DEFAULT_FILE" ]; then
	LAN_IP="$(sed -n 's/^LAN_IP="\([^"]*\)".*/\1/p' "$UCI_DEFAULT_FILE" | head -1)"
	if [ -n "$LAN_IP" ] && [ -f package/base-files/files/bin/config_generate ]; then
		sed -i "s/192\.168\.1\.1/${LAN_IP}/g" package/base-files/files/bin/config_generate
		echo "==> [diy-part2] 出厂默认 IP 已设为 ${LAN_IP}"
	fi
else
	echo "==> [diy-part2] 警告：找不到 $UCI_DEFAULT_FILE，跳过 IP 同步"
fi

# ---------------------------------------------------------------------------
# 2. 上游 PassWall：强制用第三方 feed 的版本覆盖 ImmortalWrt 自带的
#
# 两个 feed 里有同名包时 feeds install 只会装先找到的那个，必须 -f 强制覆盖，
# 否则会出现「装了上游 luci-app-passwall，依赖却是自带版本」的错配。
# ---------------------------------------------------------------------------
if [ "${USE_UPSTREAM_PASSWALL:-0}" = "1" ]; then
	echo "==> [diy-part2] 强制安装上游 PassWall 及其依赖"
	./scripts/feeds install -p passwall_packages -f -a
	./scripts/feeds install -p passwall_luci     -f -a
	./scripts/feeds install -p passwall2         -f -a || true
fi

# ---------------------------------------------------------------------------
# 3. 固件版本号里带上构建日期，方便区分自己编的第几版
# ---------------------------------------------------------------------------
RELEASE_FILE="package/base-files/files/etc/openwrt_release"
if [ -f "$RELEASE_FILE" ] && ! grep -q "ByPassWrt" "$RELEASE_FILE"; then
	sed -i "s|^DISTRIB_DESCRIPTION=.*|DISTRIB_DESCRIPTION='ByPassWrt %D %V (旁路由定制 $(date +%Y.%m.%d))'|" "$RELEASE_FILE"
	echo "==> [diy-part2] 版本描述已更新"
fi

echo "==> [diy-part2] 完成"
