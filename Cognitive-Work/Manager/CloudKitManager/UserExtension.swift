//
//  HouseExtencion.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 11/08/26.
//

import CloudKit

// MARK: - User extension (CRUD)
extension CloudKitManager {
    
    func createUser(title: String, dueDate: Date?, priority: Int = 0, house: CKRecord) async -> CKRecord? {
        let zoneID = house.recordID.zoneID
        let userID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let todo = CKRecord(recordType: "ToDo", recordID: userID)
        todo["title"]    = title
        todo["dueDate"]  = dueDate
        todo["priority"] = priority
        todo["isDone"]   = false
        todo["household"] = CKRecord.Reference(record: house, action: .deleteSelf) // apaga o todo se a casa for apagada
        todo.parent = CKRecord.Reference(record: house, action: .none) //gera relacionamento de pai
        do {
            let db = zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            let saved = try await db.save(todo)
            return saved
        } catch {
            errorMessage = "Fail to creatUser: \(error.localizedDescription)"
            return nil
        }
    }
    
    func fetchUser(household: CKRecord) async -> [CKRecord] {
        let predicate = NSPredicate(format: "household == %@", CKRecord.Reference(record: household, action: .none))
        let query = CKQuery(recordType: "ToDo", predicate: predicate)
        
        do {
            let zoneID = household.recordID.zoneID
            let db = zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)
            return results.compactMap { try? $0.1.get() }
        } catch {
            errorMessage = "Fail to fetch user: \(error.localizedDescription)"
            return []
        }
    }
    
    func updateUser(toDo: CKRecord, title: String? = nil, dueDate: Date?? = nil, priority: Int? = nil, isDone: Bool? = nil) async -> Bool {
        if let title = title       { toDo["title"] = title }
        if let dueDate = dueDate   { toDo["dueDate"] = dueDate }
        if let priority = priority { toDo["priority"] = priority }
        if let isDone = isDone     { toDo["isDone"] = isDone }
        
        do {
            let db = toDo.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            _ = try await db.save(toDo)
            return true
        } catch {
            errorMessage = "Fail to update user: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteUser(_ user: CKRecord) async -> Bool {
        do {
            let db = user.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            try await db.deleteRecord(withID: user.recordID)
            return true
        } catch {
            errorMessage = "Fail to delete user: \(error.localizedDescription)"
            return false
        }
    }
}
