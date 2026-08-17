//
//  CheckItemModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

struct CheckItemModel: CloudKitSyncable {
    static var recordType: String = "CheckItemModel"
    
    var recordID: CKRecord.ID?
    
    var name: String
    var isDone: Bool
    
    init?(record: CKRecord) {
        guard
            let name = record["checkItemName"] as? String,
            let isDone = record["isDone"] as? Bool
        else {
            return nil
        }
        
        self.recordID = record.recordID
        self.name = name
        self.isDone = isDone
    }
    
    init(name: String, isDone: Bool) {
        self.name = name
        self.isDone = isDone
    }
    
    func populate(record: CKRecord) {
        record["checkItemName"] = name
        record["isDone"] = isDone
    }
}
