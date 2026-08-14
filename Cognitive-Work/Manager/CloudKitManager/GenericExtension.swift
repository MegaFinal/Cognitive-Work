//
//  GenericExtension.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 13/08/26.
//

import CloudKit

extension CloudKitManager {

   /// Creates a new record for any `CloudKitSyncable` model.
   ///
   /// - Parameters:
   ///   - item: The model to persist.
   ///   - zoneID: Zone to save into. Defaults to the current user's
   ///     private house zone. Pass a shared zone's ID (e.g.
   ///     `room.recordID.zoneID`) to create the record directly inside
   ///     a house you don't own — same as the old `createChore` did.
   ///   - parent: Optional parent reference for nested records
   ///     (e.g. a chore whose parent is its room).
   /// - Returns: A copy of `item` with `recordID` set, or `nil` on failure.
   @discardableResult
   func  create<T: CloudKitSyncable>(
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

   /// Fetches every record of `type` visible to the current user:
   /// owned records first, then everything in shared zones.
   func fetchAll<T: CloudKitSyncable>(
       _ type: T.Type,
       predicate: NSPredicate = NSPredicate(value: true)
   ) async -> [T] {
       async let owned = fetchPrivate(type, predicate: predicate)
       async let shared = fetchShared(type, predicate: predicate)
       let (ownedItems, sharedItems) = await (owned, shared)
       return ownedItems + sharedItems
   }

   /// Fetches the first available record of `type`: owned first,
   /// falling back to shared. Mirrors the old `fetchHouse`/`fetchChores`.
   func fetchFirst<T: CloudKitSyncable>(_ type: T.Type) async throws -> T {
       if let first = await fetchPrivate(type, predicate: NSPredicate(value: true)).first {
           return first
       }

       if let first = await fetchShared(type, predicate: NSPredicate(value: true)).first {
           return first
       }

       throw CloudKitErrors.notFound(T.recordType)
   }

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

   /// Re-saves every field of an existing model.
   ///
   /// Fetches the current `CKRecord` first (so its change tag and any
   /// system fields aren't clobbered), overwrites it with `item`'s
   /// current values, then saves. Unlike the old per-type functions,
   /// this always writes the full model rather than only changed keys —
   /// see the note at the bottom of this file if you need true partial
   /// updates for a specific type.
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
}
