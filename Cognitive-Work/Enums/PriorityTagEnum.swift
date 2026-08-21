//
//  PriorityTagEnum.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

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
    
    static func isLarger (lhs: PriorityTag, rhs: PriorityTag) -> Bool {
        lhs.intValue < rhs.intValue
    }
}
