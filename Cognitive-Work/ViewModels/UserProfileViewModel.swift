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
            UserDefaults.standard.set(isCalendarSyncEnabled, forKey: "isCalendarSyncEnabled")
            
            // Handle permission and sync/cleanup logic asynchronously
            Task {
                if isCalendarSyncEnabled {
                    let granted = await CalendarManager.shared.requestAccess()
                    if granted {
                        // Permission granted: perform full synchronization
                        await syncMyAllChoresToCalendar()
                    } else {
                        // Permission denied: revert the switch to false
                        await MainActor.run {
                            self.isCalendarSyncEnabled = false
                        }
                    }
                } else {
                    // Switch turned off: remove all synchronized events from the calendar
                    await removeAllMyAssignmentsFromCalendar()
                }
            }
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
            errorMessage = "Perfil não carregado. Tente novamente."
            return
        }
        
        isSaving = true
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
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
            }
        } else {
            let success = await CloudKitManager.shared.update(privateUser)
            if success {
                isEditing = false
                didSaveSuccessfully = true
            } else {
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
            }
        }
        
        isSaving = false
    }
    
    // MARK: - Delete Account

    /// Deletes the private profile and, when it exists, fully detaches the in-house copy.
    func deleteAccount() async {
        guard let privateUser else {
            errorMessage = "Perfil não carregado. Tente novamente."
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        if let user {
            // Resolve the house and ownership before either record is gone
            let house = await user.house
            let isHouseOwner = await house?.isAdmin() == true
            
            if let house, isHouseOwner {
                // Owner: the whole house is deleted along with the account.
                guard await house.deleteAllChildren() else {
                    errorMessage = "Erro ao apagar os dados da casa."
                    return
                }
                guard await CloudKitManager.shared.delete(house) else {
                    errorMessage = CloudKitManager.shared.errorMessage ?? "Erro ao apagar a casa."
                    return
                }
            } else {
                do {
                    _ = try await CloudKitManager.shared.leaveCurrentHouse()
                } catch {
                    print("Failed to fully leave house while deleting account: \(error)")
                }
            }
        }
        
        guard await CloudKitManager.shared.delete(privateUser) else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
            return
        }
        
        CloudKitManager.shared.clearCurrentUser()
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
