//
//  RetroTriggerPolicy.swift
//  Cognitive-Work
//
//  Decides when the retrospective should be offered to the user.
//

import Foundation

/// The retrospective is offered once the period of the last division is over.
enum RetroTriggerPolicy {

    /// - Parameters:
    ///   - lastScheduledDay: The latest day that has an assignment in the house (the end of the last
    ///     division). `nil` when nothing was ever divided, so there is nothing to look back on.
    ///   - lastPresentedDay: The day the retrospective was last shown, to offer it at most once a day.
    ///   - now: Current date.
    static func shouldPresent(
        lastScheduledDay: Date?,
        lastPresentedDay: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let lastScheduledDay else { return false }
        let today = calendar.startOfDay(for: now)

        // The period is over only on the day after its last day.
        guard calendar.startOfDay(for: lastScheduledDay) < today else { return false }

        if let lastPresentedDay, calendar.isDate(lastPresentedDay, inSameDayAs: today) {
            return false
        }
        return true
    }
}
