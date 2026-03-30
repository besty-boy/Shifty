@preconcurrency import AVFoundation
import Foundation
import Observation
import UIKit

@Observable
@MainActor final class CameraManager: NSObject {
    enum AuthorizationState {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    private(set) var authorizationState: AuthorizationState = .notDetermined
    private(set) var isSessionRunning = false

    let session = AVCaptureSession()
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onPhotoCaptureFailed: ((String) -> Void)?
    var onAuthorizationStateChange: ((AuthorizationState) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.shifty.camera.session", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var cachedVideoRotationAngle: CGFloat = 90

    func startSession() {
        cachedVideoRotationAngle = resolveCurrentVideoRotationAngle()
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            updateAuthorizationState(.authorized)
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.updateAuthorizationState(.authorized)
                        self.configureAndStartSession()
                    } else {
                        self.updateAuthorizationState(.denied)
                    }
                }
            }
        case .denied:
            updateAuthorizationState(.denied)
        case .restricted:
            updateAuthorizationState(.restricted)
        @unknown default:
            updateAuthorizationState(.denied)
        }
    }

    func stopSession() {
        let session = self.session
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = false
            }
        }
    }

    func capturePhoto() {
        guard isConfigured else {
            publishCaptureError(L10n.t("camera.error.session_not_configured"))
            return
        }
        guard session.isRunning else {
            publishCaptureError(L10n.t("camera.error.session_stopped"))
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .quality
        if #available(iOS 16.0, *) {
            let dimensions = photoOutput.maxPhotoDimensions
            if dimensions.width > 0, dimensions.height > 0 {
                settings.maxPhotoDimensions = dimensions
            }
        }

        let angle = resolveCurrentVideoRotationAngle()
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func configureAndStartSession() {
        let session = self.session
        Task { @MainActor [weak self] in
            guard let self else { return }
           
            let configured = self.configureSessionIfNeeded()
            guard configured else {
                self.publishCaptureError(L10n.t("camera.error.configuration_failed"))
                return
            }

           
            self.sessionQueue.async { [weak self] in
                guard let self else { return }
                if !session.isRunning {
                    session.startRunning()
                    Task { @MainActor [weak self] in
                        self?.isSessionRunning = true
                    }
                }
            }
        }
    }

    private func configureSessionIfNeeded() -> Bool {
        guard !isConfigured else { return true }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return false
        }

        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(cameraInput) else { return false }
            session.addInput(cameraInput)
        } catch {
            return false
        }

        guard session.canAddOutput(photoOutput) else { return false }
        session.addOutput(photoOutput)

        photoOutput.maxPhotoQualityPrioritization = .quality

        if let connection = photoOutput.connection(with: .video) {
            let angle = cachedVideoRotationAngle
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }

        isConfigured = true
        return true
    }

    private func updateAuthorizationState(_ newState: AuthorizationState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            authorizationState = newState
            onAuthorizationStateChange?(newState)
        }
    }

    private func publishCaptureError(_ message: String) {
        Task { @MainActor [weak self] in
            self?.onPhotoCaptureFailed?(message)
        }
    }

    private func resolveCurrentVideoRotationAngle() -> CGFloat {
        guard Thread.isMainThread else { return cachedVideoRotationAngle }

        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .interfaceOrientation ?? .portrait

        switch orientation {
        case .portrait:
            cachedVideoRotationAngle = 90
        case .portraitUpsideDown:
            cachedVideoRotationAngle = 270
        case .landscapeLeft:
            cachedVideoRotationAngle = 180
        case .landscapeRight:
            cachedVideoRotationAngle = 0
        default:
            cachedVideoRotationAngle = 90
        }

        return cachedVideoRotationAngle
    }
}

extension CameraManager: @MainActor AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            publishCaptureError(L10n.t("camera.error.capture_failed", error.localizedDescription))
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            publishCaptureError(L10n.t("camera.error.read_failed"))
            return
        }

        guard let image = UIImage(data: imageData) else {
            publishCaptureError(L10n.t("camera.error.unsupported_format"))
            return
        }

        Task { @MainActor [weak self] in
            self?.onPhotoCaptured?(image)
        }
    }
}

