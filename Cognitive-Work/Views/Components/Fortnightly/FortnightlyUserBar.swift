//
//  DashboardUserBar.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI

struct FortnightlyUserBar: View {
    var barHeight: Double
    var barColor: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .frame(width: 40, height: barHeight)
            .foregroundStyle(barColor)
        
    }
}

#Preview {
    FortnightlyUserBar(barHeight: 148, barColor: .gray)
}
