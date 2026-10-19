//
//  RankHistoryModel.swift
//  Cognitive-Work
//
//  Created by Jonas Melo on 16/10/26.
//

import Foundation
import CloudKit

/// A user's rank and points at the end of one cycle, so they can follow their progress. Points
/// start over at every cycle, so `points` is what the user made in that cycle.
///
/// Created together with the cycle's ``CoinPayoutModel`` (same atomic save) and named
/// `rank-<cycle key>-<user recordName>`, so there is exactly one per user per cycle.
struct RankHistoryModel: CloudKitSyncable, Equatable {

    static var recordType: String = "RankHistoryModel"

    var recordID: CKRecord.ID?

    var user: CKRecord.Reference
    var cycleKey: String
    var cycleStart: Date
    var cycleEnd: Date
    var tier: Tier
    var points: Int

    init(user: CKRecord.Reference, cycleKey: String, cycleStart: Date, cycleEnd: Date, tier: Tier, points: Int) {
        self.user = user
        self.cycleKey = cycleKey
        self.cycleStart = cycleStart
        self.cycleEnd = cycleEnd
        self.tier = tier
        self.points = points
    }

    init?(record: CKRecord) {
        guard
            let user = record["user"] as? CKRecord.Reference,
            let cycleKey = record["cycleKey"] as? String,
            let cycleStart = record["cycleStart"] as? Date,
            let cycleEnd = record["cycleEnd"] as? Date,
            let tier = record["tier"] as? String,
            let points = record["points"] as? Int
        else { return nil }

        self.recordID = record.recordID
        self.user = user
        self.cycleKey = cycleKey
        self.cycleStart = cycleStart
        self.cycleEnd = cycleEnd
        self.tier = Tier(stored: tier)
        self.points = points
    }

    func populate(record: CKRecord) {
        record["user"] = user
        record["cycleKey"] = cycleKey
        record["cycleStart"] = cycleStart
        record["cycleEnd"] = cycleEnd
        record["tier"] = tier.rawValue
        record["points"] = points
    }

    static func recordID(cycleKey: String, userID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "rank-\(cycleKey)-\(userID.recordName)", zoneID: userID.zoneID)
    }

    /// `userID`'s history, most recent cycle first.
    static func fetchHistory(for userID: CKRecord.ID) async -> [RankHistoryModel] {
        await CloudKitManager.shared.fetchAll(RankHistoryModel.self)
            .filter { $0.user.recordID == userID }
            .sorted { $0.cycleKey > $1.cycleKey }
    }
}
