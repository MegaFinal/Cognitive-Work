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
 
    var name: String
    var description: String
    var dueDate: Date?
    var frequency: Recurrence
    var duration: TimeInterval
    var isPublic: Bool
    var isLate: Bool = false
    var weight: Int = 0
    var priorityTag: PriorityTag
    var image: Data?
    var checkList: [CKRecord.Reference]?
    var currentResponsible: CKRecord.Reference?
    var allResponsibleUsers: [CKRecord.Reference]?
    var room: CKRecord.Reference?
 
    init?(record: CKRecord) {
        guard
            let name = record["choreName"] as? String,
            let description = record["description"] as? String,
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
        self.name = name
        self.description = description
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
    
    init(
        name: String,
        description: String,
        dueDate: Date? = nil,
        frequency: Recurrence,
        duration: TimeInterval,
        isPublic: Bool,
        isLate: Bool = false,
        weight: Int = 0,
        priorityTag: PriorityTag,
        image: Data? = nil,
        checkList: [CKRecord.Reference]? = nil,
        currentResponsible: CKRecord.Reference? = nil,
        allResponsibleUsers: [CKRecord.Reference]? = nil,
        room: CKRecord.Reference? = nil
    ) {
        self.recordID = nil
        self.name = name
        self.description = description
        self.dueDate = dueDate
        self.frequency = frequency
        self.duration = duration
        self.isPublic = isPublic
        self.isLate = isLate
        self.weight = weight
        self.priorityTag = priorityTag
        self.image = image
        self.checkList = checkList
        self.currentResponsible = currentResponsible
        self.allResponsibleUsers = allResponsibleUsers
        self.room = room
    }
    
    func populate(record: CKRecord) {
        record["choreName"] = name
        record["description"] = description
        record["dueDate"] = dueDate
        record["frequency"] = frequency.rawValue
        record["duration"] = duration
        record["isPublic"] = isPublic
        record["isLate"] = isLate
        record["weight"] = weight
        record["priorityTag"] = priorityTag.rawValue
        record["image"] = image
        if let checkList = checkList {
            record["checkList"] = checkList
        }
        record["currentResponsible"] = currentResponsible
        if let allResponsibleUsers = allResponsibleUsers {
            record["allResponsibleUsers"] = allResponsibleUsers
        }
        record["room"] = room
    }
}
