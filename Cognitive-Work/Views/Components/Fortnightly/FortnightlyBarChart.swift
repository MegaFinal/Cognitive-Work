//
//  DashboardBarChart.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI

struct FortnightlyBarChart: View {
    var body: some View {
        ScrollView(.horizontal){
            HStack{
                ForEach(1...14, id: \.self){ bar in
                    FortnightlyDayUserBar(dayOfWeek: "Seg")
                }
            }
        }
    }
}

#Preview {
    FortnightlyBarChart()
}
