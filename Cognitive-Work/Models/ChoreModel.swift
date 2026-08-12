//
//  ChoreModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

class ChoreModel {
    private(set) var id: CKRecord.ID
    private(set) var choreName: String
    private(set) var description: String
    private(set) var dueDate: Date?
    private(set) var frequency: Recurrence
    private(set) var duration: TimeInterval
    private(set) var isPublic: Bool
    private(set) var isLate: Bool = false
    private(set) var weight: Int = 0
    private(set) var priorityTag: PriorityTag
    private(set) var image: Data?
    private(set) var previousChore: [CKRecord.Reference] = []
    private(set) var checkList: [CKRecord.Reference]
    private(set) var currentResponsible: CKRecord.Reference?
    private(set) var allResponsibleUsers: [CKRecord.Reference]
    private(set) var room: CKRecord.Reference?
    
    init?(record: CKRecord) {
        guard record.recordType == "ChoreModel",
              let choreName = record["choreName"] as? String
        else {
            return nil
        }
        
        self.id = record.recordID
        self.choreName = choreName
        self.description = record["description"] as? String ?? ""
        self.dueDate = record["dueDate"] as? Date
        self.frequency = Recurrence(rawValue: record["frequency"] as? String ?? "daily") ?? .daily
        self.duration = record["duration"] as? Double ?? -1
        self.isPublic = record["isPublic"] as? Bool ?? false
        self.isLate = record["isLate"] as? Bool ?? false
        self.weight = record["weight"] as? Int ?? 0
        self.priorityTag = PriorityTag(rawValue: record["priorityTag"] as? String ?? "notUrgent") ?? .notUrgent
        self.image = record["image"] as? Data
        self.previousChore = record["previousChore"] as? [CKRecord.Reference] ?? []
        self.checkList = record["checkList"] as? [CKRecord.Reference] ?? []
        self.currentResponsible = record["currentResponsible"] as? CKRecord.Reference
        self.allResponsibleUsers = record["allResponsibleUsers"] as? [CKRecord.Reference] ?? []
        self.room = record["room"] as? CKRecord.Reference
    }
    
    static func newChoreRecord(
        choreName: String,
        description: String,
        dueDate: Date? = nil,
        frequency: Recurrence,
        duration: DateInterval,
        isPublic: Bool,
        isLate: Bool,
        weight: Int,
        priorityTag: PriorityTag,
        image: Data,
        previousChore: [CKRecord.Reference],
        checkList: [CKRecord.Reference],
        currentResponsible: CKRecord.Reference? = nil,
        allResponsibleUsers: [CKRecord.Reference],
        room: CKRecord.Reference
    ) async -> CKRecord? {
        let zoneID = CloudKitManager.shared.houseZoneID
        
        let id = CKRecord.ID(
            recordName: UUID().uuidString,
            zoneID: zoneID
        )
        
        let record = CKRecord(
            recordType: "ChoreModel",
            recordID: id
        )

        record["choreName"] = choreName
        record["description"] = description
        record["dueDate"] = dueDate
        record["frequency"] = frequency.rawValue
        record["duration"] = duration.duration
        record["isPublic"] = isPublic
        record["isLate"] = isLate
        record["weight"] = weight
        record["priorityTag"] = priorityTag.rawValue
        record["image"] = image
        record["previousChore"] = previousChore
        record["checkList"] = checkList
        record["currentResponsible"] = currentResponsible
        record["allResponsibleUsers"] = allResponsibleUsers
        record["room"] = room
        
        return record
    }
}

enum Recurrence: String {
    case daily = "daily"
    case weekly = "weekly"
    case fortnightly = "fortnightly"
    case montly = "montly"
}

enum PriorityTag: String {
    case urgent = "urgent"
    case notUrgent = "notUrgent"
}

enum RoomColor: String {
    case urgent = "urgent"
    case notUrgent = "notUrgent"
}

class CheckItem {
    private var id: UUID = UUID()
    private var checkItemName: String
    private var isLate: Bool
    
    init(checkItemName: String, isLate: Bool) {
        self.checkItemName = checkItemName
        self.isLate = isLate
    }
}

class Room {
    private var id: UUID = UUID()
    private var roomName: String
    private var relatedChores: [ChoreModel]
    private var house: House
    private var roomColor: RoomColor
    
}
