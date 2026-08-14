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
    var badges: [CKRecord.Reference]?
    var tasks: [CKRecord.Reference]?
    var availableTime: [CKRecord.Reference]?
    var house: CKRecord.Reference?
    var coupons: [CKRecord.Reference]?
    var couponLimit: Int
    
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
        self.availableTime = record["availableTime"] as? [CKRecord.Reference]? ?? nil
        self.coupons = record["coupons"] as? [CKRecord.Reference]? ?? nil
        self.house = record["house"] as? CKRecord.Reference? ?? nil
    }
    
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
    
    func populate(record: CKRecord) {
        record["name"] = name
        record["profilePicture"] = profilePicture
        record["tier"] = tier.rawValue
        record["coins"] = coins
        record["points"] = points
        if let badges = badges {
            record["badges"] = badges
        }
        if let tasks = tasks {
            record["tasks"] = tasks
        }
        if let house = house {
            record["house"] = house
        }
        if let availableTime = availableTime {
            record["availableTime"] = availableTime
        }
        if let coupons = coupons {
            record["coupons"] = coupons
        }
        record["couponLimit"] = couponLimit
    }
}
