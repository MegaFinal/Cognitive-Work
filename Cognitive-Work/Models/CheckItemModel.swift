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
    
    private var checkItemName: String
    private var isDone: Bool
    
    init?(record: CKRecord) {
        guard
            let checkItemName = record["checkItemName"] as? String,
            let isDone = record["isDone"] as? Bool
        else {
            return nil
        }
        
        self.recordID = record.recordID
        self.checkItemName = checkItemName
        self.isDone = isDone
    }
    
    func populate(record: CKRecord) {
        record["checkItemName"] = checkItemName
        record["isDone"] = isDone
    }
}
