//
//  FilterHeaderButton.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 31/08/26.
//

import SwiftUI

struct FilterHeaderButton: View {
    @Binding var isExpanded: Bool
    var headerText: String
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text(headerText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FilterHeaderButton(isExpanded: .constant(true), headerText: "Prioridade")
}
