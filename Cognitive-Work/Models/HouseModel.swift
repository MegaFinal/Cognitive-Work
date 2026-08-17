//
//  HouseModel.swift
//  Cognitive-Work
//

import Foundation
import CloudKit

/// A house stored in CloudKit, acting as the root record every other model hangs off.
///
/// The house is the record that gets shared, so its zone determines which database the
/// related chores, rooms, and users live in.
struct HouseModel: CloudKitSyncable {

    /// CloudKit record type backing this model.
    static var recordType: String = "HouseModel"

    /// Identifier of the stored record, or `nil` before the house is saved.
    var recordID: CKRecord.ID?

    /// Name shown to the user and used as the share invitation title.
    var name: String

    /// Free-form details about the house.
    var description: String

    /// References to the ``ChoreModel`` records belonging to this house.
    var chores: [CKRecord.Reference]?

    /// References to the ``UserModel`` records that are members of this house.
    var users: [CKRecord.Reference]?

    /// References to the shopping list entries of this house.
    var shopListItem: [CKRecord.Reference]?

    /// References to the ``RoomModel`` records belonging to this house.
    var rooms: [CKRecord.Reference]?

    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when `name` or `description` is missing or has the wrong type.
    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let description = record["description"] as? String
        else {
            return nil
        }

        self.recordID = record.recordID
        self.name = name
        self.description = description
        self.chores = record["chores"] as? [CKRecord.Reference]
        self.users = record["users"] as? [CKRecord.Reference]
        self.shopListItem = record["shopListItem"] as? [CKRecord.Reference]
        self.rooms = record["rooms"] as? [CKRecord.Reference]
    }

    /// Creates a new, unsaved house.
    ///
    /// Relationship parameters are usually filled in after the related records exist.
    ///
    /// - Parameters:
    ///   - name: Name shown to the user.
    ///   - description: Free-form details about the house.
    ///   - chores: Chores already known to belong to this house.
    ///   - users: Members of this house.
    ///   - shopListItem: Shopping list entries of this house.
    ///   - rooms: Rooms already known to belong to this house.
    init(
        name: String,
        description: String,
        chores: [CKRecord.Reference]? = nil,
        users: [CKRecord.Reference]? = nil,
        shopListItem: [CKRecord.Reference]? = nil,
        rooms: [CKRecord.Reference]? = nil
    ) {
        self.recordID = nil
        self.name = name
        self.description = description
        self.chores = chores
        self.users = users
        self.shopListItem = shopListItem
        self.rooms = rooms
    }

    /// Writes this model's values into a CloudKit record.
    ///
    /// - Parameter record: The record to populate.
    ///
    /// > Important: Relationships are always written, so a `nil` collection clears the field on
    /// > the server. This differs from ``ChoreModel``, ``RoomModel``, and ``UserModel``, which
    /// > skip `nil` values and preserve whatever is stored remotely.
    func populate(record: CKRecord) {
        record["name"] = name
        record["description"] = description
        record["chores"] = chores
        record["users"] = users
        record["shopListItem"] = shopListItem
        record["rooms"] = rooms
    }
}
