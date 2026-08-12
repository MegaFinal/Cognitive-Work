import Foundation
import CloudKit

/// Represents a user stored in CloudKit.
class User: Identifiable {

    var id: CKRecord.ID
    var name: String
    var profilePicture: Data?
    var coins: Int
    var points: Int
    var house: CKRecord.Reference?
    var couponLimit: Int

    /// The original CloudKit record used for persistence operations.
    var record: CKRecord

    /// Creates a user model from a CloudKit record.
    ///
    /// - Parameter record: The CloudKit record representing the user.
    /// - Returns: A `User` instance when the record is valid;
    ///   otherwise `nil`.
    init?(record: CKRecord) {
        guard record.recordType == "User",
              let name = record["name"] as? String
        else {
            return nil
        }

        self.id = record.recordID
        self.name = name
        self.profilePicture = record["profilePicture"] as? Data
        self.coins = record["coins"] as? Int ?? -1
        self.points = record["points"] as? Int ?? -1
        self.house = record["house"] as? CKRecord.Reference
        self.couponLimit = record["couponLimit"] as? Int ?? -1
        self.record = record
    }

    /// Creates an unsaved CloudKit record representing a user.
    ///
    /// The record uses the current iCloud user's record ID within the
    /// house zone.
    ///
    /// - Parameters:
    ///   - name: The user's display name.
    ///   - profilePicture: The user's profile image data.
    ///   - coins: The user's initial coin balance.
    ///   - points: The user's initial point balance.
    ///   - house: The house associated with the user, if any.
    ///   - couponLimit: The maximum number of coupons available to the user.
    /// - Returns: A new unsaved user record, or `nil` if the current iCloud
    ///   user cannot be identified.
    static func newRecord(
        name: String,
        profilePicture: Data,
        coins: Int,
        points: Int,
        house: CKRecord.Reference?,
        couponLimit: Int
    ) async -> CKRecord? {
        guard let cloudKitUserID = try? await CKContainer.default().userRecordID()
        else {
            return nil
        }

        let zoneID = CloudKitManager.shared.houseZoneID

        let id = CKRecord.ID(
            recordName: cloudKitUserID.recordName,
            zoneID: zoneID
        )

        let record = CKRecord(
            recordType: "User",
            recordID: id
        )

        record["name"] = name
        record["profilePicture"] = profilePicture
        record["coins"] = coins
        record["points"] = points
        record["house"] = house
        record["couponLimit"] = couponLimit

        return record
    }

    /// Fetches all users associated with a house.
    ///
    /// - Parameter house: The house whose users should be fetched.
    /// - Returns: An array of `User` models created from the fetched records.
    static func fetchAllUsers(house: CKRecord) async -> [User] {
        await CloudKitManager.shared
            .fetchAllUsers(house: house)
            .compactMap(User.init(record:))
    }

    /// Deletes a user from CloudKit.
    ///
    /// - Parameter user: The CloudKit record representing the user.
    static func deleteUser(_ user: CKRecord) async {
        _ = await CloudKitManager.shared.deleteUser(user)
    }

    /// Updates the user's local properties and persists the changes to CloudKit.
    ///
    /// Only parameters with non-`nil` values are modified.
    ///
    /// - Parameters:
    ///   - name: The new display name.
    ///   - profilePicture: The new profile picture.
    ///   - coins: The new coin balance.
    ///   - points: The new point balance.
    ///   - couponLimit: The new coupon limit.
    func updateAttributes(
        name: String? = nil,
        profilePicture: Data? = nil,
        coins: Int? = nil,
        points: Int? = nil,
        couponLimit: Int? = nil
    ) async {
        if let name {
            self.name = name
        }

        if let profilePicture {
            self.profilePicture = profilePicture
        }

        if let coins {
            self.coins = coins
        }

        if let points {
            self.points = points
        }

        if let couponLimit {
            self.couponLimit = couponLimit
        }

        _ = await CloudKitManager.shared.updateUserAttributes(
            user: record,
            name: name,
            profilePicture: profilePicture,
            coins: coins,
            points: points,
            couponLimit: couponLimit
        )
    }

    /// Associates this user with a house.
    ///
    /// - Parameter house: The house to associate with the user.
    func addHouse(house: CKRecord) async {
        _ = await CloudKitManager.shared.addHouseToUser(
            user: record,
            house: house
        )
    }

    /// Removes this user's house association.
    func removeHouse() async {
        _ = await CloudKitManager.shared.removeUserHouse(
            user: record
        )
    }
}
