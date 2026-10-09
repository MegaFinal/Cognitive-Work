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
    // [newUser] Disabled until we define what tapping it should do.
    // case userProfile(UserModel)
    case chore(ChoreModel, RecurrentAssignmentModel?)
}

struct NotificationModel: Identifiable {
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

    /// The snapshot and day the current `sections` were built for.
    @ObservationIgnored private var builtSnapshotID: UUID?
    @ObservationIgnored private var builtDay: Date?

    // MARK: - Loading

    /// Reads the house data from `HouseDataStore`. The store only hits CloudKit when its
    /// data is missing or stale, so opening this screen usually costs no request at all.
    /// - Parameter force: `true` for pull-to-refresh, to bypass the store's cache.
    func load(force: Bool = false, now: Date = Date()) async {
        let store = HouseDataStore.shared
        if sections.isEmpty && !store.isUpToDate { isLoading = true }
        defer { isLoading = false }

        let snapshot = await store.load(force: force)
        guard !Task.isCancelled else { return }

        // Same data and same day: the list we already have is still correct.
        if snapshot.id == builtSnapshotID,
           let builtDay, calendar.isDate(builtDay, inSameDayAs: now) {
            return
        }

        rebuild(from: snapshot, now: now)
        builtSnapshotID = snapshot.id
        builtDay = now
    }

    /// Builds every notification from data already in memory. No CloudKit calls.
    private func rebuild(from snapshot: HouseSnapshot, now: Date) {
        guard let me = snapshot.houseUser else { return }

        // Fast lookup tables: recordID → object.
        let choresByID = Dictionary(
            snapshot.chores.compactMap { chore in chore.recordID.map { ($0, chore) } },
            uniquingKeysWith: { first, _ in first }
        )
        let roomNameByID = Dictionary(
            snapshot.rooms.compactMap { room in room.recordID.map { ($0, room.name) } },
            uniquingKeysWith: { first, _ in first }
        )
        // The same person may have more than one UserModel (same ownerRecordName).
        let myIDs = Set(
            ([me] + snapshot.users.filter { $0.ownerRecordName == me.ownerRecordName })
                .compactMap{ $0.recordID}
        )

        let windowStart = calendar.date(
            byAdding: .day, value: -Self.lifetimeInDays, to: calendar.startOfDay(for: now)
        ) ?? now

        var all: [NotificationModel] = []
        // Recurring days and one-off chores, in a single shape (see `Occurrence`).
        let occurrences = makeOccurrences(chores: snapshot.chores, assignments: snapshot.assignments,
                                          choresByID: choresByID)

        all += grabChoreNotifications(occurrences, from: windowStart, now: now)
        all += lateChoreNotifications(occurrences, roomNameByID: roomNameByID, myIDs: myIDs, now: now)
        all += divisionNotifications(snapshot.assignments)
        // [newUser] Disabled until we define what tapping it should do.
        // all += newUserNotifications(snapshot.users, myIDs: myIDs)

        // The 14-day rule lives in a single place (and nothing from the future shows up).
        all = all.filter { $0.date >= windowStart && $0.date <= now }

        sections = makeSections(from: all)
        newCount = all.filter { $0.date > lastSeenDate }.count
    }

    // MARK: - Occurrences

    /// One scheduled instance of a chore, whatever kind of chore it is:
    /// - a recurring chore → one per assignment (each day has its own users and done state);
    /// - a one-off chore → the chore itself (no assignments: it uses its own `dueDate`,
    ///   responsible users and `isDone`).
    /// The builders below only deal with this type, so they don't care which kind it is.
    private struct Occurrence {
        let chore: ChoreModel
        /// `nil` for one-off chores.
        let assignment: RecurrentAssignmentModel?
        /// Start of the day this instance is scheduled for.
        let day: Date
        let userIDs: [CKRecord.ID]
        let isDone: Bool

        var isUnassigned: Bool { userIDs.isEmpty }
    }

    /// Turns assignments and one-off chores into ``Occurrence``s.
    /// Same rules as `CarouselViewModel.rebuildUnassignedItems` for one-off chores.
    private func makeOccurrences(
        chores: [ChoreModel],
        assignments: [RecurrentAssignmentModel],
        choresByID: [CKRecord.ID: ChoreModel]
    ) -> [Occurrence] {
        // Recurring chores: one occurrence per assignment whose chore still exists.
        var result: [Occurrence] = assignments.compactMap { assignment -> Occurrence? in
            guard let chore = assignment.choreReference.flatMap({ choresByID[$0.recordID] }) else { return nil }
            return Occurrence(
                chore: chore,
                assignment: assignment,
                day: calendar.startOfDay(for: assignment.day),
                userIDs: (assignment.userReferences ?? []).map(\.recordID),
                isDone: assignment.isCompleted
            )
        }

        // One-off chores: no assignments, so the chore is its own occurrence.
        for chore in chores where (chore.dailyAssignmentsReference ?? []).isEmpty {
            // Without a date it is never "today" nor "late", so it can't become a notification.
            guard let dueDate = chore.dueDate else { continue }

            var userIDs = (chore.allResponsibleUsersReference ?? []).map(\.recordID)
            if let current = chore.currentResponsibleReference?.recordID, !userIDs.contains(current) {
                userIDs.append(current)
            }

            result.append(
                Occurrence(
                    chore: chore,
                    assignment: nil,
                    day: calendar.startOfDay(for: dueDate),
                    userIDs: userIDs,
                    isDone: chore.isDone
                )
            )
        }
        return result
    }

    // MARK: - Notification builders

    /// "N tarefas a pegar hoje": one item per day that has unclaimed occurrences.
    private func grabChoreNotifications(
        _ occurrences: [Occurrence],
        from start: Date, now: Date
    ) -> [NotificationModel] {
        let today = calendar.startOfDay(for: now)

        let open = occurrences.filter { occurrence in
            occurrence.isUnassigned && !occurrence.isDone
                && occurrence.day >= start && occurrence.day <= today
        }

        let byDay = Dictionary(grouping: open) { $0.day }

        return byDay.map { day, list in
            NotificationModel(
                id: "grab-\(day.timeIntervalSince1970)",
                kind: .grabChore,
                // Plural rules ("1 tarefa" / "3 tarefas") live in Localizable.xcstrings.
                title: L10n.tr("%lld tarefas a pegar hoje", list.count),
                subtitle: L10n.tr(Notifications.grabChore.subTitle),
                date: day,
                destination: .pickChores
            )
        }
    }

    /// "X está atrasado" (mine) and "Ninguém pegou X" (unclaimed).
    private func lateChoreNotifications(
        _ occurrences: [Occurrence],
        roomNameByID: [CKRecord.ID: String],
        myIDs: Set<CKRecord.ID>,
        now: Date
    ) -> [NotificationModel] {
        let today = calendar.startOfDay(for: now)

        return occurrences.compactMap { occurrence -> NotificationModel? in
            guard !occurrence.isDone,
                  occurrence.day < today,
                  // A chore becomes late on the day AFTER its scheduled day.
                  let lateSince = calendar.date(byAdding: .day, value: 1, to: occurrence.day)
            else { return nil }

            let chore = occurrence.chore
            // Default chores are stored in Portuguese; `localizedDefault` translates them.
            let choreName = chore.name.localizedDefault
            let kind: Notifications
            let title: String

            if occurrence.isUnassigned {
                kind = .noUserDelayedChore
                // Lowercase first letter so it reads well mid-sentence ("Ninguém pegou limpar...").
                let midSentenceName: String = choreName.prefix(1).lowercased() + choreName.dropFirst()
                title = L10n.tr("Ninguém pegou %@", midSentenceName)
            } else if occurrence.userIDs.contains(where: { myIDs.contains($0) }) {
                kind = .yourDelayedChore
                title = L10n.tr("%@ está atrasado", choreName)
            } else {
                return nil // someone else's late chore: don't notify me
            }

            let room = chore.roomReference.flatMap { roomNameByID[$0.recordID]?.localizedDefault }
                ?? L10n.tr("Sem Cômodo")
            // Assignment id for recurring days, chore id for one-off chores.
            let recordName = occurrence.assignment?.recordID?.recordName
                ?? chore.recordID?.recordName
                ?? "\(chore.name)-\(lateSince)"

            return NotificationModel(
                id: "late-\(recordName)",
                kind: kind,
                title: title,
                subtitle: L10n.tr("%@ · cerca de %lld min", room, Int(chore.duration.rounded())),
                date: lateSince,
                destination: .chore(chore, occurrence.assignment)
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
                title: L10n.tr(Notifications.newDivision.rawValue),
                subtitle: L10n.tr(Notifications.newDivision.subTitle),
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
                    title: L10n.tr(Notifications.retrospective.rawValue),
                    subtitle: L10n.tr(Notifications.retrospective.subTitle),
                    date: cycleStart,
                    destination: .retrospective
                )
            )
        }
        return result
    }

    // [newUser] Disabled until we define what tapping it should do.
//    /// "Fulano entrou na casa": everyone except me.
//    private func newUserNotifications(_ members: [UserModel], myIDs: Set<CKRecord.ID>) -> [NotificationModel] {
//        members.compactMap { user -> NotificationModel? in
//            guard let id = user.recordID, !myIDs.contains(id),
//                  let joined = user.joinedAt else { return nil }

//            return NotificationModel(
//                id: "user-\(id.recordName)",
//                kind: .newUser,
//                title: user.name + Notifications.newUser.rawValue,
//                subtitle: Notifications.newUser.subTitle,
//                date: joined,
//                destination: .userProfile(user)
//            )
//        }
//    }

    // MARK: - Grouping and "seen" state

    private func makeSections(from items: [NotificationModel]) -> [NotificationSection] {
        Dictionary(grouping: items) { calendar.startOfDay(for: $0.date) }
            .map { NotificationSection(day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    func title(for section: NotificationSection) -> String {
        if calendar.isDateInToday(section.day) { return L10n.tr("hoje") }
        if calendar.isDateInYesterday(section.day) { return L10n.tr("ontem") }
        // Follows the app language: "23 de setembro" / "September 23".
        return section.day.formatted(.dateTime.day().month(.wide).locale(L10n.locale))
    }

    var newCountText: String {
        // Singular/plural ("1 nova notificação" / "3 novas notificações") come from Localizable.xcstrings.
        newCount == 0
            ? L10n.tr("Nenhuma notificação nova")
            : L10n.tr("%lld novas notificações", newCount)
    }

    private var lastSeenDate: Date {
        defaults.object(forKey: Self.lastSeenKey) as? Date ?? .distantPast
    }

    func markAllAsSeen(now: Date = Date()) {
        defaults.set(now, forKey: Self.lastSeenKey)
    }
}
