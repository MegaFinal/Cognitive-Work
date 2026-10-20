//
//  RetroViewModel.swift
//  Cognitive-Work
//

import SwiftUI
import CloudKit

/// The retrospective numbers: my chores in the 15 days before the current cycle.
///
/// Reads from `HouseDataStore`, so it usually costs no CloudKit request. Only recurring
/// occurrences count: completed one-off chores are deleted when a new division is generated.
@Observable
class RetroViewModel {

    private(set) var completedCount = 0
    private(set) var totalCount = 0
    /// Longest run of days in the period with every one of my occurrences completed.
    private(set) var streakDays = 0
    /// Points of the occurrences I completed in the period.
    private(set) var points = 0
    /// Completed occurrences per room, most first.
    private(set) var rooms: [RetroChartItemDTO] = []
    private(set) var isLoading = true

    private let calendar = Calendar.current

    /// Share of my occurrences completed, `0...100`.
    var percentage: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount) * 100
    }

    var topRoomName: String? { rooms.first?.roomName }

    func load(now: Date = Date()) async {
        defer { isLoading = false }

        let snapshot = await HouseDataStore.shared.load()
        guard let me = snapshot.houseUser,
              let period = previousPeriod(assignments: snapshot.assignments, now: now)
        else { return }

        // The same person may have more than one UserModel (same ownerRecordName).
        let myIDs = Set(
            ([me] + snapshot.users.filter { $0.ownerRecordName == me.ownerRecordName })
                .compactMap { $0.recordID }
        )
        let choresByID = Dictionary(
            snapshot.chores.compactMap { chore in chore.recordID.map { ($0, chore) } },
            uniquingKeysWith: { first, _ in first }
        )
        let roomsByID = Dictionary(
            snapshot.rooms.compactMap { room in room.recordID.map { ($0, room) } },
            uniquingKeysWith: { first, _ in first }
        )

        let mine = snapshot.assignments.filter { assignment in
            period.contains(calendar.startOfDay(for: assignment.day))
            && (assignment.userReferences ?? []).contains { myIDs.contains($0.recordID) }
        }
        let completed = mine.filter(\.isCompleted)

        totalCount = mine.count
        completedCount = completed.count
        streakDays = longestStreak(of: mine, in: period)

        var pointsSum = 0
        var countByRoom: [CKRecord.ID: Int] = [:]
        for assignment in completed {
            guard let choreID = assignment.choreReference?.recordID,
                  let chore = choresByID[choreID] else { continue }
            pointsSum += chore.score
            if let roomID = chore.roomReference?.recordID {
                countByRoom[roomID, default: 0] += 1
            }
        }
        points = pointsSum
        rooms = countByRoom
            .compactMap { roomID, count -> RetroChartItemDTO? in
                guard let room = roomsByID[roomID] else { return nil }
                return RetroChartItemDTO(roomName: room.name, numOfChores: count, roomColor: room.color.uiColor)
            }
            .sorted { $0.numOfChores > $1.numOfChores }
    }

    /// The 15 days before the current cycle. Same cycle rule as the "Sua retrospectiva
    /// chegou" notification: the current cycle starts on the last occurrence day − 14.
    private func previousPeriod(assignments: [RecurrentAssignmentModel], now: Date) -> Range<Date>? {
        let today = calendar.startOfDay(for: now)
        guard let lastDay = assignments.map({ calendar.startOfDay(for: $0.day) }).max(),
              let cycleStart = calendar.date(byAdding: .day, value: -14, to: lastDay)
        else { return nil }

        let end = min(cycleStart, today)
        guard let start = calendar.date(byAdding: .day, value: -15, to: end) else { return nil }
        return start..<end
    }

    /// Days with nothing of mine left undone keep the streak; days without chores don't break it.
    private func longestStreak(of assignments: [RecurrentAssignmentModel], in period: Range<Date>) -> Int {
        guard !assignments.isEmpty else { return 0 }

        let daysWithPending = Set(
            assignments.filter { !$0.isCompleted }.map { calendar.startOfDay(for: $0.day) }
        )

        var longest = 0
        var current = 0
        var day = period.lowerBound
        while day < period.upperBound {
            if daysWithPending.contains(day) {
                current = 0
            } else {
                current += 1
                longest = max(longest, current)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return longest
    }
}
