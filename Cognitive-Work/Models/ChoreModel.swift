//
//  ChoreModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import SwiftUI
import CloudKit

/// A household task assigned to one or more users and belonging to a room.
@Observable
class ChoreModel: CloudKitSyncable, Identifiable {
    var id: UUID = UUID()
    
    /// CloudKit record type backing this model.
    static let recordType = "ChoreModel"

    /// Identifier of the stored record, or `nil` before the chore is saved.
    var recordID: CKRecord.ID?

    /// Title shown to the user.
    var name: String

    /// Free-form details about how the chore should be done.
    var description: String
    
    var isDone: Bool

    /// When the chore is next due, or `nil` when it has no deadline.
    var dueDate: Date?

    /// How often the chore repeats.
    var frequency: Recurrence

    /// Expected time to complete the chore, in minutes.
    var duration: Double

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
    
    var symbolName: String = "toilet"

    /// References to the chore's ``CheckItemModel`` entries.
    var checkListReference: [CKRecord.Reference]?

    /// The user currently responsible for the chore.
    var currentResponsibleReference: CKRecord.Reference?

    /// Every user in the rotation for this chore.
    var allResponsibleUsersReference: [CKRecord.Reference]?

    /// The room this chore belongs to.
    var roomReference: CKRecord.Reference?
    
    var dailyAssignmentsReference: [CKRecord.Reference]?
    
    var checkList: [CheckItemModel] {
        get async {
            if let checkListReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: CheckItemModel.self, recordReferences: checkListReference) ?? []
            }
            return []
        }
    }
    
    var currentResponsible: UserModel? {
        get async {
            if let currentResponsibleReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [currentResponsibleReference])?.first
            }
            return nil
        }
    }
    
    var allResponsibleUsers: [UserModel] {
        get async {
            if let allResponsibleUsersReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: allResponsibleUsersReference) ?? []
            }
            return []
        }
    }
    
    var room: RoomModel? {
        get async {
            if let roomReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: RoomModel.self, recordReferences: [roomReference])?.first
            }
            return nil
        }
    }

    var dailyAssignments: [DailyAssignmentModel] {
        get async {
            if let dailyAssignmentsReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: DailyAssignmentModel.self, recordReferences: dailyAssignmentsReference) ?? []
            }
            return []
        }
    }
    
    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when a required field is missing, has the wrong type, or holds an
    ///   unknown ``Recurrence`` or ``PriorityTag`` value.
    required init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let description = record["description"] as? String,
            let isDone = record["isDone"] as? Bool,
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
        self.isDone = isDone
        self.dueDate = record["dueDate"] as? Date
        self.frequency = frequency
        self.duration = duration
        self.isPublic = isPublic
        self.isLate = isLate
        self.weight = weight
        self.priorityTag = priorityTag
        self.image = record["image"] as? Data
        self.checkListReference = record["checkList"] as? [CKRecord.Reference]
        self.currentResponsibleReference = record["currentResponsible"] as? CKRecord.Reference
        self.allResponsibleUsersReference = record["allResponsibleUsers"] as? [CKRecord.Reference]
        self.roomReference = record["room"] as? CKRecord.Reference
        self.dailyAssignmentsReference = record["dailyAssignment"] as? [CKRecord.Reference]
    }

    /// Creates a new, unsaved chore.
    ///
    /// Relationship parameters are usually filled in after the related records exist.
    init(
        name: String,
        description: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        frequency: Recurrence,
        duration: Double,
        isPublic: Bool,
        isLate: Bool = false,
        weight: Int = 0,
        priorityTag: PriorityTag,
        image: Data? = nil,
        checkList: [CKRecord.Reference]? = nil,
        currentResponsible: CKRecord.Reference? = nil,
        allResponsibleUsers: [CKRecord.Reference]? = nil,
        room: CKRecord.Reference? = nil,
        dailyAssignment: [CKRecord.Reference]? = nil
    ) {
        self.recordID = nil
        self.name = name
        self.description = description
        self.isDone = isDone
        self.dueDate = dueDate
        self.frequency = frequency
        self.duration = duration
        self.isPublic = isPublic
        self.isLate = isLate
        self.weight = weight
        self.priorityTag = priorityTag
        self.image = image
        self.checkListReference = checkList
        self.currentResponsibleReference = currentResponsible
        self.allResponsibleUsersReference = allResponsibleUsers
        self.roomReference = room
        self.dailyAssignmentsReference = dailyAssignment
    }
    
    func updateCheckItem(_ item: CheckItemModel) async {
        await CloudKitManager.shared.update(item)
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
        record["isDone"] = isDone
        record["dueDate"] = dueDate
        record["frequency"] = frequency.rawValue
        record["duration"] = duration
        record["isPublic"] = isPublic
        record["isLate"] = isLate
        record["weight"] = weight
        record["priorityTag"] = priorityTag.rawValue
        record["image"] = image
        if let checkListReference {
            record["checkList"] = checkListReference
        }
        record["currentResponsible"] = currentResponsibleReference
        if let allResponsibleUsersReference {
            record["allResponsibleUsers"] = allResponsibleUsersReference
        }
        if let roomReference {
            record["room"] = roomReference
        }
        if let dailyAssignmentsReference {
            record["dailyAssignment"] = dailyAssignmentsReference
        }
    }
    
    func postpone(byDays days: Int) async {
        let currentDate = self.dueDate ?? Date()
        
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: currentDate) {
            self.dueDate = newDate
            
            await CloudKitManager.shared.update(self)
        }
    }

    func toggle() async {
        self.isDone.toggle()
        await CloudKitManager.shared.update(self)
    }
}
