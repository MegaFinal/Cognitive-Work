//
//  HouseDataStore.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import Foundation
import CloudKit

/// Everything the main tabs show, read from CloudKit in a single pass.
struct HouseSnapshot {
    let id = UUID()

    let chores: [ChoreModel]
    let users: [UserModel]

    /// Every user record of the house, including the extra records of the same person that
    /// ``users`` merges. Used to resolve who a reference points at.
    let userRecords: [UserModel]
    let rooms: [RoomModel]
    let assignments: [RecurrentAssignmentModel]

    let houseUser: UserModel?

    let privateUser: UserModel?

    /// The house's shopping list, or `nil` if it has none.
    let shopList: ShopListModel?

    /// Every shopping item visible to the user (the list keeps those whose parent it is).
    let shopItems: [ShopListItem]
}

/// Loads the house data once and serves it to every tab.
@MainActor
@Observable
final class HouseDataStore {

    static let shared = HouseDataStore()

    // MARK: - State

    /// The latest data, or `nil` until the first load finishes (and after ``reset()``).
    private(set) var snapshot: HouseSnapshot?

    /// `true` when something changed since the data in ``snapshot`` was requested.
    @ObservationIgnored
    private var isStale = true

    /// How many times ``invalidate()`` ran.
    @ObservationIgnored
    private var invalidationCount = 0

    /// The fetch currently running, so simultaneous callers wait for it instead of starting
    /// their own.
    @ObservationIgnored
    private var inFlight: Task<HouseSnapshot, Never>?

    /// Identifies the newest fetch. An older one that finishes late must not overwrite it.
    @ObservationIgnored
    private var latestFetchID: UUID?

    init() {}

    // MARK: - Reading

    /// Whether ``snapshot`` can be used as is, without asking CloudKit again.
    var isUpToDate: Bool {
        snapshot != nil && !isStale
    }

    /// The house data, fetching it only when it is missing or stale.
    @discardableResult
    func load(force: Bool = false) async -> HouseSnapshot {
        if !force {
            if let snapshot, !isStale { return snapshot }
            if let inFlight { return await inFlight.value }
        }
        return await fetch()
    }

    /// The snapshot already in memory, or a first load if there is none yet.
    func current() async -> HouseSnapshot {
        if let snapshot { return snapshot }
        return await load()
    }

    // MARK: - Invalidation

    /// Marks the snapshot as outdated; the next ``load(force:)`` fetches again.
    func invalidate() {
        invalidationCount &+= 1
        isStale = true
    }

    /// A change reported by CloudKit (push from another device): invalidates and reloads.
    @discardableResult
    func refreshAfterRemoteChange() async -> HouseSnapshot {
        invalidate()
        return await load()
    }

    /// Forgets everything, e.g. when a different account or house takes over.
    func reset() {
        inFlight?.cancel()
        inFlight = nil
        latestFetchID = nil
        snapshot = nil
        isStale = true
    }

    // MARK: - Fetching

    private func fetch() async -> HouseSnapshot {
        let fetchID = UUID()
        latestFetchID = fetchID
        let invalidationsAtStart = invalidationCount

        let task = Task { await Self.download() }
        inFlight = task
        let result = await task.value

        guard latestFetchID == fetchID else { return snapshot ?? result }

        snapshot = result
        isStale = invalidationCount != invalidationsAtStart
        inFlight = nil
        return result
    }

    /// Every request the tabs need, running in parallel.
    private nonisolated static func download() async -> HouseSnapshot {
        let cloud = CloudKitManager.shared

        async let chores = cloud.fetchAll(ChoreModel.self)
        async let userRecords = cloud.fetchHouseUserRecords()
        async let rooms = cloud.fetchAll(RoomModel.self)
        async let assignments = cloud.fetchAll(RecurrentAssignmentModel.self)
        async let houseUser = cloud.currentHouseUser()
        async let privateUser = cloud.fetchMyUser()
        async let shopList = fetchShopList()
        async let shopItems = cloud.fetchAll(ShopListItem.self)
        // Points live in `UserScoreModel`; they are copied onto the users below.
        async let scores = cloud.fetchAll(UserScoreModel.self)

        let records = await userRecords
        let currentUser = await houseUser
        await UserScoreModel.apply(scores, to: records + [currentUser].compactMap { $0 })

        return await HouseSnapshot(
            chores: chores,
            users: cloud.deduplicatedByOwner(records),
            userRecords: records,
            rooms: rooms,
            assignments: assignments,
            houseUser: currentUser,
            privateUser: privateUser,
            shopList: shopList,
            shopItems: shopItems
        )
    }

    private nonisolated static func fetchShopList() async -> ShopListModel? {
        guard let house = try? await CloudKitManager.shared.currentHouse() else { return nil }
        return await house.shopList
    }
}
