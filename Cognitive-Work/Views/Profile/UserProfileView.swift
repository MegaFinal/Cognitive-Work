//
//  ProfileView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI
import PhotosUI

struct UserProfileView: View {
    @State private var viewModel: UserProfileViewModel
    
    init(user: UserModel, onAccountDeleted: @escaping () -> Void) {
        _viewModel = State(
            initialValue: UserProfileViewModel(user: user, onAccountDeleted: onAccountDeleted)
        )
    }
    
    private var displayedUIImage: UIImage? {
        guard let data = viewModel.displayedImageData else { return nil }
        return UIImage(data: data)
    }
    
    var body: some View {
        Form {
            Section {
                EditableProfileImage(
                    image: displayedUIImage,
                    isEditing: viewModel.isEditing,
                    selection: $viewModel.selectedPhotoItem
                )
            }
            .listRowBackground(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            
            Section("Nome") {
                if viewModel.isEditing {
                    TextField("Nome", text: $viewModel.editedName)
                        .textInputAutocapitalization(.words)
                }
                else {
                    Text(viewModel.user.name)
                }
            }
        }
        .navigationTitle("Perfil")
        .toolbar {
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
                    DeleteAccountButton(user: viewModel.user, onDeleted: viewModel.onAccountDeleted)
                        .foregroundStyle(.red)
                }
            }
        }
        
        // MARK: Alert if didn't save
        .alert(
            "Não foi possível salvar",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        
        .overlay {
            if viewModel.isSaving {
                ProgressView()
            }
        }
    }
}
    // MARK: - Preview
    
    #Preview("Visualização") {
        NavigationStack {
            UserProfileView(
                user: UserModel(
                    name: "Jonas Melo",
                    profilePicture: nil,
                    tier: .tier1,
                    coins: 120,
                    points: 340,
                    couponLimit: 3
                ),
                onAccountDeleted: {}
            )
        }
    }

