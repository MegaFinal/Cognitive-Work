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
    var scrollEnabled: Bool = true
    var daysToShow: Int = 14

    var body: some View {
        let calendar = Calendar.current
        let adjustedStartDate = alignToMonday(startDate, calendar: calendar)
        
        let content = HStack(alignment: .top, spacing: 0) {
            ForEach(0..<daysToShow, id: \.self) { dayOffset in
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
        
        if scrollEnabled {
            ScrollView(.horizontal, showsIndicators: false) {
                content
            }
        } else {
            content
        }
    }

    private func alignToMonday(_ date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date
    }
}

private struct FortnightlyDayUserBar: View {
    var day: Date
    var entries: [DailyUsageEntry]
    var users: [UserModel]
    var onSelect: (DailyUsageEntry) -> Void

    private let maxBarHeight: Double = 100

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE"
        return formatter
    }

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            let formattedDay = dateFormatter.string(from: day).replacingOccurrences(of: ".", with: "")
            Text(formattedDay.capitalized)
                .font(.system(size: 16.35))
                .fontWeight(.medium)

            if !entries.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        let userIndex = users.firstIndex(where: { $0.recordID == entry.userID }) ?? (index % users.count)
                        
                        RoundedRectangle(cornerRadius: 15)
                            .fill(UserColorPalette.color(for: userIndex))
                            .frame(width: 45, height: maxBarHeight * entry.tier.heightRatio)
                            .onTapGesture {
                                onSelect(entry)
                            }
                    }
                }
            }
        }
        .frame(width: 55)
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
