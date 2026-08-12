//
//  House.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 07/08/26.
//

import Foundation
import CloudKit

class House: Identifiable {
    var id: CKRecord.ID
    var name: String
    var description: String
//    var tasks: [CKRecord.Reference?]
//    var users: [CKRecord.Reference?]
//    var shopList: [CKRecord.Reference?]
    
    /// Referência ao CKRecord original  necessária para update/delete no CloudKitManager.
    let record: CKRecord
    
    init?(record: CKRecord) {
        guard record.recordType == "House",
        let name = record["name"] as? String else {
                    return nil
        }
        self.id = record.recordID
        self.name = name
        self.description = record["description"] as? String ?? ""
//        self.tasks = record["tasks"] as? CKRecord.Reference
//        self.users = record["users"] as? CKRecord.Reference
//        self.shopList = record["shopList"] as? CKRecord.Reference
        
        self.record = record
    }
    
    static func newRecord(name: String, description: String, zoneID: CKRecordZone.ID) -> CKRecord {
        let id = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "House", recordID: id)
        record["name"] = name
        record["description"] = description
//        record["tasks"] = CKRecord.Reference(record: household, action: .none)
//        record["users"] = CKRecord.Reference(record: household, action: .none)
//        record["shopList"] = CKRecord.Reference(record: household, action: .none)
        return record
    }
    
    static func creatHouse(name: String, description: String) async {
        _ = await CloudKitManager.shared.createHouse(name: name, description: description)
    }
    
    static func fetchHouse() async -> House? {
        do {
            let houseRecord = try await CloudKitManager.shared.fetchHouse()
            return House(record: houseRecord)
        }
        catch {
            print("Error convert House record to House Type")
            return nil
        }
    }
    
    static func deleteHouse(_ house: CKRecord) async {
        _ = await CloudKitManager.shared.deleteHouse(house)
    }
    
    
    func updateUserAttributes(name: String? = nil, description: String? = nil) async {
        if let name = name { self.name = name }
        if let description = description { self.description = description }
        
        _ = await CloudKitManager.shared.updateHouseAttributes(house: record, name: name, description: description)
    }
}


