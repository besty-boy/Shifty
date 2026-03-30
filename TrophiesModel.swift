import SwiftUI

struct TrophyDefinition: Identifiable {
    let id = UUID()
    let nameKey: String
    let icon: String
    let color: Color
    let requiredLevel: Int
}

let levelTrophies: [TrophyDefinition] = [
    TrophyDefinition(nameKey: "badge.beginner", icon: "rosette",          color: AppPalette.compost, requiredLevel: 1),
    TrophyDefinition(nameKey: "badge.junior",   icon: "medal.fill",       color: AppPalette.recycle, requiredLevel: 3),
    TrophyDefinition(nameKey: "badge.expert",   icon: "star.circle.fill", color: AppPalette.accent,  requiredLevel: 5),
    TrophyDefinition(nameKey: "badge.master",   icon: "crown.fill",       color: Color(hex: "C8A951"), requiredLevel: 8)
]


let allTrophies: [TrophyDefinition] = levelTrophies

let trophyThresholds: [Int] = levelTrophies.map(\.requiredLevel)

struct ProgressTrophyDefinition: Identifiable {
    let id: String
    let nameKey: String
    let icon: String
    let color: Color
    let target: Int
}

let scanTrophies: [ProgressTrophyDefinition] = [
    ProgressTrophyDefinition(
        id: "scan_scout",
        nameKey: "trophy.scan.scout",
        icon: "camera.metering.matrix",
        color: AppPalette.accent,
        target: 10
    ),
    ProgressTrophyDefinition(
        id: "scan_sorter",
        nameKey: "trophy.scan.sorter",
        icon: "checkmark.seal.fill",
        color: AppPalette.compost,
        target: 40
    ),
    ProgressTrophyDefinition(
        id: "scan_advanced",
        nameKey: "trophy.scan.advanced",
        icon: "viewfinder.circle.fill",
        color: AppPalette.recycle,
        target: 120
    ),
    ProgressTrophyDefinition(
        id: "scan_legend",
        nameKey: "trophy.scan.legend",
        icon: "sparkles.rectangle.stack.fill",
        color: Color(hex: "C8A951"),
        target: 280
    )
]

let trainingTrophies: [ProgressTrophyDefinition] = [
    ProgressTrophyDefinition(
        id: "training_starter",
        nameKey: "trophy.training.starter",
        icon: "figure.run",
        color: AppPalette.accent,
        target: 1
    ),
    ProgressTrophyDefinition(
        id: "training_regular",
        nameKey: "trophy.training.regular",
        icon: "dumbbell.fill",
        color: AppPalette.recycle,
        target: 5
    ),
    ProgressTrophyDefinition(
        id: "training_focus",
        nameKey: "trophy.training.focus",
        icon: "brain.head.profile",
        color: AppPalette.compost,
        target: 15
    ),
    ProgressTrophyDefinition(
        id: "training_master",
        nameKey: "trophy.training.master",
        icon: "graduationcap.fill",
        color: Color(hex: "C8A951"),
        target: 30
    )
]
