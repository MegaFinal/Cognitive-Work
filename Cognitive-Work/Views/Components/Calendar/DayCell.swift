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
                .font(.title3)
                .fontWeight(isSelected ? .bold : .regular)
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(foreground)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(background)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10)) // 没有底色时，整格也能点
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }

    private var foreground: Color {
        if isSelected { return .white }
        return isSelectable ? .black : .gray   // 不可选：灰字
    }

    private var background: Color {
        if isSelected { return .blue }
        guard isSelectable else { return .clear }
        return Color.choreYellow.opacity(opacity)   // opacity 为 0 时就是透明
    }
}

#Preview {
    HStack {
        DayCell(day: Date(), isSelectable: false)  // 灰字，无底色
        DayCell(day: Date())                       // 黑字，无底色
        DayCell(day: Date(), opacity: 0.5)         // 有任务
        DayCell(day: Date(), isSelected: true)     // 选中
    }
    .padding()
}
