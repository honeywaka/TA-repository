# Git 基建收口｜Day 4 笔记：1.9 命令行基础 + PowerShell 自动化

> 日期：2026-10-01  
> 任务：编写 `Tools/quick-push.ps1`，一键完成 LFS 检查 + add + commit(带时间戳) + push  
> 状态：✅ 完成并验证

---

## 今日任务概览

| # | 任务 | 状态 | 产出物 |
|---|---|---|---|
| 1 | 1.4 分支与 PR（本地 --no-ff） | ✅ | git-homework 仓库验证通过 |
| 2 | 1.4 分支与 PR（GitHub PR 网页流程） | ⏳ 待补 | 需在 TA-repository 走完整 PR |
| 3 | **1.9 命令行基础** | ✅ | `Tools/quick-push.ps1` + GitHub 验证 |

---

## 1. 为什么学命令行脚本？

UE 技术美术的工作流里，**重复操作必须自动化**：

- 每天提交学习笔记 → 一键 push
- 检查 LFS 状态 → 防止大文件误传
- 批量重命名 / 批量导出贴图 → Python/PowerShell 脚本
- CI/CD 构建 → 全是命令行

> **原则**：如果一件事你会做第二次，就该考虑写成脚本。

---

## 2. PowerShell 脚本基础（Windows 必备）

### 2.1 执行策略（第一次写脚本必踩的坑）

PowerShell 默认禁止执行 `.ps1` 脚本！如果运行时报错：
```
无法加载文件 xxx.ps1，因为在此系统上禁止运行脚本。
```

**解决**（以管理员身份运行 PowerShell）：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

- `RemoteSigned`：本地脚本可运行，从网络下载的需签名
- `CurrentUser`：只改当前用户，不影响系统安全

### 2.2 UTF-8 编码陷阱（本次最大踩坑点）

**问题**：`notepad` 保存默认是 ANSI(GBK)，PowerShell 读 UTF-8 文件时中文乱码。

**验证截图**：见 `Docs/labs/quickpush-encoding-bug.png` —— 脚本初次运行时中文全部变成乱码/火星文。

![脚本中文乱码踩坑](quickpush-encoding-bug.png)

**正确做法**：用 `Out-File -Encoding UTF8` 写入（**方法 B：PowerShell 直接重写**，不依赖 VSCode）：
```powershell
$scriptContent | Out-File -FilePath "Tools\quick-push.ps1" -Encoding UTF8
```

**验证截图**：见 `Docs/labs/quickpush-github-verify.png` 和 `Docs/labs/quickpush-utf8-write.png` —— GitHub 网页和 PowerShell 中中文均正常显示。

![GitHub 网页确认脚本中文正常](quickpush-github-verify.png)

![PowerShell 中 UTF-8 写入过程](quickpush-utf8-write.png)

### 2.3 错误处理：`$ErrorActionPreference = "Stop"`

PowerShell 默认遇到错误会继续执行（不像 Bash 遇到错误就停），这对自动化脚本是灾难。

```powershell
$ErrorActionPreference = "Stop"  # 任何错误立即停止并抛出异常
```

配合 `try/catch`：
```powershell
try {
    $null = git rev-parse --git-dir 2>$null
} catch {
    Write-Host "当前目录不是 Git 仓库！" -ForegroundColor Red
    exit 1
}
```

### 2.4 检查上一条命令是否成功：`$LASTEXITCODE`

外部程序（如 `git`）的退出码存储在 `$LASTEXITCODE`：
```powershell
git add .
if ($LASTEXITCODE -ne 0) { throw "git add 失败" }
```

| 退出码 | 含义 |
|---|---|
| `0` | 成功 |
| `非0` | 失败（具体值因程序而异） |

---

## 3. quick-push.ps1 完整代码与逐行拆解

```powershell
# quick-push.ps1 —— 一键提交并推送（带 LFS 检查）
# 用法：在仓库根目录执行  .\Tools\quick-push.ps1

# 0. 强制停止在出错时
$ErrorActionPreference = "Stop"

# 1. 检查是否在 Git 仓库内
try {
    $null = git rev-parse --git-dir 2>$null
} catch {
    Write-Host "当前目录不是 Git 仓库！请 cd 到仓库根目录再执行。" -ForegroundColor Red
    exit 1
}

# 2. 检查 Git LFS 是否安装
$lfsVersion = git lfs version 2>$null
if ($lfsVersion) {
    Write-Host "Git LFS 已安装: $lfsVersion" -ForegroundColor Green
} else {
    Write-Host "Git LFS 未安装或不在 PATH 中！" -ForegroundColor Yellow
    Write-Host "请先运行: git lfs install" -ForegroundColor Yellow
}

# 3. 获取当前时间戳（中国格式）
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 4. 检查是否有变更要提交
$status = git status --short
if (-not $status) {
    Write-Host "工作区干净，没有变更需要提交。" -ForegroundColor Cyan
    exit 0
}

# 5. 一键三连：add → commit → push
Write-Host "开始一键提交（时间戳: $timestamp）..." -ForegroundColor Cyan

git add .
if ($LASTEXITCODE -ne 0) { throw "git add 失败" }

git commit -m "auto: $timestamp"
if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }

git push
if ($LASTEXITCODE -ne 0) { throw "git push 失败" }

Write-Host "一键推送成功！" -ForegroundColor Green
```

### 逐行解析

| 行 | 代码 | 作用 | 面试/实操考点 |
|---|---|---|---|
| 5 | `$ErrorActionPreference = "Stop"` | 严格模式，出错即停 | PowerShell 默认宽容，必须显式设置 |
| 8-13 | `try/catch` + `git rev-parse` | 防错定位：不在仓库内就退出 | `--git-dir` 返回 `.git` 目录路径；`2>$null` 吞掉错误输出 |
| 16 | `git lfs version` | 检查 LFS 安装状态 | 阶段 0 硬性要求 |
| 23 | `Get-Date -Format "..."` | 生成标准化时间戳 | `"yyyy-MM-dd HH:mm:ss"` 是中国常用格式 |
| 27 | `git status --short` | 极简状态输出 | 有变更时输出如 `M README.md`；无变更时输出空字符串 |
| 28 | `if (-not $status)` | 判断字符串是否为空 | PowerShell 里 `-not` 对空字符串返回 `$true` |
| 35-40 | `$LASTEXITCODE -ne 0` | 检查 Git 命令成败 | `ne` = not equal；这是链接外部命令的桥梁 |
| 37 | `git commit -m "auto: $timestamp"` | 带时间戳的自动提交 | 以后一眼看出是脚本自动提交还是人工提交 |

---

## 4. 执行过程实录

### 4.1 脚本写入（UTF-8 编码）

```powershell
$scriptContent = @'
# ... 脚本内容 ...
'@
$scriptContent | Out-File -FilePath "Tools\quick-push.ps1" -Encoding UTF8
```

**验证截图**：`Docs/labs/quickpush-utf8-write.png` —— PowerShell 中逐行输入 `$scriptContent`，中文显示正常，无乱码。

![PowerShell here-string 写入脚本](quickpush-utf8-write.png)

### 4.2 修复网络问题后重新 push

初次 push 遇到 `Recv failure: Connection was reset`（见 `Docs/labs/quickpush-encoding-bug.png`），这是 GitHub 网络波动，**非脚本问题**。

**解决**：直接重试 `git push`。

```powershell
git push
# Enumerating objects: 6, done.
# Writing objects: 100% (4/4), 1.14 KiB/s, done.
# To https://github.com/honeywaka/TA-repository.git
#   be1517e..300f9b2  main -> main
```

### 4.3 脚本自举验证（最爽的一刻）

修改脚本后，用脚本自己提交自己：

```powershell
.\Tools\quick-push.ps1
# Git LFS 已安装                                ← 绿色
# 开始一键提交（时间戳: 2026-10-01 17:11:45）...  ← 青色
# [main 7ab45e9] auto: 2026-10-01 17:11:45
# 1 file changed, 13 insertions(+), 15 deletions(-)
# Writing objects: 100% (4/4), 553 bytes, done.
# To https://github.com/honeywaka/TA-repository.git
#   300f9b2..7ab45e9  main -> main
# 一键推送成功！                                 ← 绿色
```

**验证截图**：`Docs/labs/quickpush-success.png` —— 完整执行输出，中文彩色显示正常，commit `7ab45e9` 推送成功。

![quick-push.ps1 一键推送成功](quickpush-success.png)

### 4.4 GitHub 网页确认

打开 `https://github.com/honeywaka/TA-repository/blob/main/Tools/quick-push.ps1`

**验证截图**：`Docs/labs/quickpush-github-verify.png` —— 显示 46 lines (36 loc)，中文注释、错误提示全部正常渲染，commit `300f9b2`（后更新为 `7ab45e9`）。

![GitHub 网页查看 quick-push.ps1](quickpush-github-verify.png)

---

## 5. 踩坑记录（血泪教训）

| 坑 | 现象 | 根因 | 解决 |
|---|---|---|---|
| **中文乱码** | 脚本里中文变成 `澹辫触` 等火星文 | `notepad` 默认 ANSI 编码保存 | 改用 `Out-File -Encoding UTF8` 写入 |
| **网络重置** | `Recv failure: Connection was reset` | GitHub HTTPS 连接被重置 | 重试 `git push`，第二次通常成功 |
| **工作区干净** | 脚本提示"没有变更"就退出 | `git status --short` 为空字符串时 `-not $status` 为真 | 这是预期行为！故意改个文件再跑 |
| **换行符警告** | `LF will be replaced by CRLF` | Windows Git 默认自动转换换行符 | 正常现象，无需处理 |

---

## 6. 扩展：为什么不用 Bash 而用 PowerShell？

| 场景 | 推荐 | 理由 |
|---|---|---|
| Windows 本地自动化 | **PowerShell** | 原生支持，不需要 WSL/Git Bash |
| 跨平台 CI/CD | Bash / Python | 兼容 Linux 服务器 |
| 复杂逻辑（条件/循环/数组） | Python | 语法更简洁，维护成本低 |
| UE 编辑器内调用 | Python (UE Python Scripting) | UE 内置 Python 插件 |

> 结论：Windows 桌面环境下，`.ps1` 是最顺手的自动化入口。等你进入阶段 1 学 Python 后，复杂脚本再用 Python 重写。

---

## 7. 产出物检查清单

- [x] `Tools/` 目录存在
- [x] `Tools/quick-push.ps1` 脚本可执行
- [x] 脚本内中文正常显示（UTF-8 编码）
- [x] LFS 检查功能正常
- [x] 一键 add + commit(带时间戳) + push 跑通
- [x] GitHub 网页能看到脚本文件和自动提交记录
- [x] 截图归档到 `Docs/labs/`（`quickpush-encoding-bug.png` 乱码踩坑、`quickpush-github-verify.png` GitHub 确认、`quickpush-utf8-write.png` UTF-8 写入、`quickpush-success.png` 一键成功、`pr-repo-yellow-banner.png` PR 黄条）

---

## 8. PR 工作流进度（已完成 ✅）

**1.4 分支与 PR —— GitHub PR 网页流程全部走完！**

已完成：
1. ✅ `git switch -c feature/pr-test`
2. ✅ 改 README.md → commit → `git push -u origin feature/pr-test`
3. ✅ GitHub 出现黄条 `Compare & pull request`（截图：`Docs/labs/pr-repo-yellow-banner.png`）
4. ✅ 点击 **Compare & pull request** → 填 Title `test: PR workflow test` → **Create pull request**（截图：`Docs/labs/pr-create.png`）
5. ✅ **Merge pull request** → 选 **Create a merge commit** → **Confirm merge**（截图：`Docs/labs/pr-merged.png`）
6. ✅ **Delete branch** 删除远程 `feature/pr-test`
7. ✅ 本地：`git switch main` → `git pull origin main` → `git branch -d feature/pr-test`（截图：`Docs/labs/pr-gitlog.png`）

**Merge 方式确认**：选的是 **Create a merge commit**（对应 `--no-ff`），commit `b8eb5c6`，log 显示：

```
b8eb5c6 (HEAD -> main, origin/main) Merge pull request #1 from honeywaka/feature/pr-test
|\  
| * b1bce6f docs: pr workflow test
|/  
* 490b54f feat: add quick-push.ps1 for one-click commit
```

**截图归档**：
- `Docs/labs/pr-create.png` —— PR #1 创建页面（Open 状态）
- `Docs/labs/pr-merged.png` —— 合并后紫色 Merged 标签 + "Pull request successfully merged"
- `Docs/labs/pr-gitlog.png` —— 本地 `git log --graph --oneline` 显示 merge commit 和分支图

---

## 9. 阶段 0 进度更新

| 阶段 0 任务 | 状态 |
|---|---|
| 1.10 UE5 环境与版本 | ✅ |
| 1.11 Git 基础（6 节笔记） | ✅ |
| 1.12 Git LFS | ✅ |
| 1.13 .gitignore | ✅ |
| 1.14 资产命名规范 | ✅ |
| 1.15 文档模板 | ✅ |
| **1.4 分支与 PR** | ✅ **全部完成** |
| **1.9 命令行基础** | ✅ **已完成** |
| 2.1 Python OOP | 待开始 |

**阶段 0 基建收口：9/9 完成！** 🎉 全部搞定！

---

> **今日金句**：写脚本的第一步不是"写代码"，而是"把手动操作重复三次，确认步骤稳定后再自动化"。你这次遇到的编码坑、网络坑，都是真实工作流的一部分——记下来，下次遇到同样的报错你就知道是 UTF-8 还是 GitHub 抽风了。💪

---

> **今日金句**：写脚本的第一步不是"写代码"，而是"把手动操作重复三次，确认步骤稳定后再自动化"。你这次遇到的编码坑、网络坑，都是真实工作流的一部分——记下来，下次遇到同样的报错你就知道是 UTF-8 还是 GitHub 抽风了。💪
