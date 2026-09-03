//
//  ProfileView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI
import PhotosUI

/// A screen that displays and manages the current user's profile.
///
/// `UserProfileView` is responsible for loading the current user's information from CloudKit
/// through ``UserProfileViewModel`` and presenting it in a form-based interface.
///
/// The screen supports:
/// - Viewing and editing the user's display name.
/// - Viewing and changing the profile picture.
/// - Displaying information about the user's house.
/// - Navigating to the hardware Wi-Fi connection flow.
/// - Deleting the current user's account.
///

struct UserProfileView: View {
    @State private var viewModelUser = UserProfileViewModel()
    @State private var viewModelHouse = HouseEditViewModel()
    @State private var viewModelHardware = HardwareViewModel()
    
    /// Converts the currently displayed profile picture data into a `UIImage`. During editing this uses the temporary selected image; otherwise it displays the image stored in CloudKit.
    private var displayedUIImage: UIImage? {
        guard let data = viewModelUser.displayedImageData else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - View
    var body: some View {
        NavigationStack {
            Group {
                if viewModelUser.isLoading {
                    ProgressView("Carregando perfil...")
                }
                Form {
                    
                    // MARK: Profile Picture
                    Section {
                        EditableProfileImage(
                            image: displayedUIImage,
                            isEditing: viewModelUser.isEditing,
                            selection: $viewModelUser.selectedPhotoItem
                        )
                    }
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    
                    // MARK: User Information
                    Section("Nome") {
                        if viewModelUser.isEditing {
                            TextField(viewModelUser.privateUser?.name ?? "", text: $viewModelUser.editedName)
                                .textInputAutocapitalization(.words)
                        }
                        else {
                            Text(viewModelUser.privateUser?.name ?? "")
                        }
                    }
                    if !viewModelUser.isEditing {
                        // MARK: House Information
                        Section("Minha Casa") {
                            // FIXME: Change for the house name if it exists
                            Text("Nome da casa")
                            
                            // MARK: Delete house button
                            HouseEditView(viewModel: viewModelHouse)
                        }
                        
                        
                        // MARK: Harware Conection
                        NavigationLink {
                            Group {
                                if viewModelHardware.hardwareIp != nil {
                                    ExistingIPView(viewModelHardware: $viewModelHardware, image: displayedUIImage)
                                } else {
                                    WifiCredentialsView()
                                }
                            }
                        } label: {
                            Text("Conectar com meu Hardware")
                        }
                    }
                }
            }
        }
        
        // MARK: Task
        .task{
            await viewModelUser.loadUser()
            await viewModelHardware.fetchIp()
        }
        
        .toolbar {
            profileEditToolbar(viewModel: viewModelUser)
        }
        
        // MARK: Alert if didn't save
        .alert(
            "Não foi possível salvar",
            isPresented: Binding(
                get: { viewModelUser.errorMessage != nil },
                set: { if !$0 { viewModelUser.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
        message: {
            Text(viewModelUser.errorMessage ?? "")
        }
        
        .overlay {
            if viewModelUser.isSaving {
                ProgressView()
            }
        }
    }
    
    //MARK: ToolBarContent
    /// Toolbar used by ``UserProfileView`` to switch between viewing and editing modes.
    
    private struct profileEditToolbar: ToolbarContent {
        @Bindable var viewModel: UserProfileViewModel
        
        var body: some ToolbarContent {
            if viewModel.isEditing {
                
                ToolbarItem(placement: .confirmationAction) {
                    Button{
                        Task { await viewModel.saveChanges() }
                    } label:{
                        Text("Salvar")
                            .foregroundStyle(.blue)
                    }
                    .disabled(viewModel.isSaving || viewModel.editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        viewModel.cancelEditing()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            
            else{
                ToolbarItem(placement: .confirmationAction){
                    Button("Editar") {
                        viewModel.startEditing()
                    }
                }
                // MARK: Delete account button
                ToolbarItem (placement: .cancellationAction) {
                    DeleteAccountButton(viewModel: viewModel)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Visualização") {
    NavigationStack {
        UserProfileView()
    }
}

