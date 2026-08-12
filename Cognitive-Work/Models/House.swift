import Foundation
import CloudKit

/// Represents a house stored in CloudKit.
class House: Identifiable {

    var id: CKRecord.ID
    var name: String
    var description: String

    /// The original CloudKit record used for persistence operations.
    let record: CKRecord

    /// Creates a house model from a CloudKit record.
    ///
    /// - Parameter record: The CloudKit record representing the house.
    /// - Returns: A `House` instance when the record is valid;
    ///   otherwise `nil`.
    init?(record: CKRecord) {
        guard record.recordType == "House",
              let name = record["name"] as? String
        else {
            return nil
        }

        self.id = record.recordID
        self.name = name
        self.description = record["description"] as? String ?? ""
        self.record = record
    }

    /// Creates a new CloudKit record representing a house.
    ///
    /// - Parameters:
    ///   - name: The house name.
    ///   - description: The house description.
    ///   - zoneID: The CloudKit zone where the record will be stored.
    /// - Returns: A new unsaved `House` CloudKit record.
    static func newRecord(name: String,description: String,zoneID: CKRecordZone.ID) -> CKRecord {
        let id = CKRecord.ID(
            recordName: UUID().uuidString,
            zoneID: zoneID
        )

        let record = CKRecord(
            recordType: "House",
            recordID: id
        )

        record["name"] = name
        record["description"] = description

        return record
    }

    /// Creates a house through the shared CloudKit manager.
    ///
    /// - Parameters:
    ///   - name: The house name.
    ///   - description: The house description.
    static func createHouse(name: String,description: String) async {
        _ = await CloudKitManager.shared.createHouse(
            name: name,
            description: description
        )
    }

    /// Fetches the first house available to the current user.
    ///
    /// - Returns: A `House` instance when a house is found;
    ///   otherwise `nil`.
    static func fetchHouse() async -> House? {
        do {
            let record = try await CloudKitManager.shared.fetchHouse()
            return House(record: record)
        } catch {
            print("Failed to convert house record to House.")
            return nil
        }
    }

    /// Deletes a house from CloudKit.
    ///
    /// - Parameter house: The CloudKit record representing the house.
    static func deleteHouse(_ house: CKRecord) async {
        _ = await CloudKitManager.shared.deleteHouse(house)
    }

    /// Updates the local model and persists the specified house attributes.
    ///
    /// - Parameters:
    ///   - name: The new house name, or `nil` to keep the current value.
    ///   - description: The new house description, or `nil` to keep the
    ///     current value.
    func updateAttributes(name: String? = nil,description: String? = nil) async {
        if let name {
            self.name = name
        }

        if let description {
            self.description = description
        }

        _ = await CloudKitManager.shared.updateHouseAttributes(
            house: record,
            name: name,
            description: description
        )
    }
}
