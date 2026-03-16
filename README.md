# Wallpaper Engine Prototype

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

## 3. 项目能力范围（Scope）

- 单屏桌面层视频播放原型
- 本地 `.mp4` / `.mov` 选择
- SwiftUI 最小控制面板 + 循环播放
- AppKit 桌面窗口 + AVFoundation 播放管线
- 持久化上次视频和播放模式
- 启动时可自动应用上次视频
- 显示器目标选择与桌面窗口诊断
- 内置事件日志（播放/显示器/窗口状态变化）
- 多视频列表、顺序/随机播放
- 菜单栏控制、登录启动开关
- 检测全屏应用时自动暂停/恢复（可选）

## 4. 本地运行

```bash
swift run
```

## 5. 打包流程（从源码到可分发）

### 5.1 打包 `.app`

```bash
zsh scripts/package_app.sh
open dist/"Wallpaper Prototype.app"
```

脚本会：

- 构建 release 二进制
- 生成 `dist/Wallpaper Prototype.app`
- 执行本地 ad-hoc 签名
- 导出 `dist/Wallpaper-Prototype-macOS.zip`

### 5.2 打包 `.dmg`

```bash
zsh scripts/package_dmg.sh
open dist/Wallpaper-Prototype-macOS.dmg
```

DMG 内容：

- `Wallpaper Prototype.app`
- `Applications` 快捷方式（拖拽安装）

### 5.3 正式发布构建（Developer ID + Notarization）

```bash
export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="your-notary-profile"
zsh scripts/release_app.sh
```

可选（跳过公证）：

```bash
SKIP_NOTARIZATION=1 zsh scripts/release_app.sh
```

首次可先保存 notary 凭据：

```bash
xcrun notarytool store-credentials "your-notary-profile" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

## 6. 常见问题

- `xcodebuild: error: SDK ... cannot be located`
  - 多半是 `xcode-select` 没指到正确的 `/Applications/Xcode.app`。
- `swift --version` 不是预期版本
  - 重新执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
- 打包后应用打不开
  - 先在本机右键打开；对外分发请用 `scripts/release_app.sh` 做 Developer ID 签名与公证。

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
git commit -m "docs: update setup and packaging guide"
git push
```

## 9. 当前约束

- 当前以 Swift Package 原型形式交付，不是 `.xcodeproj` 工程。
- 桌面层窗口行为仍依赖目标机器和 macOS 版本实测。
- `package_app.sh` 产物是本地 ad-hoc 签名，不等同于正式分发签名。
