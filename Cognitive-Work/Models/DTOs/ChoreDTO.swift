//
//  ChoreDTO.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 26/08/26.
//

import SwiftUI

@Observable
class ChoreDTO {
    let name: String
    let description: String
    let frequency: Recurrence
    let duration: Double
    let priorityTag: PriorityTag
    var isSelected: Bool = false
    
    init(name: String, description: String, frequency: Recurrence, duration: Double, priorityTag: PriorityTag){
        self.name = name
        self.description = description
        self.frequency = frequency
        self.duration = duration
        self.priorityTag = priorityTag
    }
}
