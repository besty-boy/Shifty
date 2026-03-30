import Foundation

enum WasteCategory: CaseIterable {
    case compost
    case recycle
    case trash

    var localizedName: String {
        switch self {
        case .compost:
            return L10n.t("waste.category.compost")
        case .recycle:
            return L10n.t("waste.category.recycle")
        case .trash:
            return L10n.t("waste.category.trash")
        }
    }
}

struct ClassificationResult: Equatable {
    let objectName: String
    let confidence: Float
    let category: WasteCategory
}
