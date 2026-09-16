//
//  DashboardModel.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 28/08/26.
//

import Foundation
import SwiftUI
import CloudKit

/// `DashboardModel` fetches every `ChoreModel` and keeps only the ones
/// that are due today and assigned to `user`. From that subset it derives
/// three summary statistics: how many chores there are, how much total
/// time they represent, and what percentage of them is already completed.
@Observable
class DashboardModel: Identifiable {

    var user: UserModel
    var todayChores: [ChoreModel] = []

    /// Today's chores that are still pending, i.e. `isDone == false`.
    var toDoList: [ChoreModel] = []

    // MARK: - Formatted Data

    /// The number of pending chores in ``toDoList``.
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

    /// Fetches today's chores assigned to ``user`` from CloudKit and
    /// recomputes every statistic.
    func setup() async {
        let fetchedChores = await CloudKitManager.shared.fetchAll(ChoreModel.self)

        guard let targetUserID = user.recordID else { return }

        let filtered = fetchedChores.filter { chore in
            guard let responsibleID = chore.currentResponsibleReference?.recordID,
                  let dueDate = chore.dueDate,
                  Calendar.current.isDateInToday(dueDate) else {
                return false
            }
            return responsibleID == targetUserID
        }
        self.todayChores = filtered

        // `isDone` is a plain `Bool`, not an optional, so it can't be
        // unwrapped with `guard let`. Filtering for "not done" is just
        // negating the flag directly.
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

        // The zero-state guard is based on `todayChores` (every chore due
        // today), not `toDo`: with `toDo` now meaning "pending count",
        // guarding on it would skip recomputing time/percentage whenever
        // every chore for today is already done (toDo == 0), leaving them
        // stuck at "0h00"/"0%" even though the day is fully complete.
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

        // Percentage completed is completed-out-of-today's-total, not
        // completed-out-of-pending — dividing by `toDo` here would give a
        // wrong (and division-by-zero-prone) result once tasks start being
        // completed.
        self.completionPercentage = Double(completedChoresCount) / Double(todayChores.count)
        self.completionPercentageString = "\(Int(completionPercentage * 100))%"
    }
}
