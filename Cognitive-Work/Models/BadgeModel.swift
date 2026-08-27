//
//  Badge.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 27/08/26.
//

import SwiftUI
import CloudKit

struct BadgeModel: CloudKitSyncable {
    static var recordType: String = "BadgeModel"
    
    var recordID: CKRecord.ID?
    
    var name: String
    var image: Data
    var description: String
    var isLocked: Bool
    var tier: Tier
    var quantity: Int
    var room: CKRecord.Reference?
    var users: [CKRecord.Reference]?
    
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let image = record["image"] as? Data,
            let description = record["description"] as? String,
            let isLocked = record["isLocked"] as? Bool,
            let tier = record["tier"] as? String,
            let quantity = record["quantity"] as? Int
        else {
            return nil
        }
        
        self.recordID = record.recordID
        
        self.name = name
        self.image = image
        self.description = description
        self.isLocked = isLocked
        self.tier = Tier(rawValue: tier) ?? .tier1
        self.quantity = quantity
        self.room = record["room"] as? CKRecord.Reference
        self.users = record["users"] as? [CKRecord.Reference]
    }
    
    init(name: String,
         image: Data,
         description: String,
         isLocked: Bool = true,
         tier: Tier,
         quantity: Int = 0,
         room: CKRecord.Reference? = nil,
         users: [CKRecord.Reference]? = nil)
    {
        self.name = name
        self.image = image
        self.description = description
        self.isLocked = isLocked
        self.tier = tier
        self.quantity = quantity
        self.room = room
        self.users = users
    }
    
    func populate(record: CKRecord) {
        record["name"] = name
        record["image"] = image
        record["description"] = description
        record["isLocked"] = isLocked
        record["tier"] = tier.rawValue
        record["quantity"] = quantity
        if let room {
            record["room"] = room
        }
    }
}
