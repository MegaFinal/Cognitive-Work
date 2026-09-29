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
    case undefined = -1
    case quick = 1
    case moderate = 2
    case slow = 3
    case verySlow = 4

    /// Resolves an exact minute value into an abstracted layout representation.
    static func from(minutes: Double) -> ChoreDurationTier {
        switch minutes {
        case ..<20:
            return .quick
        case 20..<60:
            return .moderate
        case 60..<90:
            return .slow
        default:
            return .verySlow
        }
    }

    /// Derives proportion scaling specific to a visual representation logic sequence.
    var heightRatio: Double {
        switch self {
        case .undefined: return 0
        case .quick: return 0.3
        case .moderate: return 0.6
        case .slow: return 1.0
        case .verySlow: return 1.5
        }
    }

    /// Localized structural string.
    var displayText: String {
        switch self {
        case .undefined: return "indefinido"
        case .quick: return "curta"
        case .moderate: return "regular"
        case .slow: return "longa"
        case .verySlow: return "extensa"
        }
    }
    
    /// Color schema context representation dictating visual complexity.
    var color: Color {
        switch self {
        case .undefined: return .gray
        case .quick: return .tagBlue
        case .moderate: return .tagGreen
        case .slow: return .tagOrange
        case .verySlow: return .tagRed
        }
    }
}
