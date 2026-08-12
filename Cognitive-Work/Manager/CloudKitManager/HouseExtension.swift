import CloudKit

// MARK: - House CRUD

extension CloudKitManager {

    /// Creates a house and its associated share in a single CloudKit operation.
    ///
    /// The house and share are saved atomically, meaning the operation
    /// succeeds only when both records can be saved.
    ///
    /// - Parameters:
    ///   - name: The display name of the house.
    ///   - description: A description of the house.
    /// - Returns: A tuple containing the created house and its share,
    ///   or `nil` if the operation fails.
    func createHouse(name: String,description: String) async -> (house: CKRecord, share: CKShare)? {
        let houseID = CKRecord.ID(
            recordName: UUID().uuidString,
            zoneID: houseZoneID
        )

        let house = CKRecord(
            recordType: "House",
            recordID: houseID
        )

        house["name"] = name
        house["description"] = description

        let share = CKShare(rootRecord: house)
        share[CKShare.SystemFieldKey.title] = name
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
                    continuation.resume(returning: (house, share))

                case .failure(let error):
                    self.errorMessage =
                        "Failed to create house: \(error.localizedDescription)"
                    continuation.resume(returning: nil)
                }
            }

            privateDB.add(operation)
        }
    }

    /// Fetches the first house available to the current user.
    ///
    /// Owned houses are checked before shared houses.
    ///
    /// - Returns: The first owned or shared house found.
    ///
    /// - Throws: `HouseError.notFound` when no house is available.
    func fetchHouse() async throws -> CKRecord {
        let ownedHouses = await fetchOwnedHouses()

        if let house = ownedHouses.first {
            return house
        }

        let sharedHouses = await fetchSharedHouses()

        if let house = sharedHouses.first {
            return house
        }

        throw HouseError.notFound
    }

    /// Fetches houses owned by the current user.
    ///
    /// - Returns: All houses stored in the current user's private database.
    private func fetchOwnedHouses() async -> [CKRecord] {
        let query = CKQuery(
            recordType: "House",
            predicate: NSPredicate(value: true)
        )

        do {
            let (results, _) = try await privateDB.records(
                matching: query,
                inZoneWith: houseZoneID
            )

            return results.compactMap {
                try? $0.1.get()
            }
        } catch {
            errorMessage =
                "Failed to fetch owned houses: \(error.localizedDescription)"
            return []
        }
    }

    /// Fetches houses shared with the current user.
    ///
    /// - Returns: All houses found in the user's shared database zones.
    private func fetchSharedHouses() async -> [CKRecord] {
        do {
            let zones = try await sharedDB.allRecordZones()
            var houses: [CKRecord] = []

            for zone in zones {
                let query = CKQuery(
                    recordType: "House",
                    predicate: NSPredicate(value: true)
                )

                let (results, _) = try await sharedDB.records(
                    matching: query,
                    inZoneWith: zone.zoneID
                )

                houses.append(
                    contentsOf: results.compactMap {
                        try? $0.1.get()
                    }
                )
            }

            return houses
        } catch {
            errorMessage =
                "Failed to fetch shared houses: \(error.localizedDescription)"
            return []
        }
    }

    /// Updates the specified attributes of a house.
    ///
    /// Only parameters with non-`nil` values are modified.
    ///
    /// - Parameters:
    ///   - house: The house record to update.
    ///   - name: The new house name, or `nil` to keep the current value.
    ///   - description: The new house description, or `nil` to keep the
    ///     current value.
    /// - Returns: `true` if the update succeeds; otherwise `false`.
    func updateHouseAttributes(
        house: CKRecord,
        name: String? = nil,
        description: String? = nil
    ) async -> Bool {
        if let name {
            house["name"] = name
        }

        if let description {
            house["description"] = description
        }

        do {
            let database = house.recordID.zoneID.ownerName == CKCurrentUserDefaultName
                ? privateDB
                : sharedDB

            _ = try await database.save(house)
            return true
        } catch {
            errorMessage =
                "Failed to update house: \(error.localizedDescription)"
            return false
        }
    }

    /// Deletes a house and its associated share.
    ///
    /// Deleting the root house record also removes the associated sharing
    /// relationship and revokes access for shared users.
    ///
    /// - Parameter house: The house record to delete.
    /// - Returns: `true` if the deletion succeeds; otherwise `false`.
    func deleteHouse(_ house: CKRecord) async -> Bool {
        do {
            try await privateDB.deleteRecord(
                withID: house.recordID
            )

            return true
        } catch {
            errorMessage =
                "Failed to delete house: \(error.localizedDescription)"
            return false
        }
    }
}

/// Errors that can occur while retrieving houses.
enum HouseError: Error, LocalizedError {

    /// Indicates that no owned or shared house was found.
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No owned or shared house was found."
        }
    }
}
