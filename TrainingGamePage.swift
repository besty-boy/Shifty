import Foundation
import SwiftUI

struct TrainingGamePage: View {
    var statsStore: EcoStatsStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var feedbackState: FeedbackState = .none
    @State private var localConfetti = false
    @State private var score: Int = 0
    @State private var wrongFeedbackCount = 0
    @State private var sessionRecorded = false

    enum FeedbackState: Equatable {
        case none
        case correct
        case wrong(correctCategory: WasteCategory)

        var isCorrect: Bool {
            if case .correct = self { return true }
            return false
        }
    }

    private struct TrainingItem: Identifiable {
        let id = UUID()
        let nameKey: String
        let emoji: String
        let category: WasteCategory
        let accent: Color
    }

    private let items: [TrainingItem] = [
        TrainingItem(nameKey: "mock.object.banana",         emoji: "🍌", category: .compost, accent: Color(hex: "E19554")),
        TrainingItem(nameKey: "mock.object.plastic_bottle", emoji: "🧴", category: .recycle, accent: Color(hex: "4A90D9")),
        TrainingItem(nameKey: "mock.object.coffee_cup",     emoji: "☕️", category: .trash,   accent: Color(hex: "7B6AA2")),
        TrainingItem(nameKey: "mock.object.cardboard",      emoji: "📦", category: .recycle, accent: Color(hex: "4C9A72")),
        TrainingItem(nameKey: "mock.object.apple_core",     emoji: "🍎", category: .compost, accent: Color(hex: "D75A57")),
        TrainingItem(nameKey: "mock.object.glass_jar",      emoji: "🫙", category: .trash, accent: Color(hex: "2798AE")),
        TrainingItem(nameKey: "mock.object.chip_bag",       emoji: "🥔", category: .recycle,   accent: Color(hex: "C77B2A")),
        TrainingItem(nameKey: "mock.object.newspaper",      emoji: "📰", category: .recycle, accent: Color(hex: "8D7AB7")),
        TrainingItem(nameKey: "mock.object.eggshells",      emoji: "🥚", category: .compost, accent: Color(hex: "78A857")),
        TrainingItem(nameKey: "mock.object.styrofoam",      emoji: "🧊", category: .compost,   accent: Color(hex: "AA5E57")),
    ]

    private let swipeThreshold: CGFloat = 90

    private var isFinished: Bool { currentIndex >= items.count }

    private var currentItem: TrainingItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    private var displayedStep: Int {
        isFinished ? items.count : min(currentIndex + 1, items.count)
    }

    private var progress: Double {
        guard !items.isEmpty else { return 0 }
        return min(max(Double(currentIndex) / Double(items.count), 0), 1)
    }

    private var isInputLocked: Bool {
        isFinished || feedbackState != .none
    }
    
    private var hintedCategory: WasteCategory? {
        let dx = dragOffset.width
        let dy = dragOffset.height
        if abs(dy) > abs(dx), dy < -30 { return .recycle }
        if dx < -30 { return .compost }
        if dx > 30 { return .trash }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FluidBackground()
                    .overlay {
                        if colorScheme == .dark {
                            Color.black.opacity(0.32).ignoresSafeArea()
                        }
                    }

                VStack(spacing: 12) {
                    trainingHeader
                        .frame(maxWidth: contentWidth(for: geo))

                    if isFinished {
                        finishedView(maxWidth: contentWidth(for: geo))
                    } else {
                        cardDeck(geo: geo)
                            .frame(maxWidth: contentWidth(for: geo))

                        feedbackBanner
                            .frame(maxWidth: contentWidth(for: geo))

                        actionRow
                            .frame(maxWidth: contentWidth(for: geo))
                            .padding(.top, -30)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 16)
                .padding(.horizontal, 12)
                .padding(.bottom, 16)

                if localConfetti {
                    ConfettiOverlay()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .sensoryFeedback(.success, trigger: score)
        .sensoryFeedback(.error, trigger: wrongFeedbackCount)
    }

    private var trainingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(localized("game.title"))
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
                        .lineLimit(1)

                    Text(localized("game.instructions"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.78) : AppPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                scoreChip
            }

            VStack(spacing: 8) {
                HStack {
                    Text(localized("game.counter", displayedStep, items.count))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.84) : AppPalette.textSecondary)

                    Spacer()

                    Text(localized("game.stage", displayedStep))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.84) : AppPalette.textSecondary)
                }

                ProgressView(value: progress)
                    .tint(AppPalette.compost)
                    .scaleEffect(x: 1, y: 1.25, anchor: .center)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.18 : 0.3), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
    }

    private var scoreChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppPalette.compost)

            Text("\(score)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(.white.opacity(colorScheme == .dark ? 0.14 : 0.86))
        }
        .accessibilityLabel(Text(L10n.t("game.score")))
        .accessibilityValue(Text("\(score)"))
    }

    private func cardDeck(geo: GeometryProxy) -> some View {
        ZStack {
            if let item = currentItem {
                if items.count - currentIndex > 1 {
                    ForEach((1...min(2, items.count - currentIndex - 1)).reversed(), id: \.self) { offset in
                        trainingCard(
                            item: items[currentIndex + offset],
                            isTop: false,
                            width: contentWidth(for: geo),
                            height: cardHeight(for: geo)
                        )
                        .scaleEffect(1 - CGFloat(offset) * 0.04)
                        .offset(y: CGFloat(offset) * 14)
                        .opacity(1 - Double(offset) * 0.18)
                        .zIndex(Double(-offset))
                    }
                }

                topCard(item: item, geo: geo)
                    .zIndex(10)
            }
        }
        .frame(height: cardHeight(for: geo) + 26)
    }

    private func topCard(item: TrainingItem, geo: GeometryProxy) -> some View {
        trainingCard(item: item, isTop: true, width: contentWidth(for: geo), height: cardHeight(for: geo))
            .offset(dragOffset)
            .rotationEffect(.degrees(Double(dragOffset.width / 24)))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if abs(dy) > abs(dx), dy < -swipeThreshold {
                            commitSwipe(target: .recycle)
                        } else if dx < -swipeThreshold {
                            commitSwipe(target: .compost)
                        } else if dx > swipeThreshold {
                            commitSwipe(target: .trash)
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(L10n.t(item.nameKey)))
            .accessibilityValue(Text(localized("game.card.swipe_hint")))
            .accessibilityAction(named: Text(categoryName(.compost))) {
                tapBin(.compost)
            }
            .accessibilityAction(named: Text(categoryName(.recycle))) {
                tapBin(.recycle)
            }
            .accessibilityAction(named: Text(categoryName(.trash))) {
                tapBin(.trash)
            }
    }

    @ViewBuilder
    private var feedbackBanner: some View {
        switch feedbackState {
        case .none:
            Color.clear.frame(height: 52)
        case .correct:
            feedbackPill(
                icon: "checkmark.circle.fill",
                text: localized("game.feedback.correct"),
                tint: AppPalette.compost
            )
            .frame(height: 52)
        case .wrong(let category):
            feedbackPill(
                icon: "xmark.circle.fill",
                text: localized(
                    "game.feedback.wrong_with_answer",
                    categoryName(category)
                ),
                tint: Color(hex: "C45A5A")
            )
            .frame(height: 52)
        }
    }

    private func feedbackPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            actionButton(
                category: .compost,
                icon: "leaf.fill",
                label: categoryName(.compost),
                tint: categoryColor(.compost),
                highlighted: hintedCategory == .compost
            ) {
                tapBin(.compost)
            }

            actionButton(
                category: .recycle,
                icon: "arrow.triangle.2.circlepath",
                label: categoryName(.recycle),
                tint: categoryColor(.recycle),
                highlighted: hintedCategory == .recycle
            ) {
                tapBin(.recycle)
            }

            actionButton(
                category: .trash,
                icon: "trash.fill",
                label: categoryName(.trash),
                tint: categoryColor(.trash),
                highlighted: hintedCategory == .trash
            ) {
                tapBin(.trash)
            }
        }
    }

    private func actionButton(
        category: WasteCategory,
        icon: String,
        label: String,
        tint: Color,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle().fill(tint)
                    }

                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Image(systemName: categoryDirectionSymbol(category))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.72) : AppPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(highlighted ? (colorScheme == .dark ? 0.35 : 0.25) : (colorScheme == .dark ? 0.2 : 0.12)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(tint.opacity(highlighted ? 0.8 : 0.35), lineWidth: highlighted ? 2 : 1)
                    }
            }
            .shadow(color: highlighted ? tint.opacity(0.35) : .clear, radius: highlighted ? 10 : 0, y: highlighted ? 6 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isInputLocked)
        .accessibilityLabel(Text(label))
        .accessibilityHint(Text(accessibilityHint(for: category)))
    }

    private func finishedView(maxWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            Text("🏁")
                .font(.system(size: 62))

            Text(localized("game.completed"))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)

            Text(localized("game.finished.score", score, items.count))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.compost)

            Text(performanceMessage)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.82) : AppPalette.textSecondary)
                .padding(.horizontal, 8)

            Button {
                restartTraining()
            } label: {
                Text(localized("game.restart"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppPalette.compost)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)
        }
        .frame(maxWidth: maxWidth)
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.18 : 0.3), lineWidth: 1)
                }
        }
    }

    private func trainingCard(item: TrainingItem, isTop: Bool, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [item.accent.opacity(0.95), item.accent.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.09))

            VStack(spacing: 10) {
                Text(item.emoji)
                    .font(.system(size: 102))
                    .shadow(color: .black.opacity(0.16), radius: 15, y: 8)

                Text(L10n.t(item.nameKey))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 14)
            }
            .padding(.bottom, 30)
            .padding(.horizontal, 20)
        }
        .frame(width: width, height: height)
        .shadow(color: item.accent.opacity(isTop ? 0.45 : 0.2), radius: isTop ? 24 : 12, y: isTop ? 12 : 6)
        .shadow(color: .black.opacity(isTop ? 0.2 : 0.1), radius: isTop ? 13 : 6, y: isTop ? 8 : 4)
    }

    private func tapBin(_ category: WasteCategory) {
        guard !isFinished, case .none = feedbackState else { return }
        commitSwipe(target: category)
    }

    private func commitSwipe(target: WasteCategory) {
        guard case .none = feedbackState, let item = currentItem else { return }

        let isCorrect = target == item.category

        feedbackState = isCorrect ? .correct : .wrong(correctCategory: item.category)
        if isCorrect { score += 1 } else { wrongFeedbackCount += 1 }

        if isCorrect {
            localConfetti = true
            statsStore.registerTrainingCorrectAnswer(category: item.category)
        }

        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
            dragOffset = flyOutOffset(for: target)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            advanceToNextCard()
            try? await Task.sleep(for: .milliseconds(220))
            feedbackState = .none
            if isCorrect {
                localConfetti = false
            }
        }
    }

    @MainActor
    private func advanceToNextCard() {
        guard currentIndex < items.count else { return }

        dragOffset = .zero
        let nextIndex = currentIndex + 1
        currentIndex = nextIndex

        if nextIndex >= items.count, !sessionRecorded {
            sessionRecorded = true
            statsStore.registerTrainingSession(score: score, totalItems: items.count)
        }
    }

    private func restartTraining() {
        currentIndex = 0
        dragOffset = .zero
        feedbackState = .none
        localConfetti = false
        score = 0
        sessionRecorded = false
    }

    private var performanceMessage: String {
        guard !items.isEmpty else { return localized("game.feedback.correct") }

        let ratio = Double(score) / Double(items.count)
        switch ratio {
        case 0.9...:
            return L10n.t("game.performance.excellent")
        case 0.7..<0.9:
            return L10n.t("game.performance.strong")
        case 0.4..<0.7:
            return L10n.t("game.performance.good")
        default:
            return L10n.t("game.performance.keep_training")
        }
    }

    private func contentWidth(for geo: GeometryProxy) -> CGFloat {
        max(260, min(geo.size.width - 24, 680))
    }

    private func cardHeight(for geo: GeometryProxy) -> CGFloat {
        let h = geo.size.height
        guard h.isFinite, h > 0 else { return 320 }
        return min(max(h * 0.48, 260), 440)
    }

    private func flyOutOffset(for category: WasteCategory) -> CGSize {
        switch category {
        case .compost:
            return CGSize(width: -640, height: -100)
        case .recycle:
            return CGSize(width: 0, height: -760)
        case .trash:
            return CGSize(width: 640, height: -100)
        }
    }

    private func accessibilityHint(for category: WasteCategory) -> String {
        switch category {
        case .compost:
            return localized("game.card.swipe_hint")
        case .recycle:
            return localized("game.card.swipe_hint")
        case .trash:
            return localized("game.card.swipe_hint")
        }
    }

    private func categoryColor(_ category: WasteCategory) -> Color {
        switch category {
        case .compost:
            return AppPalette.compost
        case .recycle:
            return AppPalette.recycle
        case .trash:
            return Color(hex: "5C5A56")
        }
    }

    private func categoryIcon(_ category: WasteCategory) -> String {
        switch category {
        case .compost:
            return "leaf.fill"
        case .recycle:
            return "arrow.triangle.2.circlepath"
        case .trash:
            return "trash.fill"
        }
    }

    private func categoryDirectionSymbol(_ category: WasteCategory) -> String {
        switch category {
        case .compost:
            return "arrow.left"
        case .recycle:
            return "arrow.up"
        case .trash:
            return "arrow.right"
        }
    }

    private func categoryName(_ category: WasteCategory) -> String {
        switch category {
        case .compost:
            return L10n.t("waste.category.compost")
        case .recycle:
            return L10n.t("waste.category.recycle")
        case .trash:
            return L10n.t("waste.category.trash")
        }
    }

    private func localized(_ key: String) -> String {
        L10n.t(key)
    }

    private func localized(_ key: String, _ args: CVarArg...) -> String {
        String(format: L10n.t(key), locale: .current, arguments: args)
    }
}

#Preview {
    TrainingGamePage(statsStore: EcoStatsStore())
}

