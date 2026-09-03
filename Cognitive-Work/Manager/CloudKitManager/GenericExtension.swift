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
        id: CKRecord.ID? = nil,
        zoneID: CKRecordZone.ID? = nil,
        parent: CKRecord.Reference? = nil
    ) async -> T? {
        await createZoneIfNeeded()
        let zone = zoneID ?? houseZoneID
        let recordID = id ?? CKRecord.ID(recordName: UUID().uuidString, zoneID: zone)

        let record = CKRecord(
            recordType: T.recordType,
            recordID: recordID
        )

        item.populate(record: record)
        if let parent {
            record.parent = parent
        }

        let database = zone.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            _ = try await database.save(record)
            var saved = item
            saved.recordID = recordID
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
    func fetchPrivate<T: CloudKitSyncable>(
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
    func fetchShared<T: CloudKitSyncable>(
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

    /// Deletes several records in a single atomic batch.
    ///
    /// > Warning: Batching a parent together with its children does **not** make the parent
    /// > deletable. CloudKit checks each delete against the records currently on the server,
    /// > not against the state the batch would leave behind, so a parent in the same batch as
    /// > its children is still rejected with "Record delete would violate validating reference".
    /// > Only pass records that are safe to remove at the same moment — see
    /// > ``deleteChildren(of:includingSelf:)``, which calls this once per hierarchy level.
    ///
    /// - Parameters:
    ///   - recordIDs: Every record to delete. Does nothing and returns `true` when empty.
    ///   - zoneID: Zone the records live in, used to pick the private or shared database.
    /// - Returns: `true` on success, otherwise `false` with ``errorMessage`` set.
    @discardableResult
    func delete(recordIDs: [CKRecord.ID], zoneID: CKRecordZone.ID) async -> Bool {
        guard !recordIDs.isEmpty else { return true }

        let database = zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            _ = try await database.modifyRecords(saving: [], deleting: recordIDs)
            return true
        } catch {
            errorMessage = "Failed to delete records: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Hierarchy Delete

    /// Deletes every record that hangs off `recordID` through CloudKit's `parent` hierarchy.
    ///
    /// Works at any depth and without knowing the record types involved: a house's rooms, those
    /// rooms' chores, and those chores' checklist items all go in one call.
    ///
    /// Deletion runs from the deepest level upwards, one operation per level. CloudKit treats
    /// `CKRecord/parent` as a *validating* reference: a record that is somebody's parent cannot
    /// be deleted while that child still exists on the server — and putting both in the same
    /// batch does not help, because each delete is checked against the server's current state.
    /// So the leaves have to actually be gone before their parent is attempted.
    ///
    /// - Parameters:
    ///   - recordID: The parent whose descendants should be removed.
    ///   - includingSelf: Pass `true` to delete `recordID` itself once its subtree is empty.
    /// - Returns: `true` on success, otherwise `false` with ``errorMessage`` set.
    ///
    /// > Important: Each level is one atomic batch, so a single level is limited to roughly 400
    /// > records — the CloudKit ceiling for one modify operation.
    @discardableResult
    func deleteChildren(of recordID: CKRecord.ID, includingSelf: Bool = false) async -> Bool {
        guard let levels = await fetchDescendantLevels(of: recordID) else { return false }

        // Deepest level first: a parent is only deletable once its children are actually gone.
        for level in levels.reversed() {
            guard await delete(recordIDs: level, zoneID: recordID.zoneID) else {
                return false
            }
        }

        guard includingSelf else { return true }

        return await delete(recordIDs: [recordID], zoneID: recordID.zoneID)
    }

    /// Deletes every descendant of a record, and optionally the record itself.
    ///
    /// See ``deleteChildren(of:includingSelf:)-(CKRecord.ID,_)``.
    @discardableResult
    func deleteChildren(of record: CKRecord, includingSelf: Bool = false) async -> Bool {
        await deleteChildren(of: record.recordID, includingSelf: includingSelf)
    }

    /// Finds every descendant of a record by rebuilding its zone's `parent` hierarchy locally.
    ///
    /// CloudKit has no "fetch my children" query — `CKQuery` needs one concrete record type per
    /// query, and children can be of any type — so this reads the zone once and walks the tree
    /// in memory instead.
    ///
    /// - Parameter recordID: The root whose descendants should be found.
    /// - Returns: One entry per level — index 0 holds the direct children, index 1 their own
    ///   children, and so on — or `nil` when the zone scan fails. Deleting has to walk this
    ///   back to front, see ``deleteChildren(of:includingSelf:)``.
    func fetchDescendantLevels(of recordID: CKRecord.ID) async -> [[CKRecord.ID]]? {
        let zoneID = recordID.zoneID
        let database = zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        var childrenByParent: [CKRecord.ID: [CKRecord.ID]] = [:]
        var token: CKServerChangeToken?

        repeat {
            do {
                let changes = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: token
                )

                for (id, result) in changes.modificationResultsByID {
                    guard
                        let record = try? result.get().record,
                        let parentID = record.parent?.recordID
                    else {
                        continue
                    }

                    childrenByParent[parentID, default: []].append(id)
                }

                token = changes.moreComing ? changes.changeToken : nil
            } catch {
                errorMessage = "Failed to scan zone \(zoneID.zoneName): \(error.localizedDescription)"
                return nil
            }
        } while token != nil

        var levels: [[CKRecord.ID]] = []
        var visited: Set<CKRecord.ID> = [recordID]
        var current = childrenByParent[recordID] ?? []

        while !current.isEmpty {
            let level = current.filter { visited.insert($0).inserted }
            guard !level.isEmpty else { break }

            levels.append(level)
            current = level.flatMap { childrenByParent[$0] ?? [] }
        }

        return levels
    }

    /// Lists every record in the zone that still points at `recordID`, and through which field.
    ///
    /// Diagnostic for "Record delete would violate validating reference": CloudKit names the
    /// blocking record's ID but not its type, nor which field holds the reference. Feed it the
    /// ID that refused to delete and print the result to find out what is holding it.
    ///
    /// - Parameter recordID: The record that CloudKit refuses to delete.
    /// - Returns: One line per reference found, or `nil` when the zone scan fails.
    func blockingReferences(to recordID: CKRecord.ID) async -> [String]? {
        let zoneID = recordID.zoneID
        let database = zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        var findings: [String] = []
        var token: CKServerChangeToken?

        repeat {
            do {
                let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)

                for (id, result) in changes.modificationResultsByID {
                    guard let record = try? result.get().record, id != recordID else { continue }

                    let origin = "\(record.recordType)/\(id.recordName)"

                    if record.parent?.recordID == recordID {
                        findings.append("\(origin) — parent")
                    }

                    for key in record.allKeys() {
                        switch record[key] {
                        case let reference as CKRecord.Reference where reference.recordID == recordID:
                            findings.append("\(origin) — field '\(key)' (\(describe(reference.action)))")

                        case let references as [CKRecord.Reference]:
                            for reference in references where reference.recordID == recordID {
                                findings.append("\(origin) — field '\(key)' (\(describe(reference.action)))")
                            }

                        default:
                            continue
                        }
                    }
                }

                token = changes.moreComing ? changes.changeToken : nil
            } catch {
                errorMessage = "Failed to scan zone \(zoneID.zoneName): \(error.localizedDescription)"
                return nil
            }
        } while token != nil

        return findings
    }

    private func describe(_ action: CKRecord.ReferenceAction) -> String {
        switch action {
        case .none: return "action: none"
        case .deleteSelf: return "action: deleteSelf"
        default: return "action: validate/unknown(\(action.rawValue))"
        }
    }

    func isOwner<T: CloudKitSyncable>(_ type: T.Type, recordID: CKRecord.ID) -> Bool {
        return recordID.zoneID.ownerName == CKCurrentUserDefaultName ? true : false
    }
}
