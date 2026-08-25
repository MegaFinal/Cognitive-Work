//
//  DayOfWeekDTO.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//

import SwiftUI

@Observable
class DayOfWeekDTO {
    let name: String
    let nameAbbreviation: String
    var freeTime: FreeTimeEnum = .none
    
    init(name: String, nameAbbreviation: String) {
        self.name = name
        self.nameAbbreviation = nameAbbreviation
    }
}
