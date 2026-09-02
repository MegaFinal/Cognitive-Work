//
//  UserProfileViewModel.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import Foundation
import PhotosUI
import _PhotosUI_SwiftUI

@Observable
final class UserProfileViewModel {
    
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
        isEditing ? editedProfilePicture : user?.profilePicture
    }
    
    var hasUnsavedChanges: Bool {
        guard let user else { return false }
        return editedName != user.name || editedProfilePicture != user.profilePicture
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
        
        user = await CloudKitManager.shared.fetchMyUser()
        if user == nil {
            errorMessage = CloudKitManager.shared.errorMessage
        }
        
        isLoading = false
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
        editedName = user?.name ?? ""
        editedProfilePicture = user?.profilePicture
        selectedPhotoItem = nil
        isEditing = true
    }
    
    func cancelEditing() {
        selectedPhotoItem = nil
        isEditing = false
    }
    
    func saveChanges() async {
        guard let user else { return }
        
        isSaving = true
        
        var updatedUser = user
        updatedUser.name = editedName
        updatedUser.profilePicture = editedProfilePicture
        
        let success = await CloudKitManager.shared.update(updatedUser)
        
        if success {
            self.user = updatedUser
            isEditing = false
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
        }
        
        isSaving = false
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async {
        guard let user else { return }

        isSaving = true

        let success = await CloudKitManager.shared.delete(user)

        if success {
            CloudKitManager.shared.clearCurrentUser()
            onAccountDeleted()
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
        }

        isSaving = false
    }
}
