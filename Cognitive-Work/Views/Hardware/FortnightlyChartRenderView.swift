//
//  FortnightlyChartRenderView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 01/09/26.
//

import SwiftUI

struct FortnightlyChartRenderView: View {
    let users: [UserModel]
    let chores: [ChoreModel]
    let usageEntries: [DailyUsageEntry]
    let startDate: Date
    
    
    var body: some View {
        VStack(spacing: 16) {
            FortnightlyBarChart(
                users: users,
                entries: usageEntries,
                startDate: startDate,
                onSelect: { _ in },
                scrollEnabled: false,
                daysToShow: 7
            )
            FortnightlyLegend(users: users)
        }
        .frame(maxWidth: 350, maxHeight: 200, alignment: .top)
        .clipped()
    }
}
