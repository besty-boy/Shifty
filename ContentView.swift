import SwiftUI

private enum ScanLaunchPhase {
    case idle
    case launching
    case scanner
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var quoteStore = QuoteStore()
    @State private var scanViewModel = ScanViewModel()
    @State private var statsStore = EcoStatsStore()
    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""

    @State private var launchProgress: CGFloat = 0
    @State private var launchPhase: ScanLaunchPhase = .idle
    @State private var launchTask: Task<Void, Never>?

    @State private var lastHandledScannerLaunchToken: Double = UserDefaults.standard.double(forKey: ScannerLaunchRequestKey.lastHandledToken)

    var body: some View {
        ZStack {
            FluidBackground()
                .ignoresSafeArea()

            if scanViewModel.currentScreen == .home {
                TabView(selection: $selectedTab) {
                    Tab(L10n.t("tab.home"), systemImage: "house.fill", value: 0) {
                        HomeView(
                            statsStore: statsStore,
                            onStart: beginScannerTransition,
                            scanTransitionProgress: launchProgress
                        )
                    }

                    Tab(L10n.t("tab.training"), systemImage: "graduationcap.fill", value: 1) {
                        TrainingGamePage(statsStore: statsStore)
                    }

                    Tab(L10n.t("tab.trophies"), systemImage: "trophy.fill", value: 2) {
                        TrophiesPage(statsStore: statsStore)
                    }

                    Tab(L10n.t("tab.scan"), systemImage: "camera.fill", value: 3, role: .search) {
                        Color.clear
                            .onAppear {
                                beginScannerTransition()
                                selectedTab = 0
                            }
                    }
                }
            } else {
                ScanView(
                    viewModel: scanViewModel,
                    statsStore: statsStore
                ) {
                    closeScanner()
                }
            }
        }
        .task { await quoteStore.ensureQuote { L10n.t("home.quote.placeholder") } }
        .onAppear {
            consumePendingScannerLaunchIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            consumePendingScannerLaunchIfNeeded()
        }
        .onDisappear {
            launchTask?.cancel()
            launchTask = nil
        }
    }

    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func beginScannerTransition() {
        guard launchPhase == .idle else { return }

        launchPhase = .launching
        launchTask?.cancel()
        launchProgress = 0

        launchTask = Task { @MainActor in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                launchProgress = 0.58
            }

            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.36, dampingFraction: 0.94)) {
                launchProgress = 1.0
            }

            try? await Task.sleep(for: .milliseconds(110))
            guard !Task.isCancelled else { return }

            scanViewModel.openScanner()
            launchPhase = .scanner

            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }

            launchProgress = 0
        }
    }

    private func closeScanner() {
        launchTask?.cancel()
        launchTask = nil
        launchProgress = 0
        launchPhase = .idle
        scanViewModel.closeScanner()
    }

    private func consumePendingScannerLaunchIfNeeded() {
        guard !isRunningInPreviews else { return }

        let pendingToken = UserDefaults.standard.double(forKey: ScannerLaunchRequestKey.pendingToken)
        guard pendingToken > lastHandledScannerLaunchToken else { return }

        lastHandledScannerLaunchToken = pendingToken
        UserDefaults.standard.set(pendingToken, forKey: ScannerLaunchRequestKey.lastHandledToken)
        beginScannerTransition()
    }
}

#Preview {
    ContentView()
}
