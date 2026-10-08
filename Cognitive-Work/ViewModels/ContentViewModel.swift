//
//  ContentViewModel.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 17/08/26.
//

import Foundation
import CloudKit
import SwiftUI

@MainActor
@Observable
class ContentViewModel {
    var errorMessage: String? = nil
    
    /// Whether the "already in a house" warning is being presented.
    var showInviteAcceptAlert: Bool = false
    
    /// Metadata of the invitation that triggered the warning.
    var shareMetadata: CKShare.Metadata? = nil
    var isSwitchingHouse = false
    
    @ObservationIgnored
    @AppStorage("didOnboard") private var didOnboard: Bool = true
    
    // MARK: - House verification
    
    var userHasNoHouse: Bool = false
    
    private var hasFetchedInitially = false
    
    var isLoading = false      // first loading
    var isRefreshing = false   // others loadings
    
    /// Fetches the user house and verify if its exist
    func fetchHouse() async {
        print("fetchHouse")
        
        let isFirstLoad = !hasFetchedInitially
        if isFirstLoad { isLoading = true }
        defer { if isFirstLoad { isLoading = false } }
        
        do {
            let house = try await CloudKitManager.shared.currentHouse(forceRefresh: true)
            guard !Task.isCancelled else { return }
            userHasNoHouse = (house == nil)
            hasFetchedInitially = true
        } catch let error as CKError where [.zoneNotFound, .userDeletedZone, .unknownItem].contains(error.code) {
            userHasNoHouse = true   // the house is really gone
        } catch {
            print("currentHouse falhou:", type(of: error), error)
            if let ck = error as? CKError {
                print("   CKError code:", ck.code.rawValue, ck.code)
                print("   partial errors:", ck.partialErrorsByItemID ?? [:])
            }
            guard !Task.isCancelled else { return }
            errorMessage = L10n.tr("Não foi possível carregar a casa. Verifique sua conexão.")
            return
        }
    }
    
    func accountWithoutHouseReturnToOnboarding() {
        Self.resetOnboardingProgress()
        self.didOnboard = false
    }
    
    /// The onboarding that opens next must start at the welcome screen, not resume a stale step.
    static func resetOnboardingProgress() {
        OnboardingStateMachine.clearPersistedProgress()
        OnboardingRollbackJournal.clear()
    }
    
    func switchHouse(to metadata: CKShare.Metadata) async {
        await CloudKitManager.shared.switchHouse(to: metadata)
        self.errorMessage = CloudKitManager.shared.errorMessage
    }
    
    // MARK: - Free time

    /// Makes the free time on the private profile and on the house profile agree, and retries a
    /// write to the house profile that failed earlier (see `FreeTimeSyncService`). Best effort:
    /// a failure is simply tried again the next time the app opens.
    func syncFreeTime() async {
        guard !userHasNoHouse else { return }
        await FreeTimeSyncService.live().reconcile()
    }

    // MARK: - Orphaned houses

    /// Leaves any house this iCloud account is still attached to without a member record
    func leaveOrphanedHouses() async {
        let removed = await CloudKitManager.shared.pruneOrphanedSharedMemberships()
        guard removed > 0 else { return }
        do {
            if try await CloudKitManager.shared.currentHouse(forceRefresh: true) == nil {
                Self.resetOnboardingProgress()
                didOnboard = false
            } else {
                NotificationCenter.default.post(name: .cloudKitDidChange, object: nil)
            }
        } catch {
            // Could not confirm whether a house is left (network, etc.).
            // Do nothing now; the next fetchHouse() will settle it.
        }
    }
}
