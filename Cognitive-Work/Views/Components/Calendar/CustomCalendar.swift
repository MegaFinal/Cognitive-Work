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
    var earliestSelectable: Date? = nil   // days before this are shown grey and can't be tapped
    
    /// Computed (not stored) so it follows a language change without recreating the view.
    private var daysOfWeek: [String] { Date.capitalizedFirstLettersOfWeekdays }
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

    /// Every day to display in the grid: from the start of the week containing the window's first day,
    /// to the end of the week containing the window's last day.
    private var gridDays: [Date] {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: window.upperBound) ?? window.lowerBound

        // Pad backwards from the week of the first day to the start of the week
        let startOffset = (calendar.component(.weekday, from: window.lowerBound) - Date.firstDayOfWeek + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -startOffset, to: window.lowerBound) else { return [] }

        // Pad forwards from the week of the last day to the end of the week
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
            // Cross-year
            return "\(monthName(first)) \(firstYear) - \(monthName(last)) \(lastYear)"
        }
        if first.monthInt != last.monthInt {
            // Cross-month
            return "\(monthName(first)) - \(monthName(last)) \(firstYear)"
        }
        // Same month
        return "\(monthName(first)) \(firstYear)"
    }
    
    private func monthName(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).locale(L10n.locale))
            .capitalized(with: L10n.locale)
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
                    && day.startOfDay >= (earliestSelectable ?? .distantPast)
                DayCell(
                    day: day,
                    opacity: selectable ? opacityForDay(day) : 0,
                    isSelectable: selectable,
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
                    .locale(L10n.locale))
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
        // Tapping an already selected date again = deselects it
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
            // Mock data: simulates varying workload volumes (0 = no chores, no background)
            opacityForDay: { day in
                let d = Calendar.current.component(.day, from: day)
                if d % 3 == 0 { return 0.9 }
                if d % 2 == 0 { return 0.4 }
                return 0
            }
        )
    }
}

/// Standard case: 15 days starting today
#Preview("15 Days Starting Today") {
    let today = Calendar.current.startOfDay(for: Date())
    let end = Calendar.current.date(byAdding: .day, value: 15, to: today)!
    return ChoreDatePickerPreview(window: today..<end)
}

/// Cross-month window: starts 5 days before the end of the current month, spanning into the next
#Preview("Cross-Month Window") {
    let calendar = Calendar.current
    let start = calendar.date(byAdding: .day, value: -4, to: Date.now.endOfMonth)!
    let startOfDay = calendar.startOfDay(for: start)
    let end = calendar.date(byAdding: .day, value: 15, to: startOfDay)!
    return ChoreDatePickerPreview(window: startOfDay..<end)
}

#Preview("Cross-Year: 15 Days Starting December 20th") {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 20))!
    let end = calendar.date(byAdding: .day, value: 15, to: start)!
    return ChoreDatePickerPreview(window: start..<end)
}
