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
        self.tier = Tier(rawValue: tier) ?? Tier.tier1
        self.currentUser = record["currentUser"] as? CKRecord.Reference
        self.lastUser = record["lastUser"] as? CKRecord.Reference
        self.task = record["task"] as? CKRecord.Reference
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
    }
}
