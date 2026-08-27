//
//  CloudKitManager.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 11/08/26.
//

import CloudKit

/// Manages CloudKit operations for houses, users, and shared records.
///
/// Failing operations return `false` or `nil` and describe the reason in ``errorMessage``.
@Observable
class CloudKitManager {

    /// The shared instance of the CloudKit manager.
    static let shared = CloudKitManager()

    // MARK: - Properties

    /// The app's iCloud container.
    let container: CKContainer

    /// Database holding records owned by the current user.
    let privateDB: CKDatabase

    /// Database holding records shared with the current user by others.
    let sharedDB: CKDatabase

    /// Description of the most recent failure, or `nil` when none occurred.
    var errorMessage: String?

    /// Name of the custom zone that stores all house data.
    private let zoneName = "HomeEnvironment"

    /// The custom zone owned by the current iCloud user.
    ///
    /// Use this zone only for operations that belong to the current user, such as creating the
    /// custom zone. For operations involving a specific house, use that house's
    /// `recordID.zoneID` instead.
    @ObservationIgnored
    lazy var houseZoneID = CKRecordZone.ID(
        zoneName: zoneName,
        ownerName: CKCurrentUserDefaultName
    )

    private init() {
        container = CKContainer(
            identifier: "iCloud.JonasMelo.Cognitive-Work"
        )
        privateDB = container.privateCloudDatabase
        sharedDB = container.sharedCloudDatabase
    }

    // MARK: - Zone Management

    /// Creates the custom house zone if it does not already exist.
    ///
    /// - Returns: `true` when the zone is successfully saved, otherwise `false`.
    ///
    /// If the operation fails, ``errorMessage`` is updated with the corresponding CloudKit error.
    @discardableResult
    func createZoneIfNeeded() async -> Bool {
        let zone = CKRecordZone(zoneID: houseZoneID)

        do {
            _ = try await privateDB.save(zone)
            return true
        } catch {
            errorMessage = "Failed to create zone: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Sharing

    /// Returns the share for a house, creating one when it does not exist yet.
    ///
    /// - Parameter house: The house record whose share should be retrieved or created.
    /// - Returns: The existing or newly created `CKShare`, or `nil` if the operation fails.
    ///
    /// > Important: New shares are created with `publicPermission == .readWrite`, so anyone
    /// > holding the link can join and edit the house.
    func resolveShare(for house: CKRecord) async -> CKShare? {
        if let existing = await fetchShare(for: house) {
            return existing
        }

        let share = CKShare(rootRecord: house)
        share[CKShare.SystemFieldKey.title] = house["name"] as? String
        share.publicPermission = .readWrite

        do {
            _ = try await privateDB.modifyRecords(saving: [house, share], deleting: [])
            return share
        } catch {
            self.errorMessage = "Failed to create share: \(error.localizedDescription)"
            return nil
        }
    }
    
    func resolveShare(for houseModel: HouseModel) async -> CKShare? {
        guard let house = await fetchRecord(for: houseModel)
        else {
            return nil
        }
        
        if let existing = await fetchShare(for: house) {
            return existing
        }

        let share = CKShare(rootRecord: house)
        share[CKShare.SystemFieldKey.title] = house["name"] as? String
        share.publicPermission = .readWrite

        do {
            _ = try await privateDB.modifyRecords(saving: [house, share], deleting: [])
            return share
        } catch {
            self.errorMessage = "Failed to create share: \(error.localizedDescription)"
            return nil
        }
    }

    /// Fetches the share associated with a house.
    ///
    /// The database is selected automatically based on the owner of the house's record zone.
    ///
    /// - Parameter house: The house record whose share should be fetched.
    /// - Returns: The associated `CKShare`, or `nil` if the house has no share or the operation
    ///   fails.
    func fetchShare(for house: CKRecord) async -> CKShare? {
        guard let shareReference = house.share else {
            return nil
        }

        let database = house.recordID.zoneID.ownerName == CKCurrentUserDefaultName
            ? privateDB
            : sharedDB

        do {
            return try await database.record(
                for: shareReference.recordID
            ) as? CKShare
        } catch {
            errorMessage = "Failed to fetch share: \(error.localizedDescription)"
            return nil
        }
    }

    /// Accepts a CloudKit share invitation.
    ///
    /// - Parameter metadata: The metadata received from the CloudKit share invitation.
    /// - Returns: `true` if the invitation was accepted successfully; otherwise `false`.
    ///
    /// If the operation fails, ``errorMessage`` contains the failure reason.
    func acceptShare(metadata: CKShare.Metadata) async -> Bool {
        let operation = CKAcceptSharesOperation(
            shareMetadatas: [metadata]
        )

        return await withCheckedContinuation { continuation in
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)

                case .failure(let error):
                    self.errorMessage =
                        "Failed to accept share invitation: \(error.localizedDescription)"
                    continuation.resume(returning: false)
                }
            }

            container.add(operation)
        }
    }

    /// Creates database subscriptions for private and shared database changes.
    ///
    /// The subscriptions request silent push notifications by enabling
    /// `shouldSendContentAvailable`.
    ///
    /// - Throws: A CloudKit error if either subscription cannot be saved.
    func createSharedSubscription() async throws {
        let sharedSubscription = CKDatabaseSubscription(
            subscriptionID: "shared-changes"
        )

        let privateSubscription = CKDatabaseSubscription(
            subscriptionID: "private-changes"
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true

        sharedSubscription.notificationInfo = notificationInfo
        privateSubscription.notificationInfo = notificationInfo

        try await privateDB.save(privateSubscription)
        try await sharedDB.save(sharedSubscription)
    }

    /// Saves a share and returns the invitation link CloudKit assigned to it.
    ///
    /// - Parameter share: The share to save.
    /// - Returns: The invitation URL other users can open to join.
    /// - Throws: A CloudKit error if the share cannot be saved, or
    ///   ``CloudKitErrors/missingShareURL`` if CloudKit returns no URL.
    func generateShareLink(share: CKShare) async throws -> URL {
        _ = try await privateDB.modifyRecords(saving: [share], deleting: [])

        guard let url = share.url else {
            throw CloudKitErrors<Any>.missingShareURL
        }

        return url
    }
}
