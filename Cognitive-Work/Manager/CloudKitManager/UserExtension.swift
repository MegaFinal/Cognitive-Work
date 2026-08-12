//
// UserExtension.swift
// Cognitive-Work
//
// Created by Jonas Fernando Nascimento Melo on 11/08/26.
//

import CloudKit

// MARK: - User CRUD

extension CloudKitManager {

    /// Creates a user record associated with the current iCloud account.
    ///
    /// The record is initially stored in the current user's private database.
    ///
    /// - Parameters:
    ///   - name: The user's display name.
    ///   - profilePicture: The user's profile image data.
    ///   - coins: The initial number of coins.
    ///   - points: The initial number of points.
    ///   - couponLimit: The maximum number of coupons available to the user.
    /// - Returns: The created user record, or `nil` if the current iCloud
    ///   user cannot be identified.
    func createUser(
        name: String,
        profilePicture: Data,
        coins: Int = 0,
        points: Int = 0,
        couponLimit: Int = 0
    ) async -> CKRecord? {
        guard let cloudKitUserID = try? await CKContainer.default().userRecordID()
        else {
            return nil
        }

        let userID = CKRecord.ID(
            recordName: cloudKitUserID.recordName,
            zoneID: houseZoneID
        )

        let user = CKRecord(
            recordType: "User",
            recordID: userID
        )

        user["name"] = name
        user["profilePicture"] = profilePicture
        user["coins"] = coins
        user["points"] = points
        user["couponLimit"] = couponLimit

        do {
            try await privateDB.save(user)
        } catch {
            print(
                "Failed to save user in private database: "
                + error.localizedDescription
            )
        }

        return user
    }

    /// Fetches all users associated with a house.
    ///
    /// The database is selected automatically based on the house's zone owner.
    ///
    /// - Parameter house: The house whose users should be fetched.
    /// - Returns: All user records associated with the specified house.
    func fetchAllUsers(house: CKRecord) async -> [CKRecord] {
        let predicate = NSPredicate(
            format: "house == %@",
            CKRecord.Reference(record: house, action: .none)
        )

        let query = CKQuery(
            recordType: "User",
            predicate: predicate
        )

        do {
            let zoneID = house.recordID.zoneID

            let database = zoneID.ownerName == CKCurrentUserDefaultName
                ? privateDB
                : sharedDB

            let (results, _) = try await database.records(
                matching: query,
                inZoneWith: zoneID
            )

            return results.compactMap {
                try? $0.1.get()
            }
        } catch {
            errorMessage =
                "Failed to fetch users: \(error.localizedDescription)"
            return []
        }
    }

    /// Updates the specified attributes of a user.
    ///
    /// Only parameters with non-`nil` values are modified.
    ///
    /// - Parameters:
    ///   - user: The user record to update.
    ///   - name: The new display name, or `nil` to keep the current value.
    ///   - profilePicture: The new profile picture, or `nil` to keep the
    ///     current value.
    ///   - coins: The new coin balance, or `nil` to keep the current value.
    ///   - points: The new point balance, or `nil` to keep the current value.
    ///   - couponLimit: The new coupon limit, or `nil` to keep the current value.
    /// - Returns: `true` if the update succeeds; otherwise `false`.
    func updateUserAttributes(
        user: CKRecord,
        name: String? = nil,
        profilePicture: Data? = nil,
        coins: Int? = nil,
        points: Int? = nil,
        couponLimit: Int? = nil
    ) async -> Bool {
        if let name {
            user["name"] = name
        }

        if let profilePicture {
            user["profilePicture"] = profilePicture
        }

        if let coins {
            user["coins"] = coins
        }

        if let points {
            user["points"] = points
        }

        if let couponLimit {
            user["couponLimit"] = couponLimit
        }

        do {
            let database = user.recordID.zoneID.ownerName == CKCurrentUserDefaultName
                ? privateDB
                : sharedDB

            _ = try await database.save(user)
            return true
        } catch {
            errorMessage =
                "Failed to update user: \(error.localizedDescription)"
            return false
        }
    }

    /// Associates a user with a house.
    ///
    /// When the house belongs to the current user, the original user record
    /// is updated. When the house belongs to another user, a copy of the user
    /// record is created in the shared zone.
    ///
    /// - Parameters:
    ///   - user: The user record to associate with the house.
    ///   - house: The house to associate with the user.
    /// - Returns: `true` if the association succeeds; otherwise `false`.
    func addHouseToUser(
        user: CKRecord,
        house: CKRecord
    ) async -> Bool {
        do {
            let database = house.recordID.zoneID.ownerName == CKCurrentUserDefaultName
                ? privateDB
                : sharedDB

            let houseReference = CKRecord.Reference(
                record: house,
                action: .none
            )

            if database === privateDB {
                user["house"] = houseReference
                user.parent = houseReference

                try await database.save(user)
            } else {
                let userCopy = CKRecord(
                    recordType: user.recordType,
                    recordID: CKRecord.ID(
                        recordName: user.recordID.recordName,
                        zoneID: house.recordID.zoneID
                    )
                )

                userCopy["name"] = user["name"]
                userCopy["house"] = houseReference
                userCopy.parent = houseReference

                try await database.save(userCopy)
            }

            return true
        } catch {
            print(
                "Failed to associate user with house: "
                + error.localizedDescription
            )

            return false
        }
    }

    /// Removes the house association from a user.
    ///
    /// - Parameter user: The user whose house association should be removed.
    /// - Returns: `true` if the update succeeds; otherwise `false`.
    func removeUserHouse(user: CKRecord) async -> Bool {
        do {
            user.parent = nil
            user["house"] = nil

            let database = user.recordID.zoneID.ownerName == CKCurrentUserDefaultName
                ? privateDB
                : sharedDB

            _ = try await database.save(user)

            return true
        } catch {
            print(
                "Failed to remove user's house: "
                + error.localizedDescription
            )

            return false
        }
    }

    /// Deletes a user record from its corresponding CloudKit database.
    ///
    /// - Parameter user: The user record to delete.
    /// - Returns: `true` if the record is deleted successfully;
    ///   otherwise `false`.
    func deleteUser(_ user: CKRecord) async -> Bool {
        do {
            let database = user.recordID.zoneID.ownerName == CKCurrentUserDefaultName
                ? privateDB
                : sharedDB

            try await database.deleteRecord(
                withID: user.recordID
            )

            return true
        } catch {
            errorMessage =
                "Failed to delete user: \(error.localizedDescription)"
            return false
        }
    }
}
