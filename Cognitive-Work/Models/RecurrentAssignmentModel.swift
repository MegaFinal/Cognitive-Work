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
    
    var userReferences: [CKRecord.Reference]?
    var userThatHaveDoneReference: CKRecord.Reference?
    var choreReference: CKRecord.Reference?
    
    @ObservationIgnored
    private var isUpdating = false

    /// EventKit calendar item persistent identifier
    var calendarEventIdentifier: String?
    
    var users: [UserModel] {
        get async {
            if let userReferences, !userReferences.isEmpty {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(
                    for: UserModel.self,
                    recordReferences: userReferences
                ) ?? []
            }
            return []
        }
    }
    
    var userThatHaveDone: UserModel? {
        get async {
            if let userThatHaveDoneReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(
                    for: UserModel.self,
                    recordReferences: [userThatHaveDoneReference]
                )?.first
            }
            return nil
        }
    }

    var chore: ChoreModel? {
        get async {
            if let choreReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(
                    for: ChoreModel.self,
                    recordReferences: [choreReference]
                )?.first
            }
            return nil
        }
    }

    init(
        day: Date,
        isCompleted: Bool = false,
        users: [CKRecord.Reference]? = nil,
        chore: CKRecord.Reference? = nil,
        calendarEventIdentifier: String? = nil
    ) {
        self.day = Calendar.current.startOfDay(for: day)
        self.isCompleted = isCompleted
        self.userReferences = users
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
        self.userReferences = record["users"] as? [CKRecord.Reference]
        self.choreReference = record["chore"] as? CKRecord.Reference
        self.userThatHaveDoneReference = record["userThatHaveDone"] as? CKRecord.Reference
        self.calendarEventIdentifier = record["calendarEventIdentifier"] as? String
    }
    
    func populate(record: CKRecord) {
        record["isCompleted"] = isCompleted
        record["day"] = day
        record["users"] = userReferences ?? []
        record["chore"] = choreReference
        record["userThatHaveDone"] = userThatHaveDoneReference
        record["calendarEventIdentifier"] = calendarEventIdentifier
    }
    
    @MainActor
    @discardableResult
    func postpone(byDays days: Int) async -> Bool {
        let calendar = Calendar.current
        let previousDay = day
        
        guard let newDay = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: day)) else { return false }
        day = newDay
        
        guard await CloudKitManager.shared.update(self) else {
            day = previousDay
            return false
        }
        return true
    }
    
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
