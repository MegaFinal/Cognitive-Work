//
//  DateExtencion.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 31/08/26.
//

import Foundation

extension Date {

    func weekdayInCurrentWeek(offset: Int, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: self)?.start ?? self
        return cal.date(byAdding: .day, value: offset, to: start) ?? start
    }
}
