//
//  EditProfileView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Bindable var viewModel: UserProfileViewModel
        
    
    var body: some View {
        VStack(spacing: 40) {
            // MARK: - Photo Picker
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    if let data = viewModel.displayedImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width * 0.7, height: width * 0.7)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.25), radius: 7.26429, x: 0, y: 5.38095)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.gray)
                            .frame(width: width * 0.7, height: width * 0.7)
                            .background(.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.25), radius: 7.26429, x: 0, y: 5.38095)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // MARK: - Name Textfield
            HStack {
                Spacer()
                TextField(
                    "",
                    text: $viewModel.editedName,
                    prompt: Text("Seu Nome")
                        .foregroundStyle(.gray)
                )
                .font(.system(size: 34))
                .frame(width: width * 0.8)
                .multilineTextAlignment(.center)
                .bold()
                Spacer()
            }
            
            Spacer()
        }
        .padding(.top, 70)
        .navigationTitle("Editar Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSaving)
        .onAppear {
            viewModel.startEditing()
        }
        .toolbar {
            // MARK: - Save Button
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await viewModel.saveChanges()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .bold()
                        .foregroundColor(.white)
                        .padding(10)
                }
                .glassEffect(
                    .regular.interactive().tint(.blue),
                    in: .circle
                )
                .disabled(!viewModel.canSave)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        // MARK: - Error Alert
        .alert(
            "Erro ao salvar",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    let mockUser = UserModel(
        name: "Dayô Araújo",
        tier: .tier1,
        ownerRecordName: "preview-owner"
    )
    let mockViewModel = UserProfileViewModel(user: mockUser)

    return NavigationStack {
        EditProfileView(viewModel: mockViewModel)
    }
}
