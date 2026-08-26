//
//  RoomDTO.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 26/08/26.
//

import SwiftUI

struct RoomDTO: Identifiable {
    let id = UUID()
    var name: String
    var symbol: String
    var isSelected: Bool = false
    var isAddButton: Bool = false
    var color: RoomColor = .blue
    var isExpanded: Bool = false
}
