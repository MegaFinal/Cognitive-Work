//
//  DashboardBarChart.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI
import CloudKit

struct FortnightlyBarChart: View {
    var users: [UserModel]
    var entries: [DailyUsageEntry]
    var startDate: Date = Date()
    var onSelect: (DailyUsageEntry) -> Void

    var body: some View {
        let calendar = Calendar.current
        let adjustedStartDate = alignToMonday(startDate, calendar: calendar)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<14, id: \.self) { dayOffset in
                    if let day = calendar.date(byAdding: .day, value: dayOffset, to: adjustedStartDate) {
                        let dayEntries = entries.filter { calendar.isDate($0.day, inSameDayAs: day) }
                        FortnightlyDayUserBar(
                            day: day,
                            entries: dayEntries,
                            users: users,
                            onSelect: onSelect
                        )
                    }
                }
            }
        }
    }

    private func alignToMonday(_ date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date
    }
}

#Preview {
    let user1ID = CKRecord.ID(recordName: "user-1")
    let user2ID = CKRecord.ID(recordName: "user-2")
    let chore1ID = CKRecord.ID(recordName: "chore-1")
    let chore2ID = CKRecord.ID(recordName: "chore-2")

    var user1 = UserModel(name: "Você", tier: .tier1, recordID: user1ID)
    var user2 = UserModel(name: "Alice", tier: .tier1, recordID: user2ID)

    let today = Date()
    let calendar = Calendar.current

    let mockEntries: [DailyUsageEntry] = [
        DailyUsageEntry(day: today, userID: user1ID, choreID: chore1ID, minutes: 15.0, choreName: "Lavar a louça"),
        DailyUsageEntry(day: calendar.date(byAdding: .day, value: 1, to: today)!, userID: user2ID, choreID: chore2ID, minutes: 90.0, choreName: "Limpar a casa")
    ]

    FortnightlyBarChart(
        users: [user1, user2],
        entries: mockEntries,
        startDate: today,
        onSelect: { entry in print("Selected: \(entry.choreName)") }
    )
}
