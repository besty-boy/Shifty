import CoreML
import Foundation
import Observation
import UIKit
import Vision

@Observable
final class ImageClassifier: @unchecked Sendable {
    private(set) var latestResult: ClassificationResult?
    private(set) var isUsingMockModel = false

    var onResult: ((ClassificationResult?) -> Void)?
    var onMockModeChange: ((Bool) -> Void)?

    private let classificationQueue = DispatchQueue(label: "com.shifty.classifier.queue", qos: .userInitiated)
    private var isProcessing = false
    private var visionRequest: VNCoreMLRequest?
    private let compostKeywords = [
        "compost",
        "organic",
        "organics",
        "organique",
        "organico",
        "bio waste",
        "biowaste",
        "biodechet",
        "biodechets",
        "dechet organique",
        "dechets organiques",
        "dechet alimentaire",
        "dechets alimentaires",
        "food waste",
        "food scrap",
        "food scraps",
        "fruit",
        "fruits",
        "vegetable",
        "vegetables",
        "epluchure",
        "epluchures",
        "peel",
        "peels",
        "trognon",
        "banana",
        "apple core",
        "leaf",
        "leaves",
        "green waste",
        "garden waste"
    ]
    private let recycleKeywords = [
        "recycle",
        "recyclage",
        "recycling",
        "reciclaje",
        "recyclable",
        "plastic",
        "plastique",
        "plastica",
        "bottle",
        "bouteille",
        "can",
        "canette",
        "aluminum",
        "aluminium",
        "metal",
        "glass",
        "verre",
        "paper",
        "papier",
        "cardboard",
        "carton",
        "packaging",
        "emballage",
        "container"
    ]
    private let trashKeywords = [
        "trash",
        "garbage",
        "residual",
        "residuel",
        "residuelle",
        "ordures",
        "menageres",
        "other",
        "autres",
        "non recyclable"
    ]

    private var mockObjectNames: [String] {
        [
            L10n.t("mock.object.banana"),
            L10n.t("mock.object.apple_core"),
            L10n.t("mock.object.plastic_bottle"),
            L10n.t("mock.object.cardboard"),
            L10n.t("mock.object.aluminum_can"),
            L10n.t("mock.object.coffee_cup")
        ]
    }

    private var mockIndex = 0
    private var lastMockDate = Date.distantPast

    init() {
        configureVisionRequest()
        isUsingMockModel = visionRequest == nil
    }

    func classify(image: UIImage) {
        classificationQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isProcessing else { return }
            self.isProcessing = true
            defer { self.isProcessing = false }

            guard let cgImage = image.cgImage else {
                self.publishMockResultIfNeeded(force: true)
                return
            }

            guard let visionRequest = self.visionRequest else {
                self.publishMockResultIfNeeded()
                return
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

            do {
                try handler.perform([visionRequest])
            } catch {
                self.publishMockResultIfNeeded(force: true)
            }
        }
    }

    private func category(for objectName: String) -> WasteCategory {
        let normalizedName = normalizedCategoryText(objectName)

        if compostKeywords.contains(where: { normalizedName.contains($0) }) {
            return .compost
        }

        if recycleKeywords.contains(where: { normalizedName.contains($0) }) {
            return .recycle
        }

        if trashKeywords.contains(where: { normalizedName.contains($0) }) {
            return .trash
        }

        return .trash
    }

    private func normalizedCategoryText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureVisionRequest() {
        guard let modelURL =
            Bundle.main.url(forResource: "WasteClassifier",
                            withExtension: "mlmodelc",
                            subdirectory: "Sources")
            ?? Bundle.main.url(forResource: "WasteClassifier",
                               withExtension: "mlpackage",
                               subdirectory: "Sources")
            ?? Bundle.main.url(forResource: "WasteClassifier",
                               withExtension: "mlmodel",
                               subdirectory: "Sources")
        else {
            fatalError("WasteClassifier model not found in Sources")
        }

        let mlModel = try! MLModel(contentsOf: modelURL)
        let visionModel = try! VNCoreMLModel(for: mlModel)

        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            self?.handleVisionResponse(request: request, error: error)
        }

        request.imageCropAndScaleOption = .centerCrop
        visionRequest = request
        updateMockMode(false)
    }

    private func handleVisionResponse(request: VNRequest, error: Error?) {
        if error != nil {
            publishMockResultIfNeeded(force: true)
            return
        }

        guard
            let observations = request.results as? [VNClassificationObservation],
            let bestObservation = observations.first
        else {
            publishMockResultIfNeeded(force: true)
            return
        }

        let cleanedObjectName = bestObservation.identifier
            .split(separator: ",")
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? bestObservation.identifier

        publishResult(objectName: cleanedObjectName, confidence: bestObservation.confidence)
    }

    private func publishMockResultIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastMockDate) > 0.7 else { return }

        lastMockDate = now
        let name = mockObjectNames[mockIndex % mockObjectNames.count]
        mockIndex += 1

        let confidence = Float.random(in: 0.62...0.95)
        publishResult(objectName: name, confidence: confidence)
    }

    private func publishResult(objectName: String, confidence: Float) {
        let clampedConfidence = min(max(confidence, 0), 1)
        let normalizedName = objectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalObjectName = normalizedName.isEmpty ? L10n.t("scan.object.unknown") : normalizedName
        let computedCategory = category(for: finalObjectName)
        let result = ClassificationResult(
            objectName: finalObjectName,
            confidence: clampedConfidence,
            category: computedCategory
        )

        Task { [weak self] in
            await self?.applyResult(result)
        }
    }

    @MainActor
    private func applyResult(_ result: ClassificationResult) {
        latestResult = result
        onResult?(result)
    }

    private func updateMockMode(_ value: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            isUsingMockModel = value
            onMockModeChange?(value)
        }
    }
}
