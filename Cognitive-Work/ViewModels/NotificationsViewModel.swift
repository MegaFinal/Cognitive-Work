//
//  NotificationsViewMode.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 30/09/26.
//

import SwiftUI
import CloudKit

/// Where the app takes the user when a notification is tapped.
/// Cases carry the data they need (which user, which chore).
enum NotificationDestination {
    case pickChores
    case retrospective
    case dashboard
    case userProfile(UserModel)
    case chore(ChoreModel, RecurrentAssignmentModel?)
}

struct NotificationModel: Identifiable {
    /// STABLE id (not UUID()): the same notification gets the same id on every rebuild.
    let id: String
    let kind: Notifications
    let title: String
    let subtitle: String
    let date: Date
    let destination: NotificationDestination
}

/// A "hoje" / "ontem" / "23 de setembro" group.
struct NotificationSection: Identifiable {
    let day: Date
    let items: [NotificationModel]
    var id: Date { day }
}

@Observable
class NotificationsViewModel {

    static let lifetimeInDays = 14
    private static let lastSeenKey = "notifications.lastSeenDate"

    private(set) var sections: [NotificationSection] = []
    private(set) var newCount = 0
    private(set) var isLoading = false

    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard

    // MARK: - Loading

    func load(now: Date = Date()) async {
        if sections.isEmpty { isLoading = true }
        defer { isLoading = false }

        // The 5 fetches run in parallel; the `await` below waits for all of them.
        async let choresTask = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let assignmentsTask = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        async let roomsTask = CloudKitManager.shared.fetchAll(RoomModel.self)
        async let membersTask = CloudKitManager.shared.fetchHouseUsers()
        async let meTask = CloudKitManager.shared.currentHouseUser()

        let (chores, assignments, rooms, members, me) =
            await (choresTask, assignmentsTask, roomsTask, membersTask, meTask)

        guard !Task.isCancelled, let me else { return }

        // Fast lookup tables: recordID → object.
        let choresByID = Dictionary(
            chores.compactMap { chore in chore.recordID.map { ($0, chore) } },
            uniquingKeysWith: { first, _ in first }
        )
        let roomNameByID = Dictionary(
            rooms.compactMap { room in room.recordID.map { ($0, room.name) } },
            uniquingKeysWith: { first, _ in first }
        )
        // The same person may have more than one UserModel (same ownerRecordName).
        let myIDs = Set(
            ([me] + members.filter { $0.ownerRecordName == me.ownerRecordName })
                .compactMap(\.recordID)
        )

        let windowStart = calendar.date(
            byAdding: .day, value: -Self.lifetimeInDays, to: calendar.startOfDay(for: now)
        ) ?? now

        var all: [NotificationModel] = []
        all += grabChoreNotifications(assignments, choresByID: choresByID, from: windowStart, now: now)
        all += lateChoreNotifications(assignments, choresByID: choresByID, roomNameByID: roomNameByID,
                                      myIDs: myIDs, from: windowStart, now: now)
        all += divisionNotifications(assignments)
        all += newUserNotifications(members, myIDs: myIDs)

        // The 14-day rule lives in a single place (and nothing from the future shows up).
        all = all.filter { $0.date >= windowStart && $0.date <= now }

        sections = makeSections(from: all)
        newCount = all.filter { $0.date > lastSeenDate }.count
    }

    // MARK: - Notification builders

    /// "N tarefas a pegar hoje": one item per day that has unclaimed slots.
    private func grabChoreNotifications(
        _ assignments: [RecurrentAssignmentModel],
        choresByID: [CKRecord.ID: ChoreModel],
        from start: Date, now: Date
    ) -> [NotificationModel] {
        let today = calendar.startOfDay(for: now)

        let open = assignments.filter { assignment in
            let nobody = assignment.userReferences?.isEmpty ?? true
            let choreExists = assignment.choreReference.flatMap { choresByID[$0.recordID] } != nil
            return nobody && !assignment.isCompleted && choreExists
                && assignment.day >= start && assignment.day <= today
        }

        let byDay = Dictionary(grouping: open) { calendar.startOfDay(for: $0.day) }

        return byDay.map { day, list in
            NotificationModel(
                id: "grab-\(day.timeIntervalSince1970)",
                kind: .grabChore,
                title: "\(list.count)" + Notifications.grabChore.rawValue,
                subtitle: Notifications.grabChore.subTitle,
                date: day,
                destination: .pickChores
            )
        }
    }

    /// "X está atrasado" (mine) and "Ninguém pegou X" (unclaimed).
    private func lateChoreNotifications(
        _ assignments: [RecurrentAssignmentModel],
        choresByID: [CKRecord.ID: ChoreModel],
        roomNameByID: [CKRecord.ID: String],
        myIDs: Set<CKRecord.ID>,
        from start: Date, now: Date
    ) -> [NotificationModel] {
        let today = calendar.startOfDay(for: now)

        return assignments.compactMap { assignment -> NotificationModel? in
            guard !assignment.isCompleted,
                  assignment.day < today,
                  let chore = assignment.choreReference.flatMap({ choresByID[$0.recordID] }),
                  // A chore becomes late on the day AFTER its scheduled day.
                  let lateSince = calendar.date(byAdding: .day, value: 1,
                                                to: calendar.startOfDay(for: assignment.day))
            else { return nil }

            let users = assignment.userReferences ?? []
            let kind: Notifications
            let title: String

            if users.isEmpty {
                kind = .noUserDelayedChore
                title = kind.rawValue + chore.name.prefix(1).lowercased() + chore.name.dropFirst()
            } else if users.contains(where: { myIDs.contains($0.recordID) }) {
                kind = .yourDelayedChore
                title = chore.name + kind.rawValue
            } else {
                return nil // someone else's late chore: don't notify me
            }

            let room = chore.roomReference.flatMap { roomNameByID[$0.recordID] } ?? "Sem cômodo"

            return NotificationModel(
                id: "late-\(assignment.recordID?.recordName ?? "\(chore.name)-\(lateSince)")",
                kind: kind,
                title: title,
                subtitle: "\(room) · cerca de \(Int(chore.duration.rounded())) min",
                date: lateSince,
                destination: .chore(chore, assignment)
            )
        }
    }

    /// "Nova divisão pronta" + "Sua retrospectiva chegou", on the current cycle's first day.
    private func divisionNotifications(_ assignments: [RecurrentAssignmentModel]) -> [NotificationModel] {
        // Same rule as CarouselViewModel.cycleWindow: first day = last day − 14.
        guard let lastDay = assignments.map({ calendar.startOfDay(for: $0.day) }).max(),
              let cycleStart = calendar.date(byAdding: .day, value: -14, to: lastDay)
        else { return [] }

        var result = [
            NotificationModel(
                id: "division-\(cycleStart.timeIntervalSince1970)",
                kind: .newDivision,
                title: Notifications.newDivision.rawValue,
                subtitle: Notifications.newDivision.subTitle,
                date: cycleStart,
                destination: .dashboard
            )
        ]

        // On the very first division there is nothing to look back on.
        let hadPreviousCycle = assignments.contains { $0.day < cycleStart }
        if hadPreviousCycle {
            result.append(
                NotificationModel(
                    id: "retro-\(cycleStart.timeIntervalSince1970)",
                    kind: .retrospective,
                    title: Notifications.retrospective.rawValue,
                    subtitle: Notifications.retrospective.subTitle,
                    date: cycleStart,
                    destination: .retrospective
                )
            )
        }
        return result
    }

    /// "Fulano entrou na casa": everyone except me.
    private func newUserNotifications(_ members: [UserModel], myIDs: Set<CKRecord.ID>) -> [NotificationModel] {
        members.compactMap { user -> NotificationModel? in
            guard let id = user.recordID, !myIDs.contains(id),
                  let joined = user.joinedAt else { return nil }

            return NotificationModel(
                id: "user-\(id.recordName)",
                kind: .newUser,
                title: user.name + Notifications.newUser.rawValue,
                subtitle: Notifications.newUser.subTitle,
                date: joined,
                destination: .userProfile(user)
            )
        }
    }

    // MARK: - Grouping and "seen" state

    private func makeSections(from items: [NotificationModel]) -> [NotificationSection] {
        Dictionary(grouping: items) { calendar.startOfDay(for: $0.date) }
            .map { NotificationSection(day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    func title(for section: NotificationSection) -> String {
        if calendar.isDateInToday(section.day) { return "hoje" }
        if calendar.isDateInYesterday(section.day) { return "ontem" }
        return section.day.formatted(
            .dateTime.day().month(.wide).locale(Locale(identifier: "pt_BR"))
        ) // "23 de setembro"
    }

    var newCountText: String {
        switch newCount {
        case 0: "Nenhuma notificação nova"
        case 1: "1 nova notificação"
        default: "\(newCount) novas notificações"
        }
    }

    private var lastSeenDate: Date {
        defaults.object(forKey: Self.lastSeenKey) as? Date ?? .distantPast
    }

    func markAllAsSeen(now: Date = Date()) {
        defaults.set(now, forKey: Self.lastSeenKey)
    }
}
