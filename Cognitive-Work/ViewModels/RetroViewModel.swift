//
//  RetroViewModel.swift
//  Cognitive-Work
//
//  Created by Claude on 19/10/26.
//

import Foundation
import CloudKit
import Observation

/// What the retrospective reads from CloudKit: the coins the user can redeem for the cycles that
/// ended.
///
/// Owned by the screen that presents the retrospective (``NotificationsView``), which calls
/// ``load()`` as soon as it appears, so the retrospective opens with everything ready. Loading also
/// settles the closed cycles (``CycleSettlementService/prepareClosedCycles(_:members:houseID:today:)``):
/// payouts, rank history and the reset of every member's rank exist even if nobody opened the
/// rewards tab.
@MainActor
@Observable
final class RetroViewModel {

    /// Coins from closed cycles not redeemed yet.
    private(set) var pendingAmount = 0
    private(set) var didRedeem = false
    private(set) var isWorking = false
    private(set) var errorText: String?

    private struct Context {
        let houseID: CKRecord.ID
        let user: UserModel
        let cycles: [HouseCycleModel]
    }

    @ObservationIgnored private var context: Context?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    // MARK: - Loading

    /// Loads once. Calls made while (or after) it runs wait for that same load instead of
    /// starting another one.
    func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
    }

    /// Loads again from scratch (pull to refresh).
    func reload() async {
        loadTask = nil
        await load()
    }

    private func performLoad() async {
        guard let houseID = try? await CloudKitManager.shared.currentHouse()?.recordID,
              let user = await CloudKitManager.shared.currentHouseUser(),
              let userID = user.recordID
        else { return }

        async let fetchedCycles = HouseCycleModel.fetchAll(inHouseZone: houseID.zoneID)
        async let fetchedMembers = CloudKitManager.shared.fetchHouseUsers()
        let (cycles, members) = await (fetchedCycles, fetchedMembers)

        let service = CycleSettlementService()
        await service.prepareClosedCycles(cycles, members: members, houseID: houseID)

        let payouts = await service.payouts(for: userID, cycles: cycles)
        context = Context(houseID: houseID, user: user, cycles: cycles)
        pendingAmount = payouts.filter { $0.status == .pending }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Redeeming

    /// Confirms the user's pending payouts and credits them to their wallet.
    func redeem() async {
        guard let context, let userID = context.user.recordID, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await CycleSettlementService().confirmPendingPayouts(
                for: userID,
                cycles: context.cycles,
                houseID: context.houseID,
                legacyCoins: context.user.coins
            )
            didRedeem = true
            pendingAmount = 0
            errorText = nil
        } catch {
            errorText = L10n.tr("Não foi possível resgatar agora. Tente de novo.")
        }
    }
}
