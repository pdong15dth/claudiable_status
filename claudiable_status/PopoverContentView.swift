import SwiftUI
import Charts
import ServiceManagement

struct PopoverContentView: View {
    var onQuit: () -> Void

    @State private var viewModel = DashboardViewModel()
    @State private var apiKey = ""
    @State private var showingSettingsPopup = false
    @State private var settingsApiKey = ""
    @State private var revealSettingsApiKey = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var toastTask: Task<Void, Never>?
    @State private var displayMode = DashboardDisplayMode.loadFromDefaults()
    @State private var isHoveringSave = false
    @State private var isHoveringClear = false
    @State private var isHoveringClose = false
    @State private var isCheckingUpdate = false
    @State private var availableUpdate: UpdateInfo?
    @State private var updateCheckDone = false
    @State private var isHoveringDownload = false
    @State private var isHoveringCheckUpdate = false

    private let neonGreen = Color(red: 0.30, green: 0.80, blue: 0.35)
    private let cardColor = Color(white: 0.10)
    private let blackColor = Color.black

    private var panelWidth: CGFloat {
        switch displayMode {
        case .compact:
            return 420
        case .full:
            return 620
        }
    }

    private var panelMinHeight: CGFloat {
        switch displayMode {
        case .compact:
            return 280
        case .full:
            return 700
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if displayMode == .compact {
                dashboardContent
                    .padding(14)
            } else {
                ScrollView {
                    dashboardContent
                        .padding(14)
                }
            }
        }
        .frame(width: panelWidth)
        .frame(minHeight: panelMinHeight)
        .background(blackColor)
        .task {
            apiKey = APIKeyStore.load()
            await refreshDashboard(showSuccessToast: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiKeyDidChange)) { _ in
            apiKey = APIKeyStore.load()
            Task {
                await refreshDashboard(showSuccessToast: false)
            }
        }
        .onChange(of: displayMode) { _, newMode in
            newMode.saveToDefaults()
            NotificationCenter.default.post(name: .dashboardDisplayModeDidChange, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateAvailable)) { notification in
            if let version = notification.userInfo?["version"] as? String {
                presentToast("Có phiên bản mới: v\(version)")
            }
        }
        .onDisappear {
            viewModel.stopStreaming()
            toastTask?.cancel()
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastBanner(message: toastMessage, isError: toastIsError)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if showingSettingsPopup {
                settingsPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage != nil)
        .animation(.easeInOut(duration: 0.2), value: showingSettingsPopup)
        .animation(.easeInOut(duration: 0.2), value: displayMode)
    }

    @ViewBuilder
    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardHeader(
                greeting: viewModel.dashboard?.welcomeText ?? "Welcome back, Dong Pham",
                subtitle: "Your API usage at a glance",
                neonGreen: neonGreen,
                isLoading: viewModel.isLoading,
                onSettings: {
                    openSettingsPopup()
                },
                onQuit: onQuit,
                onRefresh: {
                    Task {
                        await refreshDashboard(showSuccessToast: true)
                    }
                }
            )
            .padding(.top, 20)

            DisplayModeSelector(mode: $displayMode, neonGreen: neonGreen, cardColor: cardColor)

            if displayMode == .full {
                NoticeBar(neonGreen: neonGreen)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let dashboard = viewModel.dashboard {
                if displayMode == .compact {
                    CompactMetricsRow(
                        dashboard: dashboard,
                        liveStatusText: liveStatusText,
                        liveStatusColor: liveStatusColor,
                        neonGreen: neonGreen,
                        cardColor: cardColor
                    )
                } else {
                    TopMetricsRow(dashboard: dashboard, neonGreen: neonGreen, cardColor: cardColor)
                    SubscriptionRow(dashboard: dashboard, neonGreen: neonGreen, cardColor: cardColor)
                    SpendingPatternSection(
                        dailyUsage: dashboard.analytics.dailyUsage,
                        modelBreakdown: dashboard.analytics.modelBreakdown,
                        neonGreen: neonGreen,
                        cardColor: cardColor
                    )
                    UsageInsightsCard(dashboard: dashboard, cardColor: cardColor)
                    RecentActivityCard(
                        usage: dashboard.usage,
                        liveStatusText: liveStatusText,
                        liveStatusColor: liveStatusColor,
                        cardColor: cardColor
                    )
                }
            }
        }
    }

    private var liveStatusText: String {
        switch viewModel.liveConnectionState {
        case .idle:
            return "Offline"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Live"
        case .reconnecting:
            return "Reconnecting"
        }
    }

    private var liveStatusColor: Color {
        switch viewModel.liveConnectionState {
        case .connected:
            return neonGreen
        case .connecting, .reconnecting:
            return .yellow
        case .idle:
            return .gray
        }
    }

    private func refreshDashboard(showSuccessToast: Bool) async {
        await viewModel.fetchDashboard(apiKey: apiKey)
        guard showSuccessToast else { return }

        if viewModel.errorMessage == nil {
            presentToast("Đã làm mới dashboard thành công.")
        } else {
            presentToast("Làm mới thất bại.", isError: true)
        }
    }

    private func presentToast(_ message: String, isError: Bool = false) {
        toastTask?.cancel()
        toastMessage = message
        toastIsError = isError
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    private func openSettingsPopup() {
        settingsApiKey = APIKeyStore.load()
        revealSettingsApiKey = false
        launchAtLogin = SMAppService.mainApp.status == .enabled
        updateCheckDone = false
        availableUpdate = nil
        showingSettingsPopup = true
    }

    private func saveSettingsAPIKey() {
        if APIKeyStore.save(settingsApiKey) {
            apiKey = APIKeyStore.load()
            NotificationCenter.default.post(name: .apiKeyDidChange, object: nil)
            presentToast("Đã lưu API key vào Keychain.")
            showingSettingsPopup = false
        } else {
            presentToast("Không thể lưu API key vào Keychain.", isError: true)
        }
    }

    private func clearSettingsAPIKey() {
        settingsApiKey = ""
        if APIKeyStore.save(settingsApiKey) {
            apiKey = ""
            NotificationCenter.default.post(name: .apiKeyDidChange, object: nil)
            presentToast("Đã xóa API key khỏi Keychain.")
            showingSettingsPopup = false
        } else {
            presentToast("Không thể xóa API key khỏi Keychain.", isError: true)
        }
    }

    private func performUpdateCheck() async {
        isCheckingUpdate = true
        updateCheckDone = false
        availableUpdate = await UpdateChecker.checkForUpdate()
        isCheckingUpdate = false
        updateCheckDone = true
    }

    private var settingsPopup: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    showingSettingsPopup = false
                }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // MARK: Header
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(neonGreen)
                            Text("API Settings")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Button {
                            showingSettingsPopup = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isHoveringClose ? .white : .gray)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(isHoveringClose ? Color(white: 0.25) : Color(white: 0.15))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringClose = $0 }
                    }

                    // MARK: API Key field with inline eye toggle
                    HStack(spacing: 0) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(neonGreen.opacity(0.6))
                            .frame(width: 30)

                        Group {
                            if revealSettingsApiKey {
                                TextField("Nhập API key...", text: $settingsApiKey)
                            } else {
                                SecureField("Nhập API key...", text: $settingsApiKey)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white)

                        Button {
                            revealSettingsApiKey.toggle()
                        } label: {
                            Image(systemName: revealSettingsApiKey ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(revealSettingsApiKey ? neonGreen : .gray)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(white: 0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(neonGreen.opacity(0.25), lineWidth: 1)
                    )

                    // MARK: Keychain info
                    HStack(spacing: 5) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(neonGreen.opacity(0.5))
                        Text("API key được lưu cục bộ trong Keychain.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.gray)
                    }

                    // MARK: Section divider
                    Rectangle()
                        .fill(neonGreen.opacity(0.15))
                        .frame(height: 1)

                    // MARK: Launch at login toggle
                    Toggle(isOn: $launchAtLogin) {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                                .font(.system(size: 11))
                                .foregroundStyle(neonGreen.opacity(0.6))
                            Text("Khởi động cùng hệ thống")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(neonGreen)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                            presentToast("Không thể thay đổi cài đặt khởi động.", isError: true)
                        }
                    }

                    // MARK: Section divider
                    Rectangle()
                        .fill(neonGreen.opacity(0.15))
                        .frame(height: 1)

                    // MARK: Check for updates
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                                .foregroundStyle(neonGreen.opacity(0.6))
                            Text("Cập nhật")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.white)

                            Spacer()

                            if isCheckingUpdate {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else {
                                Button {
                                    Task { await performUpdateCheck() }
                                } label: {
                                    Text("Kiểm tra")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(isHoveringCheckUpdate ? .white : .gray)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(isHoveringCheckUpdate ? Color(white: 0.20) : Color(white: 0.14))
                                        )
                                }
                                .buttonStyle(.plain)
                                .onHover { isHoveringCheckUpdate = $0 }
                            }
                        }

                        if updateCheckDone {
                            if let update = availableUpdate {
                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gift.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(neonGreen)
                                        Text("v\(update.version)")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(neonGreen)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(neonGreen.opacity(0.12), in: Capsule())

                                    Spacer()

                                    Button {
                                        NSWorkspace.shared.open(update.releaseURL)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 10))
                                            Text("Tải về")
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundStyle(isHoveringDownload ? .black : Color(white: 0.05))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(isHoveringDownload ? neonGreen : neonGreen.opacity(0.85))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { isHoveringDownload = $0 }
                                }
                            } else {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(neonGreen.opacity(0.7))
                                    Text("Đang dùng phiên bản mới nhất.")
                                        .font(.system(size: 11, weight: .regular, design: .rounded))
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }

                    // MARK: Section divider
                    Rectangle()
                        .fill(neonGreen.opacity(0.15))
                        .frame(height: 1)
                    HStack(spacing: 8) {
                        Button {
                            clearSettingsAPIKey()
                        } label: {
                            Text("Xóa key")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(isHoveringClear ? .red : Color.red.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isHoveringClear ? Color.red.opacity(0.15) : Color.red.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isHoveringClear ? Color.red.opacity(0.4) : Color.red.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringClear = $0 }

                        Spacer()

                        Button {
                            saveSettingsAPIKey()
                        } label: {
                            Text("Lưu")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(isHoveringSave ? .black : Color(white: 0.05))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isHoveringSave ? neonGreen : neonGreen.opacity(0.85))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringSave = $0 }
                    }

                    // MARK: Version info
                    HStack {
                        Spacer()
                        Text("Claudible Status v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.30))
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(width: panelWidth - 20)
            .frame(maxHeight: panelMinHeight - 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(neonGreen.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: neonGreen.opacity(0.08), radius: 20, x: 0, y: 0)
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 8)
        }
    }
}

private struct DashboardHeader: View {
    let greeting: String
    let subtitle: String
    let neonGreen: Color
    let isLoading: Bool
    let onSettings: () -> Void
    let onQuit: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.gray)
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(neonGreen.opacity(0.7))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                headerButton(systemName: "gearshape.fill", tint: .white, action: onSettings)
                headerButton(systemName: "power", tint: .red, action: onQuit)
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(neonGreen)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(
                            isLoading
                                ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                                : .default,
                            value: isLoading
                        )
                        .frame(width: 30, height: 30)
                        .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
    }

    private func headerButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct NoticeBar: View {
    let neonGreen: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(neonGreen)

            Text("All models use 200K context window (optimized for cost efficiency).")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DisplayModeSelector: View {
    @Binding var mode: DashboardDisplayMode
    let neonGreen: Color
    let cardColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Text("View Mode")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.gray)

            HStack(spacing: 6) {
                modeButton(for: .compact, icon: "rectangle.compress.vertical")
                modeButton(for: .full, icon: "rectangle.expand.vertical")
            }
        }
        .padding(8)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(neonGreen.opacity(0.35), lineWidth: 1)
        )
    }

    private func modeButton(for option: DashboardDisplayMode, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                mode = option
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(option.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(mode == option ? .black : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedFillStyle(for: option))
            )
        }
        .buttonStyle(.plain)
    }

    private func selectedFillStyle(for option: DashboardDisplayMode) -> AnyShapeStyle {
        if mode == option {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [neonGreen.opacity(0.96), neonGreen.opacity(0.76)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color(white: 0.14))
    }
}

private struct CompactMetricsRow: View {
    let dashboard: LookupResponse
    let liveStatusText: String
    let liveStatusColor: Color
    let neonGreen: Color
    let cardColor: Color

    private var avgCostPerMinuteText: String {
        String(format: "%.4f ☘️/min", dashboard.analytics.daysRemaining.avgCostPerMinute)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                metricCard(
                    icon: "creditcard.fill",
                    title: "BALANCE",
                    value: dashboard.balance.usd,
                    subtitle: "Available now",
                    accent: neonGreen
                )

                metricCard(
                    icon: "hourglass.bottomhalf.filled",
                    title: "RUNWAY",
                    value: dashboard.analytics.daysRemaining.runwayMinutes.durationText,
                    subtitle: avgCostPerMinuteText,
                    accent: .white
                )
            }

            HStack(spacing: 12) {
                factBadge(icon: "dot.radiowaves.left.and.right", label: liveStatusText, accent: liveStatusColor)
                factBadge(icon: "clock", label: dashboard.lastUsed.dateTimeText, accent: .gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricCard(
        icon: String,
        title: String,
        value: String,
        subtitle: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(neonGreen)
                    .frame(width: 22, height: 22)
                    .background(Color(red: 0.08, green: 0.24, blue: 0.11), in: Circle())

                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gray)
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .monospacedDigit()

            Text(subtitle)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            LinearGradient(
                colors: [cardColor, Color(white: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(neonGreen.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    private func factBadge(icon: String, label: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(white: 0.11), in: Capsule())
    }
}

private struct TopMetricsRow: View {
    let dashboard: LookupResponse
    let neonGreen: Color
    let cardColor: Color
    @State private var maxCardHeight: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            balanceCard
                .syncHeight(maxHeight: maxCardHeight) { updateMaxCardHeight($0) }
                .frame(maxWidth: .infinity, alignment: .leading)
            runwayCard
                .syncHeight(maxHeight: maxCardHeight) { updateMaxCardHeight($0) }
                .frame(maxWidth: .infinity, alignment: .leading)
            statusCard
                .syncHeight(maxHeight: maxCardHeight) { updateMaxCardHeight($0) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func updateMaxCardHeight(_ value: CGFloat) {
        guard value > maxCardHeight else { return }
        maxCardHeight = value
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "creditcard")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("BALANCE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gray)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.2f", dashboard.balance))
                    .font(.system(size: 34, design: .rounded))
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .monospacedDigit()
                    .layoutPriority(1)

                Text("☘️")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(neonGreen, lineWidth: 1)
        )
    }

    private var runwayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("RUNWAY")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gray)
            }

            Text(dashboard.analytics.daysRemaining.runwayMinutes.durationText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text("~\(String(format: "%.4f", dashboard.analytics.daysRemaining.avgCostPerMinute)) ☘️/min")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("STATUS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gray)
            }

            Text(dashboard.status.capitalized)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(neonGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 0.05, green: 0.24, blue: 0.08), in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SubscriptionRow: View {
    let dashboard: LookupResponse
    let neonGreen: Color
    let cardColor: Color

    private var resetsIn: String {
        let calendar = Calendar.current
        let now = Date()
        guard let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .strict,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return "--"
        }

        let components = calendar.dateComponents([.hour, .minute], from: now, to: nextMidnight)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        return "\(hours)h \(minutes)m"
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(neonGreen)
                Text("Monthly Subscription")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(neonGreen)
            }

            Spacer(minLength: 10)

            HStack(spacing: 18) {
                subscriptionMetric(label: "DAILY QUOTA", value: String(format: "%.2f ☘️", dashboard.dailyQuota))
                subscriptionMetric(label: "RESETS IN", value: resetsIn)
                subscriptionMetric(label: "EXPIRES", value: dashboard.subscriptionExpiresAt.monthDayText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func subscriptionMetric(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.gray)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

private struct SpendingPatternSection: View {
    let dailyUsage: [DailyUsage]
    let modelBreakdown: [ModelBreakdown]
    let neonGreen: Color
    let cardColor: Color
    @State private var maxCardHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SPENDING PATTERN")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.gray)

            HStack(alignment: .top, spacing: 16) {
                DailySpendingCard(dailyUsage: dailyUsage, neonGreen: neonGreen, cardColor: cardColor)
                    .syncHeight(maxHeight: maxCardHeight) { updateMaxCardHeight($0) }
                    .frame(maxWidth: .infinity)
                CostBreakdownCard(modelBreakdown: modelBreakdown, neonGreen: neonGreen, cardColor: cardColor)
                    .syncHeight(maxHeight: maxCardHeight) { updateMaxCardHeight($0) }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func updateMaxCardHeight(_ value: CGFloat) {
        guard value > maxCardHeight else { return }
        maxCardHeight = value
    }
}

private struct DailySpendingCard: View {
    let dailyUsage: [DailyUsage]
    let neonGreen: Color
    let cardColor: Color

    private struct DailyPoint: Identifiable {
        let id = UUID()
        let date: Date
        let cost: Double
    }

    private var points: [DailyPoint] {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")

        return dailyUsage.compactMap { item in
            guard let date = parser.date(from: item.date) else { return nil }
            return DailyPoint(date: date, cost: item.totalCostUSD)
        }
        .sorted { $0.date < $1.date }
        .suffix(7)
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Daily Spending")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("Last 7 days")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.gray)
            }

            Chart(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Cost", point.cost)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [neonGreen.opacity(0.30), neonGreen.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Cost", point.cost)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(neonGreen)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Cost", point.cost)
                )
                .symbolSize(36)
                .foregroundStyle(neonGreen)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.gray)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.white.opacity(0.10))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
            .frame(height: 190)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CostBreakdownCard: View {
    let modelBreakdown: [ModelBreakdown]
    let neonGreen: Color
    let cardColor: Color

    private struct SliceData: Identifiable {
        let id = UUID()
        let model: String
        let cost: Double
        let percentage: Double
        let color: Color
    }

    private var slices: [SliceData] {
        let sorted = modelBreakdown.sorted { $0.totalCost > $1.totalCost }
        let total = sorted.reduce(0.0) { $0 + $1.totalCost }
        let palette: [Color] = [
            neonGreen,
            Color(red: 0.25, green: 0.68, blue: 0.33),
            Color(red: 0.18, green: 0.55, blue: 0.27),
            Color(red: 0.12, green: 0.42, blue: 0.20),
            Color(red: 0.08, green: 0.31, blue: 0.16)
        ]

        return sorted.enumerated().map { index, item in
            let percent = total > 0 ? (item.totalCost / total) * 100 : 0
            return SliceData(
                model: item.model,
                cost: item.totalCost,
                percentage: percent,
                color: palette[index % palette.count]
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Cost Breakdown")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("By model")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.gray)
            }

            HStack(alignment: .center, spacing: 20) {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Cost", max(slice.cost, 0.0001)),
                        innerRadius: .ratio(0.62),
                        angularInset: 2.0
                    )
                    .foregroundStyle(slice.color)
                }
                .chartLegend(.hidden)
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(slices.prefix(4)) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 7, height: 7)

                            Text(item.model)
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            Spacer(minLength: 6)

                            Text("\(Int(item.percentage.rounded()))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct UsageInsightsCard: View {
    let dashboard: LookupResponse
    let cardColor: Color

    private var peakHourText: String {
        guard let peakHour = dashboard.analytics.hourlyDistribution.max(by: { $0.totalCostUSD < $1.totalCostUSD }) else {
            return "--"
        }
        return peakHour.hourOfDay.hourText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Insights")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                InsightRow(title: "Total Requests", value: dashboard.stats.totalRequests.grouped)
                divider
                InsightRow(title: "Total Spent", value: dashboard.stats.totalCost.usd)
                divider
                InsightRow(title: "Input Tokens", value: dashboard.stats.promptTokens.grouped)
                divider
                InsightRow(title: "Output Tokens", value: dashboard.stats.completionTokens.grouped)
                divider
                InsightRow(title: "Last Used", value: dashboard.lastUsed.dateTimeText)
                divider
                InsightRow(title: "Peak Hour", value: peakHourText)
            }
            .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var divider: some View {
        Divider().overlay(Color.white.opacity(0.08))
    }
}

private struct InsightRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct RecentActivityCard: View {
    let usage: [UsageItem]
    let liveStatusText: String
    let liveStatusColor: Color
    let cardColor: Color
    private let modelColumnWidth: CGFloat = 160
    private let tokensColumnWidth: CGFloat = 98
    private let costColumnWidth: CGFloat = 96
    private let timeColumnWidth: CGFloat = 138

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(liveStatusColor)
                        .frame(width: 7, height: 7)
                    Text(liveStatusText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(liveStatusColor)
                }
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("MODEL")
                        .frame(width: modelColumnWidth, alignment: .leading)
                    Text("TOKENS")
                        .frame(width: tokensColumnWidth, alignment: .leading)
                    Text("COST")
                        .frame(width: costColumnWidth, alignment: .leading)
                    Text("TIME")
                        .frame(width: timeColumnWidth, alignment: .leading)
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                Divider().background(Color.gray.opacity(0.3))

                ForEach(Array(usage.prefix(5).enumerated()), id: \.element.stableID) { index, item in
                    HStack(spacing: 12) {
                        Text(item.model)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .fontDesign(.monospaced)
                            .foregroundStyle(.white)
                            .frame(width: modelColumnWidth, alignment: .leading)

                        Text("\(item.promptTokens.compactGrouped) / \(item.completionTokens.grouped)")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.gray)
                            .frame(width: tokensColumnWidth, alignment: .leading)

                        Text(item.costUSD.leafPrecise)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: costColumnWidth, alignment: .leading)

                        Text(item.createdAt.activityTimestampText)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.gray)
                            .frame(width: timeColumnWidth, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                    if index < usage.prefix(5).count - 1 {
                        Divider().background(Color.gray.opacity(0.3))
                    }
                }
            }
            .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    PopoverContentView(onQuit: {})
        .preferredColorScheme(.dark)
}

private struct CardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func syncHeight(maxHeight: CGFloat, onHeightChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: CardHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(CardHeightPreferenceKey.self, perform: onHeightChange)
        .frame(height: maxHeight > 0 ? maxHeight : nil)
    }
}
