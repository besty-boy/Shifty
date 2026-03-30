import SwiftUI
import UIKit

struct ScanView: View {
    var viewModel: ScanViewModel
    var statsStore: EcoStatsStore
    let onClose: () -> Void

    @State private var dragOffsetY: CGFloat = 0
    @State private var isClosingBySwipe = false
    @State private var shutterPressed = false
    @State private var awardedResult: ClassificationResult?
    @State private var shutterResetTask: Task<Void, Never>?
    @State private var closeTask: Task<Void, Never>?
    @State private var captureFeedbackTrigger = 0
    @State private var closeFeedbackTrigger = 0
    @State private var retakeFeedbackTrigger = 0

    private enum UIState {
        case idle
        case analyzing
        case result
    }

    private var uiState: UIState {
        if viewModel.result != nil { return .result }
        if viewModel.isAnalyzing { return .analyzing }
        return .idle
    }

    private var isCaptured: Bool {
        viewModel.capturedImage != nil
    }

    var body: some View {
        GeometryReader { geometry in
            let closeProgress = dismissProgress(height: geometry.size.height)

            ZStack {
                CameraPreviewView(session: viewModel.cameraManager.session)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        .black.opacity(0.3),
                        .clear,
                        .clear,
                        .black.opacity(0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isCaptured {
                    captureBackdrop
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                EdgeGlow(color: edgeColor, isActive: uiState != .idle)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, max(geometry.safeAreaInsets.top + 2, 8))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    Spacer(minLength: 40)

                    ZStack {
                        if let image = viewModel.capturedImage {
                            CapturedFocusPhoto(image: image)
                                .transition(.scale(scale: 0.98).combined(with: .opacity))
                        }

                        FocusFrame(
                            color: edgeColor,
                            frozen: viewModel.capturedImage != nil,
                            isAnalyzing: uiState == .analyzing
                        )
                    }
                    .frame(width: 240, height: 240)
                    .accessibilityHidden(true)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScanRegionFramePreferenceKey.self,
                                value: proxy.frame(in: .named("scanSpace"))
                            )
                        }
                    )

                    Spacer(minLength: 40)

                    statePanel
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    controls
                        .padding(.horizontal, 20)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 20)
                }

                if viewModel.isPermissionDenied {
                    PermissionOverlay()
                        .padding(24)
                }

                Color.white
                    .opacity(viewModel.flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .animation(.easeInOut(duration: 0.25), value: isCaptured)
            .offset(y: dragOffsetY)
            .scaleEffect(1 - (closeProgress * 0.035))
            .opacity(1 - Double(closeProgress) * 0.05)
            .simultaneousGesture(closeGesture(height: geometry.size.height))
            .coordinateSpace(name: "scanSpace")
            .onAppear {
                viewModel.updateScanRegion(
                    normalizedRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
                    previewSize: geometry.size
                )
            }
            .onPreferenceChange(ScanRegionFramePreferenceKey.self) { frame in
                let normalized = normalizedRect(for: frame, in: geometry.size)
                viewModel.updateScanRegion(
                    normalizedRect: normalized,
                    previewSize: geometry.size
                )
            }
            .onChange(of: viewModel.result) { _, newResult in
                guard let newResult else {
                    awardedResult = nil
                    return
                }
                handleResult(newResult)
                announceClassificationResultForVoiceOver(newResult)
            }
            .onChange(of: viewModel.isAnalyzing) { _, isAnalyzing in
                guard isAnalyzing else { return }
                announceForVoiceOver(L10n.t("scan.analyzing.title"))
            }
            .onChange(of: viewModel.isPermissionDenied) { _, isDenied in
                guard isDenied else { return }
                announceForVoiceOver(L10n.t("scan.permission.required"))
            }
            .onDisappear {
                shutterResetTask?.cancel()
                shutterResetTask = nil
                closeTask?.cancel()
                closeTask = nil
                dragOffsetY = 0
                isClosingBySwipe = false
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: captureFeedbackTrigger)
            .sensoryFeedback(.impact(weight: .light), trigger: closeFeedbackTrigger)
            .sensoryFeedback(.impact(weight: .light), trigger: retakeFeedbackTrigger)
            .sensoryFeedback(trigger: viewModel.feedbackEvent) { _, event in
                guard let event else { return nil }
                switch event.kind {
                case .impactLight:
                    return .impact(weight: .light)
                case .success:
                    return .success
                case .warning:
                    return .warning
                case .error:
                    return .error
                }
            }
        }
    }

    private var edgeColor: Color {
        switch uiState {
        case .idle:
            return .white
        case .analyzing:
            return AppPalette.accent
        case .result:
            guard let category = viewModel.result?.category else { return .white }
            switch category {
            case .compost: return AppPalette.compost
            case .recycle: return AppPalette.recycle
            case .trash: return AppPalette.trash
            }
        }
    }

    private var captureBackdrop: some View {
        ZStack {
            Rectangle()
                .fill(backdropColor.opacity(0.4))
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }

    private var backdropColor: Color {
        guard let category = viewModel.result?.category else {
            return viewModel.isAnalyzing ? AppPalette.accent : .black
        }

        switch category {
        case .compost:
            return AppPalette.compost
        case .recycle:
            return AppPalette.recycle
        case .trash:
            return AppPalette.trash
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: handleClose) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .accessibilityLabel(L10n.t("scan.close"))

            Spacer()
        }
    }
    
    
    private func handleClose() {
        closeFeedbackTrigger += 1
        onClose()
    }

    @ViewBuilder
    private var statePanel: some View {
        Group {
            switch uiState {
            case .idle:
                IdleCard(message: viewModel.statusMessage)
            case .analyzing:
                AnalyzingCard()
            case .result:
                if let result = viewModel.result {
                    ResultCard(
                        result: result,
                        anecdote: viewModel.capturedAnecdote,
                        pointsGain: statsStore.latestPointsGain
                    )
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: uiState)
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: 16) {
            if viewModel.capturedImage != nil {
                Button(action: {
                    awardedResult = nil
                    retakeFeedbackTrigger += 1
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.retakePhoto()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold))
                        Text(L10n.t("scan.new"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.t("scan.new")))
                .accessibilityHint(Text(L10n.t("scan.new.accessibility")))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))

                Spacer()
            } else {
                Spacer()
                    .frame(width: 100)
            }

            Spacer()

            shutterButton

            Spacer()

            VStack(spacing: 3) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                Text(L10n.t("scan.swipe_hint"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 100)
            .accessibilityHidden(true)
        }
        .frame(height: 72)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: viewModel.capturedImage != nil)
    }

    private var shutterButton: some View {
        Button(action: captureAction) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 76, height: 76)
                
                Circle()
                    .fill(.white)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 2)
                            .padding(4)
                    )
            }
            .scaleEffect(shutterPressed ? 0.85 : 1)
            .shadow(color: .white.opacity(0.3), radius: 12, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: shutterPressed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.t("scan.take_photo")))
        .accessibilityValue(Text(shutterAccessibilityValue))
        .accessibilityHint(Text(L10n.t("scan.new.accessibility")))
        .disabled(viewModel.isAnalyzing || viewModel.isPermissionDenied || viewModel.capturedImage != nil)
        .opacity((viewModel.isAnalyzing || viewModel.capturedImage != nil) ? 0.4 : 1)
    }

    private var shutterAccessibilityValue: String {
        if viewModel.isPermissionDenied { return L10n.t("scan.permission.required") }
        if viewModel.isAnalyzing { return L10n.t("scan.analyzing.title") }
        if viewModel.capturedImage != nil { return L10n.t("scan.new.accessibility") }
        return L10n.t("scan.ready.title")
    }

    private func captureAction() {
        guard !viewModel.isAnalyzing else { return }

        captureFeedbackTrigger += 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            shutterPressed = true
        }

        shutterResetTask?.cancel()
        shutterResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                shutterPressed = false
            }
        }

        viewModel.captureAndAnalyze()
    }

    private func closeGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isClosingBySwipe else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else { return }

                let translation = max(0, value.translation.height)
                let limit = max(height * 0.42, 220)
                dragOffsetY = dampedOffset(for: translation, limit: limit)
            }
            .onEnded { value in
                guard !isClosingBySwipe else { return }

                let verticalTranslation = max(value.translation.height, 0)
                let projectedTranslation = max(value.predictedEndTranslation.height, verticalTranslation)
                let distanceThreshold = max(height * 0.17, 110)
                let projectedThreshold = max(height * 0.28, 180)

                if verticalTranslation > distanceThreshold || projectedTranslation > projectedThreshold {
                    isClosingBySwipe = true
                    closeFeedbackTrigger += 1
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        dragOffsetY = height * 1.05
                    }
                    closeTask?.cancel()
                    closeTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(140))
                        guard !Task.isCancelled else { return }
                        onClose()
                        dragOffsetY = 0
                        isClosingBySwipe = false
                    }
                } else {
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                        dragOffsetY = 0
                    }
                }
            }
    }

    private func dismissProgress(height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        return min(max(dragOffsetY / (height * 0.28), 0), 1)
    }
    
    private func dampedOffset(for translation: CGFloat, limit: CGFloat) -> CGFloat {
        guard limit > 0 else { return 0 }

        let normalized = max(0, translation) / limit
        let eased = 1 - (1 / (normalized + 1))
        return min(eased * limit * 1.25, limit)
    }

    private func normalizedRect(for frame: CGRect, in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else {
            return CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        }
        return CGRect(
            x: frame.minX / size.width,
            y: frame.minY / size.height,
            width: frame.width / size.width,
            height: frame.height / size.height
        )
    }

    private func handleResult(_ result: ClassificationResult) {
        guard awardedResult != result else { return }
        awardedResult = result
        statsStore.registerSuccessfulScan(result: result)
    }

    private func sortInstruction(for category: WasteCategory) -> String {
        switch category {
        case .compost:
            return L10n.t("scan.sort.compost")
        case .recycle:
            return L10n.t("scan.sort.recycle")
        case .trash:
            return L10n.t("scan.sort.trash")
        }
    }

    private func announceClassificationResultForVoiceOver(_ result: ClassificationResult) {
        let objectName = result.objectName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let subject = objectName.isEmpty ? result.category.localizedName : objectName
        let confidenceText = ConfidenceLevel.from(confidence: result.confidence).localizedName
        let message = "\(subject). \(sortInstruction(for: result.category)) \(confidenceText)."
        announceForVoiceOver(message)
    }

    private func announceForVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }

        let cleaned = message
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return }
        UIAccessibility.post(notification: .announcement, argument: cleaned)
    }
}



private struct IdleCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                Text(L10n.t("scan.new"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(AppPalette.accent)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L10n.t("scan.ready.title")))
        .accessibilityValue(Text(message))
    }
}

private struct AnalyzingCard: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppPalette.accent.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .opacity(pulse ? 0.5 : 1.0)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppPalette.accent))
                    .scaleEffect(0.9)
            }

            Text(L10n.t("scan.analyzing"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.accent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: AppPalette.accent.opacity(0.2), radius: 12, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.t("scan.analyzing.title")))
        .accessibilityValue(Text(L10n.t("scan.analyzing.subtitle")))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct ResultCard: View {
    let result: ClassificationResult
    let anecdote: String
    let pointsGain: Int
    @State private var isAnecdoteExpanded = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 42, height: 42)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(textColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.localizedName.uppercased(with: Locale.current))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(textColor.opacity(0.7))
                        .kerning(0.45)

                    if let objectDisplayName {
                        Text(objectDisplayName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if pointsGain > 0 {
                    VStack(spacing: 2) {
                        Text("+\(pointsGain)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                        Text(L10n.t("scan.points"))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(categoryColor.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            Rectangle()
                .fill(textColor.opacity(0.15))
                .frame(height: 1)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.t("scan.instruction.title"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .kerning(0.25)
                }
                .foregroundStyle(textColor.opacity(0.7))
                
                Text(cleanSortInstruction)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(2)
            }

            if !cleanAnecdote.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            isAnecdoteExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(textColor.opacity(0.72))

                            Text(isAnecdoteExpanded ? L10n.t("scan.more.hide") : L10n.t("scan.more.show"))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(textColor.opacity(0.9))

                            Spacer()

                            Image(systemName: isAnecdoteExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(textColor.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)

                    if isAnecdoteExpanded {
                        Text(cleanAnecdote)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(textColor.opacity(0.88))
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(textColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ConfidencePill(level: confidenceLevel, textColor: textColor)
        }
        .padding(14)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [categoryColor.opacity(0.5), categoryColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: categoryColor.opacity(0.26), radius: 14, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(result.category.localizedName))
        .accessibilityValue(Text(accessibilitySummary))
        .accessibilityHint(Text(L10n.t("scan.instruction.title")))
    }

    private var confidenceLevel: ConfidenceLevel {
        ConfidenceLevel.from(confidence: result.confidence)
    }

    private var categoryColor: Color {
        switch result.category {
        case .compost: return AppPalette.compost
        case .recycle: return AppPalette.recycle
        case .trash: return AppPalette.trash
        }
    }
    
    private var backgroundColor: Color {
        switch result.category {
        case .recycle: return .white
        default: return categoryColor
        }
    }
    
    private var textColor: Color {
        result.category == .recycle ? AppPalette.textPrimary : .white
    }
    
    private var categoryIcon: String {
        switch result.category {
        case .compost: return "leaf.fill"
        case .recycle: return "arrow.triangle.2.circlepath"
        case .trash: return "trash.fill"
        }
    }

    private var sortInstruction: String {
        switch result.category {
        case .compost:
            return L10n.t("scan.sort.compost")
        case .recycle:
            return L10n.t("scan.sort.recycle")
        case .trash:
            return L10n.t("scan.sort.trash")
        }
    }

    private var cleanSortInstruction: String {
        condensedText(sortInstruction)
    }

    private var cleanAnecdote: String {
        condensedText(anecdote)
    }

    private var accessibilitySummary: String {
        var parts: [String] = []

        if let objectDisplayName {
            parts.append(objectDisplayName)
        }

        parts.append(cleanSortInstruction)
        parts.append(confidenceLevel.localizedName)

        if isAnecdoteExpanded, !cleanAnecdote.isEmpty {
            parts.append(cleanAnecdote)
        }

        return parts.joined(separator: ". ")
    }

    private var objectDisplayName: String? {
        let normalizedObject = normalizedLabel(result.objectName)
        guard !normalizedObject.isEmpty else { return nil }

        if normalizedObject == normalizedLabel(result.category.localizedName) {
            return nil
        }

        if categoryAliasTokens.contains(normalizedObject) {
            return nil
        }

        return result.objectName
    }

    private var categoryAliasTokens: Set<String> {
        switch result.category {
        case .compost:
            return ["compost", "organic", "organique", "organico"]
        case .recycle:
            return ["recycle", "recycling", "recyclage", "reciclaje", "recyclable"]
        case .trash:
            return ["trash", "other", "autres", "residual", "residuel", "residuelle"]
        }
    }

    private func normalizedLabel(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func condensedText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ConfidencePill: View {
    let level: ConfidenceLevel
    let textColor: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            
            Text(level.localizedName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(textColor.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(textColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var dotColor: Color {
        switch level {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}

private enum ConfidenceLevel {
    case high
    case medium
    case low

    var localizedName: String {
        switch self {
        case .high:
            return L10n.t("scan.confidence.high")
        case .medium:
            return L10n.t("scan.confidence.medium")
        case .low:
            return L10n.t("scan.confidence.low")
        }
    }

    static func from(confidence: Float) -> ConfidenceLevel {
        if confidence >= 0.84 { return .high }
        if confidence >= 0.68 { return .medium }
        return .low
    }
}

private struct EdgeGlow: View {
    let color: Color
    let isActive: Bool
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        color.opacity(isActive ? 0.6 : 0.2),
                        color.opacity(isActive ? 0.3 : 0.1),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: isActive ? 6 : 3
            )
            .blur(radius: isActive ? 8 : 4)
            .scaleEffect(pulse ? 1.002 : 0.998)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

private struct FocusFrame: View {
    let color: Color
    let frozen: Bool
    let isAnalyzing: Bool
    
    @State private var breathe = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(frozen ? 0.25 : 0.16)

            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isAnalyzing ? 4 : 3
                )
            Rectangle()
                .stroke(.white.opacity(0.18), lineWidth: 1)
                .padding(8)
        }
        .frame(width: 240, height: 240)
        .shadow(color: color.opacity(0.35), radius: 10, y: 3)
        .scaleEffect(frozen ? 0.95 : (breathe ? 1.01 : 0.99))
        .opacity(frozen ? 0.7 : 1)
        .onAppear {
            if !frozen {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
        }
    }
}

private struct CapturedFocusPhoto: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 240, height: 240)
            .clipped()
            .overlay(
                Rectangle()
                    .fill(.black.opacity(0.08))
            )
    }
}

private struct PermissionOverlay: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppPalette.accent.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppPalette.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("scan.permission.required"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.textPrimary)
                }
            }
            
            Text(L10n.t("scan.permission.body"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppPalette.textSecondary)
                .lineSpacing(2)
            
            Button(action: openSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.t("scan.permission.settings"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(AppPalette.accent)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct ScanRegionFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        guard next != .zero else { return }
        value = next
    }
}

#Preview {
    let mockStats = EcoStatsStore()
    let mockViewModel = ScanViewModel()
    ScanView(viewModel: mockViewModel, statsStore: mockStats, onClose: {})
}
