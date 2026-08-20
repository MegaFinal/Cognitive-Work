//
//  TaskSchedulerEngine.swift
//  Cognitive-Work
//

import Foundation
import CloudKit

// MARK: - Engine
struct TaskSchedulerEngine {
    
    /// Schedules unassigned and daily chores for all given users within a one-week horizon.
    ///
    /// This method performs the following key steps:
    /// 1. Filters out daily chores that have already been scheduled to prevent duplicate entries.
    /// 2. Sorts remaining non-daily chores by their normalized weight.
    /// 3. Distributes tasks among assigned and free chores accordingly.
    /// 4. Commits the final generated schedule results.
    ///
    /// - Parameters:
    ///   - chores: An array of ``ChoreModel`` instances representing all tasks to evaluate.
    ///   - users: An array of ``UserModel`` instances representing available household members.
    static func schedule(chores: [ChoreModel], users: [UserModel]) async {
        // Return immediately if the user list is empty, without performing any scheduling
        guard !users.isEmpty else { return }
        
        // Get the start time of the current day (00:00:00)
        let now = Calendar.current.startOfDay(for: Date())
        // Calculate the date 7 days from today; return if it fails
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return }
        
        // Build the scheduling context to calculate environment variables such as user available time, capacity, etc.
        let context = await buildScheduleContext(
            users: users,
            chores: chores,
            now: now,
            oneWeekLater: oneWeekLater
        )
        
        // Filter out daily chores that need to be scheduled
        // Condition: not done, daily frequency, and do not yet have generated daily assignment records
        let dailyChores = chores.filter {
            !$0.isDone && $0.frequency == .daily && ($0.dailyAssignments ?? []).isEmpty
        }
        
        // Filter all unfinished chores with no set due date
        let unassignedChores = chores.filter { !$0.isDone && $0.dueDate == nil }
        
        // Exclude daily frequency chores from the above list, keeping only common chores
        let nonDailyChores = unassignedChores.filter { $0.frequency != .daily }
        
        // Sort chores in descending order by weight, higher weights go to the top for priority scheduling
        let sortedChores = nonDailyChores.sorted { normalizedWeight(chore: $0) > normalizedWeight(chore: $1) }
        
        // Divide the sorted chores into two categories:
        // - Chores that already have a specific assigned responsible user
        let assignedChores = sortedChores.filter { $0.currentResponsible != nil }
        // - "Free" chores without a defined responsible person, requiring automatic system assignment
        let freeChores = sortedChores.filter { $0.currentResponsible == nil }
        
        // Initialize remaining capacity and minutes already assigned to each user
        var remainingCapacity = context.initialRemainingCapacity()
        var userAssignedMinutes = context.initialUserAssignedMinutes(users: users)
        
        // Store all generated scheduling results
        var allResults: [ScheduleResult] = []
        
        // Schedule all daily chores
        allResults += scheduleDailyChores(
            dailyChores,
            users: users,
            context: context,
            now: now,
            remainingCapacity: &remainingCapacity,
            userAssignedMinutes: &userAssignedMinutes
        )
        
        // Schedule chores that already have a specific responsible user
        allResults += scheduleAssignedChores(
            assignedChores,
            context: context,
            now: now,
            oneWeekLater: oneWeekLater,
            remainingCapacity: &remainingCapacity,
            userAssignedMinutes: &userAssignedMinutes
        )
        
        // Schedule free chores
        allResults += scheduleFreeChores(
            freeChores,
            users: users,
            context: context,
            now: now,
            oneWeekLater: oneWeekLater,
            remainingCapacity: &remainingCapacity,
            userAssignedMinutes: &userAssignedMinutes
        )
        
        // Commit and save the final schedule results to the cloud
        await commitScheduleResults(allResults, users: users)
    }
    
    // MARK: - Prioritization
    
    /// Calculates a combined normalized weight used to sort chores.
    ///
    /// The final weight is a weighted average: **70% priority** and **30% duration**.
    ///
    /// - Parameter chore: The ``ChoreModel`` to evaluate.
    /// - Returns: A `Double` value between `0.0` and `1.0`.
    static func normalizedWeight(chore: ChoreModel) -> Double {
        let priorityNormalized = normalization(
            value: Double(chore.priorityTag.intValue),
            min: Double(PriorityTag.low.intValue),
            max: Double(PriorityTag.urgent.intValue)
        )
        
        let timeNormalized = normalization(
            value: chore.duration,
            min: 1 * 60,
            max: 8 * 60
        )
        
        return (priorityNormalized * 0.7) + (timeNormalized * 0.3)
    }
    
    /// Normalizes a given numeric value into the range of `0...1`.
    ///
    /// - Parameters:
    ///   - value: The actual numeric value to normalize.
    ///   - minValue: The lower bound limit.
    ///   - maxValue: The upper bound limit.
    /// - Returns: A clamped `Double` between `0` and `1`.
    static func normalization(value: Double, min minValue: Double, max maxValue: Double) -> Double {
        guard maxValue != minValue else { return 0 }
        
        let normalized = (value - minValue) / (maxValue - minValue)
        
        return Swift.min(Swift.max(normalized, 0), 1)
    }
}
