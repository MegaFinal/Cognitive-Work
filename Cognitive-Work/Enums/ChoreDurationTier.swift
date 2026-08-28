//
//  ChoreDurationTier.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import Foundation
import SwiftUI

enum ChoreDurationTier: Int, CaseIterable, Hashable {
    case muitoRapido = 0
    case rapido = 1
    case moderado = 2
    case demorado = 3
    case muitoDemorado = 4

    static func from(minutes: Double) -> ChoreDurationTier {
        switch minutes {
        case ..<10:
            return .muitoRapido
        case ..<20:
            return .rapido
        case 20..<60:
            return .moderado
        case 60..<90:
            return .demorado
        default:
            return .muitoDemorado
        }
    }

    var heightRatio: Double {
        switch self {
        case .muitoRapido: return 0.1
        case .rapido: return 0.3
        case .moderado: return 0.6
        case .demorado: return 1.0
        case .muitoDemorado: return 1.5
        }
    }

    var displayText: String {
        switch self {
        case .muitoRapido: return "muito rápido"
        case .rapido: return "rápido"
        case .moderado: return "moderado"
        case .demorado: return "demorado"
        case .muitoDemorado: return "muito demorado"
        }
    }
    
    var color: Color {
        switch self {
        case .muitoRapido: return .green
        case .rapido: return .teal
        case .moderado: return .yellow
        case .demorado: return .orange
        case .muitoDemorado: return .red
        }
    }
}
