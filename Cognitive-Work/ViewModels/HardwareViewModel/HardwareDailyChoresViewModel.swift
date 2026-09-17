//
//  HardwareDailyChoresViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 17/09/26.
//

import Foundation
import CloudKit

/// A single house member's chores for today, together with their share of the day's total workload.
struct UserDailyChoresGroup: Identifiable {
    var user: UserModel

    /// This user's chores due today, in display order.
    var chores: [ChoreModel]

    /// This user's share of every chore due today across the whole house, from `0.0` to `1.0`.
    var shareOfDay: Double

    var id: String { user.id }

    /// ``shareOfDay`` formatted (e.g. `"45%"`).
    var shareOfDayFormatted: String {
        "\(Int((shareOfDay * 100).rounded()))%"
    }
}

/// Loads today's chores for every member of the house and groups them by responsible user, for
/// the daily chores dashboard (``HardwareDailyChoresView``).
@Observable
class HardwareDailyChoresViewModel {

    // MARK: - Core Data

    private var allChores: [ChoreModel] = []
    private var roomModels: [RoomModel] = []
    private var dailyAssignments: [RecurrentAssignmentModel] = []

    // MARK: - Display Data

    /// Every house member's chores due today
    private(set) var userGroups: [UserDailyChoresGroup] = []

    /// Every room referenced by today's chores, for the color legend.
    private(set) var roomsInUse: [RoomModel] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d 'de' MMMM."
        return formatter
    }()

    var todayDateFormatted: String {
        return dateFormatter.string(from: Date())
    }

    // MARK: - Initialization
    init(
        chores: [ChoreModel] = [],
        users: [UserModel] = [],
        rooms: [RoomModel] = [],
        assignments: [RecurrentAssignmentModel] = []
    ) {
        self.allChores = chores
        self.roomModels = rooms
        self.dailyAssignments = assignments
        rebuildUserGroups(for: users)
    }

    // MARK: - Data Fetching

    /// Fetches every chore, room, house member, and daily assignment from CloudKit, then
    /// rebuilds ``userGroups`` and ``roomsInUse``.
    func setup() async {
        async let fetchChores = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let fetchUsers = CloudKitManager.shared.fetchHouseUsers()
        async let fetchRoom = CloudKitManager.shared.fetchAll(RoomModel.self)
        async let fetchAssignment = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)

        let (chores, users, rooms, assignments) = await (fetchChores, fetchUsers, fetchRoom, fetchAssignment)

        self.allChores = chores
        self.roomModels = rooms
        self.dailyAssignments = assignments

        rebuildUserGroups(for: users)
    }

    // MARK: - Grouping & Statistics

    /// Rebuilds ``userGroups`` and ``roomsInUse`` from ``allChores``/``dailyAssignments`` for the
    /// given house members.
    private func rebuildUserGroups(for users: [UserModel]) {
        let today = Calendar.current.startOfDay(for: Date())

        let todaysChores: [(chore: ChoreModel, responsibleID: CKRecord.ID)] = allChores.compactMap { chore in
            guard let responsibleID = responsibleUserID(for: chore, today: today) else { return nil }
            return (chore, responsibleID)
        }

        let totalChoresToday = todaysChores.count

        self.userGroups = users.map { user in
            let choresForUser = todaysChores
                .filter { $0.responsibleID == user.recordID }
                .map { $0.chore }

            let share = totalChoresToday > 0
                ? Double(choresForUser.count) / Double(totalChoresToday)
                : 0.0

            return UserDailyChoresGroup(user: user, chores: choresForUser, shareOfDay: share)
        }
        .sorted { $0.user.name < $1.user.name }

        let roomIDsInUse = Set(todaysChores.compactMap { $0.chore.roomReference?.recordID })
        self.roomsInUse = roomModels.filter { room in
            guard let roomID = room.recordID else { return false }
            return roomIDsInUse.contains(roomID)
        }
    }

    /// The recordID of whoever is responsible for `chore` today, or `nil` when it isn't due
    /// today or has nobody assigned.
    private func responsibleUserID(for chore: ChoreModel, today: Date) -> CKRecord.ID? {
        if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
            let ids = Set(refs.map { $0.recordID })
            let todaysAssignment = dailyAssignments.first { assignment in
                guard let assignmentID = assignment.recordID, ids.contains(assignmentID) else {
                    return false
                }
                return Calendar.current.isDate(assignment.day, inSameDayAs: today)
            }
            return todaysAssignment?.userReference?.recordID
        }

        guard let dueDate = chore.dueDate, Calendar.current.isDateInToday(dueDate) else {
            return nil
        }
        return chore.currentResponsibleReference?.recordID
    }

    // MARK: - Helpers

    /// The room a chore belongs to
    func room(for chore: ChoreModel) -> RoomModel? {
        guard let roomID = chore.roomReference?.recordID else { return nil }
        return roomModels.first { $0.recordID == roomID }
    }
}
