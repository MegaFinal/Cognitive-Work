//
//  TagPickerType.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

/// Denotes logical behavior variations internally differentiating dynamic forms instances constraints.
enum TagPickerType {
    case priority
    case frequency
    case duration
        
    /// Decodes a relevant identifier label given an overarching DTO reference constraints object point.
    func labelName(for chore: ChoreDTO, currentRoom: RoomModel?) -> String {
        switch self {
        case .priority:
            return chore.priorityTag.displayName
        case .frequency:
            return chore.frequency.displayName
        case .duration:
            return ChoreDurationTier.from(minutes: chore.duration).displayText
        }
    }
    
    /// Text color of the tag: recurrence tags have their own, every other tag uses white.
    func labelTextColor(for chore: ChoreDTO) -> Color {
        switch self {
        case .frequency:
            return chore.frequency.textColor
        case .priority, .duration:
            return .white
        }
    }
    
    /// Identifies specific coloring schema contextualizing active selection behaviors.
    func labelColor(for chore: ChoreDTO, currentRoom: RoomModel?) -> Color {
        switch self {
        case .priority:
            return chore.priorityTag.color
        case .frequency:
            return chore.frequency.color
        case .duration:
            return ChoreDurationTier.from(minutes: chore.duration).color
        }
    }
}
