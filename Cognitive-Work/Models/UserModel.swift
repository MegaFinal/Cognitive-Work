//
//  UserModel.swift
//  Cognitive-Work
//

import Foundation
import CloudKit

/// A member of a house, including their gamification progress.
struct UserModel: CloudKitSyncable {

    /// CloudKit record type backing this model.
    static var recordType: String = "UserModel"

    /// Identifier of the stored record, or `nil` before the user is saved.
    var recordID: CKRecord.ID?

    /// Display name shown to other members.
    var name: String

    /// Optional avatar image.
    var profilePicture: Data?

    /// Progression level reached by the user.
    var tier: Tier

    /// Currency available to redeem coupons.
    var coins: Int

    /// Score accumulated from completed chores.
    var points: Int

    /// References to the badges the user has earned.
    var badges: [CKRecord.Reference]?

    /// References to the chores assigned to the user.
    var tasks: [CKRecord.Reference]?

    /// References to the user's declared availability slots.
    var availableTime: [CKRecord.Reference]?

    /// The house the user belongs to.
    var house: CKRecord.Reference?

    /// References to the coupons the user currently holds.
    var coupons: [CKRecord.Reference]?

    /// Maximum number of coupons the user may hold at once.
    var couponLimit: Int

    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when `name`, `coins`, `points`, or `couponLimit` is missing.
    ///
    /// Unknown or missing ``Tier`` values fall back to `.tier1`; missing collections decode as
    /// empty or `nil` rather than failing.
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let coins = record["coins"] as? Int,
            let points = record["points"] as? Int,
            let couponLimit = record["couponLimit"] as? Int
        else {
            return nil
        }

        self.recordID = record.recordID
        self.name = name
        self.coins = coins
        self.points = points
        self.couponLimit = couponLimit
        self.tier = Tier(rawValue: record["tier"] as? String ?? "") ?? .tier1
        self.profilePicture = record["profilePicture"] as? Data
        self.badges = record["badges"] as? [CKRecord.Reference] ?? []
        self.tasks = record["tasks"] as? [CKRecord.Reference] ?? []
        self.availableTime = record["availableTime"] as? [CKRecord.Reference]
        self.coupons = record["coupons"] as? [CKRecord.Reference]
        self.house = record["house"] as? CKRecord.Reference
    }

    /// Creates a new, unsaved user.
    ///
    /// Relationship parameters are usually filled in after the related records exist.
    init(
        name: String,
        profilePicture: Data? = nil,
        tier: Tier,
        coins: Int = 0,
        points: Int = 0,
        badges: [CKRecord.Reference]? = nil,
        tasks: [CKRecord.Reference]? = nil,
        availableTime: [CKRecord.Reference]? = nil,
        house: CKRecord.Reference? = nil,
        coupons: [CKRecord.Reference]? = nil,
        couponLimit: Int = 0
    ) {
        self.recordID = nil
        self.name = name
        self.profilePicture = profilePicture
        self.tier = tier
        self.coins = coins
        self.points = points
        self.badges = badges
        self.tasks = tasks
        self.availableTime = availableTime
        self.house = house
        self.coupons = coupons
        self.couponLimit = couponLimit
    }

    /// Writes this model's values into a CloudKit record.
    ///
    /// - Parameter record: The record to populate.
    ///
    /// > Note: `nil` relationships are skipped rather than written, preserving whatever is
    /// > already on the server.
    func populate(record: CKRecord) {
        record["name"] = name
        record["profilePicture"] = profilePicture
        record["tier"] = tier.rawValue
        record["coins"] = coins
        record["points"] = points
        if let badges {
            record["badges"] = badges
        }
        if let tasks {
            record["tasks"] = tasks
        }
        if let house {
            record["house"] = house
        }
        if let availableTime {
            record["availableTime"] = availableTime
        }
        if let coupons {
            record["coupons"] = coupons
        }
        record["couponLimit"] = couponLimit
    }
}
