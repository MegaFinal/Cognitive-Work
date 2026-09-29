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

    /// One slice of the room distribution chart.
    struct RoomSlice: Identifiable {
        let id: String
        let name: String
        let color: Color
        let choreCount: Int
    }

    // MARK: - 1. Daily Completion Ring

    var completedToday: Int = 0
    var totalToday: Int = 0

    /// From `0.0` to `1.0`.
    var completionProgress: Double = 0.0

    /// E.g. `"75%"`.
    var completionText: String = "0%"

    // MARK: - 2. Distribution by Room

    var roomDistribution: [RoomSlice] = []

    // MARK: - 3. Cognitive Load Comparison

    /// The user's points.
    var myCognitiveLoad: Int = 0

    /// Sum of the points of every house member.
    var houseCognitiveLoad: Int = 0

    /// The user's share of the house load, from `0.0` to `1.0`.
    var myCognitiveShare: Double = 0.0

    /// The ideal share for an even split (`1 / members`), from `0.0` to `1.0`.
    var idealCognitiveShare: Double = 0.0

    var myCognitiveShareText: String = "0%"
    var idealCognitiveShareText: String = "0%"

    // MARK: - 5. Unowned Public Chores

    var unownedPublicCount: Int = 0
    var totalPublicCount: Int = 0

    /// Fraction of public chores that still have no owner, from `0.0` to `1.0`.
    var unownedPublicProgress: Double = 0.0

    // MARK: - Load All

    /// Refreshes every chart at once.
    ///
    /// - Parameters:
    ///   - user: The user viewing the dashboard.
    ///   - houseMembers: Every house member (including `user`).
    ///   - chores: Every chore in the house.
    ///   - rooms: Every room in the house.
    ///   - todayChores: The user's chores for today (e.g. ``DashboardModel/todayChores``).
    ///   - pendingToday: Today's chores still pending (e.g. ``DashboardModel/toDoList``).
    func load(
        user: UserModel,
        houseMembers: [UserModel],
        chores: [ChoreModel],
        rooms: [RoomModel],
        todayChores: [ChoreModel],
        pendingToday: [ChoreModel]
    ) {
        loadCompletionRing(todayChores: todayChores, pendingToday: pendingToday)
        loadRoomDistribution(for: user, chores: chores, rooms: rooms)
        loadCognitiveLoad(for: user, houseMembers: houseMembers)
        loadUnownedPublicChores(chores: chores)
    }

    // MARK: - 1. Completion Ring

    func loadCompletionRing(todayChores: [ChoreModel], pendingToday: [ChoreModel]) {
        totalToday = todayChores.count
        completedToday = totalToday - pendingToday.count

        completionProgress = fraction(completedToday, of: totalToday)
        completionText = percentText(completionProgress)
    }

    /// Same ring, but fetches the user, chores and assignments from CloudKit itself.
    ///
    /// Today's and pending chores are filtered by ``DashboardModel``, so the ring always
    /// matches the progress cards on the chores screen.
    func loadCompletionRing() async {
        guard let myUser = await CloudKitManager.shared.fetchMyHouseUser() else { return }

        async let fetchChores = CloudKitManager.shared.fetchAll(ChoreModel.self)
        async let fetchAssignments = CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        let (chores, assignments) = await (fetchChores, fetchAssignments)

        let today = DashboardModel(user: myUser)
        today.setup(chores: chores, assignments: assignments)

        loadCompletionRing(todayChores: today.todayChores, pendingToday: today.toDoList)
    }

    // MARK: - 2. Room Distribution

    func loadRoomDistribution(for user: UserModel, chores: [ChoreModel], rooms: [RoomModel]) {
        let myChores = chores.filter { isResponsible(user, for: $0) }

        // Counts how many of the user's chores are in each room
        var countByRoomID: [CKRecord.ID: Int] = [:]
        for chore in myChores {
            guard let roomID = chore.roomReference?.recordID else { continue }
            countByRoomID[roomID, default: 0] += 1
        }

        roomDistribution = rooms.compactMap { room in
            guard let roomID = room.recordID,
                  let count = countByRoomID[roomID], count > 0
            else { return nil }

            return RoomSlice(
                id: roomID.recordName,
                name: room.name,
                color: room.color.uiColor,
                choreCount: count
            )
        }
        .sorted { $0.choreCount > $1.choreCount }
    }

    /// Same distribution, but fetches the rooms through each chore's `room` property.
    ///
    /// Makes one CloudKit fetch per distinct room (not one per chore).
    func loadRoomDistribution(for user: UserModel, chores: [ChoreModel]) async {
        let myChores = chores.filter { isResponsible(user, for: $0) }

        // Fetches each room only once
        var rooms: [RoomModel] = []
        var fetchedRoomIDs: Set<CKRecord.ID> = []
        for chore in myChores {
            guard let roomID = chore.roomReference?.recordID,
                  !fetchedRoomIDs.contains(roomID)
            else { continue }

            fetchedRoomIDs.insert(roomID)
            if let room = await chore.room {
                rooms.append(room)
            }
        }

        loadRoomDistribution(for: user, chores: myChores, rooms: rooms)
    }

    // MARK: - 3. Cognitive Load

    /// Compares only the user against the house total — other members are never exposed.
    func loadCognitiveLoad(for user: UserModel, houseMembers: [UserModel]) {
        myCognitiveLoad = user.points
        houseCognitiveLoad = houseMembers.reduce(0) { $0 + $1.points }

        myCognitiveShare = fraction(myCognitiveLoad, of: houseCognitiveLoad)
        idealCognitiveShare = houseMembers.isEmpty ? 0 : 1.0 / Double(houseMembers.count)

        myCognitiveShareText = percentText(myCognitiveShare)
        idealCognitiveShareText = percentText(idealCognitiveShare)
    }

    /// Fetches the user and the house members itself.
    func loadCognitiveLoad() async {
        async let fetchMyUser = CloudKitManager.shared.fetchMyHouseUser()
        async let fetchMembers = CloudKitManager.shared.fetchHouseUsers()
        let (myUser, members) = await (fetchMyUser, fetchMembers)

        guard let myUser else { return }
        loadCognitiveLoad(for: myUser, houseMembers: members)
    }

    /// Takes the user and fetches only the house members.
    func loadCognitiveLoad(for user: UserModel) async {
        let members = await CloudKitManager.shared.fetchHouseUsers()
        loadCognitiveLoad(for: user, houseMembers: members)
    }

    // MARK: - 5. Unowned Public Chores

    func loadUnownedPublicChores(chores: [ChoreModel]) {
        let publicChores = chores.filter { $0.isPublic }
        let unowned = publicChores.filter { $0.currentResponsibleReference == nil }

        totalPublicCount = publicChores.count
        unownedPublicCount = unowned.count
        unownedPublicProgress = fraction(unownedPublicCount, of: totalPublicCount)
    }

    /// Fetches every chore in the house itself.
    func loadUnownedPublicChores() async {
        let chores = await CloudKitManager.shared.fetchAll(ChoreModel.self)
        loadUnownedPublicChores(chores: chores)
    }

    // MARK: - Helpers

    /// `true` when the user is the chore's current responsible or is in its rotation.
    private func isResponsible(_ user: UserModel, for chore: ChoreModel) -> Bool {
        guard let userID = user.recordID else { return false }

        if chore.currentResponsibleReference?.recordID == userID { return true }
        return chore.allResponsibleUsersReference?.contains { $0.recordID == userID } ?? false
    }

    /// Safe division: returns `0` when the total is `0`.
    private func fraction(_ value: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }

    /// `0.75` → `"75%"`.
    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
