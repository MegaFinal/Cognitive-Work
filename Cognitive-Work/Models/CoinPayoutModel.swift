//
//  CoinPayoutModel.swift
//  Cognitive-Work
//
//  Created by Claude on 16/10/26.
//

import Foundation
import CloudKit

/// The coins one user earns for one closed cycle.
///
/// Lifecycle (see ``CycleSettlementService``):
/// 1. When a device notices a cycle ended, it creates one payout per member, `pending`, with the
///    amount frozen from the member's rank at that moment.
/// 2. The member taps "Resgatar" in the retrospective: the payout becomes `confirmed` and the
///    amount is added to their ``CoinWalletModel`` in the same atomic save.
///
/// Named `payout-<cycle key>-<user recordName>`: a second creation fails instead of duplicating,
/// and a confirmed payout is never credited again.
struct CoinPayoutModel: CloudKitSyncable, Equatable {

    static var recordType: String = "CoinPayoutModel"

    enum Status: String {
        case pending
        case confirmed
    }

    var recordID: CKRecord.ID?

    var user: CKRecord.Reference
    var cycleKey: String
    /// Rank the amount was computed from.
    var tier: Tier
    var points: Int
    var amount: Int
    var status: Status
    var confirmedAt: Date?

    init(user: CKRecord.Reference, cycleKey: String, tier: Tier, points: Int, amount: Int,
         status: Status = .pending, confirmedAt: Date? = nil) {
        self.user = user
        self.cycleKey = cycleKey
        self.tier = tier
        self.points = points
        self.amount = amount
        self.status = status
        self.confirmedAt = confirmedAt
    }

    init?(record: CKRecord) {
        guard
            let user = record["user"] as? CKRecord.Reference,
            let cycleKey = record["cycleKey"] as? String,
            let tier = record["tier"] as? String,
            let points = record["points"] as? Int,
            let amount = record["amount"] as? Int,
            let statusRaw = record["status"] as? String,
            let status = Status(rawValue: statusRaw)
        else { return nil }

        self.recordID = record.recordID
        self.user = user
        self.cycleKey = cycleKey
        self.tier = Tier(stored: tier)
        self.points = points
        self.amount = amount
        self.status = status
        self.confirmedAt = record["confirmedAt"] as? Date
    }

    func populate(record: CKRecord) {
        record["user"] = user
        record["cycleKey"] = cycleKey
        record["tier"] = tier.rawValue
        record["points"] = points
        record["amount"] = amount
        record["status"] = status.rawValue
        record["confirmedAt"] = confirmedAt
    }

    static func recordID(cycleKey: String, userID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "payout-\(cycleKey)-\(userID.recordName)", zoneID: userID.zoneID)
    }
}
