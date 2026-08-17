import Foundation
import CloudKit

/// Represents a house stored in CloudKit.
struct HouseModel: CloudKitSyncable {
    static var recordType: String = "HouseModel"
    
    var recordID: CKRecord.ID?
    
    var name: String
    var description: String
    var chores: [CKRecord.Reference]
    var users: [CKRecord.Reference]
    var shopListItem: [CKRecord.Reference]
    
    
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let description = record["description"] as? String,
            let chores = record["chores"] as? [CKRecord.Reference],
            let users = record["users"] as? [CKRecord.Reference],
            let shopListItem = record["shopListItem"] as? [CKRecord.Reference]
        else {
            return nil
        }
        
        self.recordID = record.recordID
        self.name = name
        self.description = description
        self.chores = chores
        self.users = users
        self.shopListItem = shopListItem
    }
    
    init(
        name: String,
        description: String,
        chores: [CKRecord.Reference] = [],
        users: [CKRecord.Reference] = [],
        shopListItem: [CKRecord.Reference] = []
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
        record["users"] = users
        record["shopListItem"] = shopListItem
    }
}
