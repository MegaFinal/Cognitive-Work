//
//  TagModel.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 27/08/26.
//

import Foundation
import CloudKit

struct TagModel: CloudKitSyncable {
    //TODO: implement the class diagram
    static var recordType: String = "TagModel"
    
    var recordID: CKRecord.ID?
    
    func populate(record: CKRecord) {
        
    }
    
    init?(record: CKRecord) {
        
    }
}
