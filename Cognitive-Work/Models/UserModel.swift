import Foundation
import CloudKit

struct UserModel: CloudKitSyncable {
    static var recordType: String = "UserModel"
    
    var recordID: CKRecord.ID?
    
    var name: String
    var profilePicture: Data?
    var tier: Tier
    var coins: Int
    var points: Int
    var badges: [CKRecord.Reference]
    var tasks: [CKRecord.Reference]
    var availableTime: [CKRecord.Reference]
    var house: CKRecord.Reference?
    var coupons: [CKRecord.Reference]
    var couponLimit: Int
    
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let profilePicture = record["profilePicture"] as? Data,
            let tier = Tier(rawValue: record["tier"] as? String ?? "tier1"),
            let coins = record["coins"] as? Int,
            let points = record["points"] as? Int,
            let badges = record["badges"] as? [CKRecord.Reference],
            let tasks = record["tasks"] as? [CKRecord.Reference],
            let availableTime = record["availableTime"] as? [CKRecord.Reference],
            let house = record["house"] as? CKRecord.Reference,
            let coupons = record["coupons"] as? [CKRecord.Reference],
            let couponLimit = record["couponLimit"] as? Int
        else {
            return nil
        }
        
        self.recordID = record.recordID
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
    
    init(
        name: String,
        profilePicture: Data? = nil,
        tier: Tier,
        coins: Int = 0,
        points: Int = 0,
        badges: [CKRecord.Reference] = [],
        tasks: [CKRecord.Reference] = [],
        availableTime: [CKRecord.Reference] = [],
        house: CKRecord.Reference? = nil,
        coupons: [CKRecord.Reference] = [],
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
    
    func populate(record: CKRecord) {
        record["name"] = name
        record["profilePicture"] = profilePicture
        record["tier"] = tier.rawValue
        record["coins"] = coins
        record["points"] = points
        record["badges"] = badges
        record["tasks"] = tasks
        record["house"] = house
        record["availableTime"] = availableTime
        record["coupons"] = coupons
        record["couponLimit"] = couponLimit
    }
}
