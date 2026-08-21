//
//  AvailableTimeModel.swift
//  Cognitive-Work
//
//  Created by anshu Li on 18/08/26.
//

import Foundation
import CloudKit

struct AvailableTimeModel: CloudKitSyncable {
    static let recordType: String = "AvailableTimeModel"
    
    var recordID: CKRecord.ID?
    var capacityMinutes: Int
    var day: Date
    var user: CKRecord.Reference?
    
    init(capacityMinutes: Int, day: Date, user: CKRecord.Reference? = nil) {
        self.capacityMinutes = capacityMinutes
        self.day = Calendar.current.startOfDay(for: day)
        self.user = user
    }
    
    init?(record: CKRecord) {
        guard
            let capacityMinutes = record["capacityMinutes"] as? Int,
            let day = record["day"] as? Date
        else {
            return nil
        }

        self.recordID = record.recordID
        self.capacityMinutes = capacityMinutes
        self.day = day
        self.user = record["user"] as? CKRecord.Reference
    }
    
    func populate(record: CKRecord) {
        record["capacityMinutes"] = capacityMinutes
        record["day"] = day
        if let user {
            record["user"] = user
        }
    }
}
