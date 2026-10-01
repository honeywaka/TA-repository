# quick-push.ps1 —— 一键提交并推送（带 LFS 检查）
# 用法：在仓库根目录执行  .\Tools\quick-push.ps1

$ErrorActionPreference = "Stop"

# 检查是否在 Git 仓库内
try {
    $null = git rev-parse --git-dir 2>$null
} catch {
    Write-Host "当前目录不是 Git 仓库！请 cd 到仓库根目录再执行。" -ForegroundColor Red
    exit 1
}

# 检查 Git LFS 是否安装
$lfsVersion = git lfs version 2>$null
if ($lfsVersion) {
    Write-Host "Git LFS 已安装" -ForegroundColor Green
} else {
    Write-Host "Git LFS 未安装！" -ForegroundColor Yellow
}

# 获取时间戳
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 检查是否有变更
$status = git status --short
if (-not $status) {
    Write-Host "工作区干净，没有变更需要提交。" -ForegroundColor Cyan
    exit 0
}

# 一键三连
Write-Host "开始一键提交（时间戳: $timestamp）..." -ForegroundColor Cyan

git add .
if ($LASTEXITCODE -ne 0) { throw "git add 失败" }

git commit -m "auto: $timestamp"
if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }

git push
if ($LASTEXITCODE -ne 0) { throw "git push 失败" }

Write-Host "一键推送成功！" -ForegroundColor Green
