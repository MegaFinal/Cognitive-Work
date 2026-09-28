//
//  RoomColorEnum.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import SwiftUI

/// Constrains standard logical mapping translating room properties explicitly to `SwiftUI.Color`.
enum RoomColor: String, CaseIterable, Identifiable {
    case purple = "purple"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    
    var id: String { self.rawValue }
    
    /// The palette color for this case (see the asset catalog's `Colors` group).
    var uiColor: Color {
        switch self {
        case .purple: return .chorePurple
        case .orange: return .choreOrange
        case .yellow: return .choreYellow
        case .green: return .choreGreen
        case .blue: return .choreBlue
        }
    }
    
    /// Decodes a color stored in CloudKit, including values from palettes that no longer exist.
    ///
    /// Rooms saved by older builds may hold `"red"`, `"white"` or `"pink"`. Failing on those made
    /// ``RoomModel/init(record:)`` return `nil`, which dropped the whole room — and every chore
    /// pointing at it rendered as an unknown (gray) room. Legacy values are now mapped to the
    /// closest current color 
    init?(storedValue: String?) {
        guard let storedValue else { return nil }
        
        if let current = RoomColor(rawValue: storedValue) {
            self = current
            return
        }
        
        switch storedValue {
        case "pink", "red": self = .purple
        case "white": self = .blue
        default: return nil
        }
    }
}
