//
//  ContentViewModel.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 17/08/26.
//

import Foundation
import CloudKit

/// Coordinates house persistence and CloudKit sharing for ``ContentView``.
///
/// > Warning: Temporary test implementation — **must be replaced**. Failures are printed to the
/// > console instead of being propagated, so callers cannot show an error to the user.
///
/// - TODO: Make these methods `throws` (or return `Result`) so ``ContentView`` can surface
///   failures. Owner: Jonas.
class ContentViewModel {

    /// Fetches the first house matching a predicate.
    ///
    /// - Parameter predicate: Filter applied to the query. Defaults to matching every record.
    /// - Returns: The first matching house, or `nil` when none exists.
    func loadHouse(predicate: NSPredicate = NSPredicate(value: true)) async -> HouseModel? {
        await CloudKitManager.shared
            .fetchAll(HouseModel.self, predicate: predicate)
            .first
    }

    /// Creates a house and a CloudKit share for it, returning the invitation link.
    ///
    /// Runs four steps in order: save the record, fetch its `CKRecord`, resolve a `CKShare`, and
    /// generate the share URL. If any step fails, the currently stored house is returned with a
    /// `nil` URL.
    ///
    /// - Parameters:
    ///   - houseName: Display name for the new house.
    ///   - description: Free-form description for the new house.
    /// - Returns: The stored house and the share URL, which is `nil` when sharing failed.
    ///
    /// > Important: This method also writes to CloudKit and creates the record zone, so it is not
    /// > side-effect free despite the value it returns.
    func createHouseAndShare(houseName: String, description: String) async -> (HouseModel?, URL?) {
        await CloudKitManager.shared.createZoneIfNeeded()

        let newHouse = HouseModel(name: houseName, description: description)

        guard let saved = await CloudKitManager.shared.create(newHouse) else {
            print(CloudKitManager.shared.errorMessage as Any)
            return (await loadHouse(), nil)
        }

        guard let record = await CloudKitManager.shared.fetchRecord(for: saved) else {
            print(CloudKitManager.shared.errorMessage as Any)
            return (await loadHouse(), nil)
        }

        guard let share = await CloudKitManager.shared.resolveShare(for: record) else {
            print(CloudKitManager.shared.errorMessage as Any)
            return (await loadHouse(), nil)
        }

        do {
            let shareURL = try await CloudKitManager.shared.generateShareLink(share: share)
            return (await loadHouse(), shareURL)
        } catch {
            print(CloudKitManager.shared.errorMessage as Any)
            return (await loadHouse(), nil)
        }
    }
}
