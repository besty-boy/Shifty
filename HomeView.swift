import Foundation
import SwiftUI
import UIKit
import QuartzCore
#if canImport(FoundationModels)
import FoundationModels
#endif




struct HomeView: View {
    var statsStore: EcoStatsStore
    let onStart: () -> Void
    let scanTransitionProgress: CGFloat

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @State private var showContent = false
    @State private var quote: EcoQuote = EcoQuote.dailyQuote(for: Date())
    @State private var isGeneratingQuote = false
    @State private var isAIQuote = false
    @State private var quoteTask: Task<Void, Never>?
    @State private var scanTapFeedbackTrigger = 0
    @State private var showConfetti = false
    @State private var lastObservedLevel: Int = 0
    @State private var awardedTrophyLevels: Set<Int> = []

    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var shouldAttemptAIQuoteGeneration: Bool {
        if isRunningInPreviews { return false }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return false }
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    private var clampedTransitionProgress: CGFloat {
        min(max(scanTransitionProgress, 0), 1)
    }

    private var transitionScale: CGFloat   { 1 + (0.15 * clampedTransitionProgress) }
    private var transitionBlur: CGFloat    { 12 * clampedTransitionProgress }
    private var contentOpacity: Double     { 1 - Double(clampedTransitionProgress) }

    var body: some View {
        NavigationStack {
            ZStack {
                FluidBackground()
                    .scaleEffect(transitionScale)
                    .blur(radius: transitionBlur)
                    .opacity(contentOpacity)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerCompact.sectionEntrance(show: showContent, index: 0)
                        ActivityRingCard(statsStore: statsStore)
                            .sectionEntrance(show: showContent, index: 1)
                        QuoteCard(
                            quote: quote,
                            isGenerating: isGeneratingQuote,
                            isAIGenerated: isAIQuote
                        )
                        .sectionEntrance(show: showContent, index: 2)
                        Spacer(minLength: 100)
                    }
                    
                    .padding(.bottom, 130)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .scaleEffect(transitionScale)
                .blur(radius: transitionBlur)
                .opacity(contentOpacity)

                if showConfetti {
                    ConfettiOverlay()
                        .transition(.opacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
                    showContent = true
                }
                startQuoteRefresh()
                lastObservedLevel = statsStore.level
                awardedTrophyLevels = Set(trophyThresholds.filter { statsStore.level >= $0 })
            }
            .onDisappear {
                quoteTask?.cancel()
                quoteTask = nil
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                startQuoteRefresh()
            }
            .onChange(of: statsStore.level) { oldLevel, newLevel in
                guard newLevel != oldLevel else { return }
                if newLevel > oldLevel { triggerConfetti() }
                for threshold in trophyThresholds
                    where oldLevel < threshold && newLevel >= threshold && !awardedTrophyLevels.contains(threshold) {
                    awardedTrophyLevels.insert(threshold)
                    triggerConfetti()
                }
                lastObservedLevel = newLevel
            }
        }
    
    }

    private var scannerButton: some View {
        Button(action: startScan) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(colorScheme == .dark ? 0.15 : 0.25))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        }
                    Image(systemName: "camera.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(L10n.t("home.scan.button"))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .disabled(clampedTransitionProgress > 0)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .applyScannerGlass(colorScheme: colorScheme)
        .opacity(1 - Double(clampedTransitionProgress))
        .blur(radius: 8 * clampedTransitionProgress)
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: scanTapFeedbackTrigger)
    }

    private func startScan() {
        guard clampedTransitionProgress == 0 else { return }
        scanTapFeedbackTrigger += 1
        onStart()
    }

    private func triggerConfetti() {
        showConfetti = true
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            showConfetti = false
        }
    }

   
    private func generateAIQuoteIfAvailable() async {
        guard shouldAttemptAIQuoteGeneration else {
            await applyFallbackDailyQuote()
            return
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.availability == .available {
                await MainActor.run { isGeneratingQuote = true }
                let session = LanguageModelSession(instructions: L10n.t("home.ai.instructions"))
                do {
                    let response = try await session.respond(to: L10n.t("home.ai.prompt"))
                    let text = response.content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    guard !Task.isCancelled, !text.isEmpty else { return }
                    await MainActor.run {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                            quote = EcoQuote(
                                id: "ai-\(Int(Date().timeIntervalSince1970))",
                                text: text,
                                source: L10n.t("home.ai.source")
                            )
                            isAIQuote = true
                            isGeneratingQuote = false
                        }
                    }
                    return
                } catch {}
            } else {
                await applyFallbackDailyQuote()
            }
        } else {
            await applyFallbackDailyQuote()
        }
        #else
        await applyFallbackDailyQuote()
        #endif
    }

    private func applyFallbackDailyQuote() async {
        guard !Task.isCancelled else { return }
        await MainActor.run {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                quote = EcoQuote.dailyQuote(for: Date())
                isAIQuote = false
                isGeneratingQuote = false
            }
        }
    }

    private func rotateDailyQuoteIfNeeded() {
        let next = EcoQuote.dailyQuote(for: Date())
        guard next.id != quote.id else { return }
        startQuoteRefresh()
    }

    private func startQuoteRefresh() {
        quoteTask?.cancel()
        quoteTask = Task { await generateAIQuoteIfAvailable() }
    }
}


private extension HomeView {
    var headerCompact: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(L10n.t("home.title"))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [.white, .white.opacity(0.85)]
                                : [AppPalette.textPrimary, AppPalette.textPrimary.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                        )
                    Text(L10n.t("home.streak.short", statsStore.streakDays))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay { Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1) }
                }
                .shadow(color: .orange.opacity(0.3), radius: 10, y: 3)
                .accessibilityLabel(L10n.t("home.streak.accessibility", statsStore.streakDays))
            }
            Text(L10n.t("home.subtitle"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.65) : AppPalette.textSecondary)
        }
        .padding(.horizontal, 24)
    }
}


struct ActivityRingCard: View {
    var statsStore: EcoStatsStore
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double { statsStore.levelProgress }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : AppPalette.compost.opacity(0.15),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [AppPalette.compost, AppPalette.accent, AppPalette.compost.opacity(0.8)]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: AppPalette.compost.opacity(0.4), radius: 8, x: 0, y: 4)

                VStack(spacing: 4) {
                    Text("\(statsStore.totalPoints)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [.white, .white.opacity(0.85)]
                                    : [AppPalette.textPrimary, AppPalette.textPrimary.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())

                    Text(L10n.t("home.points.label"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(
                            colorScheme == .dark
                                ? .white.opacity(0.5)
                                : AppPalette.textSecondary.opacity(0.7)
                        )
                }
            }
            .padding(.vertical, 24)

            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.compost)
                Text(L10n.t("home.points.remaining", statsStore.pointsToNextLevel))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.85) : AppPalette.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay { Capsule().fill(AppPalette.compost.opacity(colorScheme == .dark ? 0.15 : 0.1)) }
                    .overlay { Capsule().strokeBorder(.white.opacity(colorScheme == .dark ? 0.15 : 0.25), lineWidth: 1) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .applyCardBackground(colorScheme: colorScheme)
        .padding(.horizontal, 24)
    }
}


struct BentoStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let colorScheme: ColorScheme
    var size: CardSize = .medium

    enum CardSize {
        case small, medium, large
        var height: CGFloat {
            switch self {
            case .small: return 100
            case .medium, .large: return 120
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: size == .small ? 20 : 24, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: size == .small ? 36 : 40, height: size == .small ? 36 : 40)
                    .background { Circle().fill(iconColor.opacity(colorScheme == .dark ? 0.15 : 0.12)) }
                Spacer()
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: size == .small ? 22 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
                Text(label)
                    .font(.system(size: size == .small ? 12 : 13, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : AppPalette.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: size == .small ? 100 : .infinity, maxHeight: size.height)
        .padding(size == .small ? 14 : 18)
        .applyCardBackground(colorScheme: colorScheme)
    }
}


struct BentoProgressCard: View {
    let icon: String
    let iconColor: Color
    let progress: CGFloat
    let value: String
    let label: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background { Circle().fill(iconColor.opacity(colorScheme == .dark ? 0.15 : 0.12)) }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : AppPalette.textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.3)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : AppPalette.strokeSoft.opacity(0.3))
                            .frame(height: 8)
                        Capsule()
                            .fill(LinearGradient(colors: [AppPalette.compost, AppPalette.accent], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.72) : AppPalette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .applyCardBackground(colorScheme: colorScheme)
    }
}


struct QuoteCard: View {
    let quote: EcoQuote
    let isGenerating: Bool
    let isAIGenerated: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var showQuote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: isAIGenerated ? "sparkles" : "quote.opening")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isAIGenerated
                            ? LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [AppPalette.compost, AppPalette.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Spacer()
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView().tint(AppPalette.compost)
                    Text(L10n.t("quote.generating"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : AppPalette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                Text(quote.text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : AppPalette.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(showQuote ? 1 : 0)
                    .offset(y: showQuote ? 0 : 10)
                Text("— " + quote.source)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        isAIGenerated
                            ? LinearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [AppPalette.compost, AppPalette.accent], startPoint: .leading, endPoint: .trailing)
                    )
                    .opacity(showQuote ? 1 : 0)
                    .offset(y: showQuote ? 0 : 10)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .applyCardBackground(colorScheme: colorScheme)
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) { showQuote = true }
        }
        .onChange(of: quote.id) { _, _ in
            showQuote = false
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { showQuote = true }
        }
    }
}


struct ConfettiOverlay: UIViewRepresentable {
    var colors: [UIColor] = [.systemGreen, .systemYellow, .systemOrange, .systemPink, .systemBlue]
    var intensity: Float = 0.7
    var duration: TimeInterval = 1.6

    func makeUIView(context: Context) -> ConfettiUIView {
        let view = ConfettiUIView()
        view.start(colors: colors, intensity: intensity, duration: duration)
        return view
    }
    func updateUIView(_ uiView: ConfettiUIView, context: Context) {}

    final class ConfettiUIView: UIView {
        private let emitter = CAEmitterLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            layer.addSublayer(emitter)
            emitter.emitterShape = .line
            emitter.emitterMode = .surface
            emitter.birthRate = 0
        }
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        }

        func start(colors: [UIColor], intensity: Float, duration: TimeInterval) {
            emitter.emitterCells = colors.map { color in
                let cell = CAEmitterCell()
                cell.contents = makeImage(color: color).cgImage
                cell.birthRate = 12 * intensity
                cell.lifetime = 6.0
                cell.lifetimeRange = 1.0
                cell.velocity = 180
                cell.velocityRange = 80
                cell.emissionLongitude = .pi
                cell.emissionRange = .pi / 4
                cell.spin = 3.5
                cell.spinRange = 4.0
                cell.scale = 0.6
                cell.scaleRange = 0.3
                return cell
            }
            emitter.birthRate = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.emitter.birthRate = 0
            }
        }

        private func makeImage(color: UIColor) -> UIImage {
            let size = CGSize(width: 10, height: 14)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            let ctx = UIGraphicsGetCurrentContext()!
            ctx.setFillColor(color.cgColor)
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2).fill()
            let image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return image
        }
    }
}


struct BentoStatsGrid: View {
    var statsStore: EcoStatsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                BentoStatCard(
                    icon: "camera.viewfinder", iconColor: AppPalette.compost,
                    value: "\(statsStore.totalScans)", label: L10n.t("home.scans.label"),
                    colorScheme: colorScheme
                )
                BentoStatCard(
                    icon: "chart.bar.fill", iconColor: AppPalette.recycle,
                    value: L10n.t("home.level.short", statsStore.level), label: L10n.t("home.level.label"),
                    colorScheme: colorScheme
                )
            }
        }
        .padding(.horizontal, 24)
    }
}


extension View {
    @ViewBuilder
    func applyCardBackground(colorScheme: ColorScheme) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.25) : Color.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.15 : 0.25), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 20, y: 10)
    }

    @ViewBuilder
    func applyGlassMaterial(colorScheme: ColorScheme, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            let baseTint = tint ?? AppPalette.compost
            let glass: Glass = .regular
                .tint(baseTint.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .interactive()
            self
                .glassEffect(glass, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.15 : 0.25), lineWidth: 1)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 20, y: 10)
        } else {
            self
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial)
                        if let tint {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(tint.opacity(colorScheme == .dark ? 0.12 : 0.08))
                        } else {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.3))
                        }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.2 : 0.35), .clear],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 20, y: 10)
        }
    }

    @ViewBuilder
    func applyScannerGlass(colorScheme: ColorScheme) -> some View {
        if #available(iOS 26.0, *) {
            let scannerGlass: Glass = .regular
                .tint(AppPalette.compost.opacity(colorScheme == .dark ? 0.18 : 0.3))
                .interactive()
            self
                .glassEffect(scannerGlass, in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.24), lineWidth: 1) }
                .shadow(color: AppPalette.compost.opacity(colorScheme == .dark ? 0.18 : 0.35), radius: 20, y: 10)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 6)
        } else {
            self
                .background {
                    ZStack {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule()
                            .fill(LinearGradient(colors: [AppPalette.compost, AppPalette.accent],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                .opacity(colorScheme == .dark ? 0.62 : 0.85))
                    }
                }
                .overlay { Capsule().stroke(.white.opacity(colorScheme == .dark ? 0.2 : 0.32), lineWidth: 1) }
                .shadow(color: AppPalette.compost.opacity(colorScheme == .dark ? 0.2 : 0.35), radius: 20, y: 10)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 6)
        }
    }
}



private struct SectionEntranceModifier: ViewModifier {
    let show: Bool
    let index: Int
    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 16)
            .animation(.spring(response: 0.58, dampingFraction: 0.84).delay(Double(index) * 0.07), value: show)
    }
}

private extension View {
    func sectionEntrance(show: Bool, index: Int) -> some View {
        modifier(SectionEntranceModifier(show: show, index: index))
    }
}


struct FluidBackground: View {
    @State private var animate = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let baseColor       = colorScheme == .dark ? Color(hex: "11100F") : AppPalette.base
        let compostStrong   = colorScheme == .dark ? AppPalette.compost.opacity(0.25) : AppPalette.compost.opacity(0.15)
        let compostSoft     = colorScheme == .dark ? AppPalette.compost.opacity(0.09) : AppPalette.compost.opacity(0.05)
        let accentStrong    = colorScheme == .dark ? AppPalette.accent.opacity(0.22)  : AppPalette.accent.opacity(0.2)
        let accentSoft      = colorScheme == .dark ? AppPalette.accent.opacity(0.08)  : AppPalette.accent.opacity(0.05)
        let recycleStrong   = colorScheme == .dark ? AppPalette.recycle.opacity(0.16) : AppPalette.recycle.opacity(0.12)

        ZStack {
            baseColor
            Circle()
                .fill(RadialGradient(colors: [compostStrong, compostSoft, .clear], center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 400, height: 400).blur(radius: 40)
                .offset(x: animate ? -100 : -50, y: animate ? -200 : -150)
            Circle()
                .fill(RadialGradient(colors: [accentStrong, accentSoft, .clear], center: .center, startRadius: 0, endRadius: 180))
                .frame(width: 350, height: 350).blur(radius: 50)
                .offset(x: animate ? 120 : 80, y: animate ? 300 : 250)
            Circle()
                .fill(RadialGradient(colors: [recycleStrong, .clear], center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300).blur(radius: 60)
                .offset(x: animate ? -80 : -120, y: animate ? 400 : 350)
            if colorScheme == .dark {
                LinearGradient(colors: [.black.opacity(0.38), .clear, .black.opacity(0.42)], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}



struct EcoQuote: Equatable {
    let id: String
    let text: String
    let source: String

    static func dailyQuote(for date: Date) -> EcoQuote {
        let quotes = [
            EcoQuote(id: "q1", text: L10n.t("quote.q1.text"), source: L10n.t("quote.q1.source")),
            EcoQuote(id: "q2", text: L10n.t("quote.q2.text"), source: L10n.t("quote.q2.source")),
            EcoQuote(id: "q3", text: L10n.t("quote.q3.text"), source: L10n.t("quote.q3.source")),
            EcoQuote(id: "q4", text: L10n.t("quote.q4.text"), source: L10n.t("quote.q4.source")),
            EcoQuote(id: "q5", text: L10n.t("quote.q5.text"), source: L10n.t("quote.q5.source")),
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return quotes[day % quotes.count]
    }
}



enum AppPalette {
    static let base          = Color(hex: "F5F0E7")
    static let textPrimary   = Color(hex: "221E19")
    static let textSecondary = Color(hex: "625C56")
    static let accent        = Color(hex: "C9AE83")
    static let strokeSoft    = Color(hex: "D8CFC4")
    static let compost       = Color(hex: "83B86A")
    static let recycle       = Color(hex: "E9C86A")
    static let trash         = Color(hex: "2F2D2A")
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}


#Preview {
    let mockStats = EcoStatsStore()
    HomeView(statsStore: mockStats, onStart: {}, scanTransitionProgress: 0)
}

