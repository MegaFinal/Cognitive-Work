//
//  DashboardUserBar.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import SwiftUI

struct FortnightlyUserBar: View {
    var maxBarHeight: Double
    var tier: ChoreDurationTier
    var barColor: Color
    var choreName: String
    var onTap: () -> Void = {}

    var body: some View {
        let calculatedHeight = maxBarHeight * tier.heightRatio
        RoundedRectangle(cornerRadius: 4)
            .fill(barColor)
            .frame(width: 38, height: calculatedHeight)
            .onTapGesture {
                onTap()
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        FortnightlyUserBar(
            maxBarHeight: 60,
            tier: .rapido,
            barColor: .blue,
            choreName: "Lavar a louça"
        )
        FortnightlyUserBar(
            maxBarHeight: 60,
            tier: .moderado,
            barColor: .purple,
            choreName: "Estudar Swift"
        )
        FortnightlyUserBar(
            maxBarHeight: 60,
            tier: .demorado,
            barColor: .orange,
            choreName: "Limpar a casa"
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
