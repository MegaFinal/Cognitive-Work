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

    /// True while the member is leaving the house.
    private(set) var isLeaving = false

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
    @discardableResult
    func checkAdminStatus() async -> Bool {
        if house == nil {
            await fetchHouse()
        }

        guard let house
        else {
            isUserAdmin = false
            return false
        }

        isUserAdmin = await house.isAdmin() == true
        return true
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

    // MARK: - Leave

    /// Removes the signed-in member from the house (a non-admin can't delete it). The house and
    /// its data stay intact for the other residents.
    ///
    /// ``CloudKitManager/leaveCurrentHouse()`` removes the member's own record before leaving the
    /// share, so no ghost member stays in the house, and refuses the owner.
    @discardableResult
    func leaveHouse() async -> Bool {
        guard !isUserAdmin else {
            errorMessage = "The house admin can't leave the house"
            return false
        }

        isLeaving = true
        defer { isLeaving = false }

        // The in-house profile (and the free time on it) is removed when the member leaves.
        // Make sure the private profile holds the current free time first, so the next house gets
        // it without asking again. Best effort: it never blocks leaving.
        await FreeTimeSyncService.live().reconcile()

        guard (try? await CloudKitManager.shared.leaveCurrentHouse()) == true else {
            errorMessage = CloudKitManager.shared.errorMessage
            return false
        }

        house = nil
        errorMessage = nil
        prepareOnboardingAfterLosingHouse()
        return true
    }

    /// Makes the onboarding that opens after leaving or deleting a house start from the welcome
    /// screen (which leads to "create or enter a house"), not from a stale persisted step.
    private func prepareOnboardingAfterLosingHouse() {
        OnboardingStateMachine.clearPersistedProgress()
        OnboardingRollbackJournal.clear()
    }

    // MARK: - Delete

    /// Deletes the loaded house. Refuses — without ever calling CloudKit — unless the
    /// signed-in user is the one who created it.
    @discardableResult
    func deleteHouse() async -> Bool {
        guard let house else {
            errorMessage = "Failed to retrieve house"
            print(errorMessage as Any)
            return false
        }

        guard await house.isAdmin() == true else {
            errorMessage = "Failed to delete due to unauthorized credentials"
            print(errorMessage as Any)
            return false
        }

        isDeleting = true
        defer { isDeleting = false }

        // The admin's in-house profile is deleted with the house: keep the free time on the
        // private profile for the next one. Best effort.
        await FreeTimeSyncService.live().reconcile()

        guard await house.deleteAllChildren() else {
            errorMessage = "Failed to delete house children"
            print(errorMessage as Any)
            print(CloudKitManager.shared.errorMessage as Any)
            return false
        }
        
        guard await CloudKitManager.shared.delete(house) else {
            errorMessage = CloudKitManager.shared.errorMessage
            print(errorMessage as Any)
            return false
        }

        self.house = nil
        errorMessage = nil
        prepareOnboardingAfterLosingHouse()
        return true
    }

    func getOutOfTheHouse() async {
        guard let house else {
            errorMessage = "Failed to retrieve house"
            print(errorMessage as Any)
            return
        }
        
        guard await CloudKitManager.shared.delete(house) else {
            errorMessage = CloudKitManager.shared.errorMessage
            print(errorMessage as Any)
            return
        }
    }
}
