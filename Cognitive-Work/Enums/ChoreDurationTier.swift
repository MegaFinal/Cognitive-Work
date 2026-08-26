//
//  ChoreDurationTier.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import Foundation

enum ChoreDurationTier: Int, CaseIterable {
    case rapido = 1
    case moderado = 2
    case demorado = 3

    static func from(minutes: Double) -> ChoreDurationTier {
        switch minutes {
        case ..<20:
            return .rapido
        case 20..<60:
            return .moderado
        default:
            return .demorado
        }
    }

    var heightRatio: Double {
        switch self {
        case .rapido: return 0.3
        case .moderado: return 0.6
        case .demorado: return 1.0
        }
    }

    var displayText: String {
        switch self {
        case .rapido: return "rápido"
        case .moderado: return "moderado"
        case .demorado: return "demorado"
        }
    }
}
