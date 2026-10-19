//
//  GamificationViewModel.swift
//  Cognitive-Work
//
//  Created by Claude on 15/10/26.
//

import Foundation
import CloudKit

/// Feeds the rewards tab: the user's coins, the house's rooms, and the coupons each room offers.
///
/// A coupon belongs to a room through its task: ``CouponModel/task`` points at a chore, and the
/// chore points at its room. Coins come from the user's ``CoinWalletModel``; prices are
/// recomputed from each chore with ``CouponPricing``.
///
/// Loading also settles closed cycles (``CycleSettlementService/prepareClosedCycles(_:members:houseID:today:)``),
/// so the coins of a finished cycle are ready to be redeemed in the retrospective.
@MainActor
@Observable
final class GamificationViewModel {

    // MARK: - State

    /// Coins the signed-in user can spend.
    private(set) var coins: Int = 0

    /// The signed-in user's points, for the rank shown on the screen.
    private(set) var points: Int = 0

    /// Record name of the coupon being bought, so its button shows progress.
    private(set) var buyingCouponName: String?

    /// Message of the last failed purchase, shown in an alert.
    var alertMessage: String?

    private(set) var rooms: [RoomModel] = []

    /// Whether the first load finished, so the screen can tell "loading" from "empty".
    private(set) var hasLoaded = false

    /// Key of the room chosen in the picker; `nil` until the first load picks one.
    var selectedRoomKey: String?

    /// Coupons available in each room, by ``key(for:)``.
    private var couponsByRoom: [String: [CouponModel]] = [:]

    @ObservationIgnored
    private var appliedSnapshotID: UUID?

    @ObservationIgnored
    private var houseUser: UserModel?

    @ObservationIgnored
    private var houseID: CKRecord.ID?

    /// Key of the latest cycle; purchases belong to it.
    @ObservationIgnored
    private var latestCycleKey: String?

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    /// `true` inside Xcode previews, where CloudKit can't run.
    @ObservationIgnored
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    // MARK: - Init

    init() {}

    init(previewCoins: Int, rooms: [RoomModel], couponsByRoomName: [String: [CouponModel]]) {
        self.coins = previewCoins
        self.rooms = rooms
        for room in rooms {
            couponsByRoom[Self.key(for: room)] = couponsByRoomName[room.name] ?? []
        }
        self.selectedRoomKey = rooms.first.map(Self.key(for:))
        self.hasLoaded = true
    }

    // MARK: - Derived

    var selectedRoom: RoomModel? {
        rooms.first { Self.key(for: $0) == selectedRoomKey }
    }

    /// Coupons of the selected room, cheapest first.
    var selectedCoupons: [CouponModel] {
        guard let selectedRoomKey else { return [] }
        return (couponsByRoom[selectedRoomKey] ?? []).sorted { $0.price < $1.price }
    }

    func couponCount(in room: RoomModel) -> Int {
        couponsByRoom[Self.key(for: room)]?.count ?? 0
    }

    func canAfford(_ coupon: CouponModel) -> Bool {
        coins >= coupon.price
    }

    func state(of coupon: CouponModel) -> CouponCard.PurchaseState {
        guard let latestCycleKey else { return .available }
        if let myID = houseUser?.recordID, coupon.isHeld(by: myID, inCycle: latestCycleKey) {
            return .ownedByMe
        }
        return coupon.isAvailable(latestCycleKey: latestCycleKey) ? .available : .taken
    }

    /// Stable across refreshes, unlike ``RoomModel/id``, which changes on every fetch.
    static func key(for room: RoomModel) -> String {
        room.recordID?.recordName ?? room.id.uuidString
    }

    // MARK: - Loading

    func setup() async {
        guard !isPreview else { hasLoaded = true; return }
        await load()
    }

    func refresh() async {
        guard !isPreview else { return }
        await load()
    }

    /// Coalesces refresh requests and cancels the previous one.
    func requestRefresh(debounce: Duration = .milliseconds(250)) {
        guard !isPreview else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled, let self else { return }
            await self.refresh()
        }
    }

    private func load() async {
        let snapshot = await HouseDataStore.shared.load()
        let house = try? await CloudKitManager.shared.currentHouse()
        let coupons = await CloudKitManager.shared.fetchAll(CouponModel.self)
            .filter { coupon in house?.recordID.map { coupon.recordID?.zoneID == $0.zoneID } ?? true }

        var cycles: [HouseCycleModel] = []
        var balance = snapshot.houseUser?.coins ?? 0
        if let houseID = house?.recordID {
            cycles = await HouseCycleModel.fetchAll(inHouseZone: houseID.zoneID)
            // Automatic part of the payout: pending payouts for every cycle that ended.
            await CycleSettlementService().prepareClosedCycles(cycles, members: snapshot.users, houseID: houseID)
            if let userID = snapshot.houseUser?.recordID {
                balance = await CoinWalletModel.balance(for: userID, legacyCoins: snapshot.houseUser?.coins ?? 0)
            }
        }
        guard !Task.isCancelled else { return }

        houseID = house?.recordID
        latestCycleKey = HouseCycleModel.latest(cycles)?.key
        coins = balance
        apply(snapshot, coupons: coupons)
    }

    private func apply(_ snapshot: HouseSnapshot, coupons: [CouponModel]) {
        defer { hasLoaded = true }

        houseUser = snapshot.houseUser
        points = snapshot.houseUser?.points ?? 0
        rooms = snapshot.rooms

        // coupon -> chore -> room. Only coupons on sale are offered.
        var roomKeyByChore: [String: String] = [:]
        var choreByName: [String: ChoreModel] = [:]
        let roomsByRecordName = Dictionary(
            snapshot.rooms.compactMap { room in room.recordID.map { ($0.recordName, room) } },
            uniquingKeysWith: { first, _ in first }
        )
        for chore in snapshot.chores {
            guard let choreName = chore.recordID?.recordName,
                  let roomName = chore.roomReference?.recordID.recordName,
                  let room = roomsByRecordName[roomName]
            else { continue }
            roomKeyByChore[choreName] = Self.key(for: room)
            choreByName[choreName] = chore
        }

        var grouped: [String: [CouponModel]] = [:]
        let pricing = CouponPricing.current
        for var coupon in coupons where coupon.isOnSale {
            guard let choreName = coupon.task?.recordID.recordName,
                  let roomKey = roomKeyByChore[choreName]
            else { continue }
            // The price follows the chore's current frequency and duration.
            if let chore = choreByName[choreName], state(of: coupon) == .available {
                coupon.price = pricing.price(for: chore)
            }
            grouped[roomKey, default: []].append(coupon)
        }
        couponsByRoom = grouped

        if selectedRoom == nil {
            selectedRoomKey = rooms.first.map(Self.key(for:))
        }
    }

    // MARK: - Buying

    /// Buys `coupon` for the signed-in user, then reloads.
    func buy(_ coupon: CouponModel) async {
        guard buyingCouponName == nil else { return }
        guard let couponID = coupon.recordID,
              let buyerID = houseUser?.recordID,
              let houseID
        else {
            alertMessage = L10n.tr("Não foi possível concluir a compra. Tente de novo.")
            return
        }

        buyingCouponName = coupon.recordID?.recordName ?? coupon.name
        defer { buyingCouponName = nil }

        do {
            let receipt = try await CouponPurchaseService().purchase(
                couponID: couponID,
                buyerID: buyerID,
                houseID: houseID,
                cycleKey: latestCycleKey,
                legacyCoins: houseUser?.coins ?? 0
            )
            coins = receipt.newBalance
        } catch let error as CouponPurchaseService.PurchaseError {
            alertMessage = error.userMessage
        } catch {
            alertMessage = UserFacingError.message(for: error, doing: .save)
        }

        HouseDataStore.shared.invalidate()
        await load()
    }
}
