//
//  CouponExemption.swift
//  Cognitive-Work
//
//  Created by Claude on 16/10/26.
//

import Foundation
import CloudKit

/// Who is spared which chore because they hold its coupon.
///
/// A coupon bought during cycle X spares its holder in the next division generated after X:
/// - when that division is being generated, X is still the latest cycle
///   (``forNextDivision(coupons:cycles:)``);
/// - while it runs, X is the cycle before the latest (``active(coupons:cycles:)``).
enum CouponExemption {

    /// Chore record ID → users that may not get it.
    typealias Map = [CKRecord.ID: Set<CKRecord.ID>]

    /// Exemptions for the division about to be generated.
    static func forNextDivision(coupons: [CouponModel], cycles: [HouseCycleModel]) -> Map {
        guard let latest = HouseCycleModel.latest(cycles) else { return [:] }
        return map(coupons: coupons, purchasedIn: latest.key)
    }

    /// Exemptions in force in the cycle running now.
    static func active(coupons: [CouponModel], cycles: [HouseCycleModel]) -> Map {
        guard let previous = HouseCycleModel.previous(cycles) else { return [:] }
        return map(coupons: coupons, purchasedIn: previous.key)
    }

    private static func map(coupons: [CouponModel], purchasedIn cycleKey: String) -> Map {
        var result: Map = [:]
        for coupon in coupons where coupon.purchasedCycleKey == cycleKey {
            guard let choreID = coupon.task?.recordID,
                  let holderID = coupon.currentUser?.recordID
            else { continue }
            result[choreID, default: []].insert(holderID)
        }
        return result
    }

    // MARK: - Loading

    /// Coupons and cycles of the house in `zoneID`.
    static func load(houseZoneID zoneID: CKRecordZone.ID) async -> (coupons: [CouponModel], cycles: [HouseCycleModel]) {
        async let coupons = CloudKitManager.shared.fetchAll(CouponModel.self)
        async let cycles = HouseCycleModel.fetchAll(inHouseZone: zoneID)
        let (allCoupons, houseCycles) = await (coupons, cycles)
        return (allCoupons.filter { $0.recordID?.zoneID == zoneID }, houseCycles)
    }

    /// Whether `userID` may not pick `choreID` in the cycle running now.
    static func isExempt(userID: CKRecord.ID, choreID: CKRecord.ID?) async -> Bool {
        guard let choreID else { return false }
        let (coupons, cycles) = await load(houseZoneID: choreID.zoneID)
        return active(coupons: coupons, cycles: cycles)[choreID]?.contains(userID) ?? false
    }
}
