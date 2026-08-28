//
//  RoomModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

/// A room inside a house, grouping the chores that happen there.
struct RoomModel: CloudKitSyncable, Identifiable {
    var id = UUID()
    
    /// CloudKit record type backing this model.
    static var recordType: String = "RoomModel"
    
    /// Identifier of the stored record, or `nil` before the room is saved.
    var recordID: CKRecord.ID?
    
    /// Color used to identify the room in the UI.
    var color: RoomColor
    
    /// Name shown to the user.
    /// > Note: Declared optional, but both initializers always assign a value. Consider making
    /// > it non-optional.
    var name: String
    
    /// References to the ``ChoreModel`` records that belong to this room.
    private var relatedChoresReference: [CKRecord.Reference]?
    
    /// The house this room belongs to.
    private var houseReference: CKRecord.Reference?
    
    
    var relatedChores: [ChoreModel] {
        get async {
            if let relatedChoresReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: ChoreModel.self, recordReferences: relatedChoresReference) ?? []
            }
            return []
        }
    }
    
    var house: HouseModel? {
        get async {
            if let houseReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: HouseModel.self, recordReferences: [houseReference])?.first
            }
            return nil
        }
    }
        
    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when `name` is missing or the stored color is not a valid ``RoomColor``.
    ///
    /// > Warning: The color falls back to the raw string `"notUrgent"`, which looks like a
    /// > ``PriorityTag`` value rather than a ``RoomColor``. Verify the intended default.
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let color = RoomColor(rawValue: record["roomColor"] as? String ?? "notUrgent")
        else {
            return nil
        }
        
        self.recordID = record.recordID
        self.name = name
        self.relatedChoresReference = record["relatedChores"] as? [CKRecord.Reference]
        self.houseReference = record["house"] as? CKRecord.Reference
        self.color = color
    }
    
    /// Creates a new, unsaved room.
    ///
    /// - Parameters:
    ///   - name: Name shown to the user.
    ///   - relatedChores: Chores already known to belong to this room.
    ///   - house: The owning house.
    ///   - color: Color used to identify the room.
    init(
        name: String,
        relatedChores: [CKRecord.Reference]? = nil,
        house: CKRecord.Reference? = nil,
        color: RoomColor
    ) {
        self.recordID = nil
        self.name = name
        self.relatedChoresReference = relatedChores
        self.houseReference = house
        self.color = color
    }
    
    /// Writes this model's values into a CloudKit record.
    ///
    /// - Parameter record: The record to populate.
    ///
    /// > Note: `nil` relationships are skipped rather than written, preserving whatever is
    /// > already on the server.
    func populate(record: CKRecord) {
        record["name"] = name
        if let relatedChoresReference {
            record["relatedChores"] = relatedChoresReference
        }
        if let houseReference {
            record["house"] = houseReference
        }
        record["roomColor"] = color.rawValue
    }
    
    func fertchRelatedChores() async -> [ChoreModel] {
        if self.relatedChoresReference == nil {
            return []
        }
        return await CloudKitManager.shared.fetchRecordsByRecordReference(for: ChoreModel.self, recordReferences: self.relatedChoresReference!) ?? []
    }
}
