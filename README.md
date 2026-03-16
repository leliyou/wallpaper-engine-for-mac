# Wallpaper Engine Prototype

[中文](./README.md) | [English](./README.en.md)

macOS 动态壁纸原型（Apple Silicon）。

## 1. 环境要求

- 芯片: Apple Silicon（M1 / M2 / M3 / M4）
- 系统: macOS 13+（当前项目最低支持 `macOS 12.0`，但建议 13+ 开发）
- 工具: Xcode + Command Line Tools

## 2. Xcode 版本选择与下载（macOS 13 专用）

> 截至 `2026-03-16`，`macOS 13 (Ventura)` 推荐使用 `Xcode 14.3.1` 或 `Xcode 15.2`。

### 2.1 兼容版本（Ventura 13）

- `Xcode 14.3.1`：支持 macOS Ventura 13.x
- `Xcode 15.0.x / 15.1 / 15.2`：要求 macOS 13.5+
- `Xcode 15.3+`：要求 macOS 14+（Ventura 不能装）
- `Xcode 16+`：要求 macOS 14.5+（Ventura 不能装）

### 2.2 官方下载入口

- App Store（最新 Xcode）：https://apps.apple.com/us/app/xcode/id497799835?mt=12
- Apple Developer 历史版本下载页（可下 Xcode 14/15 指定版本）：https://developer.apple.com/download/all/?q=xcode
- 官方兼容表（先看再下）：https://developer.apple.com/cn/xcode/system-requirements/

### 2.3 安装后初始化（必须）

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -version
swift --version
```

## 3. 本地运行

```bash
swift run
```

## 4. 打包流程（从源码到可分发）

### 4.1 打包 `.app`

```bash
zsh scripts/package_app.sh
open dist/"Wallpaper Prototype.app"
```

### 4.2 打包 `.dmg`

```bash
zsh scripts/package_dmg.sh
open dist/Wallpaper-Prototype-macOS.dmg
```

### 4.3 正式发布构建（Developer ID + Notarization）

```bash
export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="your-notary-profile"
zsh scripts/release_app.sh
```

## 5. 在 GitHub Tag Release 上传安装包

你可以上传这些产物到 Release Assets:

- `dist/Wallpaper-Prototype-macOS.dmg`
- `dist/Wallpaper-Prototype-macOS.zip`

### 5.1 Web 页面操作（最直观）

1. 先打包出 `.dmg` / `.zip`。
2. 在 GitHub 打开仓库 `Releases` -> `Draft a new release`。
3. 填写 tag（例如 `v0.1.0`）和标题。
4. 在 `Attach binaries` 区域把 `dist/` 下文件拖进去。
5. 在说明里写更新内容，点击 `Publish release`。

推荐说明模板：

```markdown
## 更新内容
- 新增/修复：...

## 安装
1. 下载 `Wallpaper-Prototype-macOS.dmg`
2. 打开后拖拽到 Applications
3. 首次打开若被拦截，在系统设置中允许

## 已知问题
- ...
```

### 5.2 命令行操作（`gh`）

```bash
# 首次登录
gh auth login

# 创建并发布 release，同时上传安装包
gh release create v0.1.0 \
  dist/Wallpaper-Prototype-macOS.dmg \
  dist/Wallpaper-Prototype-macOS.zip \
  --title "v0.1.0" \
  --notes "First public preview release"
```

如果 tag 已存在，只上传/补传资产：

```bash
gh release upload v0.1.0 dist/Wallpaper-Prototype-macOS.dmg dist/Wallpaper-Prototype-macOS.zip --clobber
```

## 6. 主页 README 语言切换说明

- GitHub 仓库首页默认只显示根目录的 `README.md`。
- 不能做“真正的自动切换”多语言首页。
- 常见做法是像本仓库这样在顶部放语言链接：
  - 中文：`README.md`
  - 英文：`README.en.md`

## 7. 仓库结构

```text
Sources/     app source code
Resources/   app resources
Packaging/   app bundle metadata and entitlements
scripts/     packaging and release scripts
docs/        project notes and handoff docs
```

## 8. 上传到 GitHub

如果当前目录还不是 Git 仓库：

```bash
git init
git add .
git commit -m "chore: initialize repository"
git branch -M main
git remote add origin <your-github-repo-url>
git push -u origin main
```

如果已经是 Git 仓库：

```bash
git add .
git commit -m "docs: update readme and release guide"
git push
```
