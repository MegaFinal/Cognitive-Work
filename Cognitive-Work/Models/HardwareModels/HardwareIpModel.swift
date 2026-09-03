//
//  HardwareModel.swift
//  Cognitive-Work
//
//  Created by anshu Li on 02/09/26.
//

import Foundation
import CloudKit

struct HardwareIpModel: CloudKitSyncable{
    var id = UUID()
    
    var ip: String
    
    static let recordType: String = "HardwareIpModel"
    
    var recordID: CKRecord.ID?
    
    init?(record: CKRecord) {
        guard
            let ip = record["ip"] as? String
        else {
            return nil
        }
        
        self.recordID = record.recordID
        self.ip = ip
    }
    
    init(ip: String) {
        self.ip = ip
    }
    
    func populate(record: CKRecord) {
        record["ip"] = ip
    }
    
    
    
}
