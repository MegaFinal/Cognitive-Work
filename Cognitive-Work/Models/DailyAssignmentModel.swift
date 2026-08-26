//
//  DailyAssignmentModel.swift
//  Cognitive-Work
//
//  Created by anshu Li on 18/08/26.
//

import Foundation
import CloudKit

struct DailyAssignmentModel : CloudKitSyncable{
    static let recordType: String = "DailyAssignmentModel"
    
    var recordID: CKRecord.ID?
    var day: Date
    var isCompleted: Bool
    var user: CKRecord.Reference?
    var chore: CKRecord.Reference?

    init(day: Date, isCompleted: Bool = false, user: CKRecord.Reference? = nil, chore: CKRecord.Reference? = nil) {
        self.day = Calendar.current.startOfDay(for: day)
        self.isCompleted = isCompleted
        self.user = user
        self.chore = chore
    }
    
    init?(record: CKRecord) {
        guard
            let isCompleted = record["isCompleted"] as? Bool,
            let day = record["day"] as? Date
        else {
            return nil
        }

        self.recordID = record.recordID
        self.isCompleted = isCompleted
        self.day = day
        self.user = record["user"] as? CKRecord.Reference
        self.chore = record["chore"] as? CKRecord.Reference
    }
    
    func populate(record: CKRecord) {
        record["isCompleted"] = isCompleted
        record["day"] = day
        if let user {
            record["user"] = user
        }
        if let chore {
            record["chore"] = chore
        }
    }
}
