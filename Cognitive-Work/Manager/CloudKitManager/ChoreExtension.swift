//
//  ChoreExtention.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import Foundation
import CloudKit

// MARK: - House CRUD

extension CloudKitManager {

    /// Creates a house and its associated share in a single CloudKit operation.
    ///
    /// The house and share are saved atomically, meaning the operation
    /// succeeds only when both records can be saved.
    ///
    /// - Parameters:
    ///   - name: The display name of the house.
    ///   - description: A description of the house.
    /// - Returns: A tuple containing the created house and its share,
    ///   or `nil` if the operation fails.
    func createChore(
        choreName: String,
        description: String,
        dueDate: Date? = nil,
        frequency: Recurrence,
        duration: DateInterval,
        isPublic: Bool,
        priorityTag: PriorityTag,
        image: Data,
        checkList: [CKRecord.Reference],
        currentResponsible: CKRecord.Reference? = nil,
        allResponsibleUsers: [CKRecord.Reference],
        room: CKRecord.Reference
    ) async -> Bool {
        let id = CKRecord.ID(
            recordName: UUID().uuidString,
            zoneID: houseZoneID
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
        record["isLate"] = false
        record["weight"] = 0
        record["priorityTag"] = priorityTag.rawValue
        record["image"] = image
        record["checkList"] = checkList
        record["currentResponsible"] = currentResponsible
        record["allResponsibleUsers"] = allResponsibleUsers
        record["room"] = room
        record.parent = room
        
        do {
            let database = record.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

            _ = try await database.save(record)
            return true
        } catch {
            errorMessage = "Failed to update house: \(error.localizedDescription)"
            return false
        }
    }

    /// Fetches the first house available to the current user.
    ///
    /// Owned houses are checked before shared houses.
    ///
    /// - Returns: The first owned or shared house found.
    ///
    /// - Throws: `HouseError.notFound` when no house is available.
    func fetchChores() async throws -> CKRecord {
        let privateChores = await fetchPrivateChores()

        if let chore = privateChores.first {
            return chore
        }

        let sharedChores = await fetchSharedChores()

        if let chore = sharedChores.first {
            return chore
        }

        throw CloudKitErrors.choreNotFound
    }

    /// Fetches houses owned by the current user.
    ///
    /// - Returns: All houses stored in the current user's private database.
    private func fetchPrivateChores() async -> [CKRecord] {
        let query = CKQuery(
            recordType: "ChoreModel",
            predicate: NSPredicate(value: true)
        )

        do {
            let (results, _) = try await privateDB.records(
                matching: query,
                inZoneWith: houseZoneID
            )

            return results.compactMap {
                try? $0.1.get()
            }
        } catch {
            errorMessage = "Failed to fetch owned houses: \(error.localizedDescription)"
            return []
        }
    }

    /// Fetches houses shared with the current user.
    ///
    /// - Returns: All houses found in the user's shared database zones.
    private func fetchSharedChores() async -> [CKRecord] {
        do {
            let zones = try await sharedDB.allRecordZones()
            var chores: [CKRecord] = []

            for zone in zones {
                let query = CKQuery(
                    recordType: "ChoreModel",
                    predicate: NSPredicate(value: true)
                )

                let (results, _) = try await sharedDB.records(
                    matching: query,
                    inZoneWith: zone.zoneID
                )

                chores.append(
                    contentsOf: results.compactMap {
                        try? $0.1.get()
                    }
                )
            }

            return chores
        } catch {
            errorMessage = "Failed to fetch shared houses: \(error.localizedDescription)"
            return []
        }
    }

    /// Updates the specified attributes of a house.
    ///
    /// Only parameters with non-`nil` values are modified.
    ///
    /// - Parameters:
    ///   - house: The house record to update.
    ///   - name: The new house name, or `nil` to keep the current value.
    ///   - description: The new house description, or `nil` to keep the
    ///     current value.
    /// - Returns: `true` if the update succeeds; otherwise `false`.
    func updateHouseAttributes(
        chore: CKRecord,
        choreName: String? = nil,
        description: String? = nil,
        dueDate: Date? = nil,
        frequency: Recurrence? = nil,
        duration: DateInterval? = nil,
        isPublic: Bool? = nil,
        isLate: Bool? = nil,
        weight: Int? = nil,
        priorityTag: PriorityTag? = nil,
        image: Data? = nil,
        previousChore: [CKRecord.Reference]? = nil,
        checkList: [CKRecord.Reference]? = nil,
        currentResponsible: CKRecord.Reference? = nil,
        allResponsibleUsers: [CKRecord.Reference]? = nil,
        room: CKRecord.Reference? = nil
    ) async -> Bool {
        if let choreName {
            chore["choreName"] = choreName
        }

        if let description {
            chore["description"] = description
        }
        
        if let dueDate {
            chore["dueDate"] = dueDate
        }
        
        if let frequency {
            chore["frequency"] = frequency.rawValue
        }
        
        if let duration {
            chore["duration"] = duration.duration
        }
        
        if let isPublic {
            chore["isPublic"] = isPublic
        }
        
        if let isLate {
            chore["isLate"] = isLate
        }
        
        if let weight {
            chore["weight"] = weight
        }
        
        if let priorityTag {
            chore["priorityTag"] = priorityTag.rawValue
        }
        
        if let image {
            chore["image"] = image
        }
        
        if let previousChore {
            chore["previousChore"] = previousChore
        }
        
        if let checkList {
            chore["checkList"] = checkList
        }
        
        if let currentResponsible {
            chore["currentResponsible"] = currentResponsible
        }
        
        if let allResponsibleUsers {
            chore["allResponsibleUsers"] = allResponsibleUsers
        }
        
        if let room {
            chore["room"] = room
        }
        

        do {
            let database = chore.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            _ = try await database.save(chore)
            return true
        } catch {
            errorMessage = "Failed to update house: \(error.localizedDescription)"
            return false
        }
    }

    /// Deletes a house and its associated share.
    ///
    /// Deleting the root house record also removes the associated sharing
    /// relationship and revokes access for shared users.
    ///
    /// - Parameter house: The house record to delete.
    /// - Returns: `true` if the deletion succeeds; otherwise `false`.
    func deleteChore(_ chore: CKRecord) async -> Bool {
        do {
            let database = chore.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            _ = try await database.deleteRecord(withID: chore.recordID)
            return true
        } catch {
            errorMessage = "Failed to delete chore: \(error.localizedDescription)"
            return false
        }
    }
}


