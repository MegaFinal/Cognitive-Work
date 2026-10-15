//
//  UserColorPalette.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//

import Foundation
import SwiftUI

enum UserColorPalette {
    private static let colors: [Color] = [.choreBlue, .choreGreen, .choreOrange, .chorePurple, .choreYellow]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}
