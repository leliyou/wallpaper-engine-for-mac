import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var coordinator: WallpaperCoordinator
    @AppStorage("prototype.uiTheme") private var selectedThemeRawValue = UITheme.cyberConsole.rawValue
    @AppStorage("prototype.ui.dynamicEffectsEnabled") private var isDynamicEffectsEnabled = false
    @State private var isImporterPresented = false
    @State private var selectedPlaylistIndexes: Set<Int> = []

    private var theme: UITheme {
        UITheme(rawValue: selectedThemeRawValue) ?? .cyberConsole
    }

    var body: some View {
        ZStack {
            theme.background(isDynamicEffectsEnabled: isDynamicEffectsEnabled)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerPanel
                    quickActionPanel
                    controlGrid
                    statusAndPlaylistGrid
                    logPanel
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .tint(theme.palette.tint)
        .animation(.easeInOut(duration: 0.35), value: selectedThemeRawValue)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.mpeg4Movie, .movie],
            allowsMultipleSelection: true
        ) { result in
            coordinator.handleImporterResult(result)
        }
    }

    private var headerPanel: some View {
        ThemedPanel(theme: theme, isDynamicEffectsEnabled: isDynamicEffectsEnabled) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(theme.kicker)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.palette.kickerText)

                        Text(theme.heroTitle)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(theme.heroGradient)
                            .shadow(color: theme.palette.glowPrimary.opacity(0.32), radius: 14)

                        Text(theme.heroSubtitle)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.palette.secondaryText)

                        headerTelemetryStrip
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        statusChip("播放状态", coordinator.playbackState.description, accent: theme.palette.accent)
                        statusChip("当前序列", coordinator.playlistSummaryText, accent: theme.palette.secondaryAccent)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    infoTile(
                        title: "当前视频",
                        value: coordinator.currentVideoURL?.lastPathComponent ?? "未选择",
                        accent: theme.palette.accent
                    )
                    infoTile(
                        title: "目标显示器",
                        value: coordinator.applyToAllDisplays
                            ? "所有显示器"
                            : (coordinator.availableDisplays.first(where: { $0.id == coordinator.selectedDisplayID })?.name ?? "未指定"),
                        accent: theme.palette.secondaryAccent
                    )
                    infoTile(
                        title: "窗口层级",
                        value: coordinator.windowLayerStrategy.title,
                        accent: theme.palette.warning
                    )
                }

                HStack(alignment: .center, spacing: 12) {
                    panelCaption("主题矩阵")

                    Picker("主题", selection: $selectedThemeRawValue) {
                        ForEach(UITheme.allCases) { item in
                            Text(item.shortTitle).tag(item.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    Spacer()

                    Text(theme.themeDescription)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.palette.mutedText)
                }
            }
        }
    }

    private var headerTelemetryStrip: some View {
        HStack(spacing: 10) {
            telemetryPill("SYNC", accent: theme.palette.accent)
            telemetryPill("HUD", accent: theme.palette.secondaryAccent)
            telemetryPill("LIVE", accent: theme.palette.warning)
            Spacer()
            energyBars(isDynamicEffectsEnabled: isDynamicEffectsEnabled)
        }
    }

    private var quickActionPanel: some View {
        ThemedPanel(theme: theme, isDynamicEffectsEnabled: isDynamicEffectsEnabled) {
            VStack(alignment: .leading, spacing: 12) {
                panelCaption("主控动作")

                HStack(spacing: 12) {
                    Button("选择视频") {
                        isImporterPresented = true
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .primary))

                    Button("应用到桌面") {
                        coordinator.applySelectedVideo()
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .secondary))
                    .disabled(!coordinator.canApply)

                    Button("停止") {
                        coordinator.stopPlayback()
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .danger))
                    .disabled(!coordinator.isPlaying)

                    Button(coordinator.isMuted ? "取消静音" : "静音") {
                        coordinator.updateMuted(!coordinator.isMuted)
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .ghost))
                    .disabled(coordinator.playlist.isEmpty)

                    Spacer(minLength: 0)

                    Button("上一个") {
                        coordinator.playPreviousVideoManually()
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .ghost))
                    .disabled(coordinator.playlist.isEmpty)

                    Button("下一个") {
                        coordinator.playNextVideoManually()
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .ghost))
                    .disabled(coordinator.playlist.isEmpty)

                    Button("刷新诊断") {
                        coordinator.refreshDiagnosticsNow()
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .ghost))
                }
            }
        }
    }

    private var controlGrid: some View {
        HStack(alignment: .top, spacing: 18) {
            ThemedPanel(theme: theme, isDynamicEffectsEnabled: isDynamicEffectsEnabled) {
                VStack(alignment: .leading, spacing: 12) {
                    panelCaption("播放与显示")

                    Group {
                        labeledRow("当前路径") {
                            Text(coordinator.currentVideoURL?.path ?? "未选择文件")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.palette.primaryText)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }

                        labeledRow("列表模式") {
                            Picker("", selection: $coordinator.playlistMode) {
                                ForEach(PlaylistMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .onChange(of: coordinator.playlistMode) { mode in
                                coordinator.updatePlaylistMode(mode)
                            }
                        }

                        labeledRow("显示器") {
                            Picker("", selection: Binding(
                                get: { coordinator.selectedDisplayID ?? 0 },
                                set: { coordinator.updateSelectedDisplay($0) }
                            )) {
                                ForEach(coordinator.availableDisplays) { display in
                                    Text(display.summary).tag(display.id)
                                }
                            }
                            .labelsHidden()
                        }

                        labeledRow("播放模式") {
                            Picker("", selection: $coordinator.playbackStyle) {
                                ForEach(PlaybackStyle.allCases) { style in
                                    Text(style.title).tag(style)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .onChange(of: coordinator.playbackStyle) { style in
                                coordinator.updatePlaybackStyle(style)
                            }
                        }

                        labeledRow("窗口层级") {
                            Picker("", selection: $coordinator.windowLayerStrategy) {
                                ForEach(WindowLayerStrategy.allCases) { strategy in
                                    Text(strategy.title).tag(strategy)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: coordinator.windowLayerStrategy) { strategy in
                                coordinator.updateWindowLayerStrategy(strategy)
                            }
                        }
                    }
                }
            }

            ThemedPanel(theme: theme, isDynamicEffectsEnabled: isDynamicEffectsEnabled) {
                VStack(alignment: .leading, spacing: 12) {
                    panelCaption("开关矩阵")

                    themedToggle("启动时自动应用已保存视频", isOn: $coordinator.autoApplyOnLaunch) { value in
                        coordinator.updateAutoApplyOnLaunch(value)
                    }
                    themedToggle("静音播放", isOn: $coordinator.isMuted) { value in
                        coordinator.updateMuted(value)
                    }
                    themedToggle("应用到所有显示器", isOn: $coordinator.applyToAllDisplays) { value in
                        coordinator.updateApplyToAllDisplays(value)
                    }
                    themedToggle("开机自动启动", isOn: $coordinator.launchAtLoginEnabled) { value in
                        coordinator.updateLaunchAtLogin(value)
                    }
                    themedToggle("启用界面动态效果", isOn: $isDynamicEffectsEnabled) { _ in }

                    Spacer(minLength: 0)

                    Button("全部移除") {
                        coordinator.clearAllVideos()
                        selectedPlaylistIndexes.removeAll()
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .danger))
                    .disabled(coordinator.playlist.isEmpty)
                }
            }
        }
    }

    private var statusAndPlaylistGrid: some View {
        HStack(alignment: .top, spacing: 18) {
            ThemedPanel(theme: theme, isDynamicEffectsEnabled: isDynamicEffectsEnabled) {
                VStack(alignment: .leading, spacing: 12) {
                    panelCaption("状态总线")

                    monitorText(coordinator.playbackState.description)
                    monitorText(coordinator.playlistSummaryText)
                    monitorText(coordinator.windowDiagnostics)

                    if let launchAtLoginError = coordinator.launchAtLoginError {
                        monitorText(launchAtLoginError, tint: theme.palette.warning)
                    }

                    if let errorMessage = coordinator.errorMessage {
                        monitorText(errorMessage, tint: theme.palette.danger)
                    }
                }
            }

            ThemedPanel(theme: theme, isDynamicEffectsEnabled: isDynamicEffectsEnabled) {
                VStack(alignment: .leading, spacing: 12) {
                    panelCaption("播放列表总控")

                    HStack(spacing: 10) {
                        Button("删除选中") {
                            guard !selectedPlaylistIndexes.isEmpty else { return }
                            coordinator.removeVideos(at: Array(selectedPlaylistIndexes).sorted())
                            selectedPlaylistIndexes.removeAll()
                        }
                        .buttonStyle(ThemedButtonStyle(theme: theme, kind: .ghost))
                        .disabled(selectedPlaylistIndexes.isEmpty)

                        Button("全部移除") {
                            coordinator.clearAllVideos()
                            selectedPlaylistIndexes.removeAll()
                        }
                        .buttonStyle(ThemedButtonStyle(theme: theme, kind: .danger))
                        .disabled(coordinator.playlist.isEmpty)

                        Button("上移") {
                            guard let selectedIndex = selectedPlaylistIndexes.onlyElement else { return }
                            coordinator.moveVideoUp(at: selectedIndex)
                            selectedPlaylistIndexes = [max(selectedIndex - 1, 0)]
                        }
                        .buttonStyle(ThemedButtonStyle(theme: theme, kind: .ghost))
                        .disabled(selectedPlaylistIndexes.onlyElement == nil || selectedPlaylistIndexes.onlyElement == 0)

                        Button("下移") {
                            guard let selectedIndex = selectedPlaylistIndexes.onlyElement else { return }
                            coordinator.moveVideoDown(at: selectedIndex)
                            selectedPlaylistIndexes = [min(selectedIndex + 1, max(coordinator.playlist.count - 1, 0))]
                        }
                        .buttonStyle(ThemedButtonStyle(theme: theme, kind: .ghost))
                        .disabled(
                            selectedPlaylistIndexes.onlyElement == nil ||
                            selectedPlaylistIndexes.onlyElement == coordinator.playlist.count - 1
                        )
                    }

                    List(selection: $selectedPlaylistIndexes) {
                        ForEach(Array(coordinator.playlist.enumerated()), id: \.offset) { index, url in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(index == coordinator.currentVideoIndex ? theme.palette.accent : theme.palette.listDotIdle)
                                    .frame(width: 7, height: 7)
                                    .shadow(
                                        color: index == coordinator.currentVideoIndex ? theme.palette.accent.opacity(0.78) : .clear,
                                        radius: 4
                                    )

                                Text(String(format: "%02d", index + 1))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(theme.palette.listIndexText)

                                Text(url.lastPathComponent)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(theme.palette.primaryText)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(theme.palette.listRowBackground)
                            )
                            .tag(index)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                    .environment(\.colorScheme, .dark)
                    .frame(minHeight: 180, maxHeight: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.palette.listBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.palette.panelBorder.opacity(0.9), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var logPanel: some View {
        ThemedPanel(theme: theme, isDynamicEffectsEnabled: isDynamicEffectsEnabled) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    panelCaption("事件日志 / 机舱回放")
                    Spacer()
                    Button("复制全部日志") {
                        let allLogs = coordinator.eventLog.map { $0.summary }.joined(separator: "\n")
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(allLogs, forType: .string)
                    }
                    .buttonStyle(ThemedButtonStyle(theme: theme, kind: .ghost))
                    .disabled(coordinator.eventLog.isEmpty)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(coordinator.eventLog) { entry in
                            Text(entry.summary)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.palette.logText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(theme.palette.logBackground)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 140, maxHeight: 200)
            }
        }
    }

    private func panelCaption(_ text: String) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(theme.palette.accent)
                .frame(width: 18, height: 4)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(theme.palette.captionText)
        }
    }

    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.palette.labelText)
            content()
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.palette.controlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.palette.controlBorder, lineWidth: 1)
                )
        }
    }

    private func monitorText(_ text: String, tint: Color? = nil) -> some View {
        let resolvedTint = tint ?? theme.palette.accent

        return HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(resolvedTint.opacity(0.92))
                .frame(width: 3)
                .cornerRadius(99)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(theme.palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.palette.infoBackground)
        )
    }

    private func statusChip(_ title: String, _ value: String, accent: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.palette.labelText)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(theme.palette.statusBackground)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(accent.opacity(0.34), lineWidth: 1)
        )
    }

    private func infoTile(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.palette.labelText)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(theme.palette.primaryText)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.18),
                            theme.palette.tileBackgroundOverlay
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.30), lineWidth: 1)
        )
    }

    private func themedToggle(_ title: String, isOn: Binding<Bool>, action: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(theme.palette.primaryText)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.palette.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.palette.controlBorder, lineWidth: 1)
        )
        .onChange(of: isOn.wrappedValue) { newValue in
            action(newValue)
        }
    }
}

private enum UITheme: String, CaseIterable, Identifiable {
    case cyberConsole
    case deepSeaObservatory
    case sunsetCinema

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .cyberConsole:
            return "赛博控制台"
        case .deepSeaObservatory:
            return "深海观测站"
        case .sunsetCinema:
            return "日落放映厅"
        }
    }

    var kicker: String {
        switch self {
        case .cyberConsole:
            return "WALLPAPER ENGINE"
        case .deepSeaObservatory:
            return "ABYSSAL OBSERVATORY"
        case .sunsetCinema:
            return "SUNSET CINEMA"
        }
    }

    var heroTitle: String {
        switch self {
        case .cyberConsole:
            return "动态壁纸控制台"
        case .deepSeaObservatory:
            return "深海观测总站"
        case .sunsetCinema:
            return "壁纸放映厅"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .cyberConsole:
            return "本机视频 · 桌面层渲染 · 多显示器同步"
        case .deepSeaObservatory:
            return "冷蓝声呐 · 雾面玻璃 · 舱室仪表"
        case .sunsetCinema:
            return "落日映照 · 胶片暖光 · 放映机舱"
        }
    }

    var themeDescription: String {
        switch self {
        case .cyberConsole:
            return "霓虹 / 玻璃 / 扫描线 / 机舱感"
        case .deepSeaObservatory:
            return "冷蓝 / 雷达盘 / 海雾 / 深潜舱"
        case .sunsetCinema:
            return "橙红 / 胶片感 / 柔光 / 放映厅"
        }
    }

    var heroGradient: LinearGradient {
        switch self {
        case .cyberConsole:
            return LinearGradient(
                colors: [Color.white, palette.accent.opacity(0.94), palette.secondaryAccent],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .deepSeaObservatory:
            return LinearGradient(
                colors: [Color.white, Color(red: 0.66, green: 0.96, blue: 1.0), Color(red: 0.52, green: 0.86, blue: 0.98)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .sunsetCinema:
            return LinearGradient(
                colors: [Color.white, Color(red: 1.0, green: 0.78, blue: 0.58), Color(red: 1.0, green: 0.48, blue: 0.33)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    @ViewBuilder
    func background(isDynamicEffectsEnabled: Bool) -> some View {
        switch self {
        case .cyberConsole:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.06, blue: 0.12),
                        Color(red: 0.02, green: 0.03, blue: 0.08),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                animatedGlow(
                    primary: palette.glowPrimary.opacity(0.22),
                    secondary: palette.glowSecondary.opacity(0.12),
                    speed: 0.22,
                    isDynamicEffectsEnabled: isDynamicEffectsEnabled
                )

                scanlineOverlay(lineColor: palette.accent.opacity(0.05), isDynamicEffectsEnabled: isDynamicEffectsEnabled)
                cyberHUDOverlay(
                    accent: palette.accent,
                    secondary: palette.secondaryAccent,
                    isDynamicEffectsEnabled: isDynamicEffectsEnabled
                )
            }
        case .deepSeaObservatory:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.08, blue: 0.14),
                        Color(red: 0.02, green: 0.10, blue: 0.18),
                        Color(red: 0.01, green: 0.03, blue: 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                animatedGlow(
                    primary: palette.glowPrimary.opacity(0.24),
                    secondary: palette.glowSecondary.opacity(0.16),
                    speed: 0.14,
                    isDynamicEffectsEnabled: isDynamicEffectsEnabled
                )

                Circle()
                    .stroke(palette.secondaryAccent.opacity(0.15), lineWidth: 1)
                    .frame(width: 560, height: 560)

                Circle()
                    .stroke(palette.accent.opacity(0.12), lineWidth: 1)
                    .frame(width: 380, height: 380)

                radarSweep(accent: palette.accent, isDynamicEffectsEnabled: isDynamicEffectsEnabled)
                    .frame(width: 520, height: 520)

                sonarGridOverlay(accent: palette.secondaryAccent, isDynamicEffectsEnabled: isDynamicEffectsEnabled)
            }
        case .sunsetCinema:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.17, green: 0.05, blue: 0.06),
                        Color(red: 0.30, green: 0.09, blue: 0.08),
                        Color(red: 0.05, green: 0.02, blue: 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                animatedGlow(
                    primary: palette.glowPrimary.opacity(0.26),
                    secondary: palette.glowSecondary.opacity(0.18),
                    speed: 0.18,
                    isDynamicEffectsEnabled: isDynamicEffectsEnabled
                )

                projectorBeams(accent: palette.secondaryAccent, isDynamicEffectsEnabled: isDynamicEffectsEnabled)
                    .ignoresSafeArea()

                filmGrainOverlay(dotColor: Color.white.opacity(0.028), isDynamicEffectsEnabled: isDynamicEffectsEnabled)
                    .ignoresSafeArea()

                stageLightOverlay(
                    primary: palette.accent,
                    secondary: palette.secondaryAccent,
                    isDynamicEffectsEnabled: isDynamicEffectsEnabled
                )
            }
        }
    }

    var palette: ThemePalette {
        switch self {
        case .cyberConsole:
            return ThemePalette(
                tint: .cyan,
                accent: .cyan,
                secondaryAccent: Color(red: 0.34, green: 1.0, blue: 0.84),
                warning: Color(red: 1.0, green: 0.42, blue: 0.35),
                danger: Color(red: 1.0, green: 0.34, blue: 0.34),
                primaryText: Color.white.opacity(0.90),
                secondaryText: Color.white.opacity(0.74),
                mutedText: Color.white.opacity(0.52),
                labelText: Color.white.opacity(0.45),
                kickerText: Color.cyan.opacity(0.85),
                captionText: Color.cyan.opacity(0.92),
                panelFillTop: Color.white.opacity(0.08),
                panelFillMiddle: Color.white.opacity(0.03),
                panelFillBottom: Color.black.opacity(0.18),
                panelBorder: Color.cyan.opacity(0.22),
                panelInnerBorder: Color.white.opacity(0.06),
                panelShadow: Color.cyan.opacity(0.14),
                panelBackdrop: Color.black.opacity(0.24),
                controlBackground: Color.white.opacity(0.05),
                controlBorder: Color.cyan.opacity(0.10),
                infoBackground: Color.black.opacity(0.22),
                statusBackground: Color.black.opacity(0.28),
                tileBackgroundOverlay: Color.white.opacity(0.03),
                listBackground: Color.black.opacity(0.72),
                listRowBackground: Color.black.opacity(0.72),
                listDotIdle: Color.white.opacity(0.18),
                listIndexText: Color.cyan.opacity(0.90),
                logText: Color.green.opacity(0.92),
                logBackground: Color.black.opacity(0.26),
                glowPrimary: Color.cyan,
                glowSecondary: Color(red: 0.12, green: 0.95, blue: 0.82),
                primaryButtonText: Color.black.opacity(0.92),
                primaryButtonStart: Color.cyan.opacity(0.95),
                primaryButtonEnd: Color(red: 0.45, green: 1.0, blue: 0.92).opacity(0.82),
                primaryBorder: Color.cyan,
                primaryShadow: Color.cyan,
                secondaryButtonText: Color.white.opacity(0.92),
                secondaryButtonFill: Color(red: 0.14, green: 0.28, blue: 0.34).opacity(0.72),
                secondaryBorder: Color(red: 0.40, green: 1.0, blue: 0.85),
                secondaryShadow: Color(red: 0.40, green: 1.0, blue: 0.85),
                ghostButtonText: Color.white.opacity(0.92),
                ghostButtonFill: Color.white.opacity(0.05),
                ghostBorder: Color.white.opacity(0.28),
                ghostShadow: .clear,
                dangerButtonText: Color(red: 1, green: 0.88, blue: 0.88),
                dangerButtonFill: Color(red: 0.36, green: 0.08, blue: 0.08).opacity(0.72),
                dangerBorder: Color(red: 1.0, green: 0.34, blue: 0.34),
                dangerShadow: Color.red
            )
        case .deepSeaObservatory:
            return ThemePalette(
                tint: Color(red: 0.55, green: 0.90, blue: 0.98),
                accent: Color(red: 0.55, green: 0.90, blue: 0.98),
                secondaryAccent: Color(red: 0.42, green: 0.76, blue: 0.95),
                warning: Color(red: 0.99, green: 0.73, blue: 0.39),
                danger: Color(red: 1.0, green: 0.50, blue: 0.44),
                primaryText: Color.white.opacity(0.92),
                secondaryText: Color(red: 0.84, green: 0.94, blue: 0.98),
                mutedText: Color(red: 0.72, green: 0.82, blue: 0.88),
                labelText: Color(red: 0.64, green: 0.78, blue: 0.86),
                kickerText: Color(red: 0.70, green: 0.94, blue: 1.0),
                captionText: Color(red: 0.68, green: 0.92, blue: 1.0),
                panelFillTop: Color.white.opacity(0.09),
                panelFillMiddle: Color(red: 0.22, green: 0.42, blue: 0.52).opacity(0.12),
                panelFillBottom: Color.black.opacity(0.22),
                panelBorder: Color(red: 0.52, green: 0.88, blue: 0.98).opacity(0.24),
                panelInnerBorder: Color.white.opacity(0.07),
                panelShadow: Color(red: 0.24, green: 0.67, blue: 0.84).opacity(0.22),
                panelBackdrop: Color(red: 0.00, green: 0.06, blue: 0.10).opacity(0.38),
                controlBackground: Color(red: 0.75, green: 0.92, blue: 1.0).opacity(0.08),
                controlBorder: Color(red: 0.52, green: 0.88, blue: 0.98).opacity(0.14),
                infoBackground: Color(red: 0.00, green: 0.08, blue: 0.13).opacity(0.42),
                statusBackground: Color(red: 0.00, green: 0.09, blue: 0.14).opacity(0.44),
                tileBackgroundOverlay: Color.white.opacity(0.04),
                listBackground: Color(red: 0.01, green: 0.08, blue: 0.13).opacity(0.88),
                listRowBackground: Color(red: 0.06, green: 0.14, blue: 0.20).opacity(0.92),
                listDotIdle: Color(red: 0.63, green: 0.79, blue: 0.86).opacity(0.24),
                listIndexText: Color(red: 0.74, green: 0.97, blue: 1.0),
                logText: Color(red: 0.74, green: 0.97, blue: 1.0).opacity(0.95),
                logBackground: Color(red: 0.02, green: 0.10, blue: 0.16).opacity(0.56),
                glowPrimary: Color(red: 0.16, green: 0.66, blue: 0.92),
                glowSecondary: Color(red: 0.26, green: 0.88, blue: 0.98),
                primaryButtonText: Color(red: 0.01, green: 0.14, blue: 0.18),
                primaryButtonStart: Color(red: 0.62, green: 0.93, blue: 0.99),
                primaryButtonEnd: Color(red: 0.40, green: 0.78, blue: 0.95),
                primaryBorder: Color(red: 0.62, green: 0.93, blue: 0.99),
                primaryShadow: Color(red: 0.34, green: 0.76, blue: 0.95),
                secondaryButtonText: Color.white.opacity(0.93),
                secondaryButtonFill: Color(red: 0.08, green: 0.18, blue: 0.24).opacity(0.84),
                secondaryBorder: Color(red: 0.55, green: 0.90, blue: 0.98),
                secondaryShadow: Color(red: 0.24, green: 0.67, blue: 0.84),
                ghostButtonText: Color(red: 0.90, green: 0.97, blue: 1.0),
                ghostButtonFill: Color(red: 0.76, green: 0.94, blue: 1.0).opacity(0.07),
                ghostBorder: Color(red: 0.62, green: 0.88, blue: 0.96).opacity(0.30),
                ghostShadow: .clear,
                dangerButtonText: Color(red: 1.0, green: 0.90, blue: 0.88),
                dangerButtonFill: Color(red: 0.32, green: 0.10, blue: 0.09).opacity(0.76),
                dangerBorder: Color(red: 1.0, green: 0.52, blue: 0.48),
                dangerShadow: Color(red: 0.82, green: 0.34, blue: 0.30)
            )
        case .sunsetCinema:
            return ThemePalette(
                tint: Color(red: 1.0, green: 0.67, blue: 0.34),
                accent: Color(red: 1.0, green: 0.70, blue: 0.42),
                secondaryAccent: Color(red: 1.0, green: 0.48, blue: 0.33),
                warning: Color(red: 1.0, green: 0.84, blue: 0.44),
                danger: Color(red: 1.0, green: 0.46, blue: 0.39),
                primaryText: Color.white.opacity(0.92),
                secondaryText: Color(red: 1.0, green: 0.88, blue: 0.80),
                mutedText: Color(red: 0.98, green: 0.76, blue: 0.66),
                labelText: Color(red: 1.0, green: 0.80, blue: 0.70).opacity(0.72),
                kickerText: Color(red: 1.0, green: 0.76, blue: 0.54),
                captionText: Color(red: 1.0, green: 0.74, blue: 0.48),
                panelFillTop: Color.white.opacity(0.08),
                panelFillMiddle: Color(red: 0.72, green: 0.30, blue: 0.20).opacity(0.11),
                panelFillBottom: Color.black.opacity(0.22),
                panelBorder: Color(red: 1.0, green: 0.62, blue: 0.40).opacity(0.22),
                panelInnerBorder: Color.white.opacity(0.07),
                panelShadow: Color(red: 1.0, green: 0.44, blue: 0.22).opacity(0.18),
                panelBackdrop: Color(red: 0.08, green: 0.02, blue: 0.03).opacity(0.34),
                controlBackground: Color(red: 1.0, green: 0.80, blue: 0.62).opacity(0.07),
                controlBorder: Color(red: 1.0, green: 0.62, blue: 0.40).opacity(0.14),
                infoBackground: Color(red: 0.10, green: 0.03, blue: 0.03).opacity(0.42),
                statusBackground: Color(red: 0.12, green: 0.04, blue: 0.04).opacity(0.44),
                tileBackgroundOverlay: Color.white.opacity(0.04),
                listBackground: Color(red: 0.08, green: 0.03, blue: 0.03).opacity(0.90),
                listRowBackground: Color(red: 0.18, green: 0.07, blue: 0.07).opacity(0.92),
                listDotIdle: Color.white.opacity(0.18),
                listIndexText: Color(red: 1.0, green: 0.78, blue: 0.55),
                logText: Color(red: 1.0, green: 0.86, blue: 0.66).opacity(0.95),
                logBackground: Color(red: 0.15, green: 0.05, blue: 0.05).opacity(0.52),
                glowPrimary: Color(red: 1.0, green: 0.42, blue: 0.20),
                glowSecondary: Color(red: 1.0, green: 0.73, blue: 0.34),
                primaryButtonText: Color(red: 0.28, green: 0.08, blue: 0.02),
                primaryButtonStart: Color(red: 1.0, green: 0.80, blue: 0.52),
                primaryButtonEnd: Color(red: 1.0, green: 0.56, blue: 0.34),
                primaryBorder: Color(red: 1.0, green: 0.76, blue: 0.50),
                primaryShadow: Color(red: 1.0, green: 0.48, blue: 0.26),
                secondaryButtonText: Color.white.opacity(0.93),
                secondaryButtonFill: Color(red: 0.24, green: 0.08, blue: 0.06).opacity(0.82),
                secondaryBorder: Color(red: 1.0, green: 0.68, blue: 0.40),
                secondaryShadow: Color(red: 1.0, green: 0.44, blue: 0.22),
                ghostButtonText: Color(red: 1.0, green: 0.92, blue: 0.84),
                ghostButtonFill: Color(red: 1.0, green: 0.82, blue: 0.66).opacity(0.06),
                ghostBorder: Color(red: 1.0, green: 0.74, blue: 0.54).opacity(0.30),
                ghostShadow: .clear,
                dangerButtonText: Color(red: 1.0, green: 0.90, blue: 0.88),
                dangerButtonFill: Color(red: 0.40, green: 0.10, blue: 0.08).opacity(0.78),
                dangerBorder: Color(red: 1.0, green: 0.50, blue: 0.42),
                dangerShadow: Color(red: 0.90, green: 0.34, blue: 0.24)
            )
        }
    }

    @ViewBuilder
    private func scanlineOverlay(lineColor: Color, isDynamicEffectsEnabled: Bool) -> some View {
        GeometryReader { proxy in
            if isDynamicEffectsEnabled {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = CGFloat((time * 18).truncatingRemainder(dividingBy: 5))

                    Path { path in
                        let height = proxy.size.height + 12
                        let width = proxy.size.width
                        stride(from: -12.0, through: height, by: 5.0).forEach { y in
                            path.move(to: CGPoint(x: 0, y: y + phase))
                            path.addLine(to: CGPoint(x: width, y: y + phase))
                        }
                    }
                    .stroke(lineColor, lineWidth: 0.5)
                }
            } else {
                Path { path in
                    let height = proxy.size.height
                    let width = proxy.size.width
                    stride(from: 0.0, through: height, by: 5.0).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(lineColor.opacity(0.9), lineWidth: 0.45)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func radarSweep(accent: Color, isDynamicEffectsEnabled: Bool) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(accent.opacity(index == 0 ? 0.22 : 0.10))
                    .frame(width: index == 0 ? 2 : 1, height: index == 0 ? 220 : 180)
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            if isDynamicEffectsEnabled {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let rotation = Angle.degrees((time * 18).truncatingRemainder(dividingBy: 360))

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.02), accent.opacity(0.32), accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 10, height: 250)
                        .blur(radius: 4)
                        .rotationEffect(rotation)
                }
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func filmGrainOverlay(dotColor: Color, isDynamicEffectsEnabled: Bool) -> some View {
        Canvas { context, size in
            let cell: CGFloat = isDynamicEffectsEnabled ? 18 : 24
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    y += cell
                }
                x += cell
            }
        }
        .allowsHitTesting(false)
    }

    private func animatedGlow(primary: Color, secondary: Color, speed: Double, isDynamicEffectsEnabled: Bool) -> some View {
        Group {
            if isDynamicEffectsEnabled {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let primaryCenter = UnitPoint(
                        x: 0.25 + sin(time * speed) * 0.12,
                        y: 0.22 + cos(time * speed * 1.3) * 0.10
                    )
                    let secondaryCenter = UnitPoint(
                        x: 0.78 + cos(time * speed * 0.9) * 0.10,
                        y: 0.76 + sin(time * speed * 1.1) * 0.10
                    )

                    ZStack {
                        RadialGradient(
                            colors: [primary, .clear],
                            center: primaryCenter,
                            startRadius: 20,
                            endRadius: 500
                        )
                        .ignoresSafeArea()

                        RadialGradient(
                            colors: [secondary, .clear],
                            center: secondaryCenter,
                            startRadius: 30,
                            endRadius: 440
                        )
                        .ignoresSafeArea()
                    }
                }
            } else {
                ZStack {
                    RadialGradient(
                        colors: [primary, .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 480
                    )
                    .ignoresSafeArea()

                    RadialGradient(
                        colors: [secondary, .clear],
                        center: .bottomTrailing,
                        startRadius: 30,
                        endRadius: 420
                    )
                    .ignoresSafeArea()
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func projectorBeams(accent: Color, isDynamicEffectsEnabled: Bool) -> some View {
        Group {
            if isDynamicEffectsEnabled {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let drift = sin(time * 0.22) * 40

                    HStack {
                        Spacer()
                        LinearGradient(
                            colors: [accent.opacity(0.00), accent.opacity(0.13), accent.opacity(0.00)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: 320)
                        .rotationEffect(.degrees(-12))
                        .blur(radius: 12)
                        .offset(x: drift, y: -70)
                    }
                }
            } else {
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [accent.opacity(0.00), accent.opacity(0.10), accent.opacity(0.00)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 300)
                    .rotationEffect(.degrees(-12))
                    .blur(radius: 12)
                    .offset(y: -70)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func cyberHUDOverlay(accent: Color, secondary: Color, isDynamicEffectsEnabled: Bool) -> some View {
        Group {
            if isDynamicEffectsEnabled {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let pulse = 0.12 + ((sin(time * 1.4) + 1) / 2) * 0.12
                    let drift = sin(time * 0.45) * 26

                    ZStack {
                        GeometryReader { proxy in
                            Path { path in
                                let width = proxy.size.width
                                let height = proxy.size.height
                                stride(from: 0.0, through: width, by: 28.0).forEach { x in
                                    path.move(to: CGPoint(x: x + drift, y: 0))
                                    path.addLine(to: CGPoint(x: x + drift, y: height))
                                }
                                stride(from: 0.0, through: height, by: 28.0).forEach { y in
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: width, y: y))
                                }
                            }
                            .stroke(accent.opacity(0.045), lineWidth: 0.6)
                        }

                        Circle()
                            .trim(from: 0.08, to: 0.42)
                            .stroke(secondary.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 420, height: 420)
                            .offset(x: 360, y: -220)

                        Circle()
                            .trim(from: 0.52, to: 0.92)
                            .stroke(accent.opacity(0.18 + pulse), style: StrokeStyle(lineWidth: 1.5, dash: [6, 8]))
                            .frame(width: 280, height: 280)
                            .offset(x: 320, y: -210)

                        LinearGradient(
                            colors: [.clear, secondary.opacity(0.16 + pulse), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 130)
                        .blur(radius: 10)
                        .offset(y: -210)
                    }
                }
            } else {
                ZStack {
                    GeometryReader { proxy in
                        Path { path in
                            let width = proxy.size.width
                            let height = proxy.size.height
                            stride(from: 0.0, through: width, by: 32.0).forEach { x in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: height))
                            }
                            stride(from: 0.0, through: height, by: 32.0).forEach { y in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: width, y: y))
                            }
                        }
                        .stroke(accent.opacity(0.038), lineWidth: 0.55)
                    }

                    Circle()
                        .trim(from: 0.08, to: 0.42)
                        .stroke(secondary.opacity(0.26), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 420, height: 420)
                        .offset(x: 360, y: -220)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func sonarGridOverlay(accent: Color, isDynamicEffectsEnabled: Bool) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(accent.opacity(isDynamicEffectsEnabled ? (0.10 - (Double(index) * 0.015)) : 0.08), lineWidth: 1)
                    .frame(width: CGFloat(220 + index * 120), height: CGFloat(220 + index * 120))
            }

            GeometryReader { proxy in
                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    stride(from: 0.0, through: width, by: 36.0).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                }
                .stroke(accent.opacity(0.03), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func stageLightOverlay(primary: Color, secondary: Color, isDynamicEffectsEnabled: Bool) -> some View {
        Group {
            if isDynamicEffectsEnabled {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let drift = sin(time * 0.38) * 80
                    let flare = 0.10 + ((cos(time * 1.1) + 1) / 2) * 0.10

                    ZStack {
                        HStack {
                            LinearGradient(
                                colors: [primary.opacity(0.00), primary.opacity(flare), primary.opacity(0.00)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: 240)
                            .rotationEffect(.degrees(18))
                            .blur(radius: 16)
                            .offset(x: drift, y: -90)

                            Spacer()
                        }

                        HStack {
                            Spacer()
                            LinearGradient(
                                colors: [secondary.opacity(0.00), secondary.opacity(flare + 0.05), secondary.opacity(0.00)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: 260)
                            .rotationEffect(.degrees(-16))
                            .blur(radius: 18)
                            .offset(x: -drift, y: -60)
                        }
                    }
                }
            } else {
                ZStack {
                    HStack {
                        LinearGradient(
                            colors: [primary.opacity(0.00), primary.opacity(0.14), primary.opacity(0.00)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: 240)
                        .rotationEffect(.degrees(18))
                        .blur(radius: 16)
                        .offset(y: -90)

                        Spacer()
                    }

                    HStack {
                        Spacer()
                        LinearGradient(
                            colors: [secondary.opacity(0.00), secondary.opacity(0.18), secondary.opacity(0.00)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: 260)
                        .rotationEffect(.degrees(-16))
                        .blur(radius: 18)
                        .offset(y: -60)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ThemePalette {
    let tint: Color
    let accent: Color
    let secondaryAccent: Color
    let warning: Color
    let danger: Color
    let primaryText: Color
    let secondaryText: Color
    let mutedText: Color
    let labelText: Color
    let kickerText: Color
    let captionText: Color
    let panelFillTop: Color
    let panelFillMiddle: Color
    let panelFillBottom: Color
    let panelBorder: Color
    let panelInnerBorder: Color
    let panelShadow: Color
    let panelBackdrop: Color
    let controlBackground: Color
    let controlBorder: Color
    let infoBackground: Color
    let statusBackground: Color
    let tileBackgroundOverlay: Color
    let listBackground: Color
    let listRowBackground: Color
    let listDotIdle: Color
    let listIndexText: Color
    let logText: Color
    let logBackground: Color
    let glowPrimary: Color
    let glowSecondary: Color
    let primaryButtonText: Color
    let primaryButtonStart: Color
    let primaryButtonEnd: Color
    let primaryBorder: Color
    let primaryShadow: Color
    let secondaryButtonText: Color
    let secondaryButtonFill: Color
    let secondaryBorder: Color
    let secondaryShadow: Color
    let ghostButtonText: Color
    let ghostButtonFill: Color
    let ghostBorder: Color
    let ghostShadow: Color
    let dangerButtonText: Color
    let dangerButtonFill: Color
    let dangerBorder: Color
    let dangerShadow: Color
}

private struct ThemedPanel<Content: View>: View {
    let theme: UITheme
    let isDynamicEffectsEnabled: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.palette.panelFillTop,
                            theme.palette.panelFillMiddle,
                            theme.palette.panelFillBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.palette.panelBorder, lineWidth: 1)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.palette.panelInnerBorder, lineWidth: 1)
                .padding(2)

            content
                .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.palette.panelBackdrop)
                .blur(radius: 20)
        )
        .overlay(
            Group {
                if isDynamicEffectsEnabled {
                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let alpha = 0.04 + ((sin(time * 0.9) + 1) / 2) * 0.06

                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(theme.palette.accent.opacity(alpha), lineWidth: 1)
                                .padding(1)

                            GeometryReader { proxy in
                                let width = proxy.size.width
                                let travel = CGFloat((time * 120).truncatingRemainder(dividingBy: Double(width + 180))) - 90

                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.clear, lineWidth: 0)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                .clear,
                                                theme.palette.secondaryAccent.opacity(0.00),
                                                theme.palette.secondaryAccent.opacity(0.18),
                                                theme.palette.accent.opacity(0.28),
                                                theme.palette.secondaryAccent.opacity(0.18),
                                                .clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .frame(width: 120)
                                        .blur(radius: 10)
                                        .offset(x: travel)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(theme.palette.accent.opacity(0.08), lineWidth: 1)
                        .padding(1)
                }
            }
        )
        .shadow(color: theme.palette.panelShadow, radius: 18, y: 8)
    }
}

private extension ContentView {
    func telemetryPill(_ text: String, accent: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.32), lineWidth: 1)
            )
    }

    func energyBars(isDynamicEffectsEnabled: Bool) -> some View {
        Group {
            if isDynamicEffectsEnabled {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    barGroup(time: time)
                }
            } else {
                barGroup(time: nil)
            }
        }
    }

    private func barGroup(time: TimeInterval?) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { index in
                let dynamicHeight = CGFloat(8 + abs(sin((time ?? 0) * 1.8 + Double(index) * 0.45)) * 14)
                let staticHeight = CGFloat(9 + Double((index % 4) * 3))
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(index.isMultiple(of: 2) ? theme.palette.accent : theme.palette.secondaryAccent)
                    .frame(width: 5, height: time == nil ? staticHeight : dynamicHeight)
                    .shadow(color: theme.palette.accent.opacity(0.28), radius: 5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(theme.palette.statusBackground)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(theme.palette.panelBorder.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct ThemedButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case ghost
        case danger
    }

    let theme: UITheme
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background(configuration: configuration))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor.opacity(configuration.isPressed ? 0.85 : 0.45), lineWidth: 1)
            )
            .shadow(color: shadowColor.opacity(configuration.isPressed ? 0.18 : 0.35), radius: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return theme.palette.primaryButtonText
        case .secondary:
            return theme.palette.secondaryButtonText
        case .ghost:
            return theme.palette.ghostButtonText
        case .danger:
            return theme.palette.dangerButtonText
        }
    }

    private var borderColor: Color {
        switch kind {
        case .primary:
            return theme.palette.primaryBorder
        case .secondary:
            return theme.palette.secondaryBorder
        case .ghost:
            return theme.palette.ghostBorder
        case .danger:
            return theme.palette.dangerBorder
        }
    }

    private var shadowColor: Color {
        switch kind {
        case .primary:
            return theme.palette.primaryShadow
        case .secondary:
            return theme.palette.secondaryShadow
        case .ghost:
            return theme.palette.ghostShadow
        case .danger:
            return theme.palette.dangerShadow
        }
    }

    @ViewBuilder
    private func background(configuration: Configuration) -> some View {
        switch kind {
        case .primary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.palette.primaryButtonStart.opacity(configuration.isPressed ? 0.65 : 0.95),
                            theme.palette.primaryButtonEnd.opacity(configuration.isPressed ? 0.55 : 0.82)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        case .secondary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.palette.secondaryButtonFill.opacity(configuration.isPressed ? 0.92 : 1))
        case .ghost:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.palette.ghostButtonFill.opacity(configuration.isPressed ? 1 : 0.92))
        case .danger:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.palette.dangerButtonFill.opacity(configuration.isPressed ? 0.92 : 1))
        }
    }
}

private extension Set where Element == Int {
    var onlyElement: Int? {
        count == 1 ? first : nil
    }
}
