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
    
    var editedName: String = ""
    var editedProfilePicture: Data?
    var selectedPhotoItem: PhotosPickerItem? {
        didSet { loadSelectedPhoto() }
    }
    
    /// Called after a successful account deletion. Forwarded into `DeleteAccountButton`.
    let onAccountDeleted: () -> Void
    
    init(onAccountDeleted: @escaping () -> Void = {}) {
        self.onAccountDeleted = onAccountDeleted
    }
    
    var displayedImageData: Data? {
        isEditing ? editedProfilePicture : privateUser?.profilePicture
    }
    
    var hasUnsavedChanges: Bool {
        guard let privateUser else { return false }
        return editedName != privateUser.name || editedProfilePicture != privateUser.profilePicture
    }
    
    var canSave: Bool {
        !isSaving && !editedName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Loading
    
    /// Fetches the current user's record from CloudKit.
    ///
    /// Call from the view's `.task` modifier. Safe to call more than once (e.g. pull-to-refresh).
    func loadUser() async {
        isLoading = true
        defer { isLoading = false }

        privateUser = await CloudKitManager.shared.fetchMyUser()

        guard let myRecordID = try? await CloudKitManager.shared.container.userRecordID()
        else {
            errorMessage = "Não foi possível identificar a conta iCloud."
            return
        }

        let predicate = NSPredicate(
            format: "creatorUserRecordID == %@",
            CKRecord.Reference(recordID: myRecordID, action: .none)
        )

        user = await CloudKitManager.shared.fetchShared(UserModel.self, predicate: predicate).first

        if user == nil {
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
        editedProfilePicture = privateUser?.profilePicture
        selectedPhotoItem = nil
        isEditing = true
    }
    
    func cancelEditing() {
        selectedPhotoItem = nil
        isEditing = false
    }
    
    func saveChanges() async {
        guard let privateUser, let user
        else {
            print("saved not work")
            return
        }
        
        isSaving = true
        
        let updatedPrivateUser = privateUser
        updatedPrivateUser.name = editedName
        updatedPrivateUser.profilePicture = editedProfilePicture
        
        let updatedUser = user
        updatedUser.name = editedName
        updatedUser.profilePicture = editedProfilePicture
        
        let privatesuccess = await CloudKitManager.shared.update(updatedPrivateUser)
        let success = await CloudKitManager.shared.update(updatedUser)
        
        if success && privatesuccess {
            self.privateUser = updatedPrivateUser
            self.user = updatedUser
            isEditing = false
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
        }
        
        isSaving = false
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async {
        guard let privateUser, let user
        else { return }

        isSaving = true

        let privateSuccess = await CloudKitManager.shared.delete(privateUser)
        let success = await CloudKitManager.shared.delete(user)

        if success && privateSuccess {
            CloudKitManager.shared.clearCurrentUser()
            onAccountDeleted()
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
        }

        isSaving = false
    }
}
