//
//  RecurrenceEnum.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import SwiftUI

/// Defines chronological pattern constraints assigned to repeatable chore data points.
enum Recurrence: String, CaseIterable, Hashable {
    case undefined = "indefinida"
    case none = "sem recorrencia"
    case daily = "diaria"
    case weekly = "semanal"
    case fortnightly = "quinzenal"
    case monthly = "mensal"
    
    /// Layout schema applying unique visual signatures per recurring timeframe constraint.
    var color: Color {
        switch self {
        case .undefined: return .gray
        case .none: return .black
        case .daily: return .green
        case .weekly: return .yellow
        case .fortnightly: return .orange
        case .monthly: return .indigo
        }
    }
    
    var scoreValue: Int {
        switch self {
        case .undefined:
            return -1
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
