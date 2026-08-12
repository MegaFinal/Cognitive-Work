//
//  ChoreModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

struct ChoreModel: CloudKitSyncable {
    static let recordType = "ChoreModel"
 
    var recordID: CKRecord.ID?
 
    var choreName: String
    var choreDescription: String
    var dueDate: Date?
    var frequency: Recurrence
    var duration: TimeInterval
    var isPublic: Bool
    var isLate: Bool = false
    var weight: Int = 0
    var priorityTag: PriorityTag
    var image: Data
    var checkList: [CKRecord.Reference]
    var currentResponsible: CKRecord.Reference?
    var allResponsibleUsers: [CKRecord.Reference]
    var room: CKRecord.Reference
 
    func populate(record: CKRecord) {
        record["choreName"] = choreName
        record["description"] = choreDescription
        record["dueDate"] = dueDate
        record["frequency"] = frequency.rawValue
        record["duration"] = duration
        record["isPublic"] = isPublic
        record["isLate"] = isLate
        record["weight"] = weight
        record["priorityTag"] = priorityTag.rawValue
        record["image"] = image
        record["checkList"] = checkList
        record["currentResponsible"] = currentResponsible
        record["allResponsibleUsers"] = allResponsibleUsers
        record["room"] = room
    }
 
    init?(record: CKRecord) {
        guard
            let choreName = record["choreName"] as? String,
            let choreDescription = record["description"] as? String,
            let frequencyRaw = record["frequency"] as? String,
            let frequency = Recurrence(rawValue: frequencyRaw),
            let duration = record["duration"] as? TimeInterval,
            let isPublic = record["isPublic"] as? Bool,
            let isLate = record["isLate"] as? Bool,
            let weight = record["weight"] as? Int,
            let priorityTagRaw = record["priorityTag"] as? String,
            let priorityTag = PriorityTag(rawValue: priorityTagRaw),
            let image = record["image"] as? Data,
            let checkList = record["checkList"] as? [CKRecord.Reference],
            let allResponsibleUsers = record["allResponsibleUsers"] as? [CKRecord.Reference],
            let room = record["room"] as? CKRecord.Reference
        else {
            return nil
        }
 
        self.recordID = record.recordID
        self.choreName = choreName
        self.choreDescription = choreDescription
        self.dueDate = record["dueDate"] as? Date
        self.frequency = frequency
        self.duration = duration
        self.isPublic = isPublic
        self.isLate = isLate
        self.weight = weight
        self.priorityTag = priorityTag
        self.image = image
        self.checkList = checkList
        self.currentResponsible = record["currentResponsible"] as? CKRecord.Reference
        self.allResponsibleUsers = allResponsibleUsers
        self.room = room
    }
}
