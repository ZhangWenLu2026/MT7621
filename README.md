# TG RN1150W (MT7621 8 口白牌机) OpenWrt 24.10 云端编译

## 这个仓库是什么

给 `MT7621AT + MT7530 + RTL8367SB` 的 8 口白牌路由器编译 OpenWrt 24.10 固件。

- 设备信息来自原厂 `full.bin` 取证：Flash W25Q128 16MB，RAM 512MB，Breed 引导，固件区从 `0x50000` 开始
- 交换芯片：MT7530（内部 5 口）+ RTL8367SB（外挂，RGMII 级联到 MT7530 port5，GPIO7 复位）
- v1 固件把 **全部网口放进 br-lan**（纯交换机用法，无 WAN 口），管理地址 `192.168.1.1`

## 一、上传到 GitHub

1. 在 GitHub 新建一个**私有**仓库，例如 `rn1150w-openwrt`
2. 把本目录下所有文件（包括 `.github/`）上传：
   - 网页上传：Add file → Upload files，把 `.github`、`src` 两个文件夹和本 README 一起拖进去
   - 或者用 git：
     ```bash
     git init
     git add .
     git commit -m "init"
     git branch -M main
     git remote add origin https://github.com/<你的用户名>/rn1150w-openwrt.git
     git push -u origin main
     ```

## 二、云端编译

1. 打开仓库的 **Actions** 标签页
2. 左侧选 `build-openwrt-rn1150w` → 右侧 **Run workflow** → 绿色按钮
3. 等待约 40–70 分钟（首次要下载全部源码）
4. 编译完成后，在本次运行页面底部 **Artifacts** 下载 `rn1150w-firmware.zip`

里面需要的是：

```
openwrt-24.10.x-ramips-mt7621-tg_rn1150w-squashfs-sysupgrade.bin
```

其余 `-initramfs-`、`-kernel.bin` 可以不管。

## 三、用 Breed 刷入

1. 路由器断电，按住 reset 键上电，进入 Breed（`192.168.1.1`）
2. 点 **固件更新**
3. 固件文件选择上面那个 `...-squashfs-sysupgrade.bin`
4. **闪存布局必须选「公版 (0x50000)」**
5. 点「上传」→ 确认「更新」
6. 等待自动重启（约 1–2 分钟），浏览器打开 `192.168.1.1`

首次启动后建议：系统 → 备份/刷机 → 执行一次「恢复到出厂设置」，确保 overlay 干净。

## 四、刷完先做这些验证

| 检查项 | 命令 / 方法 |
|---|---|
| 交换芯片起来了吗 | `dmesg \| grep -i mt7530` |
| 端口列表 | `ls /sys/class/net`，应看到 `lan1..lan6` + `br-lan` |
| 全部进桥了吗 | `brctl show`（或 `ip link show master br-lan`） |
| 逐口插线 | 8 个物理口逐个插，看 `ethtool lanX \| grep -i link` |

**重点确认**：外挂 RTL8367SB 的 3 个口（预期是 lan6 那一段）是否也能通。如果这 3 个口不通，说明级联不在 MT7530 port5 上，而是走 MT7621 的 gmac1，那就需要换第二版 DTS（改用 `rtl8365mb` DSA 驱动直接管 RTL8367SB）——告诉我结果，我改。

## 五、回滚（不会变砖）

`breed-backup/full.bin` 是完整 16MB 编程器固件备份：

1. 进 Breed → 固件更新
2. 选 `full.bin`，闪存布局选「公版 (0x50000)」
3. 刷回即是原厂固件

## 备选：不用 GitHub，本机 WSL2 编译（Gitee 源码）

已验证可用的国内链路：

| 资源 | 地址 | 状态 |
|---|---|---|
| OpenWrt 源码 | `https://gitee.com/mirrors/OpenWrt.git`（分支 `openwrt-24.10`，带 v24.10.x / v25.12.x 标签） | ✅ 正常 |
| feeds（packages/routing/telephony） | `https://git.openwrt.org/feed/*.git` | ✅ 可达 |
| LuCI | `https://git.openwrt.org/project/luci.git` | ✅ 可达 |
| 源码包 | `https://sources.openwrt.org/` | ✅ 可达 |

> Gitee 免费版**不提供 CI**（Gitee Go 需要企业版），所以它只能当"下载快的源码站"，编译还是得在本机跑。

### 1. 装 Ubuntu（必须装到 D 盘，C 盘只剩 27GB 不够）

管理员 PowerShell：

```powershell
wsl --install -d Ubuntu --location D:\WSL\Ubuntu
```

装完会要求设置 Linux 用户名和密码。然后确认：

```powershell
wsl -d Ubuntu -- uname -r
```

### 2. 一条命令开编

```powershell
wsl -d Ubuntu -- bash /mnt/d/openwrt/openwrt-build/wsl-build.sh
```

16 线程大约 40–70 分钟，产物自动拷到 `D:\openwrt\out\`。

脚本做的事：apt 装依赖 → gitee 克隆 `openwrt-24.10` → 拷 DTS / 追加机型 → `feeds update/install` → `make defconfig` → `make download` → `make -j16`。

如果中途断了，重跑同一个命令即可接着编（脚本对 clone 和机型注入都做了幂等处理）。

## 六、当前已知的不确定项

- MT7530 port5 是否就是 RTL 的级联口（最有可能，但未 100% 验证）
- GPIO7 复位极性（已按厂商序列推断为低电平工作，若 lan6 不通可改 `gpio-export,output = <1>`）
- 面板 8 个口与 lan1..lan6 的对应关系（刷完插线即可确认，不影响功能）
- LED 未配置（厂商 LED 定义与 GPIO 尚未确认，先不写避免冲突）
