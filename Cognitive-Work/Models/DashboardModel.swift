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
        let today = calendar.startOfDay(for: Date())

        var myAssignmentsToday: Set<CKRecord.ID> = []
        for assignment in assignments {
            guard let assignmentID = assignment.recordID,
                  assignment.userReference?.recordID == targetUserID,
                  calendar.isDate(assignment.day, inSameDayAs: today)
            else { continue }
            myAssignmentsToday.insert(assignmentID)
        }

        let filtered = chores.filter { chore in
            if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
                return refs.contains { myAssignmentsToday.contains($0.recordID) }
            } else {
                guard let responsibleID = chore.currentResponsibleReference?.recordID,
                      let dueDate = chore.dueDate,
                      calendar.isDateInToday(dueDate)
                else { return false }
                return responsibleID == targetUserID
            }
        }
        self.todayChores = filtered

        let pendingChores = todayChores.filter { chore in
            !chore.isDone
        }
        self.toDoList = pendingChores

        calculateStatistics()
    }

    /// Recomputes ``toDo``, ``totalTimeFormatted``,
    /// ``completionPercentage`` and ``completionPercentageString`` from
    /// ``todayChores`` and ``toDoList``.
    private func calculateStatistics() {
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

        let completedChoresCount = todayChores.filter { $0.isDone }.count

        self.completionPercentage = Double(completedChoresCount) / Double(todayChores.count)
        self.completionPercentageString = "\(Int(completionPercentage * 100))%"
    }
}
