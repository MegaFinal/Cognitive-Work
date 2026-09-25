//
//  DashboardModel.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 28/08/26.
//

import Foundation
import SwiftUI
import CloudKit

/// `DashboardModel` keeps only the chores that are due today and assigned to `user`, out of
/// chores/assignments the caller already fetched
@Observable
class DashboardModel: Identifiable {

    var user: UserModel
    var todayChores: [ChoreModel] = []

    /// Today's chores that are still pending
    var toDoList: [ChoreModel] = []

    // MARK: - Formatted Data

    /// The number of pending chores
    var toDo: Int = 0

    /// (e.g. `"1h30"`).
    var totalTimeFormatted: String = "0h00"

    /// The fraction, from `0.0` to `1.0`, of today's chores that are marked as done
    var completionPercentage: Double = 0.0

    /// (e.g. `"75%"`)
    var completionPercentageString: String = "0%"

    init(user: UserModel) {
        self.user = user
    }

    /// Recomputes every statistic for today's chores assigned to ``user``, out of `chores`
    /// and `assignments` the caller already has in memory (no CloudKit request here).
    ///
    /// - Parameters:
    ///   - chores: Every chore, e.g. ``CarouselViewModel/cardModels``.
    ///   - assignments: Every recurrent assignment, e.g. ``CarouselViewModel/dailyAssignments``.
    func setup(chores: [ChoreModel], assignments: [RecurrentAssignmentModel]) {
        guard let targetUserID = user.recordID else { return }

        let calendar = Calendar.current
        // The same day the grid shows — tomorrow while the schedule is being tested — so the
        // progress cards count the chores the user actually sees. Follows
        // ``CarouselViewModel/gridDayOffsetFromToday``; set that back to `0` and this goes
        // back to today with it.
        let today = CarouselViewModel.gridTargetDay()

        // Keyed by assignment recordID (not just a Set) so `isDoneToday(_:)` below can read
        // back each assignment's own `isCompleted`, not just whether it exists.
        var myAssignmentsToday: [CKRecord.ID: RecurrentAssignmentModel] = [:]
        for assignment in assignments {
            guard let assignmentID = assignment.recordID,
                  assignment.userReference?.recordID == targetUserID,
                  calendar.isDate(assignment.day, inSameDayAs: today)
            else { continue }
            myAssignmentsToday[assignmentID] = assignment
        }

        let filtered = chores.filter { chore in
            if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
                return refs.contains { myAssignmentsToday[$0.recordID] != nil }
            } else {
                guard let responsibleID = chore.currentResponsibleReference?.recordID,
                      let dueDate = chore.dueDate,
                      calendar.isDate(dueDate, inSameDayAs: today)
                else { return false }
                return responsibleID == targetUserID
            }
        }
        self.todayChores = filtered

        func isDoneToday(_ chore: ChoreModel) -> Bool {
            guard let refs = chore.dailyAssignmentsReference, !refs.isEmpty else {
                return chore.isDone
            }
            let todaysAssignments = refs.compactMap { myAssignmentsToday[$0.recordID] }
            guard !todaysAssignments.isEmpty else { return chore.isDone }
            return todaysAssignments.allSatisfy { $0.isCompleted }
        }

        self.toDoList = todayChores.filter { !isDoneToday($0) }

        calculateStatistics(isDoneToday: isDoneToday)
    }

    /// Recomputes ``toDo``, ``totalTimeFormatted``,
    /// ``completionPercentage`` and ``completionPercentageString`` from
    /// ``todayChores`` and ``toDoList``.
    ///
    /// - Parameter isDoneToday: Same predicate ``setup(chores:assignments:)`` used to build
    ///   ``toDoList``, so the completion count and ``toDoList`` never disagree about a chore.
    private func calculateStatistics(isDoneToday: (ChoreModel) -> Bool) {
        self.toDo = toDoList.count

        guard !todayChores.isEmpty else {
            self.totalTimeFormatted = "0h00"
            self.completionPercentageString = "0%"
            return
        }

        let totalMinutes = todayChores.reduce(into: 0.0) { total, chore in
            total += chore.duration
        }

        let hours = Int(totalMinutes / 60)
        let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60.0))
        self.totalTimeFormatted = "\(hours)h\(String(format: "%02d", minutes))"

        let completedChoresCount = todayChores.filter { isDoneToday($0) }.count

        self.completionPercentage = Double(completedChoresCount) / Double(todayChores.count)
        self.completionPercentageString = "\(Int(completionPercentage * 100))%"
    }
}
