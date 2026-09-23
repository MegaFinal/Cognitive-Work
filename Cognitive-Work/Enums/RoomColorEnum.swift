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
    case pink = "pink"
    
    var id: String { self.rawValue }

    /// Maps custom identifier constants safely to rendering layouts contexts.
    var uiColor: Color {
        switch self {
        case .purple: return .purple
        case .orange: return .choreOrange
        case .yellow: return .choreYellow
        case .green: return .choreGreen
        case .blue: return .choreBlue
        case .pink: return .chorePink
        }
    }

    /// The color icons and text should use when drawn directly over ``uiColor`` (chore cards,
    /// carousel cards, etc.), so they stay legible against it.
    ///
    /// Every case but ``white`` is saturated enough for white content on top; a white room
    /// needs black content instead, or its icon and labels render white-on-white and vanish.
    var contentColor: Color {
        self == .purple ? .black : .white
    }
}
