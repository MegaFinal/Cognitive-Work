//
//  HouseEditViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 31/08/26.
//

import Foundation
import CloudKit

/// Owns every house CRUD operation and returns admin state for views to read.
@MainActor
@Observable
final class HouseEditViewModel {

    /// The house currently loaded for display/editing.
    private(set) var house: HouseModel?

    /// True while a house is being fetched.
    private(set) var isLoading = false

    /// True while a delete is in flight.
    ///
    /// Kept separate from ``isLoading`` so the two operations can overlap without one
    /// switching the other's indicator off when it finishes first.
    private(set) var isDeleting = false

    private(set) var errorMessage: String?
    var isUserAdmin: Bool = false

    init(house: HouseModel? = nil) {
        self.house = house
    }

    // MARK: - Authorization

    /// Resolves ``isUserAdmin`` for the loaded house.
    ///
    /// Fetches a house first only when this view model wasn't handed one at init —
    /// otherwise the injected house would be silently replaced by whatever
    /// ``fetchHouse()`` happens to find.
    func checkAdminStatus() async {
        if house == nil {
            await fetchHouse()
        }

        guard let house
        else {
            isUserAdmin = false
            return
        }

        isUserAdmin = await house.isAdmin() == true
    }

    // MARK: - Fetch

    /// Loads a single house by its record ID.
    func fetchHouse() async {
        isLoading = true
        defer { isLoading = false }

        guard let fetchedHouse = try? await CloudKitManager.shared.fetchFirst(HouseModel.self)
        else {
            errorMessage = "Failed to retrieve the record"
            return
        }

        house = fetchedHouse
        errorMessage = nil
    }

    // MARK: - Delete

    /// Deletes the loaded house. Refuses — without ever calling CloudKit — unless the
    /// signed-in user is the one who created it.
    @discardableResult
    func deleteHouse() async -> Bool {
        guard let house else {
            errorMessage = "Failed to retrieve house"
            print(errorMessage)
            return false
        }

        guard await house.isAdmin() == true else {
            errorMessage = "Failed to delete due to unauthorized credentials"
            print(errorMessage)
            return false
        }

        isDeleting = true
        defer { isDeleting = false }

        guard await house.deleteAllChildren() else {
            errorMessage = "Failed to delete house children"
            print(errorMessage)
            print(CloudKitManager.shared.errorMessage)
            return false
        }
        
        guard await CloudKitManager.shared.delete(house) else {
            errorMessage = CloudKitManager.shared.errorMessage
            print(errorMessage as Any)
            return false
        }

        self.house = nil
        errorMessage = nil
        return true
    }
}
