//
//  ChoresViewProgressSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import SwiftUI

struct ChoresViewProgressSection: View {
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
