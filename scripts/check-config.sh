#!/usr/bin/env bash
#
# check-config.sh —— 核对种子配置里点名要的包，有多少真的进了最终 .config
#
# `make defconfig` 遇到不存在的 CONFIG_PACKAGE_xxx 会静默丢弃，不报错也不提示。
# 这个脚本把丢掉的都列出来，免得等固件刷完才发现某个插件根本没编进去。
#
# 用法：check-config.sh <种子配置路径> <最终 .config 路径>
#
set -uo pipefail

SEED="${1:?用法: check-config.sh <seed.config> <.config>}"
FINAL="${2:?用法: check-config.sh <seed.config> <.config>}"

missing=0
kept=0

echo "=========================================================="
echo " 配置核对：$SEED  ->  $FINAL"
echo "=========================================================="

while IFS= read -r sym; do
	if grep -qx "${sym}=y" "$FINAL"; then
		kept=$((kept + 1))
	else
		printf '  ✗ 未编入: %s\n' "${sym#CONFIG_}"
		missing=$((missing + 1))
	fi
done < <(grep -oE '^CONFIG_PACKAGE_[A-Za-z0-9_.-]+=y' "$SEED" | sed 's/=y$//')

echo "----------------------------------------------------------"
echo "  已编入 ${kept} 个，未编入 ${missing} 个"
if [ "$missing" -gt 0 ]; then
	echo ""
	echo "  未编入的常见原因："
	echo "    - 该 feed 里没有这个包（名字变了 / 换仓库了）"
	echo "    - 依赖不满足，被 defconfig 连带关掉了"
	echo "    - 和已选的包冲突"
	echo "  这不会让编译失败，但对应功能不会出现在固件里。"
fi
echo "=========================================================="

# 不阻断构建：少个把插件不该让整个固件白编
exit 0
