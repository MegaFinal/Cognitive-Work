//
//  ScheduleContext.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 20/08/26.
//

import CloudKit

// MARK: - Modelos de apoio

struct ScheduleContext {
    let userAvailableTimeMap: [CKRecord.ID: [AvailableTimeModel]]
    let choreResponsibleMap: [CKRecord.ID: UserModel]
    let userTotalCapacity: [CKRecord.ID: Int]
    let minimumCapacity: Int

    func initialRemainingCapacity() -> [CKRecord.ID: Double] {
        var map: [CKRecord.ID: Double] = [:]
        for (_, slots) in userAvailableTimeMap {
            for slot in slots {
                guard let id = slot.recordID else { continue }
                map[id] = Double(slot.capacityMinutes)
            }
        }
        return map
    }

    func initialUserAssignedMinutes(users: [UserModel]) -> [CKRecord.ID: Int] {
        Dictionary(uniqueKeysWithValues: users.compactMap { user -> (CKRecord.ID, Int)? in
            guard let id = user.recordID else { return nil }
            return (id, 0)
        })
    }
}

struct ScheduleResult {
    var chore: ChoreModel
    var newAssignments: [DailyAssignmentModel] = []
}

