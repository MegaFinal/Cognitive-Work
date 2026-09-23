//
//  RecurrenceEnum.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import SwiftUI

/// Defines chronological pattern constraints assigned to repeatable chore data points.
enum Recurrence: String, CaseIterable, Hashable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case fortnightly = "fortnightly"
    case monthly = "monthly"
    
    /// Layout schema applying unique visual signatures per recurring timeframe constraint.
    var color: Color {
        switch self {
        case .none: return .gray
        case .daily: return .green
        case .weekly: return .yellow
        case .fortnightly: return .orange
        case .monthly: return .indigo
        }
    }
    
    var scoreValue: Int {
        switch self {
        case .none:
            return 0
        case .daily:
            return 3
        case .weekly:
            return 5
        case .fortnightly:
            return 8
        case .monthly:
            return 13
        }
    }
}
