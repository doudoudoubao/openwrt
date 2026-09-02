#!/bin/sh
# 登录时给一条简短提示（OpenWrt 的 /etc/profile 会自动加载 profile.d/*.sh）

_bp_ip="$(uci -q get network.lan.ipaddr)"
_bp_gw="$(uci -q get network.lan.gateway)"

printf '\n'
printf '  \033[1;36m旁路由 ByPassWrt\033[0m   本机 %s   网关 %s\n' "${_bp_ip:-?}" "${_bp_gw:-?}"

# root 密码为空是 OpenWrt 出厂状态，局域网内谁都能 SSH 进来，必须提醒
if grep -q '^root::' /etc/shadow 2>/dev/null; then
	printf '  \033[1;31m! root 密码为空，请立刻执行 passwd 设置密码\033[0m\n'
fi

# 常见排障入口，省得每次翻文档
printf '  排障: \033[0;33mcat /tmp/bypass-setup.log\033[0m (首次配置日志)  '
printf '\033[0;33mlogread -e passwall\033[0m  \033[0;33m/etc/init.d/smartdns status\033[0m\n\n'

unset _bp_ip _bp_gw
