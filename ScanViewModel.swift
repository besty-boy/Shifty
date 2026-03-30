import Foundation
import Observation
import UIKit

enum AppScreen {
    case home
    case scanner
}

enum ScanFeedbackKind: Equatable {
    case impactLight
    case success
    case warning
    case error
}

struct ScanFeedbackEvent: Equatable {
    let id: Int
    let kind: ScanFeedbackKind
}

@MainActor
@Observable
final class ScanViewModel {
    var currentScreen: AppScreen = .home
    private(set) var result: ClassificationResult?
    private(set) var authorizationState: CameraManager.AuthorizationState = .notDetermined
    private(set) var isMockModeEnabled = false
    private(set) var capturedImage: UIImage?
    private(set) var capturedAnecdote = ""
    private(set) var isAnalyzing = false
    private(set) var flashOpacity: Double = 0.0
    private(set) var statusMessage = L10n.t("scan.status.ready")
    private(set) var captureErrorMessage: String?
    private(set) var feedbackEvent: ScanFeedbackEvent?

    let cameraManager: CameraManager
    private let classifier: ImageClassifier

    private var analysisTimeoutTask: Task<Void, Never>?
    private var flashResetTask: Task<Void, Never>?
    private var scanRegionNormalized = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    private var previewSize: CGSize = .zero
    private let scanRegionInnerInsetRatio: CGFloat = 0.08
    private var feedbackSequence = 0

    init(
        cameraManager: CameraManager,
        classifier: ImageClassifier
    ) {
        self.cameraManager = cameraManager
        self.classifier = classifier

        authorizationState = cameraManager.authorizationState
        isMockModeEnabled = classifier.isUsingMockModel

        cameraManager.onPhotoCaptured = { [weak self] image in
            Task { @MainActor [weak self] in
                self?.handleCapturedPhoto(image)
            }
        }

        cameraManager.onPhotoCaptureFailed = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleCaptureFailure(message)
            }
        }

        cameraManager.onAuthorizationStateChange = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.authorizationState = state
            }
        }

        classifier.onResult = { [weak self] newResult in
            Task { @MainActor [weak self] in
                self?.handleClassificationResult(newResult)
            }
        }

        classifier.onMockModeChange = { [weak self] isMock in
            Task { @MainActor [weak self] in
                self?.isMockModeEnabled = isMock
            }
        }
    }

    convenience init() {
        self.init(
            cameraManager: CameraManager(),
            classifier: ImageClassifier()
        )
    }

    func openScanner() {
        currentScreen = .scanner
        statusMessage = L10n.t("scan.status.ready")
        cameraManager.startSession()
    }

    func closeScanner() {
        cameraManager.stopSession()
        resetCaptureState()
        currentScreen = .home
    }

    func captureAndAnalyze() {
        guard !isAnalyzing else { return }
        guard !isPermissionDenied else { return }
        guard capturedImage == nil else { return }

        captureErrorMessage = nil
        statusMessage = L10n.t("scan.status.capture")
        cameraManager.capturePhoto()
    }

    func updateScanRegion(normalizedRect: CGRect, previewSize: CGSize) {
        let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let clamped = normalizedRect.standardized.intersection(bounds)
        guard clamped.width > 0, clamped.height > 0 else { return }

       
        if areRectsAlmostEqual(scanRegionNormalized, clamped), areSizesAlmostEqual(self.previewSize, previewSize) {
            return
        }

        scanRegionNormalized = clamped
        self.previewSize = previewSize
    }

    func retakePhoto() {
        resetCaptureState()
        statusMessage = L10n.t("scan.status.ready")
    }

    var isPermissionDenied: Bool {
        authorizationState == .denied || authorizationState == .restricted
    }

    private func handleCaptureFailure(_ message: String) {
        analysisTimeoutTask?.cancel()
        analysisTimeoutTask = nil
        flashResetTask?.cancel()
        flashResetTask = nil

        isAnalyzing = false
        captureErrorMessage = message
        statusMessage = L10n.t("scan.error.capture_failed")
        flashOpacity = 0
        emitFeedback(.error)
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        result = nil
        capturedAnecdote = ""

        let analysisImage = cropImageToScanRegion(image) ?? image
        capturedImage = analysisImage
        statusMessage = L10n.t("scan.status.analyzing")
        isAnalyzing = true
        flashOpacity = 0.9
        emitFeedback(.impactLight)

        scheduleAnalysisTimeout()

        flashResetTask?.cancel()
        flashResetTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.flashOpacity = 0
        }

        classifier.classify(image: analysisImage)
    }

    private func handleClassificationResult(_ newResult: ClassificationResult?) {
        guard capturedImage != nil else { return }
        guard isAnalyzing else { return }

        analysisTimeoutTask?.cancel()
        analysisTimeoutTask = nil

        guard let newResult else {
            statusMessage = L10n.t("scan.status.unrecognized")
            captureErrorMessage = L10n.t("scan.error.no_usable_result")
            isAnalyzing = false
            emitFeedback(.error)
            return
        }

        result = newResult
        capturedAnecdote = anecdote(for: newResult)
        statusMessage = newResult.confidence < 0.68
            ? L10n.t("scan.status.done.low_confidence")
            : L10n.t("scan.status.done")
        isAnalyzing = false

        if newResult.confidence < 0.68 {
            emitFeedback(.warning)
        } else {
            emitFeedback(.success)
        }
    }

    private func resetCaptureState() {
        analysisTimeoutTask?.cancel()
        analysisTimeoutTask = nil
        flashResetTask?.cancel()
        flashResetTask = nil

        result = nil
        capturedImage = nil
        capturedAnecdote = ""
        captureErrorMessage = nil
        isAnalyzing = false
        flashOpacity = 0
    }

    private func anecdote(for result: ClassificationResult) -> String {
        switch result.category {
        case .compost:
            return L10n.t("scan.anecdote.compost")
        case .recycle:
            return L10n.t("scan.anecdote.recycle")
        case .trash:
            return L10n.t("scan.anecdote.trash")
        }
    }

    private func scheduleAnalysisTimeout() {
        analysisTimeoutTask?.cancel()
        analysisTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2500))
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard self.isAnalyzing else { return }

            self.isAnalyzing = false
            self.statusMessage = L10n.t("scan.status.timeout")
            self.captureErrorMessage = L10n.t("scan.error.timeout")
            self.emitFeedback(.warning)
        }
    }

    private func emitFeedback(_ kind: ScanFeedbackKind) {
        feedbackSequence += 1
        feedbackEvent = ScanFeedbackEvent(id: feedbackSequence, kind: kind)
    }

    private func areRectsAlmostEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.0005) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance &&
        abs(lhs.origin.y - rhs.origin.y) <= tolerance &&
        abs(lhs.size.width - rhs.size.width) <= tolerance &&
        abs(lhs.size.height - rhs.size.height) <= tolerance
    }

    private func areSizesAlmostEqual(_ lhs: CGSize, _ rhs: CGSize, tolerance: CGFloat = 0.5) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance &&
        abs(lhs.height - rhs.height) <= tolerance
    }

    private func cropImageToScanRegion(_ image: UIImage) -> UIImage? {
        let normalizedImage = image.normalizedUpOrientation()
        guard let cgImage = normalizedImage.cgImage else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let imageBounds = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)

        let focusRegion = innerFocusRegion(from: scanRegionNormalized)

        guard previewSize.width > 0, previewSize.height > 0 else {
            let fallbackCrop = CGRect(
                x: focusRegion.minX * imageWidth,
                y: focusRegion.minY * imageHeight,
                width: focusRegion.width * imageWidth,
                height: focusRegion.height * imageHeight
            ).integral.intersection(imageBounds)

            guard fallbackCrop.width > 10, fallbackCrop.height > 10 else { return nil }
            guard let croppedCGImage = cgImage.cropping(to: fallbackCrop) else { return nil }
            return UIImage(cgImage: croppedCGImage, scale: normalizedImage.scale, orientation: .up)
        }

        let viewRect = CGRect(
            x: focusRegion.minX * previewSize.width,
            y: focusRegion.minY * previewSize.height,
            width: focusRegion.width * previewSize.width,
            height: focusRegion.height * previewSize.height
        )

        let scale = max(previewSize.width / imageWidth, previewSize.height / imageHeight)
        let displayedWidth = imageWidth * scale
        let displayedHeight = imageHeight * scale

        let overflowX = (displayedWidth - previewSize.width) / 2
        let overflowY = (displayedHeight - previewSize.height) / 2

        var cropRect = CGRect(
            x: (viewRect.minX + overflowX) / scale,
            y: (viewRect.minY + overflowY) / scale,
            width: viewRect.width / scale,
            height: viewRect.height / scale
        ).integral

        cropRect = cropRect.intersection(imageBounds)

        guard cropRect.width > 10, cropRect.height > 10 else { return nil }
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }

        return UIImage(cgImage: croppedCGImage, scale: normalizedImage.scale, orientation: .up)
    }

    private func innerFocusRegion(from region: CGRect) -> CGRect {
        let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let base = region.standardized.intersection(bounds)
        guard base.width > 0, base.height > 0 else { return CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4) }

        let insetX = base.width * scanRegionInnerInsetRatio
        let insetY = base.height * scanRegionInnerInsetRatio
        let inner = base.insetBy(dx: insetX, dy: insetY).intersection(bounds)

        if inner.width > 0.15, inner.height > 0.15 {
            return inner
        }

        return base
    }
}

private extension UIImage {
    func normalizedUpOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
