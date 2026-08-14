//
//  RoomModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

struct RoomModel: CloudKitSyncable {
    static var recordType: String = "RoomModel"
    
    var record: CKRecord?
    var recordID: CKRecord.ID?
    
    var name: String?
    var relatedChores: [CKRecord.Reference]?
    var house: CKRecord.Reference?
    var color: RoomColor
    
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let color = RoomColor(rawValue: record["roomColor"] as? String ?? "notUrgent")
        else {
            return nil
        }
        
        self.record = record
        self.recordID = record.recordID
        self.name = name
        self.relatedChores = record["relatedChores"] as? [CKRecord.Reference]
        self.house = record["house"] as? CKRecord.Reference
        self.color = color
    }
    
    init(
        name: String,
        relatedChores: [CKRecord.Reference]? = nil,
        house: CKRecord.Reference? = nil,
        color: RoomColor
    ) {
        self.record = nil
        self.recordID = nil
        self.name = name
        self.relatedChores = relatedChores
        self.house = house
        self.color = color
    }
    
    func populate(record: CKRecord) {
        record["name"] = name
        if let relatedChores = relatedChores {
            record["relatedChores"] = relatedChores
        }
        if let house = house {
            record["house"] = house
        }
        record["roomColor"] = color.rawValue
    }
    
    func toRecord() -> CKRecord {
        let record = self.record ?? CKRecord(recordType: RoomModel.recordType)
        
        record["name"] = name
        if let relatedChores = relatedChores {
            record["relatedChores"] = relatedChores
        }
        if let house = house {
            record["house"] = house
        }
        record["roomColor"] = color.rawValue
        
        return record
    }
}
