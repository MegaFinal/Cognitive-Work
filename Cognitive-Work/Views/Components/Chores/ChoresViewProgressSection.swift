//
//  ChoresViewProgressSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import SwiftUI

/// An informational layout segment displaying metric-based progress cards.
struct ChoresViewProgressSection: View {
    
    /// Injects the active color state into the backgrounds of the generated statistical cards.
    var activeRoomColor: Color = .gray
    
    var body: some View {
        HStack(spacing: 10) {
            ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min", color: activeRoomColor)
            ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min", color: activeRoomColor)
            ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min", color: activeRoomColor)
        }
        .padding(.horizontal, 30)
        .animation(.easeInOut, value: activeRoomColor)
    }
}

#Preview {
    ChoresViewProgressSection()
}
