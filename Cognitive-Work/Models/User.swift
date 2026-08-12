//
//  User.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 12/08/26.
//
import Foundation
import CloudKit

class User: Identifiable {
    var id: CKRecord.ID
    var name: String
    var profilePicture: Data
    var coins: Int
    var points: Int
//    var tier: Tier
//    var badges: [Badge]
//    var house: CKRecord.Reference
//    var tasks: [CKRecord.Reference]
//    var avalibleTime: [AvalibleTime]
//    var coupons: [Coupon]
    var couponLimit: Int
    
    /// Referência ao CKRecord original  necessária para update/delete no CloudKitManager.
    var record: CKRecord
    
    init?(record: CKRecord) {
        guard record.recordType == "User",
        let name = record["name"] as? String else {
                    return nil
        }
        self.id = record.recordID
        self.name = name
        self.profilePicture = record["profilePicture"] as? Data ?? Data()
        self.coins = record["coins"] as? Int ?? -1
        self.points = record["points"] as? Int ?? -1
//        self.tier = record["tier"] as? CKRecord.Reference
//        self.badges = record["badges"] as? CKRecord.Reference
//        self.tasks = record["tasks"] as? CKRecord.Reference
//        self.houses = record["houses"] as? CKRecord.Reference
//        self.avalibleTime = record["avalibleTime"] as? CKRecord.Reference
//        self.coupons = record["coupons"] as? CKRecord.Reference
        self.couponLimit = record["couponLimit"] as? Int ?? -1
        
        self.record = record
    }
}
