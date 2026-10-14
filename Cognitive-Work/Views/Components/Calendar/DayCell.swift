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
        // "sexta-feira, 25 de setembro" — "Selecionado" — "Muitas tarefas"
        .voiceOverLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(L10n.locale)))
        .voiceOverValue(loadDescription)
        // Voice Control: the number shown in the cell ("Toque em 25"), then "25 de setembro".
        .voiceControlNames([
            day.formatted(.dateTime.day().locale(L10n.locale)),
            day.formatted(.dateTime.day().month(.wide).locale(L10n.locale))
        ])
        .voiceOverTraits(.isSelected, when: isSelected)
        // Days outside the window (or already past) can't be picked: skip them.
        .accessibilityHidden(!isSelectable)
    }
    
    /// How busy the day is, as shown by the yellow background's strength.
    private var loadDescription: String {
        guard isSelectable, opacity > 0 else { return "" }
        return opacity >= 0.6 ? L10n.tr("Muitas tarefas") : L10n.tr("Poucas tarefas")
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
