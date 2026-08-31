//
//  CheckItemDTO.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import Foundation
import CloudKit

/// A generic data transfer object for buffering an unsaved checklist item edit operation.
struct CheckItemDTO: Identifiable {
    let id = UUID()
    var name: String
    var isDone: Bool

    /// Identifier of the original stored record, if this DTO is editing an existing checklist
    /// item. `nil` means the item hasn't been persisted yet.
    var originalRecordID: CKRecord.ID?

    init(name: String, isDone: Bool, originalRecordID: CKRecord.ID? = nil) {
        self.name = name
        self.isDone = isDone
        self.originalRecordID = originalRecordID
    }

    /// Creates a draft from an already-persisted checklist item, for the editing flow.
    init(from model: CheckItemModel) {
        self.name = model.name
        self.isDone = model.isDone
        self.originalRecordID = model.recordID
    }
}
