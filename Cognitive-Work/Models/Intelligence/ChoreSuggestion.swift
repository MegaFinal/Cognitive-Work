//
//  ChoreSuggestion.swift
//  Cognitive-Work
//
//  Created by anshu Li on 26/10/26.
//

import Foundation
import FoundationModels

// MARK: - What the on-device model returns

/// How often the chore repeats: what the person said, or else what usually fits the chore.
@Generable
nonisolated enum GeneratedChoreFrequency: String {
    case once, daily, weekly, fortnightly, monthly
}

/// Mirror of ``ChoreDurationTier`` without `undefined`.
@Generable
nonisolated enum GeneratedChoreDuration: String {
    case quick, moderate, slow, verySlow
}

/// Mirror of ``PriorityTag``; `notSaid` when the person didn't say how urgent it is.
@Generable
nonisolated enum GeneratedChorePriority: String {
    case notSaid, low, medium, high, urgent
}

@Generable
nonisolated struct GeneratedChore {
    @Guide(description: "The chore, short, starting with a verb")
    var name: String

    @Guide(description: "One room copied exactly from the rooms list, or none")
    var room: String

    var frequency: GeneratedChoreFrequency
    var duration: GeneratedChoreDuration
    var priority: GeneratedChorePriority

    @Guide(description: "Extra how-to details the person said, in their words. Empty if none")
    var details: String

    @Guide(description: "Steps or parts the person listed, one short item each. Empty if none", .maximumCount(8))
    var steps: [String]
}

/// Typical checklist steps for a chore, suggested when the person listed none.
@Generable
nonisolated struct GeneratedChecklistIdeas {
    @Guide(description: "Short, concrete steps to do the chore", .maximumCount(5))
    var items: [String]
}

// MARK: - What the form uses

/// A filled-in chore form, ready for the person to check. Only `name` and `durationMinutes`
/// are always set; the rest is `nil` when the text didn't say it (or no room fits).
struct ChoreSuggestion {
    /// What the person typed or said.
    let input: String
    let name: String
    let room: RoomModel?
    let frequency: Recurrence?
    let durationMinutes: Double
    let priority: PriorityTag?
    /// Housemates named in the text (and the person typing, for "eu"), read by code.
    let responsibleUsers: [UserModel]?
    /// How-to details the person said ("usar luva"), for "Detalhes"; `nil` when none.
    let details: String?
    /// Steps the person listed ("o vaso, a pia e o box"), for the checklist; empty when none.
    let steps: [String]
}

extension IntelligenceManager {

    /// Fills a chore form from a description ("lavar a louça toda semana, eu e Ana").
    ///
    /// The model picks name, room, frequency, duration and priority. People are matched by code
    /// from the text itself, like the shopping list, so a name is never invented.
    ///
    /// - Returns: `nil` when AI is unavailable or the request fails.
    func suggestChore(
        for text: String,
        rooms: [RoomModel],
        housemates: [UserModel],
        currentUser: UserModel?
    ) async -> ChoreSuggestion? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        // Rooms as the person sees them (translated default names, e.g. "Kitchen").
        let roomNames = rooms.map { $0.name.localizedDefault }
        let prompt = IntelligencePrompts.ChoreParse.self
        guard let generated = await generate(
            GeneratedChore.self,
            prompt: prompt.prompt(for: input, rooms: roomNames),
            instructions: instructions(task: prompt.task, output: .appLanguage),
            promptID: prompt.id
        ) else { return nil }

        let name = String(
            generated.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(TextLimits.choreName)
        )

        return ChoreSuggestion(
            input: input,
            name: name.isEmpty ? String(input.prefix(TextLimits.choreName)) : name,
            room: Self.room(named: generated.room, in: rooms),
            frequency: Self.recurrence(from: generated.frequency),
            durationMinutes: Self.tier(from: generated.duration).minutes,
            priority: Self.priority(from: generated.priority),
            responsibleUsers: Self.consumersMentioned(
                in: input,
                housemates: housemates,
                currentUser: currentUser,
                everyoneCounts: false
            ),
            details: Self.cleaned(generated.details, limit: TextLimits.choreDescription),
            steps: generated.steps.compactMap { Self.cleaned($0, limit: TextLimits.checklistItem) }
        )
    }

    /// Up to five typical steps for a chore ("Limpar o banheiro" -> vaso, pia, box…), in the
    /// app's language. Only suggestions: the form shows them as chips the person taps to add.
    ///
    /// - Parameter existing: Items already on the checklist, so they aren't suggested again.
    /// - Returns: `nil` when AI is unavailable or the request fails.
    func suggestChecklist(for name: String, room: String?, existing: [String]) async -> [String]? {
        let prompt = IntelligencePrompts.ChoreChecklistIdeas.self
        guard let generated = await generate(
            GeneratedChecklistIdeas.self,
            prompt: prompt.prompt(name: name, room: room, existing: existing),
            instructions: instructions(task: prompt.task, output: .appLanguage),
            promptID: prompt.id
        ) else { return nil }

        let taken = Set(existing.map(Self.foldedKey))
        var seen = Set<String>()
        return generated.items.compactMap { item in
            guard let text = Self.cleaned(item, limit: TextLimits.checklistItem) else { return nil }
            let key = Self.foldedKey(text)
            guard !taken.contains(key), seen.insert(key).inserted else { return nil }
            return text
        }
    }

    /// Trimmed, first letter capitalized, cut to `limit`; `nil` when empty.
    private static func cleaned(_ text: String, limit: Int) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:-")))
        guard !trimmed.isEmpty else { return nil }
        let capitalized = trimmed.prefix(1).uppercased(with: L10n.locale) + trimmed.dropFirst()
        return String(capitalized.prefix(limit))
    }

    /// Lowercased without accents, to compare checklist items.
    static func foldedKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Mapping

    /// The room whose name (stored or translated) matches, ignoring case and accents.
    private static func room(named name: String, in rooms: [RoomModel]) -> RoomModel? {
        func folded(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let wanted = folded(name)
        guard !wanted.isEmpty, wanted != "none" else { return nil }
        return rooms.first { folded($0.name) == wanted || folded($0.name.localizedDefault) == wanted }
    }

    private static func recurrence(from frequency: GeneratedChoreFrequency) -> Recurrence? {
        switch frequency {
        case .once: return Recurrence.none
        case .daily: return .daily
        case .weekly: return .weekly
        case .fortnightly: return .fortnightly
        case .monthly: return .monthly
        }
    }

    private static func tier(from duration: GeneratedChoreDuration) -> ChoreDurationTier {
        switch duration {
        case .quick: return .quick
        case .moderate: return .moderate
        case .slow: return .slow
        case .verySlow: return .verySlow
        }
    }

    private static func priority(from priority: GeneratedChorePriority) -> PriorityTag? {
        switch priority {
        case .notSaid: return nil
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .urgent: return .urgent
        }
    }
}
