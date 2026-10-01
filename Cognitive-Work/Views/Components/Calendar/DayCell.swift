//
//  DayCell.swift
//  Cognitive-Work
//
//  Created by anshu Li on 23/09/26.
//

import SwiftUI

struct DayCell: View {
    let day: Date
    var opacity: Double = 0
    var isSelectable: Bool = true
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(day.formatted(.dateTime.day()))
                .font(.system(size: 15))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(foreground)
                .background(
                    Circle()
                        .fill(background)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }

    private var foreground: Color {
        if isSelected { return .white }
        return isSelectable ? .black : .gray
    }

    private var background: Color {
        if isSelected { return .black }
        guard isSelectable else { return .clear }
        return Color.choreYellow.opacity(opacity)
    }
}

#Preview {
    HStack {
        DayCell(day: Date(), isSelectable: false)
        DayCell(day: Date())
        DayCell(day: Date(), opacity: 0.5)
        DayCell(day: Date(), isSelected: true) 
    }
    .padding()
}
