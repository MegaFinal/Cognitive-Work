//
//  RecurrentAssignmentModel.swift
//  Cognitive-Work
//
//  Created by anshu Li on 18/08/26.
//

import Foundation
import CloudKit

struct RecurrentAssignmentModel : CloudKitSyncable{
    static let recordType: String = "DailyAssignmentModel"
    
    var recordID: CKRecord.ID?
    var day: Date
    var isCompleted: Bool
    
    var userReference: CKRecord.Reference?
    var choreReference: CKRecord.Reference?
    
    var user: UserModel? {
        get async {
            if let userReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [userReference])?.first
            }
            return nil
        }
    }

    var chore: ChoreModel? {
        get async {
            if let choreReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: ChoreModel.self, recordReferences: [choreReference])?.first
            }
            return nil
        }
    }

    init(day: Date, isCompleted: Bool = false, user: CKRecord.Reference? = nil, chore: CKRecord.Reference? = nil) {
        self.day = Calendar.current.startOfDay(for: day)
        self.isCompleted = isCompleted
        self.userReference = user
        self.choreReference = chore
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
        self.userReference = record["user"] as? CKRecord.Reference
        self.choreReference = record["chore"] as? CKRecord.Reference
    }
    
    func populate(record: CKRecord) {
        record["isCompleted"] = isCompleted
        record["day"] = day
        if let userReference {
            record["user"] = userReference
        }
        if let choreReference {
            record["chore"] = choreReference
        }
    }
}
