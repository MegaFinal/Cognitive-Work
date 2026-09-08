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
    
    /// Suffix appended to a private profile's `recordName` to derive the `recordName` of the
    /// copy that lives inside a house. See ``houseUserRecordID(for:inHouseZone:)``.
    private let houseUserSuffix = "-house"

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

    // MARK: - Current User

    /// UserDefaults key used to remember which `UserModel` record belongs to whoever is
    /// using this device.
    private let currentUserRecordNameKey = "currentUserRecordName"

    /// `recordID` of the `UserModel` that belongs to whoever is using this device.
    ///
    /// This is persisted locally rather than derived from CloudKit: once housemates become
    /// visible through shared data, nothing on a `UserModel` record itself says "this one is
    /// you" — every record looks the same. Set once by ``setCurrentUser(_:)`` right after the
    /// profile is created (or re-fetched), and read back by ``fetchMyUser()``.
    var currentUserRecordID: CKRecord.ID? {
        guard let recordName = UserDefaults.standard.string(forKey: currentUserRecordNameKey)
        else {
            return nil
        }
        return CKRecord.ID(recordName: recordName, zoneID: houseZoneID)
    }

    /// Remembers `user` as the profile that belongs to this device, so future launches (and
    /// lists that include housemates) can tell it apart from everyone else.
    ///
    /// - Parameter user: The current device owner's own `UserModel`. Does nothing if
    ///   `user.recordID` is `nil`.
    func setCurrentUser(_ user: UserModel) {
        guard let recordID = user.recordID else { return }
        UserDefaults.standard.set(recordID.recordName, forKey: currentUserRecordNameKey)
    }

    /// Fetches the `UserModel` that belongs to this device, using the `recordID` persisted by
    /// ``setCurrentUser(_:)``.
    ///
    /// A user's own profile always lives in their own private zone (see ``create(_:zoneID:parent:)``),
    /// so this always reads from ``privateDB``.
    ///
    /// - Returns: The current user's profile, or `nil` when nothing was ever persisted or the
    ///   fetch fails.
    func fetchMyUser() async -> UserModel? {
        guard let recordID = currentUserRecordID else { return nil }

        do {
            let record = try await privateDB.record(for: recordID)
            return UserModel(record: record)
        } catch {
            errorMessage = "Failed to fetch current user: \(error.localizedDescription)"
            return nil
        }
    }

    /// The `recordID` a user's in-house copy must be created with.
    ///
    /// A person ends up with two `UserModel` records: the private profile created by
    /// `OnboardingViewModel.createUser()`, and a copy inside the house's zone (created by
    /// `createHouseAndLinkUser()` for the owner, `joinHouse()` for an invited member). Nothing
    /// on the records themselves links the two, so the copy's name is *derived* from the
    /// private one instead — that is the only thing that makes ``fetchMyHouseUser()`` possible
    /// without a query.
    ///
    /// The suffix is what allows the house owner to have both records: their house lives in
    /// their own private zone, so an identical `recordName` in the same zone would simply be
    /// the same record.
    ///
    /// - Parameters:
    ///   - privateRecordID: `recordID` of the private profile.
    ///   - zoneID: Zone the house lives in (`house.recordID.zoneID`).
    func houseUserRecordID(
        for privateRecordID: CKRecord.ID,
        inHouseZone zoneID: CKRecordZone.ID
    ) -> CKRecord.ID {
        CKRecord.ID(
            recordName: privateRecordID.recordName + houseUserSuffix,
            zoneID: zoneID
        )
    }

    /// Fetches this device's own `UserModel` record *inside the current house* — the one
    /// housemates can see, as opposed to the private profile returned by ``fetchMyUser()``.
    ///
    /// Reads the record directly by ID, derived via ``houseUserRecordID(for:inHouseZone:)``,
    /// so it needs no `CKQuery` and works the same whether the house is owned (private
    /// database) or joined through a share (shared database).
    ///
    /// - Returns: The in-house copy, or `nil` when there is no house yet, the house was
    ///   deleted, or the copy predates this naming convention.
    func fetchMyHouseUser() async -> UserModel? {
        guard let privateRecordID = currentUserRecordID,
              let houseZoneID = (try? await fetchFirst(HouseModel.self))?.recordID?.zoneID
        else {
            return nil
        }

        let recordID = houseUserRecordID(for: privateRecordID, inHouseZone: houseZoneID)
        let database = houseZoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        do {
            return UserModel(record: try await database.record(for: recordID))
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            errorMessage = "Failed to fetch house user: \(error.localizedDescription)"
            return nil
        }
    }

    /// Whether `user` is the profile that belongs to this device, as opposed to a housemate
    /// fetched alongside it (e.g. via ``fetchAll(_:predicate:)``).
    func isCurrentUser(_ user: UserModel) -> Bool {
        guard let recordID = user.recordID else { return false }
        return recordID.recordName
            == UserDefaults.standard.string(forKey: currentUserRecordNameKey)
    }

    /// Clears the persisted current-user record, e.g. after the account is deleted.
    func clearCurrentUser() {
        UserDefaults.standard.removeObject(forKey: currentUserRecordNameKey)
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
            ? privateDB // dono
            : sharedDB // convidado

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
    @discardableResult
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
    
    @discardableResult
    func leaveCurrentHouse() async -> Bool {
        guard let house = try? await fetchFirst(HouseModel.self),
              let record = await fetchRecord(for: house),
              let share = await fetchShare(for: record)
        else {
            return false
        }

        // O dono não "sai": ele deleta ou para de compartilhar.
        guard share.recordID.zoneID.ownerName != CKCurrentUserDefaultName else {
            errorMessage = "Failed to leave house: current user is the owner"
            return false
        }

        do {
            _ = try await sharedDB.deleteRecord(withID: share.recordID)
            return true
        } catch {
            errorMessage = "Failed to leave house: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func switchHouse(to metadata: CKShare.Metadata) async -> Bool {
        await leaveCurrentHouse()
        return await acceptShare(metadata: metadata)
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
    
    func createAsset(from data: Data) -> CKAsset? {
        //Create a temporary file URL
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let temporaryFileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            //Write the Data to the temporary URL
            try data.write(to: temporaryFileURL)
            
            //Initialize and return the CKAsset
            return CKAsset(fileURL: temporaryFileURL)
        } catch {
            print("Failed to write data to temporary file: \(error)")
            return nil
        }
    }
}

extension CloudKitManager {

    // MARK: - Debug / Cleanup

    /// Deletes every record owned by the current user by dropping the custom zone that
    /// holds all of them, then recreates the (now empty) zone so the app keeps working.
    ///
    /// Every model created through `⁠ create(_:zoneID:parent:) ⁠` lives in `⁠ houseZoneID ⁠`
    /// by default, so removing that single zone wipes houses, rooms, chores, users and
    /// everything else in one atomic server-side operation — no need to enumerate record
    /// types or paginate queries.
    ///
    /// - Returns: ⁠ true ⁠ when the zone was deleted and recreated successfully.
    @discardableResult
    func deleteAllPrivateRecords() async -> Bool {
        do {
            _ = try await privateDB.deleteRecordZone(withID: houseZoneID)
        } catch {
            errorMessage = "Failed to delete zone: \(error.localizedDescription)"
            return false
        }

        return await createZoneIfNeeded()
    }

    /// Leaves every house shared with the current user, across every shared zone.
    ///
    /// > Note: CloudKit doesn't let a participant delete another account's private zone —
    /// > only its owner can do that. Deleting the `⁠ CKShare ⁠` record is the correct
    /// > equivalent available to a participant: it removes every reference this account
    /// > holds into shared houses, without touching the owner's actual data.
    ///
    /// - Returns: ⁠ true ⁠ when every shared house was successfully left.
    @discardableResult
    func leaveAllSharedHouses() async -> Bool {
        let sharedHouses = await fetchAll(HouseModel.self).filter {
            guard let recordID = $0.recordID else { return false }
            return !isOwner(HouseModel.self, recordID: recordID)
        }

        var allSucceeded = true

        for house in sharedHouses {
            guard let record = await fetchRecord(for: house),
                  let share = await fetchShare(for: record)
            else {
                allSucceeded = false
                continue
            }

            do {
                _ = try await sharedDB.deleteRecord(withID: share.recordID)
            } catch {
                errorMessage = "Failed to leave house \(house.name): \(error.localizedDescription)"
                allSucceeded = false
            }
        }

        return allSucceeded
    }

    /// Deletes everything the current user can reach: every record they own, plus their
    /// participation in every house shared with them.
    ///
    /// > Warning: Destructive, irreversible debug utility. Nothing in the app calls it
    /// > automatically.
    ///
    /// - Returns: ⁠ true ⁠ when both steps succeeded.
    @discardableResult
    func deleteAllRecords() async -> Bool {
        let leftShared = await leaveAllSharedHouses()
        let deletedPrivate = await deleteAllPrivateRecords()
        return leftShared && deletedPrivate
    }
}

