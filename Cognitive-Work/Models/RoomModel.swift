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
    
    var recordID: CKRecord.ID?
    
    private var name: String?
    private var relatedChores: [CKRecord.Reference]
    private var house: CKRecord.Reference
    private var color: RoomColor
    
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let relatedChores = record["relatedChores"] as? [CKRecord.Reference],
            let house = record["house"] as? CKRecord.Reference,
            let color = RoomColor(rawValue: record["roomColor"] as? String ?? "notUrgent")
        else {
            return nil
        }
        
        self.recordID = record.recordID
        self.name = name
        self.relatedChores = relatedChores
        self.house = house
        self.color = color
    }
    
    func populate(record: CKRecord) {
        record["name"] = name
        record["relatedChores"] = relatedChores
        record["house"] = house
        record["roomColor"] = color.rawValue
    }
}
