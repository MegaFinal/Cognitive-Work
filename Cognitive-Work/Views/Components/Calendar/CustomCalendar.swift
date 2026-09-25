//
//  Calendar.swift
//  Cognitive-Work
//
//  Created by anshu Li on 23/09/26.
//

import SwiftUI

struct CustomCalendar: View {
    @Binding var selectedDate: Date?
    let window: Range<Date>
    let opacityForDay: (Date) -> Double
    var highlightedDays: [Date] = []
    var showsSelectionLabel: Bool = true
    
    private let daysOfWeek = Date.capitalizedFirstLettersOfWeekdays
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            weekdayRow
            dayGrid
            if showsSelectionLabel { selectedDateLabel }
        }
        .padding()
    }
    
    // MARK: - Data

    /// 网格里要显示的每一天：从窗口第一天所在那周的第一天，
    /// 到窗口最后一天所在那周的最后一天。
    private var gridDays: [Date] {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: window.upperBound) ?? window.lowerBound

        // 第一天所在那周，往前补到一周的起点
        let startOffset = (calendar.component(.weekday, from: window.lowerBound) - Date.firstDayOfWeek + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -startOffset, to: window.lowerBound) else { return [] }

        // 最后一天所在那周，往后补到一周的终点
        let endOffset = 6 - (calendar.component(.weekday, from: lastDay) - Date.firstDayOfWeek + 7) % 7
        guard let gridEnd = calendar.date(byAdding: .day, value: endOffset, to: lastDay) else { return [] }

        var days: [Date] = []
        var day = gridStart
        while day <= gridEnd {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
    
    // MARK: - Header
    
    private var headerTitle: String {
        let first = window.lowerBound
        let last = calendar.date(byAdding: .day, value: -1, to: window.upperBound) ?? first
        
        let firstYear = calendar.component(.year, from: first)
        let lastYear = calendar.component(.year, from: last)
        
        if firstYear != lastYear {
            // 跨年：Dezembro 2026 - Janeiro 2027
            return "\(monthName(first)) \(firstYear) - \(monthName(last)) \(lastYear)"
        }
        if first.monthInt != last.monthInt {
            // 跨月：Setembro - Outubro 2026
            return "\(monthName(first)) - \(monthName(last)) \(firstYear)"
        }
        // 同一个月：Setembro 2026
        return "\(monthName(first)) \(firstYear)"
    }
    
    private func monthName(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).locale(Locale(identifier: "pt_BR")))
            .capitalized
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        Text(headerTitle)
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
    
    private var weekdayRow: some View {
        HStack {
            ForEach(daysOfWeek.indices, id: \.self) { index in
                Text(daysOfWeek[index])
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.black.opacity(0.4))
            }
        }
    }
    
    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(gridDays, id: \.self) { day in
                let selectable = window.contains(day.startOfDay)
                DayCell(
                    day: day,
                    opacity: selectable ? opacityForDay(day) : 0,
                    isSelectable: selectable,          // 窗口外：灰字、无底色、不可点
                    isSelected: isSelected(day) || isHighlighted(day),
                    action: { select(day) }
                )
            }
        }
    }
    
    
    private var selectedDateLabel: some View {
        if let selectedDate {
            Text(selectedDate.formatted(
                .dateTime
                    .weekday(.wide).day().month(.wide).year()
                    .locale(Locale(identifier: "pt_BR")))
            )
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            Text("Nenhuma data selecionada")
                .font(.system(size: 15))
                .italic()
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    // MARK: - Actions
    
    private func isSelected(_ day: Date) -> Bool {
        guard let selectedDate else { return false }
        return calendar.isDate(selectedDate, inSameDayAs: day)
    }
    
    private func select(_ day: Date) {
        // 再点一次已选中的日期 = 取消选择
        selectedDate = isSelected(day) ? nil : day.startOfDay
    }
    
    private func isHighlighted(_ day: Date) -> Bool {
        highlightedDays.contains { calendar.isDate($0, inSameDayAs: day) }
    }
}

// MARK: - Previews

private struct ChoreDatePickerPreview: View {
    let window: Range<Date>
    @State private var selected: Date?
    
    var body: some View {
        CustomCalendar(
            selectedDate: $selected,
            window: window,
            // 假数据：模拟不同的任务量（0 = 没任务，无底色）
            opacityForDay: { day in
                let d = Calendar.current.component(.day, from: day)
                if d % 3 == 0 { return 0.9 }
                if d % 2 == 0 { return 0.4 }
                return 0
            }
        )
    }
}

/// 常规情况：今天起 15 天
#Preview("今天起 15 天") {
    let today = Calendar.current.startOfDay(for: Date())
    let end = Calendar.current.date(byAdding: .day, value: 15, to: today)!
    return ChoreDatePickerPreview(window: today..<end)
}

/// 窗口跨月：从本月倒数第 5 天开始，可以翻到下个月
#Preview("窗口跨月") {
    let calendar = Calendar.current
    let start = calendar.date(byAdding: .day, value: -4, to: Date.now.endOfMonth)!
    let startOfDay = calendar.startOfDay(for: start)
    let end = calendar.date(byAdding: .day, value: 15, to: startOfDay)!
    return ChoreDatePickerPreview(window: startOfDay..<end)
}

#Preview("跨年：从 12月20日起 15 天") {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 20))!
    let end = calendar.date(byAdding: .day, value: 15, to: start)!
    return ChoreDatePickerPreview(window: start..<end)
}
