//
//  ProfileView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI
import PhotosUI

struct UserProfileView: View {
    @State private var viewModel = UserProfileViewModel()
    
    private var displayedUIImage: UIImage? {
        guard let data = viewModel.displayedImageData else { return nil }
        return UIImage(data: data)
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Carregando perfil...")
            }
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
                        Text(viewModel.user?.name ?? "")
                    }
                }
            }
        }
        .navigationTitle("Perfil")
        .task{
            await viewModel.loadUser()
        }
        .toolbar {
            ProfileEditToolbar(viewModel: viewModel)
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
        UserProfileView()
    }
}

