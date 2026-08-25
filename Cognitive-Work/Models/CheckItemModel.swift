//
//  CheckItemModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

/// A single entry in a chore's checklist.
struct CheckItemModel: CloudKitSyncable, Identifiable {
    var id: String {
        recordID?.recordName ?? UUID().uuidString
    }
    
    /// CloudKit record type backing this model.
    static var recordType: String = "CheckItemModel"
    
    /// Identifier of the stored record, or `nil` before the item is saved.
    var recordID: CKRecord.ID?
    
    /// Label shown to the user.
    ///
    /// > Note: Persisted under the `checkItemName` key, unlike the other models, which use
    /// > `name`. Keep this in mind when writing queries.
    var name: String
    
    /// Whether the item has been checked off.
    var isDone: Bool
    
    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when a required field is missing or has the wrong type.
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
    
    /// Creates a new, unsaved checklist item.
    ///
    /// - Parameters:
    ///   - name: Label shown to the user.
    ///   - isDone: Whether the item starts checked off.
    init(name: String, isDone: Bool) {
        self.name = name
        self.isDone = isDone
    }
    
    /// Writes this model's values into a CloudKit record.
    ///
    /// - Parameter record: The record to populate.
    func populate(record: CKRecord) {
        record["checkItemName"] = name
        record["isDone"] = isDone
    }
}
