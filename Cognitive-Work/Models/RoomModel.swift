//
//  RoomModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

/// A room inside a house, grouping the chores that happen there.
struct RoomModel: CloudKitSyncable {

    /// CloudKit record type backing this model.
    static var recordType: String = "RoomModel"

    /// Identifier of the stored record, or `nil` before the room is saved.
    var recordID: CKRecord.ID?

    /// Name shown to the user.
    ///
    /// > Note: Declared optional, but both initializers always assign a value. Consider making
    /// > it non-optional.
    var name: String?

    /// References to the ``ChoreModel`` records that belong to this room.
    var relatedChores: [CKRecord.Reference]?

    /// The house this room belongs to.
    var house: CKRecord.Reference?

    /// Color used to identify the room in the UI.
    var color: RoomColor

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
        self.relatedChores = record["relatedChores"] as? [CKRecord.Reference]
        self.house = record["house"] as? CKRecord.Reference
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
        self.relatedChores = relatedChores
        self.house = house
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
        if let relatedChores {
            record["relatedChores"] = relatedChores
        }
        if let house {
            record["house"] = house
        }
        record["roomColor"] = color.rawValue
    }
}
