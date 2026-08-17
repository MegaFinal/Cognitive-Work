//
//  ChoreModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

/// A household task assigned to one or more users and belonging to a room.
struct ChoreModel: CloudKitSyncable {

    /// CloudKit record type backing this model.
    static let recordType = "ChoreModel"

    /// Identifier of the stored record, or `nil` before the chore is saved.
    var recordID: CKRecord.ID?

    /// Title shown to the user.
    var name: String

    /// Free-form details about how the chore should be done.
    var description: String

    /// When the chore is next due, or `nil` when it has no deadline.
    var dueDate: Date?

    /// How often the chore repeats.
    var frequency: Recurrence

    /// Expected time to complete the chore, in seconds.
    var duration: TimeInterval

    /// Whether every member of the house can see and claim the chore.
    var isPublic: Bool

    /// Whether the chore is past its ``dueDate``.
    var isLate: Bool = false

    /// Effort score used to balance workload between users.
    var weight: Int = 0

    /// Priority level shown in the UI.
    var priorityTag: PriorityTag

    /// Optional illustrative image.
    var image: Data?

    /// References to the chore's ``CheckItemModel`` entries.
    var checkList: [CKRecord.Reference]?

    /// The user currently responsible for the chore.
    var currentResponsible: CKRecord.Reference?

    /// Every user in the rotation for this chore.
    var allResponsibleUsers: [CKRecord.Reference]?

    /// The room this chore belongs to.
    var room: CKRecord.Reference?

    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when a required field is missing, has the wrong type, or holds an
    ///   unknown ``Recurrence`` or ``PriorityTag`` value.
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let description = record["description"] as? String,
            let frequencyRaw = record["frequency"] as? String,
            let frequency = Recurrence(rawValue: frequencyRaw),
            let duration = record["duration"] as? TimeInterval,
            let isPublic = record["isPublic"] as? Bool,
            let isLate = record["isLate"] as? Bool,
            let weight = record["weight"] as? Int,
            let priorityTagRaw = record["priorityTag"] as? String,
            let priorityTag = PriorityTag(rawValue: priorityTagRaw)
        else {
            return nil
        }

        self.recordID = record.recordID
        self.name = name
        self.description = description
        self.dueDate = record["dueDate"] as? Date
        self.frequency = frequency
        self.duration = duration
        self.isPublic = isPublic
        self.isLate = isLate
        self.weight = weight
        self.priorityTag = priorityTag
        self.image = record["image"] as? Data
        self.checkList = record["checkList"] as? [CKRecord.Reference]
        self.currentResponsible = record["currentResponsible"] as? CKRecord.Reference
        self.allResponsibleUsers = record["allResponsibleUsers"] as? [CKRecord.Reference]
        self.room = record["room"] as? CKRecord.Reference
    }

    /// Creates a new, unsaved chore.
    ///
    /// Relationship parameters are usually filled in after the related records exist.
    init(
        name: String,
        description: String,
        dueDate: Date? = nil,
        frequency: Recurrence,
        duration: TimeInterval,
        isPublic: Bool,
        isLate: Bool = false,
        weight: Int = 0,
        priorityTag: PriorityTag,
        image: Data? = nil,
        checkList: [CKRecord.Reference]? = nil,
        currentResponsible: CKRecord.Reference? = nil,
        allResponsibleUsers: [CKRecord.Reference]? = nil,
        room: CKRecord.Reference? = nil
    ) {
        self.recordID = nil
        self.name = name
        self.description = description
        self.dueDate = dueDate
        self.frequency = frequency
        self.duration = duration
        self.isPublic = isPublic
        self.isLate = isLate
        self.weight = weight
        self.priorityTag = priorityTag
        self.image = image
        self.checkList = checkList
        self.currentResponsible = currentResponsible
        self.allResponsibleUsers = allResponsibleUsers
        self.room = room
    }

    /// Writes this model's values into a CloudKit record.
    ///
    /// - Parameter record: The record to populate.
    ///
    /// > Note: `nil` collections are skipped rather than written, so an existing list on the
    /// > server is preserved instead of being cleared.
    func populate(record: CKRecord) {
        record["name"] = name
        record["description"] = description
        record["dueDate"] = dueDate
        record["frequency"] = frequency.rawValue
        record["duration"] = duration
        record["isPublic"] = isPublic
        record["isLate"] = isLate
        record["weight"] = weight
        record["priorityTag"] = priorityTag.rawValue
        record["image"] = image
        if let checkList {
            record["checkList"] = checkList
        }
        record["currentResponsible"] = currentResponsible
        if let allResponsibleUsers {
            record["allResponsibleUsers"] = allResponsibleUsers
        }
        record["room"] = room
    }
}
