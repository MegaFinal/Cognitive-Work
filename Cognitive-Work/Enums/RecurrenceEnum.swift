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
        case .none: return .recurrenceTagPurple
        case .daily: return .recurrenceTagRed
        case .weekly: return .recurrenceTagOrange
        case .fortnightly: return .recurrenceTagGreen
        case .monthly: return .recurrenceTagBlue
        }
    }
    
    var textColor: Color {
        switch self {
        case .undefined: return .gray
        case .none: return .recurrenceTextPurple
        case .daily: return .recurrenceTextRed
        case .weekly: return .recurrenceTextOrange
        case .fortnightly: return .recurrenceTextGreen
        case .monthly: return .recurrenceTextBlue
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
        case .none: return L10n.tr("única")
        case .daily: return L10n.tr("diária")
        case .weekly: return L10n.tr("semanal")
        case .fortnightly: return L10n.tr("quinzenal")
        case .monthly: return L10n.tr("mensal")
        case .undefined: return L10n.tr("indefinida")
        }
    }
}
