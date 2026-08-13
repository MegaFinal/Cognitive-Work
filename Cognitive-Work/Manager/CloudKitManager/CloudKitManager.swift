//
// CloudKitManager.swift
// Cognitive-Work
//
// Created by Jonas Fernando Nascimento Melo on 11/08/26.
//

import CloudKit

/// Manages CloudKit operations for houses, users, and shared records.
@Observable
class CloudKitManager {

    /// The shared instance of the CloudKit manager.
    static let shared = CloudKitManager()

    // MARK: - Properties

    let container: CKContainer
    let privateDB: CKDatabase
    let sharedDB: CKDatabase

    var errorMessage: String?

    private let zoneName = "HomeEnvironment"

    /// The custom zone owned by the current iCloud user.
    ///
    /// This zone should only be used for operations that belong
    /// to the current user, such as creating the custom zone.
    /// For operations involving a specific house, use the house's
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
    /// - Returns: `true` when the zone is successfully saved,
    ///   otherwise `false`.
    ///
    /// If the operation fails, `errorMessage` is updated with
    /// the corresponding CloudKit error.
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

    /// Creates and saves a share for a house when one does not already exist.
    ///
    /// If the house already has an associated share, the existing share
    /// is returned instead of creating a new one.
    ///
    /// - Parameter house: The house whose share should be retrieved or created.
    /// - Returns: The existing or newly created `CKShare`, or `nil` if the
    ///   operation fails.
    func resolveShare(for house: CKRecord) async -> CKShare? {
        if let existing = await fetchShare(for: house) {
            return existing
        }

        let share = CKShare(rootRecord: house)
        share[CKShare.SystemFieldKey.title] = house["name"] as? String
        share.publicPermission = .readWrite

        let operation = CKModifyRecordsOperation(
            recordsToSave: [house, share],
            recordIDsToDelete: nil
        )

        operation.savePolicy = .allKeys

        return await withCheckedContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: share)

                case .failure(let error):
                    self.errorMessage =
                        "Failed to create share: \(error.localizedDescription)"
                    continuation.resume(returning: nil)
                }
            }

            privateDB.add(operation)
        }
    }

    /// Fetches the share associated with a house.
    ///
    /// The database is selected automatically based on the owner of the
    /// house's record zone.
    ///
    /// - Parameter house: The house whose share should be fetched.
    /// - Returns: The associated `CKShare`, or `nil` if the house has no share
    ///   or the operation fails.
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
            errorMessage =
                "Failed to fetch share: \(error.localizedDescription)"
            return nil
        }
    }

    /// Accepts a CloudKit share invitation.
    ///
    /// - Parameter metadata: The metadata received from the CloudKit
    ///   share invitation.
    /// - Returns: `true` if the invitation was accepted successfully;
    ///   otherwise `false`.
    ///
    /// If the operation fails, `errorMessage` contains the failure reason.
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
}
