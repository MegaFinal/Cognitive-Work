//
//  DashboardViewModel.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI
import CloudKit

@Observable
class DashboardViewModel {

    // MARK: - Chart Data Types

    /// One room inside a chart (a bar segment or a legend item).
    struct RoomSlice: Identifiable {
        let id: String
        let name: String
        let color: Color
        let choreCount: Int
    }

    /// One column of the daily chart: one day, split by room.
    struct DaySlice: Identifiable {
        let day: Date
        let rooms: [RoomSlice]
        var id: Date { day }
    }

    // MARK: - Cache

    private var user: UserModel?
    private var houseMembers: [UserModel] = []
    private var chores: [ChoreModel] = []
    private var assignments: [RecurrentAssignmentModel] = []
    private var rooms: [RoomModel] = []

    // MARK: - Period

    /// Monday of the selected week. The chart always goes from Monday to Sunday.
    var periodStart: Date = DashboardViewModel.mondayOfWeek(containing: .now)

    /// Monday of the week that contains `date` (weeks run Monday → Sunday).
    static func mondayOfWeek(containing date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // 1 = Sunday, 2 = Monday
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    // MARK: - 1. Daily Completion Ring

    var completedToday: Int = 0
    var totalToday: Int = 0
    var completionProgress: Double = 0.0
    var completionText: String = "0%"

    // MARK: - 2. Room Distribution (legend)

    /// Rooms that appear in the period, with their total chore count.
    var roomDistribution: [RoomSlice] = []

    // MARK: - 3. Cognitive Load

    /// The user's points (also used by the "42 pontos" card).
    var myCognitiveLoad: Int = 0
    var houseCognitiveLoad: Int = 0
    var myCognitiveShare: Double = 0.0
    var idealCognitiveShare: Double = 0.0
    var myCognitiveShareText: String = "0%"
    var idealCognitiveShareText: String = "0%"

    // MARK: - 4. Daily Distribution by Room

    var dailyRoomDistribution: [DaySlice] = []

    // MARK: - 5. Unowned Public Chores

    var unownedPublicCount: Int = 0
    var totalPublicCount: Int = 0
    var unownedPublicProgress: Double = 0.0

    // MARK: - Load

    /// Fetches everything from CloudKit, fills the cache and computes every chart.
    func load() async {
        async let fetchUser = CloudKitManager.shared.fetchMyHouseUser()
        async let fetchMembers = CloudKitManager.shared.fetchHouseUsers()
        async let fetchChores = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let fetchAssignments = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        async let fetchRooms = CloudKitManager.shared.fetchAll(RoomModel.self)

        user = await fetchUser
        houseMembers = await fetchMembers
        chores = await fetchChores
        assignments = await fetchAssignments
        rooms = await fetchRooms

        refresh()
    }

    /// Recomputes every chart from the cache
    func refresh() {
        loadCompletionRing()
        loadCognitiveLoad()
        loadDailyRoomDistribution()
        loadRoomDistribution()
        loadUnownedPublicChores()
    }

    /// Moves to the next (`+1`) or previous (`-1`) week and recomputes from the cache.
    func changePeriod(by offset: Int) {
        guard let newStart = Calendar.current.date(byAdding: .day, value: offset * 7, to: periodStart)
        else { return }
        periodStart = newStart
        loadDailyRoomDistribution()
        loadRoomDistribution()
    }

    // MARK: - 1. Completion Ring

    func loadCompletionRing() {
        guard let user else { return }

        // Same filter as the chores screen
        let today = DashboardModel(user: user)
        today.setup(chores: chores, assignments: assignments)

        totalToday = today.todayChores.count
        completedToday = totalToday - today.toDoList.count
        completionProgress = fraction(completedToday, of: totalToday)
        completionText = percentText(completionProgress)
    }

    // MARK: - 2. Room Distribution

    /// Sums the daily chart per room — must run after `loadDailyRoomDistribution()`.
    func loadRoomDistribution() {
        var totals: [String: RoomSlice] = [:]
        for slice in dailyRoomDistribution.flatMap(\.rooms) {
            let previous = totals[slice.id]?.choreCount ?? 0
            totals[slice.id] = RoomSlice(
                id: slice.id,
                name: slice.name,
                color: slice.color,
                choreCount: previous + slice.choreCount
            )
        }
        roomDistribution = totals.values.sorted { $0.choreCount > $1.choreCount }
    }

    // MARK: - 3. Cognitive Load

    func loadCognitiveLoad() {
        guard let user else { return }

        myCognitiveLoad = user.points
        houseCognitiveLoad = houseMembers.reduce(0) { $0 + $1.points }
        myCognitiveShare = fraction(myCognitiveLoad, of: houseCognitiveLoad)
        idealCognitiveShare = houseMembers.isEmpty ? 0 : 1.0 / Double(houseMembers.count)
        myCognitiveShareText = percentText(myCognitiveShare)
        idealCognitiveShareText = percentText(idealCognitiveShare)
    }

    // MARK: - 4. Daily Room Distribution

    func loadDailyRoomDistribution() {
        guard let userID = user?.recordID else { return }
        let calendar = Calendar.current
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: periodStart) }

        // The user's assignments, by recordID
        let myAssignments = Dictionary(
            assignments
                .filter { $0.userReference?.recordID == userID }
                .compactMap { a in a.recordID.map { ($0, a) } },
            uniquingKeysWith: { first, _ in first }
        )

        // Dates on which each chore falls for the user
        func dates(of chore: ChoreModel) -> [Date] {
            if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
                return refs.compactMap { myAssignments[$0.recordID]?.day }
            }
            if chore.currentResponsibleReference?.recordID == userID, let due = chore.dueDate {
                return [due]
            }
            return []
        }

        dailyRoomDistribution = days.map { day in
            let choresOfDay = chores.filter { chore in
                dates(of: chore).contains { calendar.isDate($0, inSameDayAs: day) }
            }
            let slices: [RoomSlice] = rooms.compactMap { room in
                let count = choresOfDay.filter { $0.roomReference?.recordID == room.recordID }.count
                guard count > 0, let id = room.recordID else { return nil }
                return RoomSlice(id: id.recordName, name: room.name, color: room.color.uiColor, choreCount: count)
            }
            return DaySlice(day: day, rooms: slices)
        }
    }

    // MARK: - 5. Unowned Public Chores

    func loadUnownedPublicChores() {
        let publicChores = chores.filter { $0.isPublic }

        totalPublicCount = publicChores.count
        unownedPublicCount = publicChores.filter { $0.currentResponsibleReference == nil }.count
        unownedPublicProgress = fraction(unownedPublicCount, of: totalPublicCount)
    }

    // MARK: - Helpers

    private func fraction(_ value: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
