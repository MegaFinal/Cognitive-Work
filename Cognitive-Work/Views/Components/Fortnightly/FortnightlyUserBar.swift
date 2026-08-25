//
//  DashboardUserBar.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI

struct FortnightlyUserBar: View {
    var maxBarHeight: Double
    var durationMinutes: Double
    var maxMinutes: Double = 120.0
    var barColor: Color
    var choreName: String
    
    var body: some View {
        let ratio = min(1.0, max(0.0, durationMinutes / maxMinutes))
        let calculatedHeight = max(14.0, ratio * maxBarHeight)
        
        return RoundedRectangle(cornerRadius: 4)
            .fill(barColor)
            .frame(width: 38, height: calculatedHeight)
//            .overlay(
//                    Text("\(Int(durationMinutes))m")
//                        .font(.system(size: 8, weight: .bold))
//                        .foregroundColor(.white)
//            )
    }
}

// MARK: - Preview Mock
#Preview{
    VStack(spacing: 16) {
        FortnightlyUserBar(
            maxBarHeight: 60,
            durationMinutes: 30.0,
            maxMinutes: 120.0,
            barColor: .blue,
            choreName: "Lavar a louça"
        )
        
        FortnightlyUserBar(
            maxBarHeight: 60,
            durationMinutes: 60.0,
            maxMinutes: 120.0,
            barColor: .purple,
            choreName: "Estudar Swift"
        )
        
        FortnightlyUserBar(
            maxBarHeight: 60,
            durationMinutes: 120.0,
            maxMinutes: 120.0,
            barColor: .orange,
            choreName: "Limpar a casa"
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
