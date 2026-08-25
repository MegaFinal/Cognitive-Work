//
//  PriorityTagEnum.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import SwiftUI

enum PriorityTag: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var intValue: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    static func isLarger (lhs: PriorityTag, rhs: PriorityTag) -> Bool {
        lhs.intValue < rhs.intValue
    }
}
