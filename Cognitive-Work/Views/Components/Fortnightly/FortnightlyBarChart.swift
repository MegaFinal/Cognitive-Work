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

    var body: some View {
        let calendar = Calendar.current
        let adjustedStartDate = alignToMonday(startDate, calendar: calendar)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<14, id: \.self) { dayOffset in
                    if let day = calendar.date(byAdding: .day, value: dayOffset, to: adjustedStartDate) {
                        let dayEntries = entries.filter { calendar.isDate($0.day, inSameDayAs: day) }
                        FortnightlyDayUserBar(day: day, entries: dayEntries, users: users)
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

    var user1 = UserModel(name: "Você", tier: .tier1)
    user1.recordID = user1ID
    var user2 = UserModel(name: "Alice", tier: .tier1)
    user2.recordID = user2ID

    let today = Date()
    let calendar = Calendar.current

    let mockEntries: [DailyUsageEntry] = [
        DailyUsageEntry(day: today, userID: user1ID, minutes: 45.0, choreName: "Lavar a louça"),
        DailyUsageEntry(day: calendar.date(byAdding: .day, value: 1, to: today)!, userID: user2ID, minutes: 120.0, choreName: "Limpar a casa"),
        DailyUsageEntry(day: today, userID: user1ID, minutes: 30.0, choreName: "Lavar a roupa")
    ]

    return FortnightlyBarChart(
        users: [user1, user2],
        entries: mockEntries,
        startDate: today
    )
}
