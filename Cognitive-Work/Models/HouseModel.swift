import Foundation
import CloudKit

/// Represents a house stored in CloudKit.
struct HouseModel: CloudKitSyncable {
    static var recordType: String = "HouseModel"
    
    var recordID: CKRecord.ID?
    
    var name: String
    var description: String
    var chores: [CKRecord.Reference]?
    var users: [CKRecord.Reference]?
    var shopListItem: [CKRecord.Reference]?
    var rooms: [CKRecord.Reference]?


    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let description = record["description"] as? String
        else {
            return nil
        }
        
        self.recordID = record.recordID
        self.name = name
        self.description = description
        self.chores = record["chores"] as? [CKRecord.Reference]
        self.users = record["users"] as? [CKRecord.Reference]
        self.shopListItem = record["shopListItem"] as? [CKRecord.Reference]
        self.rooms = record["rooms"] as? [CKRecord.Reference]
    }
    
    init(
        name: String,
        description: String,
        chores: [CKRecord.Reference]? = nil,
        users: [CKRecord.Reference]? = nil,
        shopListItem: [CKRecord.Reference]? = nil
    ) {
        self.recordID = nil
        self.name = name
        self.description = description
        self.chores = chores
        self.users = users
        self.shopListItem = shopListItem
    }
    
    func populate(record: CKRecord) {
        record["name"] = name
        record["description"] = description
        record["chores"] = chores
        if let chores = chores {
            record["chores"] = chores
        }
        record["users"] = users
        if let users = users {
            record["users"] = users
        }
        record["shopListItem"] = shopListItem
        if let shopListItem = shopListItem {
            record["shopListItem"] = shopListItem
        }
        record["rooms"] = rooms
        if let rooms = rooms {
            record["rooms"] = rooms
        }
    }
}
