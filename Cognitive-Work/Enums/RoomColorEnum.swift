//
//  RoomColorEnum.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import SwiftUI

enum RoomColor: String {
    case red = "red"
    case blue = "blue"
    
    var uiColor: Color {
        switch self {
        case .red:
            return .red
        case .blue:
            return .blue
        }
    }
}
