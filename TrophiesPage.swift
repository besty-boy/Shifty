import SwiftUI

struct TrophiesPage: View {
    var statsStore: EcoStatsStore
    @Environment(\.colorScheme) private var colorScheme

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var nextLockedLevelTrophy: TrophyDefinition? {
        allTrophies.first { statsStore.level < $0.requiredLevel }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerCard
                    globalLevelCard
                    levelMilestonesCard

                    ProgressTrophySectionCard(
                        title: t("trophy.scan.title"),
                        subtitle: t("trophy.scan.subtitle"),
                        currentValue: statsStore.totalScans,
                        currentLabel: t("home.scans.label"),
                        trophies: scanTrophies,
                        colorScheme: colorScheme
                    )

                    ProgressTrophySectionCard(
                        title: t("trophy.training.title"),
                        subtitle: t("trophy.training.subtitle"),
                        currentValue: statsStore.trainingSessionsCompleted,
                        currentLabel: t("trophy.training.sessions"),
                        trophies: trainingTrophies,
                        colorScheme: colorScheme
                    )

                    trainingHighlightsCard
                }
                .frame(maxWidth: min(geo.size.width - 24, 760))
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .background(colorScheme == .dark ? Color.black : AppPalette.base)
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("home.trophies.title"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)

                Text(t("trophy.page.subtitle"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : AppPalette.textSecondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(AppPalette.accent.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppPalette.accent)
            }
        }
        .padding(18)
        .applyCardBackground(colorScheme: colorScheme)
    }

    private var globalLevelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("trophy.global_level"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)

                    Text(t("trophy.global_level_hint", statsStore.pointsToNextLevel))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.74) : AppPalette.textSecondary)
                }

                Spacer()

                Text(L10n.t("home.level.short", statsStore.level))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(AppPalette.compost)
            }

            ProgressView(value: statsStore.levelProgress)
                .tint(AppPalette.compost)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)

            HStack(spacing: 10) {
                statsChip(icon: "star.fill", value: "\(statsStore.totalPoints)", label: t("home.total.points"), tint: AppPalette.accent)
                statsChip(icon: "camera.fill", value: "\(statsStore.totalScans)", label: t("home.scans.label"), tint: AppPalette.recycle)
                statsChip(icon: "figure.run", value: "\(statsStore.trainingSessionsCompleted)", label: t("trophy.training.sessions"), tint: AppPalette.compost)
            }
        }
        .padding(18)
        .applyCardBackground(colorScheme: colorScheme)
    }

    private var levelMilestonesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("trophy.level_badges"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(allTrophies) { trophy in
                    let unlocked = statsStore.level >= trophy.requiredLevel
                    levelBadgeCell(trophy: trophy, unlocked: unlocked)
                }
            }

            if let nextLockedLevelTrophy {
                Text(
                    t(
                        "home.trophies.progress_hint",
                        nextLockedLevelTrophy.requiredLevel - statsStore.level,
                        L10n.t(nextLockedLevelTrophy.nameKey)
                    )
                )
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.76) : AppPalette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppPalette.accent.opacity(colorScheme == .dark ? 0.18 : 0.1))
                }
            }
        }
        .padding(18)
        .applyCardBackground(colorScheme: colorScheme)
    }

    private func levelBadgeCell(trophy: TrophyDefinition, unlocked: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill((unlocked ? trophy.color : .gray).opacity(unlocked ? 0.18 : 0.12))
                    .frame(width: 58, height: 58)

                Image(systemName: trophy.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(unlocked ? trophy.color : Color.gray.opacity(0.55))
            }

            Text(L10n.t(trophy.nameKey))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(unlocked ? (colorScheme == .dark ? .white : AppPalette.textPrimary) : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(L10n.t("home.trophies.level_requirement", trophy.requiredLevel))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(unlocked ? trophy.color : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(unlocked
                      ? trophy.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                      : Color.gray.opacity(colorScheme == .dark ? 0.08 : 0.06)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(unlocked ? trophy.color.opacity(0.25) : Color.gray.opacity(0.2), lineWidth: 1)
                }
        }
        .opacity(unlocked ? 1 : 0.72)
    }

    private var trainingHighlightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("trophy.training.highlights"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)

            HStack(spacing: 10) {
                highlightChip(
                    icon: "checkmark.seal.fill",
                    value: "\(statsStore.perfectTrainingSessions)",
                    label: t("trophy.training.perfect"),
                    tint: AppPalette.compost
                )
                highlightChip(
                    icon: "target",
                    value: "\(statsStore.bestTrainingScore)",
                    label: t("trophy.training.best_score"),
                    tint: AppPalette.accent
                )
            }
        }
        .padding(18)
        .applyCardBackground(colorScheme: colorScheme)
    }

    private func statsChip(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.68) : AppPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.15 : 0.1))
        }
    }

    private func highlightChip(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.72) : AppPalette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.15 : 0.1))
        }
    }

    private func t(_ key: String) -> String {
        L10n.t(key)
    }

    private func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: L10n.t(key), locale: .current, arguments: args)
    }
}

private struct ProgressTrophySectionCard: View {
    let title: String
    let subtitle: String
    let currentValue: Int
    let currentLabel: String
    let trophies: [ProgressTrophyDefinition]
    let colorScheme: ColorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var unlockedCount: Int {
        trophies.filter { currentValue >= $0.target }.count
    }

    private var nextTarget: ProgressTrophyDefinition? {
        trophies.first { currentValue < $0.target }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : AppPalette.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.76) : AppPalette.textSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentValue)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(AppPalette.compost)
                    Text(currentLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.72) : AppPalette.textSecondary)
                }
            }

            ProgressView(value: Double(unlockedCount), total: Double(max(trophies.count, 1)))
                .tint(AppPalette.compost)
                .scaleEffect(x: 1, y: 1.15, anchor: .center)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(trophies) { trophy in
                    trophyCell(trophy)
                }
            }

            if let nextTarget {
                Text(
                    L10n.t(
                        "trophy.progress.next",
                        max(0, nextTarget.target - currentValue),
                        L10n.t(nextTarget.nameKey)
                    )
                )
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.78) : AppPalette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppPalette.compost.opacity(colorScheme == .dark ? 0.15 : 0.08))
                }
            }
        }
        .padding(18)
        .applyCardBackground(colorScheme: colorScheme)
    }

    private func trophyCell(_ trophy: ProgressTrophyDefinition) -> some View {
        let unlocked = currentValue >= trophy.target
        let progressValue = min(currentValue, trophy.target)

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill((unlocked ? trophy.color : Color.gray).opacity(unlocked ? 0.2 : 0.12))
                    .frame(width: 58, height: 58)

                Image(systemName: trophy.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(unlocked ? trophy.color : Color.gray.opacity(0.6))
            }

            Text(L10n.t(trophy.nameKey))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(unlocked ? (colorScheme == .dark ? .white : AppPalette.textPrimary) : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(unlocked ? L10n.t("trophy.unlocked") : "\(progressValue)/\(trophy.target)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(unlocked ? trophy.color : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(unlocked
                      ? trophy.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                      : Color.gray.opacity(colorScheme == .dark ? 0.08 : 0.06)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(unlocked ? trophy.color.opacity(0.25) : Color.gray.opacity(0.2), lineWidth: 1)
                }
        }
        .opacity(unlocked ? 1 : 0.74)
    }
}

#Preview {
    TrophiesPage(statsStore: EcoStatsStore())
}
