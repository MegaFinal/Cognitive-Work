//
//  ShopListItem.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 27/08/26.
//

import Foundation
import CloudKit

/// A single entry belonging to a ``ShopListModel``
@Observable
class ShopListItem: CloudKitSyncable, Identifiable {
    private let localID = UUID().uuidString

    var id: String {
        recordID?.recordName ?? localID
    }

    static var recordType: String = "ShopListItem"

    var recordID: CKRecord.ID?

    var name: String

    var value: Double?

    var quantity: Int

    /// The unit ``quantity`` is expressed in (grams, liters, individual pieces, …).
    var unitMeasurement: UnitMeasurement

    /// Whether the item has already been purchased.
    var isBought: Bool

    /// The aisle the item belongs to; the list groups by it.
    var category: ShopItemCategory

    /// When the item was added.
    private(set) var createdAt: Date

    /// The list this item belongs to (the record's `parent`).
    var listRecordID: CKRecord.ID?

    /// The user who actually bought the item
    private var buyerUserReference: CKRecord.Reference?

    /// Other users who will use/share this item, e.g. to split its cost.
    var relatedUsersReference: [CKRecord.Reference]?

    /// The user who added this item to the list
    private var addedByUserReference: CKRecord.Reference?

    private var tagsReference: [CKRecord.Reference]?

    /// Who bought the item, as a record id (for resolving against an already-fetched pool).
    var buyerRecordID: CKRecord.ID? { buyerUserReference?.recordID }

    /// Who added the item, as a record id.
    var addedByRecordID: CKRecord.ID? { addedByUserReference?.recordID }

    var buyerUser: UserModel? {
        get async {
            if let buyerUserReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [buyerUserReference])?.first
            }
            return nil
        }
    }

    /// Users who will use/share this item
    var relatedUsers: [UserModel] {
        get async {
            if let relatedUsersReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: relatedUsersReference) ?? []
            }
            return []
        }
    }

    /// Resolves ``relatedUsers`` against an already-fetched pool of users (e.g.
    /// ``ShopListViewModel/houseUsers``) instead of making a network request.
    ///
    /// - Parameter pool: Users to search, typically every house member.
    /// - Returns: The subset of `pool` referenced by this item.
    func relatedUsers(in pool: [UserModel]) -> [UserModel] {
        guard let relatedUsersReference else { return [] }
        let ids = Set(relatedUsersReference.map { $0.recordID })
        return pool.filter { user in
            guard let recordID = user.recordID else { return false }
            return ids.contains(recordID)
        }
    }

    /// Who added this item to the list. See ``addedByUserReference``.
    var addedByUser: UserModel? {
        get async {
            if let addedByUserReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [addedByUserReference])?.first
            }
            return nil
        }
    }

    var tags: [TagModel] {
        get async {
            if let tagsReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: TagModel.self, recordReferences: tagsReference) ?? []
            }
            return []
        }
    }

    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when a required field is missing or has the wrong type, or when the
    ///   stored unit/priority isn't a known case.
    required init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let quantity = record["quantity"] as? Int,
            let unitMeasurement = record["unitMeasurement"] as? String,
            let isBought = record["isBought"] as? Bool
        else {
            return nil
        }

        self.recordID = record.recordID

        self.name = name
        self.value = record["value"] as? Double
        self.quantity = quantity
        self.unitMeasurement = UnitMeasurement(rawValue: unitMeasurement) ?? .gram
        self.isBought = isBought
        self.category = ShopItemCategory(rawValue: record["category"] as? String ?? "") ?? .other
        self.createdAt = record.creationDate ?? Date()
        self.listRecordID = record.parent?.recordID
        self.buyerUserReference = record["buyerUser"] as? CKRecord.Reference
        self.relatedUsersReference = record["relatedUsers"] as? [CKRecord.Reference]
        self.addedByUserReference = record["addedByUser"] as? CKRecord.Reference
        self.tagsReference = record["tags"] as? [CKRecord.Reference]
    }

    /// Creates a new, unsaved shopping list item.
    ///
    /// - Parameters:
    ///   - name: Label shown to the user.
    ///   - value: Estimated or actual price, when known.
    ///   - quantity: How many units to buy.
    ///   - unitMeasurement: The unit `quantity` is expressed in.
    ///   - isBought: Whether the item starts already purchased. Defaults to `false`.
    ///   - relatedUsers: Other users who will use/share this item.
    ///   - addedByUser: The user adding this item, for gamification credit.
    init(
        name: String,
        value: Double? = nil,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        isBought: Bool = false,
        category: ShopItemCategory = .other,
        relatedUsers: [CKRecord.Reference]? = nil,
        addedByUser: CKRecord.Reference? = nil,
        recordID: CKRecord.ID? = nil
    ) {
        self.recordID = recordID
        self.name = name
        self.value = value
        self.quantity = quantity
        self.unitMeasurement = unitMeasurement
        self.isBought = isBought
        self.category = category
        self.createdAt = Date()
        self.relatedUsersReference = relatedUsers
        self.addedByUserReference = addedByUser
    }

    /// Writes this model's values into a CloudKit record.
    ///
    /// - Parameter record: The record to populate.
    ///
    /// > Note: `nil` relationships are skipped rather than written, preserving whatever is
    /// > already on the server (same convention as ``ChoreModel/populate(record:)``).
    func populate(record: CKRecord) {
        record["name"] = name
        record["value"] = value
        record["quantity"] = quantity
        record["unitMeasurement"] = unitMeasurement.rawValue
        record["isBought"] = isBought
        record["category"] = category.rawValue
        
        if let buyerUserReference {
            record["buyerUser"] = buyerUserReference
        }
        if let relatedUsersReference {
            record["relatedUsers"] = relatedUsersReference
        }
        if let addedByUserReference {
            record["addedByUser"] = addedByUserReference
        }
        if let tagsReference {
            record["tags"] = tagsReference
        }
    }

    /// Flips ``isBought`` and persists the change
    @discardableResult
    func toggle() async -> Bool {
        isBought.toggle()
        // Optimistic update, rolled back if CloudKit rejects it (it used to stay flipped on
        // screen even though the change was never saved).
        guard await CloudKitManager.shared.update(self) else {
            isBought.toggle()
            return false
        }
        return true
    }

    /// Marks the item bought by `user`, recording both ``isBought`` and ``buyerUserReference``
    /// in a single update instead of two separate writes.
    ///
    /// - Parameter user: The user who bought the item.
    @discardableResult
    func markBought(by user: UserModel) async -> Bool {
        guard let buyerID = user.recordID else { return false }
        let previousBuyer = buyerUserReference
        isBought = true
        buyerUserReference = CKRecord.Reference(recordID: buyerID, action: .none)
        guard await CloudKitManager.shared.update(self) else {
            isBought = false
            buyerUserReference = previousBuyer
            return false
        }
        return true
    }

    /// Applies edited field values and persists them in one update. Mirrors
    /// ``ChoreModel/save(from:targetAssignments:)``: the editable fields live on this method
    /// rather than being set directly by callers, since ``relatedUsersReference`` is private.
    ///
    /// - Parameters:
    ///   - name: Label shown to the user.
    ///   - value: Estimated or actual price, when known.
    ///   - quantity: How many units to buy.
    ///   - unitMeasurement: The unit `quantity` is expressed in.
    ///   - relatedUsers: Other users who will use/share this item.
    /// - Returns: `true` when the update reached CloudKit.
    @discardableResult
    func update(
        name: String,
        value: Double?,
        quantity: Int,
        unitMeasurement: UnitMeasurement,
        category: ShopItemCategory,
        relatedUsers: [UserModel]
    ) async -> Bool {
        self.category = category
        self.name = name
        self.value = value
        self.quantity = quantity
        self.unitMeasurement = unitMeasurement
        self.relatedUsersReference = relatedUsers.compactMap { user -> CKRecord.Reference? in
            guard let recordID = user.recordID else { return nil }
            return CKRecord.Reference(recordID: recordID, action: .none)
        }
        return await CloudKitManager.shared.update(self)
    }
}
