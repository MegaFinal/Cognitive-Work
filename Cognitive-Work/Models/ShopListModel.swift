//
//  ShopListModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/09/26.
//

import Foundation
import CloudKit

/// A named shopping list belonging to a house, holding a collection of ``ShopListItem`` entries.
@Observable
class ShopListModel: CloudKitSyncable, Identifiable {
    private let localID = UUID().uuidString

    var id: String {
        recordID?.recordName ?? localID
    }

    static var recordType: String = "ShopListModel"

    var recordID: CKRecord.ID?

    var name: String

    /// References to this list's ``ShopListItem`` entries.
    private var itemsReference: [CKRecord.Reference]?

    /// The house this list belongs to.
    var houseReference: CKRecord.Reference?

    /// This list's items, fetched from CloudKit.
    var items: [ShopListItem] {
        get async {
            guard let itemsReference, !itemsReference.isEmpty else { return [] }
            return await CloudKitManager.shared.fetchRecordsByRecordReference(for: ShopListItem.self, recordReferences: itemsReference) ?? []
        }
    }

    var house: HouseModel? {
        get async {
            if let houseReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: HouseModel.self, recordReferences: [houseReference])?.first
            }
            return nil
        }
    }

    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when `name` is missing.
    required init?(record: CKRecord) {
        guard let name = record["name"] as? String else {
            return nil
        }

        self.recordID = record.recordID
        self.name = name
        self.itemsReference = record["items"] as? [CKRecord.Reference]
        self.houseReference = record["house"] as? CKRecord.Reference
    }

    /// Creates a new, unsaved shopping list.
    ///
    /// - Parameters:
    ///   - name: Name shown to the user.
    ///   - items: Items already known to belong to this list.
    ///   - house: The owning house.
    init(
        name: String,
        items: [CKRecord.Reference]? = nil,
        house: CKRecord.Reference? = nil,
        recordID: CKRecord.ID? = nil
    ) {
        self.recordID = recordID
        self.name = name
        self.itemsReference = items
        self.houseReference = house
    }

    /// Writes this model's values into a CloudKit record.
    ///
    /// - Parameter record: The record to populate.
    func populate(record: CKRecord) {
        record["name"] = name
        if let itemsReference {
            record["items"] = itemsReference
        }
        if let houseReference {
            record["house"] = houseReference
        }
    }

    // MARK: - Items

    /// Saves `item` as a child of this list and appends it to ``itemsReference``.
    ///
    /// - Parameter item: The item to save (not yet saved — no `recordID` of its own).
    /// - Returns: The saved item, with its `recordID` set, or `nil` on failure.
    @discardableResult
    func addItem(_ item: ShopListItem) async -> ShopListItem? {
        guard let recordID else {
            CloudKitManager.shared.errorMessage = "Failed to add item: list missing recordID"
            return nil
        }

        let parentReference = CKRecord.Reference(recordID: recordID, action: .none)

        guard
            let created = await CloudKitManager.shared.create(item, zoneID: recordID.zoneID, parent: parentReference),
            let createdRecordID = created.recordID
        else {
            return nil
        }

        itemsReference = (itemsReference ?? []) + [CKRecord.Reference(recordID: createdRecordID, action: .none)]
        guard await CloudKitManager.shared.update(self) else { return nil }

        return created
    }

    /// Deletes `item` and removes it from ``itemsReference``.
    @discardableResult
    func removeItem(_ item: ShopListItem) async -> Bool {
        guard let itemRecordID = item.recordID else { return false }
        guard await CloudKitManager.shared.delete(item) else { return false }

        itemsReference = (itemsReference ?? []).filter { $0.recordID != itemRecordID }
        return await CloudKitManager.shared.update(self)
    }
}
