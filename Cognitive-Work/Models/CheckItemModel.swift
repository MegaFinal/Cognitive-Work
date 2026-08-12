//
//  CheckItemModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation

class CheckItemModel {
    private var id: UUID = UUID()
    private var checkItemName: String
    private var isLate: Bool
    
    init(checkItemName: String, isLate: Bool) {
        self.checkItemName = checkItemName
        self.isLate = isLate
    }
}
