//
//  FilterOptionRow.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 31/08/26.
//

import SwiftUI

struct FilterOptionRow<Item: Hashable>: View {
    let items: [Item]
    let isSelected: (Item) -> Bool
    let label: (Item) -> String
    let onSelect: (Item) async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button {
                    Task {
                        await onSelect(item)
                    }
                } label: {
                    HStack {
                        Image(systemName: isSelected(item) ? "checkmark.circle.fill" : "circle")
                        Text(label(item))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if item != items.last {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
