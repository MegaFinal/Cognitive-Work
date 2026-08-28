//
//  ShopListItem.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 27/08/26.
//

import Foundation
import CloudKit

struct ShopListItem: CloudKitSyncable {
    static var recordType: String = "ShopListItem"
    
    var recordID: CKRecord.ID?
    
    var name: String
    var description: String
    var value: Double?
    var quantity: Int
    var unitMeasuremente: UnitMeasurement
    var priorityTag: PriorityTag
    var isBought: Bool
    
    private var perceptiveUserReference: CKRecord.Reference?
    private var percharserUserReference: CKRecord.Reference?
    private var relatedUsersReference: [CKRecord.Reference]?
    private var tagsReference: [CKRecord.Reference]?
    
    var perceptiveUser: UserModel? {
        get async {
            if let perceptiveUserReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [perceptiveUserReference])?.first
            }
            return nil
        }
    }
    
    var percharserUser: UserModel? {
        get async {
            if let percharserUserReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [percharserUserReference])?.first
            }
            return nil
        }
    }
    
    var relatedUsers: [UserModel] {
        get async {
            if let relatedUsersReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: relatedUsersReference) ?? []
            }
            return []
        }
    }
    
    var tags: [TagModel] {
        get async {
            if let tagsReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: TagModel.self, recordReferences: tagsReference) ?? []
            }
            return []
        }
    }
    
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let description = record["description"] as? String,
            let value = record["value"] as? Double,
            let quantity = record["quantity"] as? Int,
            let unitMeasuremente = record["unitMeasuremente"] as? String,
            let priorityTag = record["priorityTag"] as? String,
            let isBought = record["isBought"] as? Bool
        else {
            return nil
        }
        
        self.recordID = record.recordID
        
        self.name = name
        self.description = description
        self.value = value
        self.quantity = quantity
        self.unitMeasuremente = UnitMeasurement(rawValue: unitMeasuremente) ?? .gram
        self.priorityTag = PriorityTag(rawValue: priorityTag) ?? .low
        self.isBought = isBought
        self.perceptiveUserReference = record["perceptiveUser"] as? CKRecord.Reference
        self.percharserUserReference = record["percharserUser"] as? CKRecord.Reference
        self.relatedUsersReference = record["relatedUsers"] as? [CKRecord.Reference]
        self.tagsReference = record["tags"] as? [CKRecord.Reference]
    }
    
    init(
        name: String,
        description: String,
        value: Double?,
        quantity: Int,
        unitMeasuremente: UnitMeasurement,
        priorityTag: PriorityTag,
        isBought: Bool = false,
        recordID: CKRecord.ID? = nil
    ) {
        self.name = name
        self.description = description
        self.value = value
        self.quantity = quantity
        self.unitMeasuremente = unitMeasuremente
        self.priorityTag = priorityTag
        self.isBought = isBought
        self.recordID = recordID
    }
    
    func populate(record: CKRecord) {
        record["name"] = self.name
        record["description"] = self.description
        record["value"] = self.value
        record["quantity"] = self.quantity
        record["unitMeasuremente"] = self.unitMeasuremente.rawValue
        record["priorityTag"] = self.priorityTag.rawValue
        record["isBought"] = self.isBought
        if perceptiveUserReference != nil {
            record["perceptiveUser"] = self.perceptiveUserReference
        }
        if percharserUserReference != nil {
            record["percharserUser"] = self.percharserUserReference
        }
        if relatedUsersReference != nil {
            record["relatedUsers"] = self.relatedUsersReference
        }
        if tagsReference != nil {
            record["tags"] = self.tagsReference
        }
    }
}
