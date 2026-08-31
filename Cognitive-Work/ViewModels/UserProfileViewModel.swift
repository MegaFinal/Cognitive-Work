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

    private(set) var user: UserModel

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

    init(user: UserModel, onAccountDeleted: @escaping () -> Void) {
        self.user = user
        self.onAccountDeleted = onAccountDeleted
    }

    var displayedImageData: Data? {
        isEditing ? editedProfilePicture : user.profilePicture
    }

    var hasUnsavedChanges: Bool {
        editedName != user.name || editedProfilePicture != user.profilePicture
    }

    var canSave: Bool {
        !isSaving && !editedName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func startEditing() {
        editedName = user.name
        editedProfilePicture = user.profilePicture
        selectedPhotoItem = nil
        isEditing = true
    }

    func cancelEditing() {
        selectedPhotoItem = nil
        isEditing = false
    }

    func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        var updatedUser = user
        updatedUser.name = editedName
        updatedUser.profilePicture = editedProfilePicture

        let success = await CloudKitManager.shared.update(updatedUser)

        if success {
            user = updatedUser
            isEditing = false
        } else {
            errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
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
}
