//
//  TagModel.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 27/08/26.
//

import Foundation
import CloudKit
import SwiftUI
struct TagModel: CloudKitSyncable {
    //TODO: implement the class diagram
    static var recordType: String = "TagModel"
    
    var recordID: CKRecord.ID?
    
    var name: String
    var color: Color
    
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let colorHex = record["color"] as? String
        else {
            return nil
        }
        
        self.name = name
        self.color = Color(hex: colorHex) ?? .gray
    }
    
    init(name: String, color: Color) {
        self.name = name
        self.color = color
    }
    
    func populate(record: CKRecord) {
        record["name"] = name
        record["color"] = color.toHex()
    }
}

