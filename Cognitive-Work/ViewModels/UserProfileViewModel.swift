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
            } else {
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
            }
        } else {
            let success = await CloudKitManager.shared.update(privateUser)
            if success {
                isEditing = false
            } else {
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
            }
        }
        
        isSaving = false
    }
    
    // MARK: - Delete Account
    
    /// Deletes the private profile and, when it exists, the in-house copy.
    func deleteAccount() async {
        guard let privateUser else {
            errorMessage = "Perfil não carregado. Tente novamente."
            return
        }
        
        isSaving = true
        
        if let user {
            async let deletePrivate = CloudKitManager.shared.delete(privateUser)
            async let deleteHouse = CloudKitManager.shared.delete(user)
            
            let (privateSuccess, houseSuccess) = await (deletePrivate, deleteHouse)
            
            if privateSuccess && houseSuccess {
                CloudKitManager.shared.clearCurrentUser()
                onAccountDeleted()
            } else {
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
            }
        } else {
            let success = await CloudKitManager.shared.delete(privateUser)
            if success {
                CloudKitManager.shared.clearCurrentUser()
                onAccountDeleted()
            } else {
                errorMessage = CloudKitManager.shared.errorMessage ?? "Erro desconhecido."
            }
        }
        isSaving = false
    }
}
