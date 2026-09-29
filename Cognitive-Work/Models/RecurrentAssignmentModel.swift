//
//  RecurrentAssignmentModel.swift
//  Cognitive-Work
//
//  Created by anshu Li on 18/08/26.
//

import Foundation
import CloudKit

@Observable
class RecurrentAssignmentModel: CloudKitSyncable {
    static let recordType: String = "DailyAssignmentModel"
    
    var recordID: CKRecord.ID?
    var day: Date
    var isCompleted: Bool
    
    var userReference: CKRecord.Reference?
    var userThatHaveDoneReference: CKRecord.Reference?
    
    var choreReference: CKRecord.Reference?
    
    @ObservationIgnored
    private var isUpdating = false

    /// EventKit calendar item persistent identifier
    var calendarEventIdentifier: String?
    
    var user: UserModel? {
        get async {
            if let userReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [userReference])?.first
            }
            return nil
        }
    }
    
    var userThatHaveDone: UserModel? {
        get async {
            if let userThatHaveDoneReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [userThatHaveDoneReference])?.first
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

    init(day: Date, isCompleted: Bool = false, user: CKRecord.Reference? = nil, chore: CKRecord.Reference? = nil, calendarEventIdentifier: String? = nil) {
        self.day = Calendar.current.startOfDay(for: day)
        self.isCompleted = isCompleted
        self.userReference = user
        self.choreReference = chore
        self.calendarEventIdentifier = calendarEventIdentifier
    }
    
    required init?(record: CKRecord) {
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
        self.userThatHaveDoneReference = record["userThatHaveDone"] as? CKRecord.Reference
        self.calendarEventIdentifier = record["calendarEventIdentifier"] as? String
    }
    
    func populate(record: CKRecord) {
        record["isCompleted"] = isCompleted
        record["day"] = day
        record["user"] = userReference
        record["chore"] = choreReference
        record["userThatHaveDone"] = userThatHaveDoneReference
        record["calendarEventIdentifier"] = calendarEventIdentifier
    }
    
    /// Flips ``isCompleted``, records who did it and persists the change.
    ///
    /// - Returns: `true` when CloudKit saved it. On failure the occurrence is left as it was.
    @MainActor
    @discardableResult
    func toggle() async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        defer { isUpdating = false }
        
        guard let myUserRecordID = await CloudKitManager.shared.currentHouseUser()?.recordID
        else { return false }
        
        let previousIsCompleted = isCompleted
        let previousDoer = userThatHaveDoneReference
        
        isCompleted.toggle()
        userThatHaveDoneReference = isCompleted
        ? CKRecord.Reference(recordID: myUserRecordID, action: .none)
        : nil
        
        guard await CloudKitManager.shared.update(self) else {
            isCompleted = previousIsCompleted
            userThatHaveDoneReference = previousDoer
            return false
        }
        return true
    }
}
