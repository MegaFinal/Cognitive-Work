//
//  DashboardDayUserBar.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI

struct FortnightlyDayUserBar: View {
    var dayOfWeek: String
    
    var body: some View {
        VStack{
            Text(dayOfWeek)
                .font(.system(size: 16.35))
                .fontWeight(.medium)
            
            ForEach((1...5), id: \.self) { user in
                FortnightlyUserBar(barHeight: 100, barColor: .gray)
            }
        }
    }
}

#Preview {
    FortnightlyDayUserBar(dayOfWeek: "Seg")
}
