//
//  HardwareModel.swift
//  Cognitive-Work
//
//  Created by anshu Li on 02/09/26.
//

import Foundation
import CloudKit

struct HardwareHostNameModel: CloudKitSyncable {
    var id = UUID()
    
    var hostName: String
    
    static let recordType: String = "HardwareIpModel"
    
    var recordID: CKRecord.ID?
    
    init?(record: CKRecord) {
        guard
            let ip = record["ip"] as? String
        else {
            return nil
        }
        
        self.recordID = record.recordID
        self.hostName = ip
    }
    
    init(hostName: String) {
        self.hostName = hostName
    }
    
    func populate(record: CKRecord) {
        record["ip"] = hostName
    }
    
    
    
}
