//
//  ChoreDTO.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 26/08/26.
//

import SwiftUI

/// A chore as presented during onboarding, before it is persisted to CloudKit.
///
/// This type carries only what the selection screens need, keeping the UI free
/// from CloudKit references. Once the user confirms the selection, the picked
/// instances are mapped into ``ChoreModel`` records.
///
/// Declared as a class so ``isSelected`` can be mutated in place while the
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

    /// Name shown to the user.
    let name: String

    /// Short explanation of what the chore involves.
    let description: String

    /// How often the chore repeats.
    let frequency: Recurrence

    /// Estimated time to complete the chore, in minutes.
    let duration: Double

    /// Priority level used to sort and highlight the chore.
    let priorityTag: PriorityTag

    /// Whether the user marked this chore to be split between the residents.
    ///
    /// Starts as `false` and is driven by the `Toggle` of the selection screen.
    var isSelected: Bool = false

    // MARK: - Initialization

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
        priorityTag: PriorityTag
    ) {
        self.name = name
        self.description = description
        self.frequency = frequency
        self.duration = duration
        self.priorityTag = priorityTag
    }
}
