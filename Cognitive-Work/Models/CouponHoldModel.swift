//
//  CouponHoldModel.swift
//  Cognitive-Work
//
//  Created by Claude on 16/10/26.
//

import Foundation
import CloudKit

/// Marks that a user bought a coupon in a room during a cycle, enforcing "at most one coupon per
/// room per user per cycle".
///
/// The coupon record alone can't enforce that rule: two purchases of *different* coupons in the
/// same room write different records, so CloudKit sees no conflict. Every purchase in a room also
/// writes this record, named `hold-<user recordName>-<room recordName>`, which turns two such
/// purchases into a conflict on the same record: only one succeeds.
///
/// A hold only counts while ``cycleKey`` is the latest cycle; in a later cycle it is simply
/// overwritten by the next purchase, never deleted.
struct CouponHoldModel: CloudKitSyncable, Equatable {

    static var recordType: String = "CouponHoldModel"

    var recordID: CKRecord.ID?

    var user: CKRecord.Reference
    var room: CKRecord.Reference
    var coupon: CKRecord.Reference
    var cycleKey: String

    init(user: CKRecord.Reference, room: CKRecord.Reference, coupon: CKRecord.Reference, cycleKey: String) {
        self.user = user
        self.room = room
        self.coupon = coupon
        self.cycleKey = cycleKey
    }

    init?(record: CKRecord) {
        guard
            let user = record["user"] as? CKRecord.Reference,
            let room = record["room"] as? CKRecord.Reference,
            let coupon = record["coupon"] as? CKRecord.Reference,
            let cycleKey = record["cycleKey"] as? String
        else { return nil }

        self.recordID = record.recordID
        self.user = user
        self.room = room
        self.coupon = coupon
        self.cycleKey = cycleKey
    }

    func populate(record: CKRecord) {
        record["user"] = user
        record["room"] = room
        record["coupon"] = coupon
        record["cycleKey"] = cycleKey
    }

    static func recordID(userID: CKRecord.ID, roomID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "hold-\(userID.recordName)-\(roomID.recordName)", zoneID: userID.zoneID)
    }
}
