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
        self.calendarEventIdentifier = record["calendarEventIdentifier"] as? String
    }
    
    func populate(record: CKRecord) {
        record["isCompleted"] = isCompleted
        record["day"] = day
        record["user"] = userReference
        record["chore"] = choreReference
        record["calendarEventIdentifier"] = calendarEventIdentifier
    }
    
    @MainActor
    @discardableResult
    func toggleAndAssignPointsToTheUser() async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        defer { isUpdating = false }

        // 1. Muda a UI na hora
        let wasDone = isCompleted
        let previousReference = userThatHaveDoneReference
        isCompleted.toggle()

        // 2. Buscas em paralelo
        async let userFetch = CloudKitManager.shared.fetchMyHouseUser()
        async let choreFetch = chore

        guard let myUser = await userFetch,
              let myUserRecordID = myUser.recordID,
              let chore = await choreFetch
        else {
            rollback(to: wasDone, reference: previousReference)
            return false
        }

        if isCompleted {
            userThatHaveDoneReference = CKRecord.Reference(recordID: myUserRecordID, action: .none)
        } else {
            userThatHaveDoneReference = nil
        }

        let score = calculatePoints(for: chore)
        async let scoreUpdated = isCompleted
            ? myUser.addScore(value: score)
            : myUser.subtractScore(value: score)
        async let taskUpdated = CloudKitManager.shared.update(self)

        let (scoreOK, taskOK) = await (scoreUpdated, taskUpdated)

        
        if !taskOK {
            rollback(to: wasDone, reference: previousReference)
        }
        //TODO: remove print
        print(myUser.points)
        return scoreOK && taskOK
    }

    @MainActor
    private func rollback(to wasDone: Bool, reference: CKRecord.Reference?) {
        isCompleted = wasDone
        userThatHaveDoneReference = reference
    }

    private func calculatePoints(for chore: ChoreModel, now: Date = .now) -> Int {
        let base = chore.priorityTag.scoreValue
                 + chore.frequency.scoreValue
                 + TimeScore.getPoints(time: chore.duration)

        guard let dueDate = chore.dueDate else { return base }

        let calendar = Calendar.current
        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0

        guard daysUntilDue > 0 else { return base }
        return base >> daysUntilDue
    }
}
