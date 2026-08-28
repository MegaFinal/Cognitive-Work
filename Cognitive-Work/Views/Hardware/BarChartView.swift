//
//  BarChartView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 27/08/26.
//

import SwiftUI

struct BarChartView: View {
    let values: [CGFloat]
    let labels: [String]
    let title: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .bold()
                    .padding(.leading, 4)
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 2) {
                            Spacer()
                            Rectangle()
                                .fill(isMax(index) ? Color.gray : Color.black)
                                .frame(height: value * 85)
                            Text(labels[index])
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 100)
            }
        }
        .frame(width: 296, height: 128)
    }
    
    private func isMax(_ index: Int) -> Bool {
        guard let maxValue = values.max() else { return false }
        return values[index] == maxValue
    }
}

#Preview {
    BarChartView(
        values: [0.4, 0.9, 0.6, 0.3, 0.7],
        labels: ["Seg", "Ter", "Qua", "Qui", "Sex"],
        title: "Tarefa da semana"
    )
}
