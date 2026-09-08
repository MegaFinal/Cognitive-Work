//
//  RoomColorEnum.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import SwiftUI

/// Constrains standard logical mapping translating room properties explicitly to `SwiftUI.Color`.
enum RoomColor: String, CaseIterable, Identifiable {
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    
    var id: String { self.rawValue }

    /// Maps custom identifier constants safely to rendering layouts contexts.
    var uiColor: Color {
        switch self {
        case .red: return .red
        case .orange: return .choreOrange
        case .yellow: return .choreYellow
        case .green: return .choreGreen
        case .blue: return .choreBlue
        case .purple: return .chorePink
        }
    }
}
