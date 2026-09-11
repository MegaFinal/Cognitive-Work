//
//  UserModel.swift
//  Cognitive-Work
//

import Foundation
import CloudKit

/// A member of a house, including their gamification progress.
class UserModel: CloudKitSyncable, Identifiable, Hashable {
    private let localID = UUID().uuidString

    var id: String {
        recordID?.recordName ?? localID
    }
    
    /// CloudKit record type backing this model.
    static var recordType: String = "UserModel"
    
    /// Identifier of the stored record, or `nil` before the user is saved.
    var recordID: CKRecord.ID?
    
    /// Display name shown to other members.
    var name: String
    
    /// Optional avatar image.
    var profilePicture: CKAsset?
    
    /// Progression level reached by the user.
    var tier: Tier
    
    /// Currency available to redeem coupons.
    var coins: Int
    
    /// Score accumulated from completed chores.
    var points: Int
    
    /// References to the badges the user has earned.
    var badgesReference: [CKRecord.Reference]?
    
    /// References to the chores assigned to the user.
    var choresReference: [CKRecord.Reference]?
    
    /// References to the user's declared availability slots.
    var availableTimeReference: [CKRecord.Reference]?
    
    /// The house the user belongs to.
    var houseReference: CKRecord.Reference?
    
    /// References to the coupons the user currently holds.
    var couponsReference: [CKRecord.Reference]?
    
    /// Maximum number of coupons the user may hold at once.
    var couponLimit: Int
    
    var chores: [ChoreModel] {
        get async {
            if let choresReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: ChoreModel.self, recordReferences: choresReference) ?? []
            }
            return []
        }
    }
    
    var availableTime: [AvailableTimeModel] {
        get async {
            if let availableTimeReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: AvailableTimeModel.self, recordReferences: availableTimeReference) ?? []
            }
            return []
        }
    }
    
    var house: HouseModel? {
        get async {
            if let houseReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: HouseModel.self, recordReferences: [houseReference])?.first
            }
            return nil
        }
    }
    // TODO: badges and coupon
    
    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when `name`, `coins`, `points`, or `couponLimit` is missing.
    ///
    /// Unknown or missing ``Tier`` values fall back to `.tier1`; missing collections decode as
    /// empty or `nil` rather than failing.
    required init?(record: CKRecord) {
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
        self.profilePicture = record["profilePicture"] as? CKAsset
        self.badgesReference = record["badges"] as? [CKRecord.Reference] ?? []
        self.choresReference = record["chores"] as? [CKRecord.Reference] ?? []
        self.availableTimeReference = record["availableTime"] as? [CKRecord.Reference]
        self.couponsReference = record["coupons"] as? [CKRecord.Reference]
        self.houseReference = record["house"] as? CKRecord.Reference
    }
    
    /// Creates a new, unsaved user.
    ///
    /// Relationship parameters are usually filled in after the related records exist.
    init(
        name: String,
        profilePicture: CKAsset? = nil,
        tier: Tier,
        coins: Int = 0,
        points: Int = 0,
        badges: [CKRecord.Reference]? = nil,
        tasks: [CKRecord.Reference]? = nil,
        availableTime: [CKRecord.Reference]? = nil,
        house: CKRecord.Reference? = nil,
        coupons: [CKRecord.Reference]? = nil,
        couponLimit: Int = 0,
        recordID: CKRecord.ID? = nil
    ) {
        self.recordID = recordID
        self.name = name
        self.profilePicture = profilePicture
        self.tier = tier
        self.coins = coins
        self.points = points
        self.badgesReference = badges
        self.choresReference = tasks
        self.availableTimeReference = availableTime
        self.houseReference = house
        self.couponsReference = coupons
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
        if let badgesReference {
            record["badges"] = badgesReference
        }
        if let choresReference {
            record["chores"] = choresReference
        }
        if let houseReference {
            record["house"] = houseReference
        }
        if let availableTimeReference {
            record["availableTime"] = availableTimeReference
        }
        if let couponsReference {
            record["coupons"] = couponsReference
        }
        record["couponLimit"] = couponLimit
    }
    
    @discardableResult
    func setAvailableTimes(_ times: [AvailableTimeModel], forWeeks weeks: Int = 4) async -> Bool {
        guard let recordID else {
            CloudKitManager.shared.errorMessage = "Failed to add availableTime: user missing recordID"
            return false
        }
        
        let calendar: Calendar = .current
        let userRef = CKRecord.Reference(recordID: recordID, action: .deleteSelf)
        var newRefs: [CKRecord.Reference] = []
        
        var recordsToSave: [CKRecord] = []
        
        for (offset, time) in times.enumerated() {
            
            guard time.capacityMinutes > 0 else { continue }
            
            let baseDay = Date().weekdayInCurrentWeek(offset: offset, calendar: calendar)
            
            for weekOffset in 0..<weeks {
                guard let futureDay = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: baseDay) else {
                    continue
                }
                
                let newID = CKRecord.ID(recordName: UUID().uuidString, zoneID: recordID.zoneID)
                let record = CKRecord(recordType: AvailableTimeModel.recordType, recordID: newID)
                record.parent = houseReference
                
                let linked = AvailableTimeModel(
                    capacityMinutes: time.capacityMinutes,
                    day: futureDay,
                    user: userRef
                )
                linked.populate(record: record)
            
                recordsToSave.append(record)
                newRefs.append(CKRecord.Reference(recordID: newID, action: .none))
            }
        }
        
        if !recordsToSave.isEmpty {
                let saveSuccess = await CloudKitManager.shared.batchSave(records: recordsToSave, zoneID: recordID.zoneID)
                guard saveSuccess else { return false }
            }
        
        self.availableTimeReference = newRefs
        
        return await CloudKitManager.shared.update(self)
    }
    
    @discardableResult
    func setAvailableTime(capacityMinutes: Int, day: Date) async -> Bool {
        await setAvailableTimes([
            AvailableTimeModel(capacityMinutes: capacityMinutes, day: day)
        ])
    }
    
    // To conform to Hashable
    static func == (lhs: UserModel, rhs: UserModel) -> Bool {
        // compare both records
        if let l = lhs.recordID, let r = rhs.recordID { return l == r }
        // if they don't have records, compare memory space
        return lhs === rhs
    }

    // To conform to Hashable -> creates hash
    func hash(into hasher: inout Hasher) {
        if let recordID {
            hasher.combine(recordID)
        } else {
            hasher.combine(ObjectIdentifier(self))
        }
    }
}
