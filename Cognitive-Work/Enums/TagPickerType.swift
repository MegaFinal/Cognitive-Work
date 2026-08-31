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
    case room
        
    /// Decodes a relevant identifier label given an overarching DTO reference constraints object point.
    func labelName(for chore: ChoreDTO, currentRoom: RoomModel?) -> String {
        switch self {
        case .priority:
            return chore.priorityTag.rawValue.capitalized
        case .frequency:
            return chore.frequency.rawValue.capitalized
        case .duration:
            let minutes = chore.duration / 60
            return ChoreDurationTier.from(minutes: minutes).displayText.capitalized
        case .room:
            return currentRoom?.name.capitalized ?? "Sem Cômodo"
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
            let minutes = chore.duration / 60
            return ChoreDurationTier.from(minutes: minutes).color
        case .room:
            return currentRoom?.color.uiColor ?? .gray
        }
    }
}
