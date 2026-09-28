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
        case .daily: return .choreGreen
        case .weekly: return .choreYellow
        case .fortnightly: return .choreOrange
        case .monthly: return .chorePurple
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
    
    var displayName: String {
        switch self {
        case .none: return "Única"
        case .daily: return "Diária"
        case .weekly: return "Semanal"
        case .fortnightly: return "Quinzenal"
        case .monthly: return "Mensal"
        }
    }
}
