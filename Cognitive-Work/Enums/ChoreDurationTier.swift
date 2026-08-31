//
//  ChoreDurationTier.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import Foundation
import SwiftUI

/// Abstract tier categorizing length constraints mapping expected completion difficulty.
enum ChoreDurationTier: Int, CaseIterable, Hashable {
    case muitoRapido = 0
    case rapido = 1
    case moderado = 2
    case demorado = 3
    case muitoDemorado = 4

    /// Resolves an exact minute value into an abstracted layout representation.
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

    /// Derives proportion scaling specific to a visual representation logic sequence.
    var heightRatio: Double {
        switch self {
        case .muitoRapido: return 0.1
        case .rapido: return 0.3
        case .moderado: return 0.6
        case .demorado: return 1.0
        case .muitoDemorado: return 1.5
        }
    }

    /// Localized structural string.
    var displayText: String {
        switch self {
        case .muitoRapido: return "muito rápido"
        case .rapido: return "rápido"
        case .moderado: return "moderado"
        case .demorado: return "demorado"
        case .muitoDemorado: return "muito demorado"
        }
    }
    
    /// Color schema context representation dictating visual complexity.
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
