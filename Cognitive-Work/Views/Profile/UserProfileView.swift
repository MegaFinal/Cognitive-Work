//
//  ProfileView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI
import PhotosUI

struct UserProfileView: View {
    @State private var viewModelUser = UserProfileViewModel()
    @State private var viewModelHouse = HouseEditViewModel()
    
    private var displayedUIImage: UIImage? {
        guard let data = viewModelUser.displayedImageData else { return nil }
        return UIImage(data: data)
    }
    
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
                            TextField(viewModelUser.user?.name ?? "", text: $viewModelUser.editedName)
                                .textInputAutocapitalization(.words)
                        }
                        else {
                            Text(viewModelUser.user?.name ?? "")
                        }
                    }
                    if !viewModelUser.isEditing {
                        // MARK: House Information
                        Section("Minha Casa") {
                            // FIXME: Change for the house name if it exists
                            Text("Nome da casa")
                            HouseEditView(viewModel: viewModelHouse)
                        }
                        
                        
                        // MARK: Harware Conection
                        NavigationLink {
                            WifiCredentialsView()
                        } label: {
                            Text("Conectar com meu Hardware")
                        }
                    }
                }
            }
        }
//        .navigationTitle("Perfil")
        .task{
            await viewModelUser.loadUser()
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

