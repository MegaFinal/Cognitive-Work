//
//  GenericExtension.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 13/08/26.
//

import CloudKit

/// Generic CRUD operations shared by every ``CloudKitSyncable`` model.
///
/// Each method picks the private or shared database automatically from the owner of the
/// record's zone. Failures return `nil`, `false`, or an empty array and set
/// ``CloudKitManager/errorMessage``.
extension CloudKitManager {

    // MARK: - Create

    /// Creates a new record for any `CloudKitSyncable` model.
    ///
    /// - Parameters:
    ///   - item: The model to persist.
    ///   - zoneID: Zone to save into. Defaults to the current user's private house zone. Pass a
    ///     shared zone's ID (e.g. `room.recordID.zoneID`) to create the record directly inside a
    ///     house you don't own.
    ///   - parent: Optional parent reference for nested records (e.g. a chore whose parent is
    ///     its room).
    /// - Returns: A copy of `item` with `recordID` set, or `nil` on failure.
    @discardableResult
    func create<T: CloudKitSyncable>(
        _ item: T,
        zoneID: CKRecordZone.ID? = nil,
        parent: CKRecord.Reference? = nil
    ) async -> T? {
        await createZoneIfNeeded()
        let zone = zoneID ?? houseZoneID
        let id = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone)
        let record = CKRecord(recordType: T.recordType, recordID: id)

        item.populate(record: record)
        if let parent {
            record.parent = parent
        }

        let database = zone.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            _ = try await database.save(record)
            var saved = item
            saved.recordID = id
            return saved
        } catch {
            errorMessage = "Failed to create \(T.recordType): \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Fetch

    /// Fetches every record of `type` visible to the current user: private records first, then
    /// everything in shared zones.
    ///
    /// - Parameters:
    ///   - type: The model type to fetch.
    ///   - predicate: Filter applied to the query. Defaults to matching every record.
    /// - Returns: Owned items followed by shared items. Empty when nothing matches or the query
    ///   fails.
    func fetchAll<T: CloudKitSyncable>(
        _ type: T.Type,
        predicate: NSPredicate = NSPredicate(value: true)
    ) async -> [T] {
        async let owned = fetchPrivate(type, predicate: predicate)
        async let shared = fetchShared(type, predicate: predicate)
        let (ownedItems, sharedItems) = await (owned, shared)
        return ownedItems + sharedItems
    }

    /// Fetches the raw `CKRecord` backing a model, needed for sharing operations.
    ///
    /// - Parameter item: The model whose record should be fetched. Must already have a
    ///   `recordID`.
    /// - Returns: The matching `CKRecord`, or `nil` if the item was never saved or the fetch
    ///   fails.
    func fetchRecord<T: CloudKitSyncable>(for item: T) async -> CKRecord? {
        guard let recordID = item.recordID else {
            errorMessage = "Failed to fetch \(T.recordType): missing recordID"
            return nil
        }

        let database = recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            return try await database.record(for: recordID)
        } catch {
            errorMessage = "Failed to fetch \(T.recordType): \(error.localizedDescription)"
            return nil
        }
    }
    
    func fetchRecordsByRecordReference<T: CloudKitSyncable>(for type: T.Type,recordReferences: [CKRecord.Reference]) async -> [T]? {
        var records: [CKRecord]? = []
        for recordReference in recordReferences {
            let database = recordReference.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
            do {
                let fetchedRecord = try await database.record(for: recordReference.recordID)
                records?.append(fetchedRecord)
            } catch {
                errorMessage = "Failed to fetch \(recordReference.recordID.recordName): \(error.localizedDescription)"
                return nil
            }
        }
        return records?.compactMap { T.init(record: $0) }
    }

    /// Fetches the first available record of `type`, searching private records before shared
    /// ones.
    ///
    /// - Parameter type: The model type to fetch.
    /// - Returns: The first matching model.
    /// - Throws: ``CloudKitErrors/notFound(_:)`` when no record of that type exists.
    func fetchFirst<T: CloudKitSyncable>(_ type: T.Type) async throws -> T {
        if let first = await fetchPrivate(type, predicate: NSPredicate(value: true)).first {
            return first
        }

        if let first = await fetchShared(type, predicate: NSPredicate(value: true)).first {
            return first
        }

        throw CloudKitErrors.notFound(T.recordType)
    }

    /// Queries the current user's own house zone.
    private func fetchPrivate<T: CloudKitSyncable>(
        _ type: T.Type,
        predicate: NSPredicate
    ) async -> [T] {
        let query = CKQuery(recordType: T.recordType, predicate: predicate)

        do {
            let (results, _) = try await privateDB.records(matching: query, inZoneWith: houseZoneID)
            return results.compactMap { try? $0.1.get() }.compactMap(T.init(record:))
        } catch {
            errorMessage = "Failed to fetch \(T.recordType): \(error.localizedDescription)"
            return []
        }
    }

    /// Queries every zone shared with the current user and merges the results.
    private func fetchShared<T: CloudKitSyncable>(
        _ type: T.Type,
        predicate: NSPredicate
    ) async -> [T] {
        do {
            let zones = try await sharedDB.allRecordZones()
            var items: [T] = []

            for zone in zones {
                let query = CKQuery(recordType: T.recordType, predicate: predicate)
                let (results, _) = try await sharedDB.records(matching: query, inZoneWith: zone.zoneID)
                items.append(contentsOf: results.compactMap { try? $0.1.get() }.compactMap(T.init(record:)))
            }

            return items
        } catch {
            errorMessage = "Failed to fetch shared \(T.recordType): \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Update & Delete

    /// Re-saves every field of an existing model.
    ///
    /// Fetches the current `CKRecord` first, overwrites it with `item`'s current values, then
    /// saves.
    ///
    /// - Parameter item: The model to update. Must already have a `recordID`.
    /// - Returns: `true` on success, otherwise `false`.
    @discardableResult
    func update<T: CloudKitSyncable>(_ item: T) async -> Bool {
        guard let recordID = item.recordID else {
            errorMessage = "Failed to update \(T.recordType): missing recordID"
            return false
        }

        let database = recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            let record = try await database.record(for: recordID)
            item.populate(record: record)
            _ = try await database.save(record)
            return true
        } catch {
            errorMessage = "Failed to update \(T.recordType): \(error.localizedDescription)"
            return false
        }
    }
    
    func update(record: CKRecord) async -> Bool {
        let database = record.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            _ = try await database.save(record)
            return true
        } catch {
            errorMessage = "Failed to update \(record.recordType): \(error.localizedDescription)"
            return false
        }
    }

    /// Deletes the record backing a model.
    ///
    /// - Parameter item: The model to delete. Must already have a `recordID`.
    /// - Returns: `true` on success, otherwise `false`.
    ///
    /// > Important: Child records are not removed unless CloudKit's parent hierarchy cascades
    /// > the deletion.
    @discardableResult
    func delete<T: CloudKitSyncable>(_ item: T) async -> Bool {
        guard let recordID = item.recordID else {
            errorMessage = "Failed to delete \(T.recordType): missing recordID"
            return false
        }

        let database = recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            _ = try await database.deleteRecord(withID: recordID)
            return true
        } catch {
            errorMessage = "Failed to delete \(T.recordType): \(error.localizedDescription)"
            return false
        }
    }
    
    @discardableResult
    func delete<T: CloudKitSyncable>(_ type: T.Type, recordID: CKRecord.ID) async -> Bool {
        let database = recordID.zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            _ = try await database.deleteRecord(withID: recordID)
            return true
        } catch {
            errorMessage = "Failed to delete \(T.recordType): \(error.localizedDescription)"
            return false
        }
    }
    
    func isOwner<T: CloudKitSyncable>(_ type: T.Type, recordID: CKRecord.ID) async -> Bool {
        return recordID.zoneID.ownerName == CKCurrentUserDefaultName ? true : false
    }
}
