import SwiftUI

private struct OnboardingHighlight: Identifiable {
    let id: String
    let icon: String
    let text: String
}

private struct OnboardingFeatureStep: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let highlights: [OnboardingHighlight]
}

private struct QuizOption: Identifiable {
    let id: Int
    let title: String
    let icon: String
}

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var selection = 0
    @State private var selectedQuizAnswer: Int?
    @State private var quizSuccessTrigger = 0

    private let correctQuizIndex = 0

    private var quizIndex: Int { features.count }
    private var totalSteps: Int { features.count + 1 }
    private var isOnQuiz: Bool { selection == quizIndex }

    private var canAdvance: Bool {
        !isOnQuiz || selectedQuizAnswer == correctQuizIndex
    }

    private var primaryActionTitle: String {
        selection == totalSteps - 1
            ? localized("onboarding.start")
            : localized("onboarding.next")
    }

    private var primaryActionIcon: String {
        selection == totalSteps - 1 ? "checkmark" : "arrow.right"
    }

    private var features: [OnboardingFeatureStep] {
        [
            OnboardingFeatureStep(
                id: 0,
                title: localized("onboarding.page1.title"),
                subtitle: localized("onboarding.page1.subtitle"),
                symbol: "camera.viewfinder",
                tint: AppPalette.accent,
                highlights: [
                    fixedHighlight(id: "scan-1", icon: "camera.fill", key: "scan.take_photo"),
                    fixedHighlight(id: "scan-2", icon: "sparkles", key: "scan.status.analyzing"),
                    fixedHighlight(id: "scan-3", icon: "arrow.triangle.2.circlepath", key: "scan.sort.recycle"),
                    fixedHighlight(id: "scan-4", icon: "mic.fill", key: "onboarding.page1.siri")
                ]
            ),
            OnboardingFeatureStep(
                id: 1,
                title: localized("onboarding.page2.title"),
                subtitle: localized("onboarding.page2.subtitle"),
                symbol: "leaf.fill",
                tint: AppPalette.compost,
                highlights: bulletHighlights(
                    idPrefix: "why",
                    key: "onboarding.why.subtitle",
                    icons: ["shippingbox.fill", "aqi.medium", "globe.europe.africa.fill"]
                )
            ),
            OnboardingFeatureStep(
                id: 2,
                title: localized("onboarding.page3.title"),
                subtitle: localized("onboarding.page3.subtitle"),
                symbol: "rosette",
                tint: AppPalette.recycle,
                highlights: [
                    fixedHighlight(id: "points-1", icon: "plus.circle.fill", key: "home.total.points"),
                    fixedHighlight(id: "points-2", icon: "chart.line.uptrend.xyaxis", key: "home.level.label"),
                    fixedHighlight(id: "points-3", icon: "trophy.fill", key: "home.trophies.title")
                ]
            ),
            OnboardingFeatureStep(
                id: 3,
                title: localized("onboarding.stats.title"),
                subtitle: localized("onboarding.stats.subtitle"),
                symbol: "chart.bar.xaxis",
                tint: AppPalette.accent,
                highlights: bulletHighlights(
                    idPrefix: "stats",
                    key: "onboarding.stats.subtitle",
                    icons: ["tree.fill", "bolt.fill", "leaf.arrow.circlepath"]
                )
            )
        ]
    }

    private var quizOptions: [QuizOption] {
        [
            QuizOption(id: 0, title: localized("onboarding.quiz.q1.option.recycle"), icon: "arrow.triangle.2.circlepath"),
            QuizOption(id: 1, title: localized("onboarding.quiz.q1.option.compost"), icon: "leaf.fill"),
            QuizOption(id: 2, title: localized("onboarding.quiz.q1.option.trash"), icon: "trash.fill")
        ]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FluidBackground()
                    .ignoresSafeArea()

                if colorScheme == .dark {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                }

                VStack(spacing: 14) {
                    topBar
                        .frame(maxWidth: contentWidth(for: geo))

                    progressCard
                        .frame(maxWidth: contentWidth(for: geo))

                    pager
                        .frame(maxWidth: contentWidth(for: geo))

                    pageIndicators

                    footer
                        .frame(maxWidth: contentWidth(for: geo))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 14)
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
        }
        .sensoryFeedback(.success, trigger: quizSuccessTrigger)
    }

    private var topBar: some View {
        HStack {
            Button(action: stepBack) {
                Label(localized("onboarding.back"), systemImage: "chevron.left")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
            }
            .buttonStyle(.plain)
            .opacity(selection == 0 ? 0 : 1)
            .allowsHitTesting(selection != 0)

            Spacer()

            if selection < totalSteps - 1 {
                Button(action: onFinish) {
                    Text(localized("onboarding.skip"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.86) : AppPalette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text(localized("onboarding.progress", selection + 1, totalSteps))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.84) : AppPalette.textSecondary)

                Spacer()

                Text("\(selection + 1)/\(totalSteps)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
            }

            ProgressView(value: Double(selection), total: Double(max(totalSteps - 1, 1)))
                .tint(AppPalette.compost)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 1)
                }
        }
    }

    private var pager: some View {
        TabView(selection: $selection) {
            ForEach(features) { feature in
                OnboardingFeatureCard(step: feature)
                    .tag(feature.id)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
            }

            OnboardingQuizCard(
                title: localized("onboarding.quiz.title"),
                question: localized("onboarding.quiz.q1.title"),
                options: quizOptions,
                selectedIndex: selectedQuizAnswer,
                correctIndex: correctQuizIndex,
                correctText: localized("onboarding.quiz.q1.feedback.correct"),
                wrongText: localized("onboarding.quiz.q1.feedback.wrong"),
                explanationText: localized("scan.sort.recycle"),
                onSelect: selectQuizAnswer
            )
            .tag(quizIndex)
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selection)
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == selection
                          ? (colorScheme == .dark ? Color.white : AppPalette.textPrimary)
                          : Color.white.opacity(colorScheme == .dark ? 0.25 : 0.5))
                    .frame(width: index == selection ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selection)
            }
        }
        .padding(.top, 2)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if isOnQuiz, selectedQuizAnswer != correctQuizIndex {
                Text(localized("onboarding.quiz.gate"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.82) : AppPalette.textSecondary)
            }

            Button(action: advance) {
                HStack(spacing: 10) {
                    Text(primaryActionTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Image(systemName: primaryActionIcon)
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppPalette.compost, AppPalette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.18 : 0.26), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.45)
        }
    }

    private func advance() {
        if selection < totalSteps - 1 {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                selection += 1
            }
            return
        }

        onFinish()
    }

    private func stepBack() {
        guard selection > 0 else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            selection -= 1
        }
    }

    private func selectQuizAnswer(_ index: Int) {
        let wasCorrect = (selectedQuizAnswer == correctQuizIndex)
        selectedQuizAnswer = index

        if !wasCorrect, index == correctQuizIndex {
            quizSuccessTrigger += 1
        }
    }

    private func contentWidth(for geo: GeometryProxy) -> CGFloat {
        max(270, min(geo.size.width - 8, 700))
    }

    private func fixedHighlight(id: String, icon: String, key: String) -> OnboardingHighlight {
        OnboardingHighlight(id: id, icon: icon, text: localized(key))
    }

    private func bulletHighlights(idPrefix: String, key: String, icons: [String]) -> [OnboardingHighlight] {
        let raw = localized(key)
        let lines = raw
            .components(separatedBy: "\n")
            .map(normalizedBulletLine)
            .filter { !$0.isEmpty }

        let count = min(lines.count, icons.count)
        return (0..<count).map { idx in
            OnboardingHighlight(id: "\(idPrefix)-\(idx)", icon: icons[idx], text: lines[idx])
        }
    }

    private func normalizedBulletLine(_ line: String) -> String {
        var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("-") || value.hasPrefix("•") {
            value.removeFirst()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private func localized(_ key: String) -> String {
        L10n.t(key)
    }

    private func localized(_ key: String, _ args: CVarArg...) -> String {
        String(format: L10n.t(key), locale: .current, arguments: args)
    }
}

private struct OnboardingFeatureCard: View {
    let step: OnboardingFeatureStep

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero

            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)

                Text(step.subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.82) : AppPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(step.highlights) { highlight in
                    highlightRow(highlight)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 1)
                }
        }
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [step.tint.opacity(0.95), step.tint.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 124, height: 124)
                .shadow(color: step.tint.opacity(0.4), radius: 16, y: 10)

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 124, height: 124)

            Image(systemName: step.symbol)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightRow(_ highlight: OnboardingHighlight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: highlight.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(step.tint)
                .frame(width: 22)

            Text(highlight.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : AppPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(step.tint.opacity(colorScheme == .dark ? 0.23 : 0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(step.tint.opacity(0.3), lineWidth: 1)
                }
        }
    }
}

private struct OnboardingQuizCard: View {
    let title: String
    let question: String
    let options: [QuizOption]
    let selectedIndex: Int?
    let correctIndex: Int
    let correctText: String
    let wrongText: String
    let explanationText: String
    let onSelect: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.accent.opacity(0.95), AppPalette.recycle.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 124, height: 124)
                    .shadow(color: AppPalette.accent.opacity(0.38), radius: 16, y: 10)

                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 124, height: 124)

                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(question)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : AppPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(options) { option in
                    optionRow(option)
                }
            }

            if let selectedIndex {
                feedbackBlock(isCorrect: selectedIndex == correctIndex)
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 1)
                }
        }
    }

    private func optionRow(_ option: QuizOption) -> some View {
        let isSelected = selectedIndex == option.id
        let isCorrect = option.id == correctIndex

        return Button {
            onSelect(option.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: option.icon)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 24)

                Text(option.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSelected {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundStyle(optionForeground(isSelected: isSelected))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(optionBackground(isSelected: isSelected, isCorrect: isCorrect))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(optionBorder(isSelected: isSelected, isCorrect: isCorrect), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private func feedbackBlock(isCorrect: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.seal.fill" : "xmark.octagon.fill")
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text(isCorrect ? correctText : wrongText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                Text(explanationText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isCorrect ? AppPalette.compost : Color(hex: "C45A5A"))
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill((isCorrect ? AppPalette.compost : Color(hex: "C45A5A")).opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder((isCorrect ? AppPalette.compost : Color(hex: "C45A5A")).opacity(0.25), lineWidth: 1)
                }
        }
    }

    private func optionForeground(isSelected: Bool) -> Color {
        if isSelected { return .white }
        return colorScheme == .dark ? .white : AppPalette.textPrimary
    }

    private func optionBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        if isSelected {
            return (isCorrect ? AppPalette.compost : Color(hex: "C45A5A")).opacity(0.9)
        }
        return .white.opacity(colorScheme == .dark ? 0.09 : 0.58)
    }

    private func optionBorder(isSelected: Bool, isCorrect: Bool) -> Color {
        if isSelected {
            return .white.opacity(0.28)
        }
        return (isCorrect ? AppPalette.compost : AppPalette.strokeSoft).opacity(0.35)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
