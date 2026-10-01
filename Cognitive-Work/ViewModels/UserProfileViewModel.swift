//
//  UserProfileViewModel.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import Foundation
import PhotosUI
import _PhotosUI_SwiftUI
import CloudKit

@Observable
final class UserProfileViewModel {
    
    private(set) var privateUser: UserModel?
    private(set) var user: UserModel?
    private(set) var isLoading: Bool = false
    
    var isEditing = false
    var isSaving = false
    var errorMessage: String?
    /// Set to `true` right after ``saveChanges()`` persists successfully, so the view can show
    /// a brief success confirmation. The view resets it once that confirmation is dismissed.
    var didSaveSuccessfully = false
    
    var editedName: String = ""
    var editedProfilePicture: Data?
    var selectedPhotoItem: PhotosPickerItem? {
        didSet { loadSelectedPhoto() }
    }
    
    /// Apple Calendar synchronization switch managed by the ViewModel.
    ///
    /// Toggling this property automatically requests calendar access and performs
    /// full synchronization when enabled, or clears all synchronized events when disabled.
    /// The state is persisted in `UserDefaults`.
    var isCalendarSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "isCalendarSyncEnabled") {
        didSet {
            guard oldValue != isCalendarSyncEnabled else { return }
            UserDefaults.standard.set(isCalendarSyncEnabled, forKey: "isCalendarSyncEnabled")
            
            // A revert caused by a denied permission must not run the "turned off" branch
            // (which used to remove points that were never granted).
            if isRevertingCalendarSync {
                isRevertingCalendarSync = false
                return
            }
            
            let enabled = isCalendarSyncEnabled
            Task { await handleCalendarSyncChange(enabled: enabled) }
        }
    }
    
    /// `true` while the calendar is being synchronized or cleaned up, so the settings screen can
    /// show progress next to the switch.
    private(set) var isSyncingCalendar = false
    
    /// Set right before the switch is programmatically reverted after a denied permission.
    @ObservationIgnored
    private var isRevertingCalendarSync = false
    
    /// Requests access and syncs (or cleans up) the calendar, then awards/removes the points.
    ///
    /// Before, the points were requested with an unawaited `async let`, which Swift cancels
    /// when the scope ends, and they were awarded even when the permission was denied.
    private func handleCalendarSyncChange(enabled: Bool) async {
        isSyncingCalendar = true
        defer { isSyncingCalendar = false }
        
        if enabled {
            guard await CalendarManager.shared.requestAccess() else {
                isRevertingCalendarSync = true
                isCalendarSyncEnabled = false
                return
            }
            await syncMyAllChoresToCalendar()
            _ = await ScoreManager.shared.assignScoreForMyUser(score: ScoreValues.appleCalendarLinked.points)
        } else {
            await removeAllMyAssignmentsFromCalendar()
            _ = await ScoreManager.shared.removeScoreForMyUser(score: ScoreValues.appleCalendarLinked.points)
        }
    }
    
    init(user: UserModel? = nil, onAccountDeleted: @escaping () -> Void = {}) {
        self.user = user
        self.onAccountDeleted = onAccountDeleted
    }
    
    /// Called after a successful account deletion. Forwarded into `DeleteAccountButton`.
    let onAccountDeleted: () -> Void
    
    init(onAccountDeleted: @escaping () -> Void = {}) {
        self.onAccountDeleted = onAccountDeleted
    }
    
    var displayedImageData: Data? {
        if isEditing {
            return editedProfilePicture
        }
        
        if let fileURL = privateUser?.profilePicture?.fileURL {
            do {
                return try Data(contentsOf: fileURL)
            }
            catch {
                print("error to convert Image no data")
                return nil
            }
        }
        return nil
    }
    
    var hasUnsavedChanges: Bool {
        guard let privateUser else { return false }
        return editedName != privateUser.name || editedProfilePicture != privateUser.profilePicture?.fileURL?.dataRepresentation
    }
    
    var canSave: Bool {
        !isSaving && !editedName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Loading
    
    /// Fetches both of the current user's records from CloudKit: the private profile and the
    /// copy that lives inside the house.
    ///
    /// Call from the view's `.task` modifier. Safe to call more than once (e.g. pull-to-refresh).
    ///
    /// > Note: ``user`` being `nil` is a normal state — the person may not have created or
    /// > joined a house yet, or the house may have been deleted. Editing the private profile
    /// > keeps working either way.
    func loadUser() async {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
        
        isLoading = true
        defer { isLoading = false }
        
        async let fetchPrivate = CloudKitManager.shared.fetchMyUser()
        async let fetchHouse = CloudKitManager.shared.fetchMyHouseUser()
        
        let (fetchedPrivate, fetchedHouse) = await (fetchPrivate, fetchHouse)
        
        privateUser = fetchedPrivate
        user = fetchedHouse
        
        if privateUser == nil {
            errorMessage = CloudKitManager.shared.errorMessage
        }
    }
    
    private func loadSelectedPhoto() {
        guard let selectedPhotoItem else { return }
        Task {
            if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                editedProfilePicture = data
            }
        }
    }
    
    // MARK: - Editing Account
    
    func startEditing() {
        editedName = privateUser?.name ?? ""
        if let fileURL = privateUser?.profilePicture?.fileURL {
            do {
                editedProfilePicture = try Data(contentsOf: fileURL)
            }
            catch {
                print("error to start editing, cannot convert data")
            }
        }
        selectedPhotoItem = nil
        didSaveSuccessfully = false
        isEditing = true
    }
    
    func cancelEditing() {
        selectedPhotoItem = nil
        isEditing = false
    }
    
    /// Writes the edited name and picture to the private profile and, when it exists, to the
    /// in-house copy as well.
    ///
    /// The in-house copy is what housemates see, so both records have to move together — but
    /// its absence is not an error (see ``loadUser()``), it just means there is no house yet.
    func saveChanges() async {
        guard let privateUser else {
            errorMessage = L10n.tr("Perfil não carregado. Tente novamente.")
            return
        }
        
        isSaving = true
        
        // Snapshot so a failed save doesn't leave the unsaved name/photo on screen.
        let previousPrivateName = privateUser.name
        let previousPrivatePicture = privateUser.profilePicture
        let previousHouseName = user?.name
        let previousHousePicture = user?.profilePicture
        
        privateUser.name = editedName
        
        if let editedProfilePicture {
            privateUser.profilePicture = CloudKitManager.shared.createAsset(from: editedProfilePicture)
        }
        
        if let user {
            user.name = editedName
            if let editedProfilePicture {
                user.profilePicture = CloudKitManager.shared.createAsset(from: editedProfilePicture)
            }
            
            async let updatePrivate = CloudKitManager.shared.update(privateUser)
            async let updateHouse = CloudKitManager.shared.update(user)
            
            let (privateSuccess, houseSuccess) = await (updatePrivate, updateHouse)
            
            if privateSuccess && houseSuccess {
                isEditing = false
                didSaveSuccessfully = true
            } else {
                if !privateSuccess {
                    privateUser.name = previousPrivateName
                    privateUser.profilePicture = previousPrivatePicture
                }
                if !houseSuccess, let previousHouseName {
                    user.name = previousHouseName
                    user.profilePicture = previousHousePicture
                }
                errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Erro desconhecido.")
            }
        } else {
            let success = await CloudKitManager.shared.update(privateUser)
            if success {
                isEditing = false
                didSaveSuccessfully = true
            } else {
                privateUser.name = previousPrivateName
                privateUser.profilePicture = previousPrivatePicture
                errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Erro desconhecido.")
            }
        }
        
        isSaving = false
    }
    
    // MARK: - Delete Account

    /// Deletes everything this account has in the app and detaches it from every house.
    func deleteAccount() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        
        guard await CloudKitManager.shared.deleteCurrentAccount() else {
            errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Não foi possível excluir o perfil. Tente novamente.")
            return
        }
        
        privateUser = nil
        user = nil
        onAccountDeleted()
    }
    
    // MARK: - Calendar
    
    /// Synchronizes all chores (recurrent and one-off) assigned to the current user to Apple Calendar.
    private func syncMyAllChoresToCalendar() async {
        // Fetch the current house user
        guard let myHouseUser = await CloudKitManager.shared.fetchMyHouseUser(),
              let myUserID = myHouseUser.recordID else {
            print("Sync failed: Could not fetch the current house user record.")
            return
        }
        
        // Fetch all chore data
        let allChores = await CloudKitManager.shared.fetchAll(ChoreModel.self)
        var choresMap: [CKRecord.ID: ChoreModel] = [:]
        for chore in allChores {
            if let choreID = chore.recordID {
                choresMap[choreID] = chore
            }
        }
        
        // Fetch all recurrent assignment instances
        let allAssignments = await CloudKitManager.shared.fetchAll(RecurrentAssignmentModel.self)
        
        // Call CalendarManager's unified batch sync entry
        await CalendarManager.shared.batchSyncAllChores(
            allAssignments,
            allChores: allChores,
            choresMap: choresMap,
            currentUserID: myUserID
        )
        
        print("All chores synchronized to Apple Calendar successfully!")
    }
    
    /// Clears all chore events belonging to the user from Apple Calendar.
    private func removeAllMyAssignmentsFromCalendar() async {
        // Clear all events under the calendar instantly
        await CalendarManager.shared.clearAllMyCalendarEvents()
        print("Successfully removed all user chore schedules from Apple Calendar.")
    }
}
