import Foundation

enum L10n {
    static func resource(_ key: String) -> LocalizedStringResource {
        LocalizedStringResource(
            String.LocalizationValue(key),
            table: "Localizable",
            bundle: .main
        )
    }

    static func t(_ key: String) -> String {
        String(
            localized: String.LocalizationValue(key),
            table: "Localizable",
            bundle: .main,
            locale: .current
        )
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: .current, arguments: args)
    }
}
