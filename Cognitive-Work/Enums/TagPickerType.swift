//
//  TagPickerType.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI
import CloudKit

enum TagPickerType {
    case priority
    case frequency
    case duration
    case room
        
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
