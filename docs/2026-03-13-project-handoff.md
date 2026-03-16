# Wallpaper Engine Prototype 交接文档（2026-03-13）

## 1. 项目目标与当前状态
- 目标：在 macOS（Apple Silicon，兼容 macOS 12+）实现可加载本地视频的动态壁纸原型。
- 当前状态：可本地运行、可打包为 `.app/.zip/.dmg`，核心功能可用，已完成多轮多显示器与全屏交互问题修复。

## 2. 环境与基础约束
- 代码形态：`Swift Package`（非 `.xcodeproj`）。
- 主要技术栈：`SwiftUI + AppKit + AVFoundation + ServiceManagement`。
- 最低系统版本：`macOS 12.0`。
- 关键目录：
  - 源码：`Sources/WallpaperPrototypeApp`
  - 打包配置：`Packaging`
  - 脚本：`scripts`
  - 产物：`dist`

## 3. 运行与打包
- 开发运行：
  - `swift run`
- 编译检查：
  - `swift build`
- 本地 App 打包：
  - `zsh scripts/package_app.sh`
  - 产物：`dist/Wallpaper Prototype.app`、`dist/Wallpaper-Prototype-macOS.zip`
- DMG 打包：
  - `zsh scripts/package_dmg.sh`
  - 产物：`dist/Wallpaper-Prototype-macOS.dmg`
- 发布脚手架（签名/公证）：
  - `zsh scripts/release_app.sh`

## 4. 功能范围（已落地）
- 本地视频导入（`.mp4/.mov`）。
- 播放列表：
  - 顺序/随机轮播
  - 上一个/下一个
  - 多选删除、全部移除、上移/下移
  - 持久化恢复
- 桌面应用：
  - 单显示器或所有显示器同播
  - 窗口层级策略切换
- 菜单栏：
  - 打开主窗口、应用、停止、上一项、下一项、退出
- 其他控制：
  - 选择后自动应用
  - 静音（设置开关 + 顶部“静音/取消静音”按钮）
  - 开机自启开关
  - 诊断刷新与事件日志
- 中文化：
  - 主窗口、菜单栏、状态与错误文案已中文化

## 5. 多显示器/全屏相关修复结论
- 已修问题（核心）：
  - 点击任意窗口触发重播：已去掉 `frontmost-app` 的无条件重挂。
  - 全屏 Space 切换触发重播：已去掉 `active-space` 的无条件重挂。
  - 一块屏全屏影响另一块屏：在“应用到所有显示器”模式下，禁用全局全屏自动暂停逻辑。
- 当前恢复策略：
  - 仅在“目标桌面窗口数量不足（确实丢窗口）”时自动恢复重挂。
  - 普通窗口焦点切换、全屏程序来回切换不应导致另一屏从头播放。

## 6. 核心代码位置（接手优先读）
- 应用入口与菜单栏：
  - `Sources/WallpaperPrototypeApp/AppMain.swift`
- 主 UI：
  - `Sources/WallpaperPrototypeApp/ContentView.swift`
- 业务中枢（状态、恢复逻辑、播放控制协调）：
  - `Sources/WallpaperPrototypeApp/WallpaperCoordinator.swift`
- 桌面窗口管理：
  - `Sources/WallpaperPrototypeApp/DesktopWindowManager.swift`
- 视频播放控制：
  - `Sources/WallpaperPrototypeApp/VideoPlaybackController.swift`
- 偏好持久化：
  - `Sources/WallpaperPrototypeApp/PrototypePreferencesStore.swift`

## 7. 里程碑摘要（按时间）
- 12:44：设计文档 + SwiftPM 骨架
- 12:54：基础状态持久化与播放模式
- 15:48~16:28：自动应用、显示器诊断、事件日志、播放列表、菜单栏、全屏暂停
- 16:34~16:58：`.app/.zip/.dmg` 打包与发布脚手架
- 16:52：最低版本下放至 macOS 12，菜单栏/窗口重开兼容化
- 17:05：界面中文化
- 17:17：选后自动应用、静音持久化、多选删除、按钮可用性修正
- 17:24~17:41：多显示器恢复策略多轮收敛，消除无谓重挂导致的黑闪重播

## 8. 收尾阶段编译验证（已补录）
- 验证命令：
  - `swift build`
  - `zsh scripts/package_app.sh`（在需要交付新 app 时）
- 收尾相关修复均已单独通过 `swift build`：
  - 去除 `frontmost-app` 无条件重挂
  - 去除 `active-space` 无条件重挂
  - 多屏同播下禁用全局全屏自动暂停
  - 恢复条件收紧为”仅在目标桌面窗口确实缺失时触发”
  - 新增 `ensureWindowsVisible()` 方法确保 Space 切换后窗口正确显示
  - 新增 `isWindowVisibleOnCurrentSpace()` 检查每个显示器窗口是否在当前 Space 可见
- 最近交付产物仍位于：
  - `dist/Wallpaper Prototype.app`
  - `dist/Wallpaper-Prototype-macOS.zip`

## 8.1 扩展显示器 Space 切换后黑屏修复（2026-03-13 补充）
- 问题现象：扩展显示器切换 Space 后切回来，屏幕变黑无视频
- 根因分析：
  1. 窗口设置了 `.canJoinAllSpaces` 但切换后可能不在正确的层级
  2. 恢复逻辑只检查窗口数量，未检查每个窗口是否真的在当前 Space 可见
  3. 窗口可能"可见"但图层丢失导致黑屏
  4. **关键发现**：窗口 frame 被 macOS 重置为很小的尺寸（如顶部一个小条）
  5. 多屏模式下缺少定期检查窗口状态的机制
  6. **最新发现**：窗口可能被移到错误位置（如屏幕上方），只露出底部一点
  7. **最终发现**：窗口和 frame 都正确，但 AVPlayerLayer 在 Space 切换后停止渲染
- 修复内容：
  1. `recoverDesktopPlaybackIfNeeded()`: active-space 时直接重新应用视频
  2. `getWindowStatusSummary()`: 显示子图层信息
  3. `forceRefreshLayerFrames()`: 强制设置所有子图层的 frame 和 bounds
  4. `getDetailedWindowStatus()`: 新增详细诊断方法
  5. Space 变化防抖间隔从 0.1 秒改为 0.2 秒

## 8.2 已知问题与待解决
- "前台出现全屏应用时暂停"选项在多屏模式下行为不明确：
  - 当前逻辑：开启 `applyToAllDisplays` 时完全跳过全屏暂停
  - 用户期望可能是：每个显示器独立控制，扩展屏全屏不影响主屏
  - 待重构：需要更精细的每显示器独立控制逻辑

## 9. 已知边界与风险
- 当前是原型结构（SwiftPM），后续若走正式发行建议转 `Xcode Project` 管理签名与能力配置。
- 多显示器与 Mission Control/Space 相关行为依赖系统窗口服务器，建议在不同机型和系统小版本继续实机回归。
- 当前恢复策略已“保守化”（只在缺窗口时恢复），若未来发现“有窗口但图层丢失”的极端机型问题，需要补“图层健康检查”。

## 10. 建议后续任务（给下一位成员）
1. 加一套“播放不中断”回归清单并脚本化（多屏、全屏、Space、焦点切换）。
2. 增加“恢复原因”可视化（日志分级/统计），方便现场定位。
3. 完成 Developer ID 签名与 notarization 的正式发布流程。
4. 评估是否拆分为模块化结构（窗口管理/播放/偏好/诊断），降低后续维护成本。

## 11. 变更追踪
- 详细变更记录见：`.golutra/agents/history.md`
- 初始设计文档见：`docs/plans/2026-03-13-wallpaper-prototype-design.md`
