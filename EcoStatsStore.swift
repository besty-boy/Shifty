import Foundation
import Observation

@Observable
final class EcoStatsStore {
    private(set) var totalPoints: Int
    private(set) var totalScans: Int
    private(set) var streakDays: Int
    private(set) var latestPointsGain: Int = 0
    private(set) var lastScanDate: Date?

    private(set) var trainingSessionsCompleted: Int
    private(set) var perfectTrainingSessions: Int
    private(set) var bestTrainingScore: Int

    let pointsPerLevel: Int

    private let userDefaults: UserDefaults
    private let calendar = Calendar.current

    init(userDefaults: UserDefaults = .standard, pointsPerLevel: Int = 120) {
        self.userDefaults = userDefaults
        self.pointsPerLevel = pointsPerLevel

        totalPoints = userDefaults.integer(forKey: StatsKeys.totalPoints)
        totalScans = userDefaults.integer(forKey: StatsKeys.totalScans)
        streakDays = userDefaults.integer(forKey: StatsKeys.streakDays)
        lastScanDate = userDefaults.object(forKey: StatsKeys.lastScanDate) as? Date

        trainingSessionsCompleted = userDefaults.integer(forKey: StatsKeys.trainingSessionsCompleted)
        perfectTrainingSessions = userDefaults.integer(forKey: StatsKeys.perfectTrainingSessions)
        bestTrainingScore = userDefaults.integer(forKey: StatsKeys.bestTrainingScore)
    }

    var level: Int {
        max(1, (totalPoints / pointsPerLevel) + 1)
    }

    var pointsIntoCurrentLevel: Int {
        totalPoints % pointsPerLevel
    }

    var pointsToNextLevel: Int {
        max(0, pointsPerLevel - pointsIntoCurrentLevel)
    }

    var levelProgress: Double {
        guard pointsPerLevel > 0 else { return 0 }
        return Double(pointsIntoCurrentLevel) / Double(pointsPerLevel)
    }

    func registerSuccessfulScan(result: ClassificationResult) {
        let earned = points(for: result)
        totalPoints += earned
        totalScans += 1
        latestPointsGain = earned

        updateStreak(now: Date())
        persist()
    }

    func registerTrainingCorrectAnswer(category: WasteCategory) {
        let trainingResult = ClassificationResult(objectName: "training", confidence: 0.95, category: category)
        let earned = points(for: trainingResult)
        totalPoints += earned
        latestPointsGain = earned
        persist()
    }

    func registerTrainingSession(score: Int, totalItems: Int) {
        let clampedScore = max(0, score)
        trainingSessionsCompleted += 1

        if totalItems > 0, clampedScore >= totalItems {
            perfectTrainingSessions += 1
        }

        bestTrainingScore = max(bestTrainingScore, clampedScore)
        persist()
    }

    private func points(for result: ClassificationResult) -> Int {
        let clampedConfidence = min(max(result.confidence, 0), 1)
        let confidenceBonus = Int((clampedConfidence * 100) / 6.0)
        let categoryBonus: Int

        switch result.category {
        case .compost:
            categoryBonus = 9
        case .recycle:
            categoryBonus = 8
        case .trash:
            categoryBonus = 5
        }

        return max(10, confidenceBonus + categoryBonus)
    }

    private func updateStreak(now: Date) {
        guard let lastScanDate else {
            streakDays = 1
            self.lastScanDate = now
            return
        }

        if calendar.isDate(lastScanDate, inSameDayAs: now) {
            self.lastScanDate = now
            return
        }

        if
            let nextDay = calendar.date(byAdding: .day, value: 1, to: lastScanDate),
            calendar.isDate(nextDay, inSameDayAs: now)
        {
            streakDays += 1
        } else {
            streakDays = 1
        }

        self.lastScanDate = now
    }

    private func persist() {
        userDefaults.set(totalPoints, forKey: StatsKeys.totalPoints)
        userDefaults.set(totalScans, forKey: StatsKeys.totalScans)
        userDefaults.set(streakDays, forKey: StatsKeys.streakDays)
        userDefaults.set(lastScanDate, forKey: StatsKeys.lastScanDate)

        userDefaults.set(trainingSessionsCompleted, forKey: StatsKeys.trainingSessionsCompleted)
        userDefaults.set(perfectTrainingSessions, forKey: StatsKeys.perfectTrainingSessions)
        userDefaults.set(bestTrainingScore, forKey: StatsKeys.bestTrainingScore)
    }
}

private enum StatsKeys {
    static let totalPoints = "eco_stats_total_points"
    static let totalScans = "eco_stats_total_scans"
    static let streakDays = "eco_stats_streak_days"
    static let lastScanDate = "eco_stats_last_scan_date"

    static let trainingSessionsCompleted = "eco_stats_training_sessions_completed"
    static let perfectTrainingSessions = "eco_stats_training_perfect_sessions"
    static let bestTrainingScore = "eco_stats_training_best_score"
}
