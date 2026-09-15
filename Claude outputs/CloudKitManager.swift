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
///
/// ## Onboarding audit — what changed and why
///
/// - ``houseUserRecordID(for:inHouseZone:)`` is now **idempotent**. It used to append `"-house"`
///   unconditionally, so passing it a record ID that was already a house copy produced
///   `"…-house-house"`. `OnboardingViewModel.joinHouse()` does exactly that whenever
///   `currentUser` already holds the house copy (which happens on every resumed session, since
///   `checkExistingAccount()` assigns the house copy to `currentUser`). The guest's public
///   profile was then written under a name ``fetchMyHouseUser()`` never looks for, so every
///   later lookup returned `nil`, their free time was silently never saved, and the admin's
///   gate counted them as pending forever.
/// - ``fetchZoneRecords(_:inZone:)`` was added: an index-free way to read every record of a type
///   inside one zone, built on `recordZoneChanges` the same way ``fetchDescendantLevels(of:)``
///   already was. `CKQuery` needs fields to be marked *Queryable* in the CloudKit schema, and
///   when that index is missing the query throws, gets swallowed, and the caller sees an empty
///   array that is indistinguishable from "nothing exists yet" — which is how both onboarding
///   wait screens ended up polling forever.
/// - ``createSharedSubscription()`` no longer aborts halfway. Saving a subscription whose ID
///   already exists throws, and because both saves shared one `do` block the *shared* database
///   subscription was frequently never created at all.
/// - ``switchHouse(to:)`` now honours the result of ``leaveCurrentHouse()`` instead of accepting
///   the new share regardless, which could leave a device holding two houses at once.
/// - The destructive cleanup helpers moved behind `#if DEBUG`. They were being called from
///   `Onboarding.swift`'s `.task`, wiping every private record and leaving every shared house on
///   each launch that happened before onboarding finished.
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
    ///
    /// > Warning: This property is observed by SwiftUI and written from whatever context a
    /// > CloudKit call happens to finish on. Onboarding no longer writes to it concurrently
    /// > (see `OnboardingViewModel.saveSelectedRooms()`, whose task group was replaced by a
    /// > serial loop), but `commitScheduleResults(_:users:houseZoneID:houseRecordID:monthlyChoresToToggle:)`
    /// > still updates records from a `TaskGroup`. Isolating this property to the main actor is
    /// > the recommended follow-up once the scheduler is revisited.
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
    let houseZoneID = CKRecordZone.ID(
        zoneName: "HomeEnvironment",
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

    private let currentUserRecordNameKey = "currentUserRecordName"

    /// Remembers `user` as the profile that belongs to this device.
    func setCurrentUser(_ user: UserModel) {
        guard let recordID = user.recordID else { return }
        UserDefaults.standard.set(recordID.recordName, forKey: currentUserRecordNameKey)
    }

    /// The `recordName` of the private profile this device remembers, if any.
    ///
    /// - Note: **Onboarding fix:** exposed so callers can tell "no profile was ever created on
    ///   this device" apart from "a profile exists but could not be fetched right now". The two
    ///   used to be indistinguishable, and `CreateOrEnterHouseOnboardingView` treated both as a
    ///   dead end.
    var storedCurrentUserRecordName: String? {
        UserDefaults.standard.string(forKey: currentUserRecordNameKey)
    }

    /// Fetches the `UserModel` that belongs to this device securely.
    ///
    /// > Important: This method prioritizes a direct `CKRecord.ID` fetch using local `UserDefaults`
    /// > to bypass CloudKit's strict `CKQuery` index requirements. It only falls back to a query
    /// > if the user has reinstalled the app and lost their local defaults.
    ///
    /// - Note: **Onboarding fix:** the fallback query only ever worked when `ownerRecordName` was
    ///   marked *Queryable* in the CloudKit schema, and `OnboardingViewModel.createUser()` never
    ///   called ``setCurrentUser(_:)``, so the fast path was empty for freshly created profiles.
    ///   A person who created their profile and relaunched the app before creating a house ended
    ///   up with no reachable profile at all — the "I tap create house and nothing happens" report.
    ///   `createUser()` now records the profile, and this method keeps the query as a true fallback.
    func fetchMyUser() async -> UserModel? {
        // 1. Direct ID Lookup (Fastest, zero-configuration required)
        if let recordName = UserDefaults.standard.string(forKey: currentUserRecordNameKey) {
            let recordID = CKRecord.ID(recordName: recordName, zoneID: houseZoneID)
            if let record = try? await privateDB.record(for: recordID) {
                return UserModel(record: record)
            }
        }

        // 2. Fallback Query (Requires 'ownerRecordName' to be Queryable in CloudKit Console)
        guard let recordID = await fetchCurrentUserRecordID() else { return nil }

        let predicate = NSPredicate(format: "ownerRecordName == %@", recordID.recordName)
        if let user = await fetchPrivate(UserModel.self, predicate: predicate).first {
            setCurrentUser(user) // Save it for next time
            return user
        }

        // 3. Index-free fallback (Onboarding fix)
        //
        // When the `ownerRecordName` index is missing, step 2 throws and returns an empty array
        // that looks exactly like "this person has no profile". Scanning the zone answers the
        // question without depending on the CloudKit schema being configured correctly.
        let owned = await fetchZoneRecords(UserModel.self, inZone: houseZoneID)
        if let user = owned.first(where: { $0.ownerRecordName == recordID.recordName && !isHouseUser($0) }) {
            setCurrentUser(user)
            return user
        }

        return nil
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
    /// - Note: **Onboarding fix:** the derivation is now idempotent. Passing an ID that already
    ///   carries the suffix returns the same ID instead of producing `"…-house-house"`, which
    ///   used to create a public profile nobody could ever find again.
    ///
    /// - Parameters:
    ///   - privateRecordID: `recordID` of the private profile.
    ///   - zoneID: Zone the house lives in (`house.recordID.zoneID`).
    func houseUserRecordID(
        for privateRecordID: CKRecord.ID,
        inHouseZone zoneID: CKRecordZone.ID
    ) -> CKRecord.ID {
        let baseName = privateRecordName(from: privateRecordID.recordName)

        return CKRecord.ID(
            recordName: baseName + houseUserSuffix,
            zoneID: zoneID
        )
    }

    /// Strips the in-house suffix from a `recordName`, if it carries one.
    ///
    /// - Note: **Onboarding fix:** the inverse of the derivation performed by
    ///   ``houseUserRecordID(for:inHouseZone:)``, so a house copy can always be traced back to
    ///   the private profile it was made from.
    func privateRecordName(from recordName: String) -> String {
        guard recordName.hasSuffix(houseUserSuffix) else { return recordName }
        return String(recordName.dropLast(houseUserSuffix.count))
    }

    /// Whether `user` is a house copy rather than a private profile.
    ///
    /// - Note: **Onboarding fix:** lets callers assert which of the two records they are holding
    ///   before deriving anything from it.
    func isHouseUser(_ user: UserModel) -> Bool {
        guard let recordName = user.recordID?.recordName else { return false }
        return recordName.hasSuffix(houseUserSuffix)
    }

    func fetchCurrentUserRecordID() async -> CKRecord.ID? {
        return try? await container.userRecordID()
    }

    /// Fetches this device's own `UserModel` record *inside the current house* — the one
    /// housemates can see, as opposed to the private profile returned by ``fetchMyUser()``.
    ///
    /// Reads the record directly by ID, derived via ``houseUserRecordID(for:inHouseZone:)``,
    /// so it needs no `CKQuery` and works the same whether the house is owned (private
    /// database) or joined through a share (shared database).
    ///
    /// - Note: **Onboarding fix:** `house` can now be supplied by the caller. Resolving it
    ///   internally through ``fetchFirst(_:)`` returns whichever house CloudKit happens to
    ///   surface first, with no ordering guarantee — fine when a device belongs to exactly one
    ///   house, wrong as soon as it does not (see ``switchHouse(to:)``).
    ///
    /// - Parameter house: The house whose copy to read. Resolved via ``fetchFirst(_:)`` when omitted.
    /// - Returns: The in-house copy, or `nil` when there is no house yet, the house was
    ///   deleted, or the copy predates this naming convention.
    func fetchMyHouseUser(in house: HouseModel? = nil) async -> UserModel? {
        // Onboarding fix: the right-hand operand of `??` is an `@autoclosure () throws -> T?` —
        // a *synchronous* closure — so `await` cannot appear inside it. Folding the lookup into
        // `??` produces "'async' call in a function that does not support concurrency", even
        // though the enclosing method is `async`. It has to be written out.
        var resolvedHouse = house

        if resolvedHouse == nil {
            resolvedHouse = try? await fetchFirst(HouseModel.self)
        }

        guard let privateRecordID = await fetchMyUser()?.recordID,
              let houseZoneID = resolvedHouse?.recordID?.zoneID
        else {
            return nil
        }

        let recordID = houseUserRecordID(
            for: privateRecordID,
            inHouseZone: houseZoneID
        )
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
    ///
    /// - Note: **Onboarding fix:** the stored name belongs to the *private* profile, so the
    ///   comparison now also accepts that profile's house copy. Previously every list of
    ///   housemates failed to recognise the device's own public record.
    func isCurrentUser(_ user: UserModel) -> Bool {
        guard let recordID = user.recordID,
              let storedName = UserDefaults.standard.string(forKey: currentUserRecordNameKey)
        else {
            return false
        }

        return privateRecordName(from: recordID.recordName) == privateRecordName(from: storedName)
    }

    /// Clears the persisted current-user record, e.g. after the account is deleted.
    func clearCurrentUser() {
        UserDefaults.standard.removeObject(forKey: currentUserRecordNameKey)
    }

    // MARK: - Index-free Reads

    /// Reads every record of `type` inside one zone without using a `CKQuery`.
    ///
    /// - Note: **Onboarding fix:** `CKQuery` refuses to run unless the fields it touches (and
    ///   `recordName` itself, for `NSPredicate(value: true)`) are marked *Queryable* in the
    ///   CloudKit schema. A missing index throws, ``fetchPrivate(_:predicate:)`` and
    ///   ``fetchShared(_:predicate:)`` swallow the error, and the caller receives `[]` — which
    ///   both onboarding wait screens read as "not ready yet" and polled on forever. Walking the
    ///   zone's change feed answers the same question with no schema requirements at all; it is
    ///   the technique ``fetchDescendantLevels(of:)`` already relies on.
    ///
    /// - Parameters:
    ///   - type: The model type to read.
    ///   - zoneID: Zone to scan. The database is chosen from the zone's owner.
    /// - Returns: Every decodable record of that type in the zone. Empty when the zone is empty
    ///   or unreachable.
    func fetchZoneRecords<T: CloudKitSyncable>(
        _ type: T.Type,
        inZone zoneID: CKRecordZone.ID
    ) async -> [T] {
        let database = zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB

        var items: [T] = []
        var token: CKServerChangeToken?

        repeat {
            do {
                let changes = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: token
                )

                for (_, result) in changes.modificationResultsByID {
                    guard let record = try? result.get().record,
                          record.recordType == T.recordType,
                          let item = T.init(record: record)
                    else {
                        continue
                    }

                    items.append(item)
                }

                token = changes.moreComing ? changes.changeToken : nil
            } catch {
                errorMessage = "Failed to scan zone \(zoneID.zoneName): \(error.localizedDescription)"
                return items
            }
        } while token != nil

        return items
    }

    /// Reads every record of `type` that belongs to `house`, without using a `CKQuery`.
    ///
    /// - Note: **Onboarding fix:** the index-free counterpart of ``fetchHouseUsers(of:)`` and
    ///   friends. Used by the onboarding screens that must not depend on schema configuration.
    ///
    /// - Parameters:
    ///   - type: The model type to read.
    ///   - house: The house whose zone should be scanned.
    /// - Returns: Every decodable record of that type in the house's zone.
    func fetchHouseRecords<T: CloudKitSyncable>(
        _ type: T.Type,
        of house: HouseModel
    ) async -> [T] {
        guard let zoneID = house.recordID?.zoneID else { return [] }
        return await fetchZoneRecords(type, inZone: zoneID)
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
            _ = try await privateDB
                .modifyRecords(saving: [house, share], deleting: [])
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
            _ = try await privateDB
                .modifyRecords(saving: [house, share], deleting: [])
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
    func leaveCurrentHouse() async throws -> Bool {
        guard let house = try? await fetchFirst(HouseModel.self),
              let record = await fetchRecord(for: house),
              let share = await fetchShare(for: record)
        else {
            return false
        }

        // O dono não "sai": ele deleta ou para de compartilhar.
        guard share.recordID.zoneID.ownerName != CKCurrentUserDefaultName else {
            errorMessage = "Failed to leave house: current user is the owner"
            throw CloudKitErrors<Any>.currentHouseOwnerCannotLeaveTheHouse
        }

        do {
            _ = try await sharedDB.deleteRecord(withID: share.recordID)
            return true
        } catch {
            errorMessage = "Failed to leave house: \(error.localizedDescription)"
            return false
        }
    }

    /// Leaves the current house and joins the one described by `metadata`.
    ///
    /// - Note: **Onboarding fix:** the return value of ``leaveCurrentHouse()`` is now honoured.
    ///   That method returns `false` without throwing in several ordinary situations (no house
    ///   found, the house record cannot be fetched, the house has no share), and the previous
    ///   implementation only reacted to a *thrown* error — so the new share was accepted anyway
    ///   and the device ended up holding two houses. Every "current house" lookup in the app goes
    ///   through ``fetchFirst(_:)``, which then returns whichever of the two CloudKit surfaces
    ///   first, with no ordering guarantee: chores from one house, members from the other.
    @discardableResult
    func switchHouse(to metadata: CKShare.Metadata) async -> Bool {
        do {
            guard try await leaveCurrentHouse() else {
                errorMessage = errorMessage
                ?? "Failed to switch house: could not leave the current house."
                return false
            }

            return await acceptShare(metadata: metadata)
        }
        catch {
            print("\(String(describing: errorMessage))")
            return false
        }
    }

    /// Creates database subscriptions for private and shared database changes.
    ///
    /// The subscriptions request silent push notifications by enabling
    /// `shouldSendContentAvailable`.
    ///
    /// - Note: **Onboarding fix:** each subscription is now saved independently and an
    ///   "already exists" failure is treated as success. Both saves used to share one `do`
    ///   block, so the very common `serverRecordChanged` error raised by re-saving the private
    ///   subscription (every relaunch, every rejoin) threw before the *shared* subscription was
    ///   ever created — and the caller swallowed it with `try?`. A guest with no shared-database
    ///   subscription never receives a change notification at all.
    ///
    /// > Important: `shouldSendContentAvailable` produces a **silent** push, which iOS only
    /// > delivers when the target declares the `remote-notification` background mode. This
    /// > project's `Info.plist` does not declare `UIBackgroundModes`, so none of these pushes
    /// > are delivered and `.cloudKitDidChange` is never posted from
    /// > `AppDelegate.application(_:didReceiveRemoteNotification:)`. Add the key (see the
    /// > diagnosis document) — and note that the onboarding screens no longer depend on it,
    /// > because they poll as well.
    ///
    /// - Throws: A CloudKit error if a subscription cannot be saved for a reason other than
    ///   already existing.
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

        try await save(subscription: privateSubscription, in: privateDB)
        try await save(subscription: sharedSubscription, in: sharedDB)
    }

    /// Saves one subscription, treating "this subscription already exists" as success.
    ///
    /// - Note: **Onboarding fix:** see ``createSharedSubscription()``.
    private func save(subscription: CKSubscription, in database: CKDatabase) async throws {
        do {
            _ = try await database.save(subscription)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // The subscription is already registered — nothing to do.
            return
        } catch let error as CKError where error.code == .unknownItem {
            // The database has no subscription support configured yet; not fatal for the caller.
            return
        }
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
        let temporaryFileURL = temporaryDirectory.appendingPathComponent(
            UUID().uuidString
        )

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

    /// Saves a collection of records to CloudKit in a single batch operation.
    ///
    /// This method determines the appropriate database (private or shared) based on the provided **zone ID** and executes a **batch save** using `modifyRecords(saving:deleting:)`.
    ///
    /// - Parameters:
    ///   - records: An array of **`CKRecord`** objects to be saved.
    ///   - zoneID: The **`CKRecordZone.ID`** indicating where the records reside.
    ///
    /// - Returns: A **Boolean** value indicating whether the batch operation succeeded (`true`) or failed (`false`).
    ///
    /// - Important: If the operation fails, the error message is stored in **`self.errorMessage`**.
    @discardableResult
    func batchSave(records: [CKRecord], zoneID: CKRecordZone.ID) async -> Bool {
        let isPrivate = zoneID.ownerName == CKCurrentUserDefaultName
        let database = isPrivate ? privateDB : sharedDB
        do {
            _ = try await database.modifyRecords(saving: records, deleting: [])

            return true
        } catch {
            self.errorMessage = "Batch save failed: \(error.localizedDescription)"
            return false
        }
    }
}

#if DEBUG
extension CloudKitManager {

    // MARK: - Debug / Cleanup

    /// Deletes every record owned by the current user by dropping the custom zone that
    /// holds all of them, then recreates the (now empty) zone so the app keeps working.
    ///
    /// Every model created through `⁠ create(_:zoneID:parent:) ⁠` lives in `⁠ houseZoneID ⁠`
    /// by default, so removing that single zone wipes houses, rooms, chores, users and
    /// everything else in one atomic server-side operation — no need to enumerate record
    /// types or paginate queries.
    ///
    /// > Warning: **Onboarding fix:** this extension is now compiled only in `DEBUG` builds.
    /// > `Onboarding.swift` was calling ``deleteAllRecords()`` from its `.task`, so the entire
    /// > private zone was dropped and every shared house left on *every* launch that happened
    /// > before onboarding finished — taking the just-created profile, the house, its rooms, its
    /// > chores and every guest's availability with it.
    ///
    /// - Returns: ⁠ true ⁠ when the zone was deleted and recreated successfully.
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
    /// > only its owner can do that. Deleting the `⁠ CKShare ⁠` record is the correct
    /// > equivalent available to a participant: it removes every reference this account
    /// > holds into shared houses, without touching the owner's actual data.
    ///
    /// - Returns: ⁠ true ⁠ when every shared house was successfully left.
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
    /// > automatically — and after this audit that statement is true again. Call it only from an
    /// > explicit, confirmed debug action.
    ///
    /// - Returns: ⁠ true ⁠ when both steps succeeded.
    @discardableResult
    func deleteAllRecords() async -> Bool {
        let leftShared = await leaveAllSharedHouses()
        let deletedPrivate = await deleteAllPrivateRecords()
        return leftShared && deletedPrivate
    }
}
#endif
