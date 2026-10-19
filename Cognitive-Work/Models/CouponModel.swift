//
//  Coupon.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 27/08/26.
//

import Foundation
import CloudKit

struct CouponModel: CloudKitSyncable {
    static var recordType: String = "CouponModel"
    
    var recordID: CKRecord.ID?
    
    var name: String
    var isOnSale: Bool
    var price: Int
    var tier: Tier
    var currentUser: CKRecord.Reference?
    var lastUser: CKRecord.Reference?
    var task: CKRecord.Reference?
    
    /// Key of the ``HouseCycleModel`` in which ``currentUser`` bought the coupon. The purchase
    /// spares its holder this chore in the next division generated after that cycle.
    var purchasedCycleKey: String?
    
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let isOnSale = record["isOnSale"] as? Bool,
            let price = record["price"] as? Int,
            let tier = record["tier"] as? String
        else {
            return nil
        }
        
        self.recordID = record.recordID
        
        self.name = name
        self.isOnSale = isOnSale
        self.price = price
        self.tier = Tier(stored: tier)
        self.currentUser = record["currentUser"] as? CKRecord.Reference
        self.lastUser = record["lastUser"] as? CKRecord.Reference
        self.task = record["task"] as? CKRecord.Reference
        self.purchasedCycleKey = record["purchasedCycleKey"] as? String
    }
    
    init(
        name: String,
        isOnSale: Bool,
        price: Int,
        tier: Tier,
        currentUser: CKRecord.Reference? = nil,
        lastUser: CKRecord.Reference? = nil,
        task: CKRecord.Reference? = nil
        )
    {
        self.name = name
        self.isOnSale = isOnSale
        self.price = price
        self.tier = tier
        self.currentUser = currentUser
        self.lastUser = lastUser
        self.task = task
    }
    
    func populate(record: CKRecord) {
        record["name"] = self.name
        record["isOnSale"] = self.isOnSale
        record["price"] = self.price
        record["tier"] = tier.rawValue
        if let currentUser {
            record["currentUser"] = currentUser
        }
        if let lastUser {
            record["lastUser"] = lastUser
        }
        if let task {
            record["task"] = task
        }
        if let purchasedCycleKey {
            record["purchasedCycleKey"] = purchasedCycleKey
        }
    }
}

/// Every chore has one coupon, created together with it and listed under the chore's room in the
/// rewards tab.
extension CouponModel {

    /// The rank a coupon gets from the chore's ``ChoreModel/score``: the harder the chore, the
    /// higher the rank, from ``Tier/bronze1`` to ``Tier/diamond3`` in steps of 4 points
    /// (scores start at about 8). ``Tier/master`` is not given to coupons.
    static func tier(forScore score: Int) -> Tier {
        let ranks = Tier.allCases.filter { $0 != .master }
        let index = min(max((score - 8) / 4, 0), ranks.count - 1)
        return ranks[index]
    }

    /// Whether the coupon can be bought in the cycle `latestCycleKey`.
    ///
    /// A coupon has one holder at a time. Once a newer cycle exists the purchase has been used
    /// (or is being used), so anyone can buy it again for the following division.
    func isAvailable(latestCycleKey: String) -> Bool {
        guard isOnSale else { return false }
        guard currentUser != nil, let purchasedCycleKey else { return true }
        return purchasedCycleKey < latestCycleKey
    }

    /// Whether `userID` bought this coupon during the cycle `cycleKey`.
    func isHeld(by userID: CKRecord.ID, inCycle cycleKey: String) -> Bool {
        currentUser?.recordID == userID && purchasedCycleKey == cycleKey
    }

    /// A coupon for `chore`, priced by ``CouponPricing`` and pointing at it through ``task``.
    ///
    /// The reference uses `.deleteSelf`, so CloudKit deletes the coupon whenever the chore is
    /// deleted, whichever screen deletes it (including the onboarding rollback).
    ///
    /// - Parameter choreRecordID: Record ID of the chore; it may not be saved yet.
    init(for chore: ChoreModel, choreRecordID: CKRecord.ID) {
        let score = max(chore.score, 1)
        self.init(
            name: chore.name,
            isOnSale: true,
            price: CouponPricing.current.price(for: chore),
            tier: CouponModel.tier(forScore: score),
            task: CKRecord.Reference(recordID: choreRecordID, action: .deleteSelf)
        )
    }
}
