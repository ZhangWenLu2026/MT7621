#!/bin/bash
# 在 WSL2 Ubuntu 里跑：bash /mnt/d/openwrt/openwrt-build/wsl-build.sh
# 源码走 gitee 镜像，feeds/源码包走 openwrt 官方（已确认国内可达）
set -euo pipefail

SRC=/mnt/d/openwrt/openwrt-build/src
OUT=/mnt/d/openwrt/out
WORK=$HOME/rn1150w
BRANCH=openwrt-24.10

echo "==> [0/6] 同步时钟（WSL2 常见时间漂移会让编译报错）"
sudo hwclock -s || true

echo "==> [1/6] 安装编译依赖"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y build-essential clang flex bison g++ gawk \
  gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
  python3-setuptools python3-dev rsync unzip zlib1g-dev file wget curl \
  time

echo "==> [2/6] 拉取 OpenWrt 源码（gitee 镜像）"
mkdir -p "$WORK" "$OUT"
cd "$WORK"
if [ ! -d openwrt/.git ]; then
  git clone --depth=1 -b "$BRANCH" https://gitee.com/mirrors/OpenWrt.git openwrt
else
  echo "已存在，跳过 clone"
fi
cd "$WORK/openwrt"

echo "==> [3/6] 注入机型"
cp "$SRC/mt7621_tg_rn1150w.dts" target/linux/ramips/dts/
if ! grep -q "tg_rn1150w" target/linux/ramips/image/mt7621.mk; then
  cat "$SRC/mt7621.mk.append" >> target/linux/ramips/image/mt7621.mk
fi

echo "==> [4/6] 更新 feeds"
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> [5/6] 生成配置"
cat > .config <<'EOF'
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_ramips_mt7621_DEVICE_tg_rn1150w=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-proto-ppp=y
EOF
make defconfig
grep -E "DEVICE_tg_rn1150w|PACKAGE_luci=" .config

echo "==> [6/6] 下载源码包 + 编译（-j$(nproc)）"
make -j"$(nproc)" download V=s || echo "!! 部分源码包下载失败，继续编译，缺失的会再提示"
make -j"$(nproc)" V=s

echo "==> 拷贝产物到 $OUT"
cp -v bin/targets/ramips/mt7621/*tg_rn1150w* "$OUT"/ 2>/dev/null || true
ls -lh "$OUT"
echo "完成。Windows 路径：D:\\openwrt\\out"
