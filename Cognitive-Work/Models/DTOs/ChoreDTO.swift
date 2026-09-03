//
//  ChoreDTO.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 26/08/26.
//

import SwiftUI
import CloudKit

/// A chore as presented during onboarding or editing, before it is persisted to CloudKit.
///
/// This type carries only what the selection screens need, keeping the UI free
/// from direct CloudKit mutations. Once the user confirms the selection, the picked
/// instances are mapped into ``ChoreModel`` records.
///
/// Declared as a class so ``isSelected`` and other properties can be mutated in place while the
/// instance is shared by a list row, and marked `@Observable` so those
/// mutations refresh the views observing it.
///
/// Example:
/// ```swift
/// let chore = ChoreDTO(
///     name: "Wash the dishes",
///     description: "Includes drying and putting away",
///     frequency: .daily,
///     duration: 10,
///     priorityTag: .high
/// )
/// ```
@Observable
final class ChoreDTO: Identifiable {

    // MARK: - Properties

    /// Stable identity used by `ForEach`.
    ///
    /// > Note: Generated locally instead of relying on ``name``, so two chores
    /// > sharing the same name never collapse into a single row.
    let id = UUID()
    
    /// Identifier of the original stored record, if this DTO is editing an existing chore.
    var originalRecordID: CKRecord.ID?

    /// Name shown to the user.
    var name: String

    /// Short explanation of what the chore involves.
    var description: String

    /// How often the chore repeats.
    var frequency: Recurrence

    /// Estimated time to complete the chore, in minutes.
    var duration: Double

    /// Priority level used to sort and highlight the chore.
    var priorityTag: PriorityTag

    /// Whether the user marked this chore to be split between the residents.
    ///
    /// Starts as `false` and is driven by the `Toggle` of the selection screen.
    var isSelected: Bool = false
    
    /// Whether every member of the house can see and claim the chore.
    var isPublic: Bool
    
    /// The SF Symbol name used as the chore's icon.
    var symbolName: String
    
    /// Reference to the room this chore belongs to.
    var roomDTO: RoomDTO
    
    var room: RoomModel?
    var roomReference: CKRecord.Reference?
    
    /// Every user in the rotation for this chore.
    var responsibleUsers: [UserModel] = []
    
    /// The checklist items for this chore.
    var checklist: [CheckItemDTO] = []
    
    /// Whether the chore currently has a checklist enabled in the UI.
    var hasChecklist: Bool = false

    // MARK: - Initialization
    
    /// Creates a new, empty chore draft for the creation flow.
    init() {
        self.name = ""
        self.description = ""
        self.frequency = .weekly
        self.duration = 1800
        self.priorityTag = .medium
        self.isPublic = false
        self.symbolName = "toilet"
        self.roomDTO = RoomDTO(name: "Banheiro", symbol: "toilet")
    }

    /// Creates a chore draft from an existing ``ChoreModel`` for the editing flow.
    ///
    /// - Parameters:
    ///   - model: The original chore model to copy data from.
    ///   - users: The previously assigned responsible users.
    ///   - checklist: The previously assigned checklist items.
    ///   - room: The room this chore belongs to.
    init(
        from model: ChoreModel,
        users: [UserModel],
        checklist: [CheckItemDTO],
        room: RoomModel? = nil
    ) {
        self.originalRecordID = model.recordID
        self.name = model.name
        self.description = model.description
        self.frequency = model.frequency
        self.duration = model.duration
        self.priorityTag = model.priorityTag
        self.isPublic = model.isPublic
        self.symbolName = model.symbolName
        
        self.responsibleUsers = users
        self.checklist = checklist
        self.hasChecklist = !checklist.isEmpty
        
        if let roomModel = room, let roomRecordID = roomModel.recordID {
            self.roomReference = CKRecord.Reference(recordID: roomRecordID, action: .none)
        }
        self.roomDTO = RoomDTO(name: "NoDTO", symbol: "xmark")
    }

    /// Creates a chore for the onboarding selection screens.
    ///
    /// - Parameters:
    ///   - name: Name shown to the user.
    ///   - description: Short explanation of what the chore involves.
    ///   - frequency: How often the chore repeats.
    ///   - duration: Estimated time to complete the chore, in minutes.
    ///   - priorityTag: Priority level used to sort and highlight the chore.
    init(
        name: String,
        description: String,
        frequency: Recurrence,
        duration: Double,
        priorityTag: PriorityTag,
        room: RoomDTO
    ) {
        self.name = name
        self.description = description
        self.frequency = frequency
        self.duration = duration
        self.priorityTag = priorityTag
        self.isPublic = false
        self.symbolName = "toilet"
        self.roomDTO = room
    }
}
