//
//  PriorityTagEnum.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import SwiftUI

/// Enumerates strict constraints defining urgency characteristics applied within context filters.
enum PriorityTag: String, CaseIterable, Hashable {
    case low = "não urgente"
    case medium = "pouco urgente"
    case high = "urgente"
    case urgent = "muito urgente"
    
    /// Structural value evaluating ranking priorities.
    var intValue: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
    
    /// Color layout representing an abstract priority urgency.
    var color: Color {
        switch self {
        case .low: return .choreGreen
        case .medium: return .choreYellow
        case .high: return .choreOrange
        case .urgent: return .red
        }
    }
    
    var scoreValue: Int {
        switch self {
        case .low:
            5
        case .medium:
            8
        case .high:
            13
        case .urgent:
            21
        }
    }
    
    /// Verifies superiority evaluation directly between conflicting constraint instances.
    static func isLarger (lhs: PriorityTag, rhs: PriorityTag) -> Bool {
        lhs.intValue < rhs.intValue
    }
}
