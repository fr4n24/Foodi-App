// GymLink-App/Managers/LeaderboardViewModel.swift
import Foundation
import Combine
import FirebaseFirestore

// MARK: - Enums

enum LeaderboardCategory: String, CaseIterable {
    case overall  = "Overall"
    case weight   = "Weight"
    case streak   = "Streak"
    case gains    = "Gains"
    case gyms     = "Gyms"
}

enum TimePeriod: String, CaseIterable {
    case daily   = "Today"
    case weekly  = "Week"
    case monthly = "Month"
    case allTime = "All Time"

    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .daily:   return cal.startOfDay(for: now)
        case .weekly:  return cal.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .monthly: return cal.date(byAdding: .month, value: -1, to: now) ?? now
        case .allTime: return Date(timeIntervalSince1970: 0)
        }
    }
}

// Keep old filter for any legacy references
enum LeaderboardFilter: String, CaseIterable {
    case users        = "Users"
    case gyms         = "Gyms"
    case workoutTypes = "Workout Types"
}

// MARK: - Models

struct LeaderboardUser: Identifiable {
    var id: String
    var username: String
    var score: Int              // points for Overall; count for Lifts/Progress; delta for Gains
    var profilePicURL: String?
    var gainDetail: String? = nil  // e.g. "+20 lbs (Bench Press)"
}

struct GymRank: Identifiable {
    var id: String
    var name: String
    var count: Int
}

struct FoodTypeRank: Identifiable {
    var id: String
    var name: String
    var count: Int
}

// MARK: - ViewModel

final class LeaderboardViewModel: ObservableObject {
    @Published var users: [LeaderboardUser] = []
    @Published var gymRanks: [GymRank]        = []
    @Published var foodTypeRanks: [FoodTypeRank] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    // MARK: - Primary fetch dispatcher
    func fetch(period: TimePeriod, category: LeaderboardCategory) {
        isLoading = true
        switch category {
        case .overall where period == .allTime:
            fetchAllTimeScore()
        case .overall:
            fetchAllTimeScore()
        case .weight:
            fetchHeaviestLifts(period: period)
        case .streak:
            fetchStreaks()
        case .gains:
            fetchGains(period: period)
        case .gyms:
            fetchGymRanks()
        }
    }

    // MARK: - All-time score (from user doc)
    func fetchOnce(limit: Int = 50) {
        fetchAllTimeScore(limit: limit)
    }

    private func fetchAllTimeScore(limit: Int = 50) {
        db.collection("users")
            .order(by: "score", descending: true)
            .limit(to: limit)
            .getDocuments { [weak self] snap, _ in
                let list = (snap?.documents ?? []).map { d -> LeaderboardUser in
                    let x = d.data()
                    return LeaderboardUser(
                        id: d.documentID,
                        username: x["username"] as? String ?? "Unknown",
                        score: x["score"] as? Int ?? 0,
                        profilePicURL: x["profilePicURL"] as? String
                    )
                }
                DispatchQueue.main.async {
                    self?.users = list
                    self?.isLoading = false
                }
                self?.loadGymAndWorkoutTypes()
            }
    }

    // MARK: - Activity-based ranking (posts in period)
    private func fetchByPostActivity(period: TimePeriod, postCategory: String?) {
        db.collection("posts")
            .whereField("timestamp", isGreaterThan: Timestamp(date: period.startDate))
            .getDocuments { [weak self] snap, _ in
                guard let self = self else { return }
                let docs = snap?.documents ?? []

                // Count posts per author, filter by category in memory
                var countMap: [String: Int] = [:]
                var authorNameMap: [String: String] = [:]

                for doc in docs {
                    let data = doc.data()
                    let cat = data["category"] as? String ?? "workout"
                    if let filter = postCategory, cat != filter { continue }

                    let authorId = data["authorId"] as? String ?? ""
                    let author   = data["author"] as? String ?? ""
                    guard !authorId.isEmpty else { continue }
                    countMap[authorId, default: 0] += 1
                    authorNameMap[authorId] = author
                }

                let sorted = countMap.sorted { $0.value > $1.value }.prefix(50)

                guard !sorted.isEmpty else {
                    DispatchQueue.main.async {
                        self.users = []
                        self.isLoading = false
                    }
                    return
                }

                // Batch-fetch user docs for profile pics
                let group = DispatchGroup()
                var userDocs: [String: [String: Any]] = [:]

                for (uid, _) in sorted {
                    group.enter()
                    self.db.collection("users").document(uid).getDocument { snap, _ in
                        if let data = snap?.data() { userDocs[uid] = data }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.users = sorted.map { (uid, count) in
                        let d = userDocs[uid] ?? [:]
                        return LeaderboardUser(
                            id: uid,
                            username: d["username"] as? String ?? authorNameMap[uid] ?? "Unknown",
                            score: count,
                            profilePicURL: d["profilePicURL"] as? String
                        )
                    }
                    self.isLoading = false
                }
            }
    }

    // MARK: - Gains leaderboard (workout progression)
    private func fetchGains(period: TimePeriod) {
        db.collection("posts")
            .whereField("category", isEqualTo: "workout")
            .whereField("timestamp", isGreaterThan: Timestamp(date: period.startDate))
            .getDocuments { [weak self] snap, _ in
                guard let self = self else { return }
                let docs = snap?.documents ?? []

                // Per user: track their single biggest gain
                typealias GainInfo = (delta: Double, detail: String, username: String)
                var best: [String: GainInfo] = [:]

                for doc in docs {
                    let d = doc.data()
                    guard let newVal  = d["newValue"]      as? Double,
                          let prevVal = d["previousValue"] as? Double,
                          newVal > prevVal else { continue }
                    let authorId = d["authorId"] as? String ?? ""
                    guard !authorId.isEmpty else { continue }

                    let delta    = newVal - prevVal
                    let exercise = d["exerciseName"] as? String ?? "Exercise"
                    let unit     = d["progressionUnit"] as? String ?? "reps"
                    let author   = d["author"] as? String ?? ""
                    let fmtDelta = delta.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(delta))" : String(format: "%.1f", delta)
                    let detail = "+\(fmtDelta) \(unit) (\(exercise))"

                    if let existing = best[authorId] {
                        if delta > existing.delta { best[authorId] = (delta, detail, author) }
                    } else {
                        best[authorId] = (delta, detail, author)
                    }
                }

                let sorted = best.sorted { $0.value.delta > $1.value.delta }.prefix(50)
                guard !sorted.isEmpty else {
                    DispatchQueue.main.async { self.users = []; self.isLoading = false }
                    return
                }

                let group = DispatchGroup()
                var userDocs: [String: [String: Any]] = [:]
                for (uid, _) in sorted {
                    group.enter()
                    self.db.collection("users").document(uid).getDocument { snap, _ in
                        if let data = snap?.data() { userDocs[uid] = data }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    self.users = sorted.map { (uid, gain) in
                        let d = userDocs[uid] ?? [:]
                        return LeaderboardUser(
                            id: uid,
                            username: d["username"] as? String ?? gain.username,
                            score: Int(gain.delta),
                            profilePicURL: d["profilePicURL"] as? String,
                            gainDetail: gain.detail
                        )
                    }
                    self.isLoading = false
                }
            }
    }

    // MARK: - Heaviest lifts leaderboard
    private func fetchHeaviestLifts(period: TimePeriod) {
        db.collection("posts")
            .whereField("category", isEqualTo: "workout")
            .whereField("timestamp", isGreaterThan: Timestamp(date: period.startDate))
            .getDocuments { [weak self] snap, _ in
                guard let self = self else { return }
                let docs = snap?.documents ?? []

                typealias LiftInfo = (weight: Double, display: String, exercise: String, username: String)
                var best: [String: LiftInfo] = [:]

                for doc in docs {
                    let d = doc.data()
                    guard let newVal = d["newValue"] as? Double, newVal > 0 else { continue }
                    let unit = d["progressionUnit"] as? String ?? ""
                    guard unit == "lbs" || unit == "kg" else { continue }
                    let authorId = d["authorId"] as? String ?? ""
                    guard !authorId.isEmpty else { continue }
                    let exercise = d["exerciseName"] as? String ?? "Lift"
                    let author   = d["author"]   as? String ?? ""
                    let weightKg = unit == "kg" ? newVal : newVal * 0.453592
                    let display  = "\(Int(newVal)) \(unit) – \(exercise)"

                    if let existing = best[authorId] {
                        if weightKg > existing.weight { best[authorId] = (weightKg, display, exercise, author) }
                    } else {
                        best[authorId] = (weightKg, display, exercise, author)
                    }
                }

                let sorted = best.sorted { $0.value.weight > $1.value.weight }.prefix(50)
                guard !sorted.isEmpty else {
                    DispatchQueue.main.async { self.users = []; self.isLoading = false }
                    return
                }

                let group = DispatchGroup()
                var userDocs: [String: [String: Any]] = [:]
                for (uid, _) in sorted {
                    group.enter()
                    self.db.collection("users").document(uid).getDocument { snap, _ in
                        if let data = snap?.data() { userDocs[uid] = data }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    self.users = sorted.map { (uid, lift) in
                        let d = userDocs[uid] ?? [:]
                        return LeaderboardUser(
                            id: uid,
                            username: d["username"] as? String ?? lift.username,
                            score: Int(lift.weight),
                            profilePicURL: d["profilePicURL"] as? String,
                            gainDetail: lift.display
                        )
                    }
                    self.isLoading = false
                }
            }
    }

    // MARK: - Workout streak leaderboard
    func fetchStreaks() {
        db.collection("users")
            .order(by: "workoutStreak", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snap, _ in
                let list = (snap?.documents ?? []).compactMap { d -> LeaderboardUser? in
                    let x = d.data()
                    let streak = x["workoutStreak"] as? Int ?? 0
                    guard streak > 0 else { return nil }
                    return LeaderboardUser(
                        id: d.documentID,
                        username: x["username"] as? String ?? "Unknown",
                        score: streak,
                        profilePicURL: x["profilePicURL"] as? String,
                        gainDetail: "\(streak) day streak 🔥"
                    )
                }
                DispatchQueue.main.async {
                    self?.users = list
                    self?.isLoading = false
                }
            }
    }

    // MARK: - Gym + Workout type ranks
    func fetchGymRanks() {
        loadGymAndWorkoutTypes()
    }

    private func loadGymAndWorkoutTypes() {
        db.collection("posts").getDocuments { [weak self] snapshot, _ in
            guard let documents = snapshot?.documents else { return }

            var gymCounts: [String: Int] = [:]
            var foodTypeCounts: [String: Int] = [:]

            for doc in documents {
                let data = doc.data()
                let gym      = (data["gym"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let foodType = (data["foodType"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !gym.isEmpty      { gymCounts[gym, default: 0] += 1 }
                if !foodType.isEmpty { foodTypeCounts[foodType, default: 0] += 1 }
            }

            let gymRanks = gymCounts
                .map { GymRank(id: $0.key, name: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }

            let foodTypeRanks = foodTypeCounts
                .map { FoodTypeRank(id: $0.key, name: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }

            DispatchQueue.main.async {
                self?.gymRanks = gymRanks
                self?.foodTypeRanks = foodTypeRanks
                self?.isLoading = false
            }
        }
    }
}
