//
//  DashboardDayUserBar.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI
import CloudKit

struct FortnightlyDayUserBar: View {
    var day: Date
    var entries: [DailyUsageEntry]
    var users: [UserModel]

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE"
        return formatter
    }

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            VStack(spacing: 6) {
                let formattedDay = dateFormatter.string(from: day).replacingOccurrences(of: ".", with: "")
                Text(formattedDay.capitalized)
                    .font(.system(size: 16.35))
                    .fontWeight(.medium)

                if !entries.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            let userIndex = users.firstIndex(where: { $0.recordID == entry.userID }) ?? (index % users.count)
                            let userColor = UserColorPalette.color(for: userIndex)

                            FortnightlyUserBar(
                                maxBarHeight: 50,
                                durationMinutes: entry.minutes,
                                maxMinutes: 120.0,
                                barColor: userColor,
                                choreName: entry.choreName
                            )
                        }
                    }
                }
            }
        }
        .frame(width: 50)
    }
}

#Preview {
    let user1ID = CKRecord.ID(recordName: "user-1")
    let user2ID = CKRecord.ID(recordName: "user-2")

    var user1 = UserModel(name: "Você", tier: .tier1)
    user1.recordID = user1ID
    var user2 = UserModel(name: "Alice", tier: .tier1)
    user2.recordID = user2ID

    let mockEntries: [DailyUsageEntry] = [
        DailyUsageEntry(day: Date(), userID: user1ID, minutes: 45.0, choreName: "Lavar a louça"),
        DailyUsageEntry(day: Date(), userID: user2ID, minutes: 120.0, choreName: "Limpar a casa"),
        DailyUsageEntry(day: Date(), userID: user1ID, minutes: 30.0, choreName: "Lavar a roupa")
    ]

    return FortnightlyDayUserBar(
        day: Date(),
        entries: mockEntries,
        users: [user1, user2]
    )
    .padding()
}
