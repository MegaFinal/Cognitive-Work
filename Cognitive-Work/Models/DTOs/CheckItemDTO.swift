//
//  CheckItemDTO.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import Foundation

struct CheckItemDTO: Identifiable {
    let id = UUID()
    var name: String
    var isDone: Bool
}
