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
    var profilePicture: Data?
    var coins: Int
    var points: Int
    //    var tier: Tier
    //    var badges: [Badge]
    var house: CKRecord.Reference?
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
        self.profilePicture = record["profilePicture"] as? Data
        self.coins = record["coins"] as? Int ?? -1
        self.points = record["points"] as? Int ?? -1
        //        self.tier = record["tier"] as? CKRecord.Reference
        //        self.badges = record["badges"] as? CKRecord.Reference
        //        self.tasks = record["tasks"] as? CKRecord.Reference
        self.house = record["house"] as? CKRecord.Reference
        //        self.avalibleTime = record["avalibleTime"] as? CKRecord.Reference
        //        self.coupons = record["coupons"] as? CKRecord.Reference
        self.couponLimit = record["couponLimit"] as? Int ?? -1
        
        self.record = record
    }
    
    static func newRecord(name: String, profilePicture: Data, coins: Int, points: Int, house: CKRecord.Reference?, couponLimit: Int) async -> CKRecord? {
        guard let cloudKitUserID = try? await CKContainer.default().userRecordID()
        else {return nil}
        let zoneID = CloudKitManager.shared.houseZoneID
        let id = CKRecord.ID(recordName: cloudKitUserID.recordName, zoneID: zoneID)
        let record = CKRecord(recordType: "User", recordID: id)
        record["name"] = name
        record["profilePicture"] = profilePicture
        record["coins"] = coins
        record["points"] = points
        record["house"] = house
        record["couponLimit"] = couponLimit
        
        return record
    }
    
    static func fetchAllUsers(house: CKRecord) async -> [User] {
        return await CloudKitManager.shared.fetchAllUsers(house: house).compactMap(User.init(record: ))
    }
    
    static func deleteUser(_ user: CKRecord) async {
        _ = await CloudKitManager.shared.deleteUser(user)
    }
    
    func updateUserAttributes(name: String? = nil,profilePicture: Data? = nil,
                              coins: Int? = nil, points: Int? = nil,
                              couponLimit: Int? = nil) async {
        if let name = name { self.name = name }
        if let profilePicture = profilePicture { self.profilePicture = profilePicture }
        if let coins = coins { self.coins = coins }
        if let points = points { self.points = points }
        if let couponLimit = couponLimit { self.couponLimit = couponLimit }
        
        _ = await CloudKitManager.shared.updateUserAttributes(user: record, name: name, profilePicture: profilePicture, coins: coins, points: points, couponLimit: couponLimit)
    }
    
    func addHouseToUser(house: CKRecord) async {
        _ = await CloudKitManager.shared.addHouseToUser(user: record, house: house)
    }
    
    func removeUserHouse() async {
        _ = await CloudKitManager.shared.removeUserHouse(user: record)
    }
}
