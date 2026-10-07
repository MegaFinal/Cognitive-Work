//
//  MemojiOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import SwiftUI
import PhotosUI

/// Onboarding step where the user picks a profile picture and a display name.
///
/// Saves the profile to CloudKit on "Continuar" and only advances once the
/// record actually comes back.
struct CreateProfileOnboardingView: View {
    
    // MARK: - Properties
    
    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel
    
    @State private var usernameText: String = ""
    
    /// Image chosen through the system photo picker, before it is converted.
    @State private var selectedItem: PhotosPickerItem? = nil
    
    /// `true` while the picked photo is being loaded and converted.
    @State private var isLoadingImage = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            headerText
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, height * 0.02)
            
            Spacer(minLength: 16)
            
            EditableProfileImage(image: viewModel.userProfilePicture, isEditing: true, selection: $selectedItem, isLoading: isLoadingImage)
            
            TextField("Nome", text: $viewModel.userName)
                .textFieldStyle(.plain)
                .font(.system(size: 43, weight: .bold))
                .foregroundColor(.primary)
                .accentColor(.blue)
                .multilineTextAlignment(.center)
                .characterLimit(TextLimits.userName, text: $viewModel.userName)
                .submitLabel(.done)
                .padding(.top, 32)
            
            Spacer(minLength: 16)
            
            OnboardingProgressButton(text: "Continuar", isLoading: viewModel.isLoading, isDisabled: viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty) {
                Task {
                    viewModel.isLoading = true
                    await viewModel.createUser()
                    if viewModel.currentUser != nil {
                        if viewModel.stateMachine.flow == .invitedWithoutProfile {
                            guard await viewModel.joinHouse() else {
                                viewModel.isLoading = false
                                return
                            }
                        }
                        viewModel.goToNextView()
                    }
                    viewModel.isLoading = false
                }
            }
            .padding(.bottom, height * 0.02)
        }
        .padding(.horizontal, width * 0.0565)
        .alert("Não deu para criar o perfil", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                isLoadingImage = true
                defer { isLoadingImage = false }
                
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    await MainActor.run {
                        viewModel.updateProfileImage(uiImage)
                    }
                }
            }
        }
        .dismissKeyboardOnTap()
    }
    
    // MARK: - Subviews
    
    /// Title and supporting copy for this onboarding step.
    private var headerText: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quem é você na casa?")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: false)

            
            Text("Escolha uma foto e um nome para utilizar no app")
                .font(.system(size: 16))
                .foregroundStyle(.gray)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    CreateProfileOnboardingView(viewModel: $viewModel)
        .environment(OnboardingViewModel())
}

