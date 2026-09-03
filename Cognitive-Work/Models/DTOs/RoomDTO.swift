//
//  RoomDTO.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 26/08/26.
//

import SwiftUI
import CloudKit

/// A room as presented during onboarding, before it is persisted to CloudKit.
///
/// This type carries only what the room selection screens need, keeping the UI
/// free from CloudKit references. Once the user confirms the selection, the
/// picked instances are mapped into ``RoomModel`` records.
///
/// Each instance also holds its own presentation state, so a list of rooms can
/// track selection and expansion per row instead of sharing a single flag.
///
/// Example:
/// ```swift
/// var rooms = [
///     RoomDTO(name: "Kitchen", symbol: "fork.knife"),
///     RoomDTO(name: "Bathroom", symbol: "shower")
/// ]
/// ```
struct RoomDTO: Identifiable {

    // MARK: - Properties

    /// Stable identity used by `ForEach`.
    ///
    /// > Note: Generated locally rather than derived from ``RoomModel``, whose
    /// > `recordID` is `nil` until the record reaches CloudKit.
    let id = UUID()

    /// Name shown to the user.
    var name: String

    /// SF Symbol name used as the room icon.
    var symbol: String

    /// Whether the user picked this room to be part of the house.
    var isSelected: Bool = false

    /// Whether this entry is the trailing "add room" placeholder instead of a
    /// real room.
    ///
    /// Lets the grid render the creation button as one more cell, keeping a
    /// single `ForEach` over the collection.
    var isAddButton: Bool = false

    /// Color used to identify the room in the UI.
    var color: RoomColor = .blue

    /// Whether the room section is showing its chores.
    ///
    /// Held per room so expanding one section leaves the others untouched.
    var isExpanded: Bool = false
}
