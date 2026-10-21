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
    
    /// Not used: the name is typed into ``OnboardingViewModel/userName``.
    @State private var usernameText: String = ""
    
    /// Image chosen through the system photo picker, before it is converted.
    @State private var selectedItem: PhotosPickerItem? = nil
    
    /// `true` while the picked photo is being loaded and converted.
    @State private var isLoadingImage = false
    
    /// Whether the banner picker sheet is open.
    @State private var isPickingBanner = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            OnboardingHeader(
                title: "Quem é você na casa?",
                description: "Escolha uma foto e um nome para utilizar no app",
                containerInset: width * 0.0565
            )
            
            Spacer(minLength: 16)
            
            // MARK: - Photo with banner
            EditableProfileImage(
                image: viewModel.userProfilePicture,
                isEditing: true,
                selection: $selectedItem,
                isLoading: isLoadingImage,
                banner: viewModel.userBanner,
                onEditBanner: { isPickingBanner = true }
            )
            .disabled(viewModel.isLoading)
            
            // MARK: - Name field
            TextField("Nome", text: $viewModel.userName)
                .textFieldStyle(.plain)
                .font(.system(size: 43, weight: .bold))
                .foregroundColor(.primary)
                .accentColor(.blue)
                .multilineTextAlignment(.center)
                .characterLimit(TextLimits.userName, text: $viewModel.userName)
                .submitLabel(.done)
                .padding(.top, 52)
                .accessibilityLabel(Text(L10n.tr("Nome")))
                .voiceControlNames([L10n.tr("Nome"), L10n.tr("Seu nome")])
                .accessibilityHint(Text(L10n.tr("Como os outros moradores vão te ver no app")))
            
            Spacer(minLength: 16)
            
            // MARK: - "Continuar": saves the profile (and joins the house when invited)
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
        // MARK: - Error alert
        .alert("Não deu para criar o perfil", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // MARK: - Loading the picked photo
        .onChange(of: isLoadingImage) { wasLoading, isLoading in
            if wasLoading && !isLoading { VoiceOver.announce(L10n.tr("Foto atualizada")) }
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
        // MARK: - Banner picker
        .sheet(isPresented: $isPickingBanner) {
            ProfileBannerSheet(banner: viewModel.userBanner, image: viewModel.userProfilePicture) { banner in
                viewModel.userBanner = banner
            }
        }
        .dismissKeyboardOnTap()
        .onboardingBackButton(viewModel: viewModel)
        .onAppear {
            // Coming back to this step with a profile kept from an earlier run: show its name.
            if viewModel.userName.isEmpty, let user = viewModel.currentUser {
                viewModel.userName = user.name
                viewModel.userBanner = user.banner
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    CreateProfileOnboardingView(viewModel: $viewModel)
        .environment(OnboardingViewModel())
}

