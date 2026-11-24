# 把本地编译配置推送到 GitHub 仓库
# 用法（在 D:\openwrt\openwrt-build 下）：
#   powershell -ExecutionPolicy Bypass -File .\push-to-github.ps1
# 如果仓库是私有的，第一次推送会弹窗让你登录 / 或需要先把 SSH key 加到 GitHub

$ErrorActionPreference = "Stop"
$repo = "https://github.com/ZhangWenLu2026/MT7621.git"
$branch = "main"

Set-Location $PSScriptRoot

if (-not (Test-Path ".git")) {
    git init
}
git branch -M $branch

$remotes = git remote
if ($remotes -contains "origin") {
    git remote set-url origin $repo
} else {
    git remote add origin $repo
}

git add -A
$status = git status --porcelain
if ($status) {
    git -c user.name="ZhangWenLu2026" -c user.email="ZhangWenLu2026@users.noreply.github.com" commit -m "add RN1150W OpenWrt 24.10 build config"
} else {
    Write-Host "没有新的改动需要提交"
}

# 远端若已有初始提交（比如网页上建 README），先合并再推
git fetch origin $branch 2>$null
if ($LASTEXITCODE -eq 0) {
    git pull --rebase --allow-unrelated-histories origin $branch 2>$null
}

git push -u origin $branch
Write-Host "完成：https://github.com/ZhangWenLu2026/MT7621"
