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
@Observable
class HouseModel: CloudKitSyncable {

    /// CloudKit record type backing this model.
    static var recordType: String = "HouseModel"

    /// Identifier of the stored record, or `nil` before the house is saved.
    var recordID: CKRecord.ID?

    /// Name shown to the user and used as the share invitation title.
    var name: String

    /// Free-form details about the house.
    var description: String

    /// References to the ``ChoreModel`` records belonging to this house.
    private var choresReference: [CKRecord.Reference]?

    /// References to the ``UserModel`` records that are members of this house.
    private var usersReference: [CKRecord.Reference]?

    /// References to the shopping list entries of this house.
    private var shopListItemReference: [CKRecord.Reference]?

    /// References to the ``RoomModel`` records belonging to this house.
    private var roomsReference: [CKRecord.Reference]?
    
    var chores: [ChoreModel] {
        get async {
            if let choresReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: ChoreModel.self, recordReferences: choresReference) ?? []
            }
            return []
        }
    }
    
    var users: [UserModel] {
        get async {
            if let usersReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: usersReference) ?? []
            }
            return []
        }
    }
    
    // TODO: ShopListItem
    
    var room: [RoomModel] {
        get async {
            if let roomsReference {
                return await CloudKitManager.shared.fetchRecordsByRecordReference(for: RoomModel.self, recordReferences: roomsReference) ?? []
            }
            return []
        }
    }
    
    /// Creates a model from a CloudKit record.
    ///
    /// - Parameter record: The record to decode.
    /// - Returns: `nil` when `name` or `description` is missing or has the wrong type.
    required init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let description = record["description"] as? String
        else {
            return nil
        }

        self.recordID = record.recordID
        self.name = name
        self.description = description
        self.choresReference = record["chores"] as? [CKRecord.Reference]
        self.usersReference = record["users"] as? [CKRecord.Reference]
        self.shopListItemReference = record["shopListItem"] as? [CKRecord.Reference]
        self.roomsReference = record["rooms"] as? [CKRecord.Reference]
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
        self.choresReference = chores
        self.usersReference = users
        self.shopListItemReference = shopListItem
        self.roomsReference = rooms
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
        record["chores"] = choresReference
        record["users"] = usersReference
        record["shopListItem"] = shopListItemReference
        record["rooms"] = roomsReference
    }
    
    @discardableResult
    func appendRoom(rooms: [RoomModel]) async -> Bool {
        for room in rooms {
            if let recordID = room.recordID {
                let roomReference = CKRecord.Reference(recordID: recordID, action: .none)
                roomsReference?.append(roomReference)
            }
        }
        return await CloudKitManager.shared.update(self)
    }
    
    func reference(action: CKRecord.ReferenceAction) -> CKRecord.Reference? {
        if let recordID {
            return CKRecord.Reference(recordID: recordID, action: .none)
        }
        print("House doesn't have a recordID")
        return nil
    }
    
    // MARK: - Authorization
    
    /// Whether the user is the one who created this house.
    func isAdmin() async -> Bool? {
        guard let recordID = self.recordID else { return nil }
        return await CloudKitManager.shared.isOwner(HouseModel.self, recordID: recordID)
    }
    
    // MARK: - Update
    //
    /// Renames the house and/or updates its description, persisting the change to CloudKit.
    ///
    /// Only the user referenced by ``adminReference`` may succeed here
    ///
    /// - Parameters:
    ///   - name: New name for the house.
    ///   - description: New description for the house.
    ///   - requesterID: `recordID` of the ``UserModel`` attempting the change.
    /// - Throws: ``CloudKitErrors/notAuthorized`` if `requesterID` isn't the admin.
    @discardableResult
    func update(name: String, description: String, requesterID: CKRecord.ID) async -> Bool {
        guard await isAdmin() == true else { return false }
        
        self.name = name
        self.description = description
        return await CloudKitManager.shared.update(self)
    }
    
    func fetchSelfRecord() async -> CKRecord? {
        if let recordID {
            return await CloudKitManager.shared.fetchRecord(for: self)
        }
        return nil
    }
}
