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
    
    /// Flag for including monthly chores
    var shouldBeIncluded: Bool?
    
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
    
    var dailyAssignments: [RecurrentAssignmentModel] {
        get async {
            if let dailyAssignmentsReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: RecurrentAssignmentModel.self, recordReferences: dailyAssignmentsReference) ?? []
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
        self.shouldBeIncluded = (record["shouldBeIncluded"] as? Int).map { $0 != 0 }
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
        roomReference: CKRecord.Reference? = nil,
        dailyAssignment: [CKRecord.Reference]? = nil
    ) {
        self.recordID = nil
        self.name = name
        self.description = description
        self.isDone = isDone
        self.dueDate = dueDate
        self.frequency = frequency
        self.shouldBeIncluded = frequency == .monthly ? Bool.random() : nil
        self.duration = duration
        self.isPublic = isPublic
        self.isLate = isLate
        self.weight = weight
        self.priorityTag = priorityTag
        self.image = image
        self.checkListReference = checkList
        self.currentResponsibleReference = currentResponsible
        self.allResponsibleUsersReference = allResponsibleUsers
        self.roomReference = roomReference
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
        record["shouldBeIncluded"] = shouldBeIncluded.map { $0 ? 1 : 0 }
        record["duration"] = duration
        record["isPublic"] = isPublic
        record["isLate"] = isLate
        record["weight"] = weight
        record["priorityTag"] = priorityTag.rawValue
        record["image"] = image
        
        record["checkList"] = checkListReference ?? []
        record["currentResponsible"] = currentResponsibleReference
        record["allResponsibleUsers"] = allResponsibleUsersReference ?? []
        record["room"] = roomReference
        record["dailyAssignment"] = dailyAssignmentsReference ?? []
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
    
    /// Applies the edits made in `DTO` to this chore and persists everything to CloudKit.
    ///
    /// The chore is saved first (if it doesn't exist yet) so it has a `recordID` before its
    /// checklist items are created. On failure at any step, the method returns early and
    /// leaves ``CloudKitManager/errorMessage`` set with the reason.
    ///
    /// - Parameters:
    ///   - choreDTO: The edited values collected by the create/edit screen.
    ///   - targetAssignments: Optional recurrent assignment instances to update if this is an occurrence of a recurring chore.
    func save(from choreDTO: ChoreDTO, targetAssignments: [RecurrentAssignmentModel] = []) async {
        // Copy user-editable fields from the DTO onto the model
        applyEditableFields(from: choreDTO)
        
        // Validate required CloudKit reference properties from the related room and house
        guard let house = await room?.house,
              let zoneID = house.recordID?.zoneID,
              let houseReference = await room?.houseReference
        else { return }
        
        let parentReference = CKRecord.Reference(recordID: houseReference.recordID, action: .none)
        
        // Create the record in CloudKit if it's new, ensuring it obtains a valid recordID
        if recordID == nil {
            guard let createdChore = await CloudKitManager.shared.create(self, zoneID: zoneID, parent: parentReference)
            else { return }
            recordID = createdChore.recordID
        }
        
        guard let choreRecordID = recordID else { return }
        let choreReference = CKRecord.Reference(recordID: choreRecordID, action: .none)
        
        // Sync and associate checklist items with the saved chore reference
        self.checkListReference = await CheckItemModel.sync(from: choreDTO.checklist, parent: choreReference)
        
        // Handle recurrent assignments if specific occurrences are being targeted
        if !targetAssignments.isEmpty {
            await updateRecurrentAssignments(
                for: choreDTO.responsibleUsers,
                targetAssignments: targetAssignments
            )
        }
        
        // Perform a final update to persist all modified fields to CloudKit
        await CloudKitManager.shared.update(self)
    }
    
    /// Copies every user-editable field from `choreDTO` onto this chore.
    private func applyEditableFields(from choreDTO: ChoreDTO) {
        name = choreDTO.name
        description = choreDTO.description
        frequency = choreDTO.frequency
        duration = choreDTO.duration
        priorityTag = choreDTO.priorityTag
        isPublic = choreDTO.isPublic
        symbolName = choreDTO.symbolName
        roomReference = choreDTO.roomReference
        
        allResponsibleUsersReference = choreDTO.responsibleUsers.compactMap { responsibleUser in
            responsibleUser.recordID.map { CKRecord.Reference(recordID: $0, action: .none) }
        }
    }
    
    /// Updates the user references for specific occurrences of a recurring chore based on selected users.
    private func updateRecurrentAssignments(
        for selectedUsers: [UserModel],
        targetAssignments: [RecurrentAssignmentModel]) async {
            let selectedUserIDs = Set(selectedUsers.compactMap { $0.recordID })
            var modelsToUpdate: [RecurrentAssignmentModel] = []
            
            // Clear user references for records that are no longer selected
            for assignment in targetAssignments {
                guard let userID = assignment.userReference?.recordID,
                      !selectedUserIDs.contains(userID)
                else { continue }
                
                assignment.userReference = nil
                modelsToUpdate.append(assignment)
            }
            
            // Fill available slots with newly selected users who aren't yet assigned
            var freeSlots = targetAssignments.filter { $0.userReference == nil }
            let alreadyAssignedUserIDs = Set(targetAssignments.compactMap { $0.userReference?.recordID })
            let needsAssignment = selectedUsers.filter {
                guard let id = $0.recordID else { return false }
                return !alreadyAssignedUserIDs.contains(id)
            }
            
            for user in needsAssignment {
                guard let userID = user.recordID else { continue }
                guard !freeSlots.isEmpty else { break }
                let slot = freeSlots.removeFirst()
                slot.userReference = CKRecord.Reference(recordID: userID, action: .none)
                modelsToUpdate.append(slot)
            }
            
            // Batch update the modified assignment models in CloudKit
            if !modelsToUpdate.isEmpty {
                await CloudKitManager.shared.batchUpdate(modelsToUpdate)
            }
        }
}
