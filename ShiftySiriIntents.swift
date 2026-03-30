import AppIntents
import Foundation

struct OpenScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Scanner"
    static let description = IntentDescription("Open Shifty directly on the scanner screen.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: ScannerLaunchRequestKey.pendingToken)
        return .result(dialog: "Opening Shifty scanner.")
    }
}

struct ShiftyShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenScannerIntent(),
            phrases: [
                "Scan with \(.applicationName)",
                "Open scanner in \(.applicationName)",
                "Scanne avec \(.applicationName)",
                "Ouvre le scanner dans \(.applicationName)"
            ],
            shortTitle: "Open Scanner",
            systemImageName: "camera.viewfinder"
        )
    }
}
