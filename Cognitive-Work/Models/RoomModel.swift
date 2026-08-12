//
//  RoomModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation

class RoomModel {
    private var id: UUID = UUID()
    private var roomName: String
    private var relatedChores: [ChoreModel]
    private var house: House
    private var roomColor: RoomColor
    
    init(id: UUID, roomName: String, relatedChores: [ChoreModel], house: House, roomColor: RoomColor) {
        self.id = id
        self.roomName = roomName
        self.relatedChores = relatedChores
        self.house = house
        self.roomColor = roomColor
    }
}
