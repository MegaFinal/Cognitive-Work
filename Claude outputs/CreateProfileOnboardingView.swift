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
///
/// ## Onboarding audit — what changed and why
///
/// The doc comment above already described the intended behaviour; the implementation did not
/// match it in two ways:
///
/// - ``OnboardingViewModel/createUser()`` silently did nothing when no photo had been chosen,
///   because its entire body was nested inside `if let imageData = userProfilePicture?.jpegData(...)`.
///   The picture is optional in this UI — the button only requires a name — so tapping
///   "Continuar" without one produced no record, no error and no navigation. That is fixed in the
///   view model; this screen now also refuses to advance unless a profile really came back.
/// - For a guest arriving from an invite link (`invitedWithoutProfile`), `joinHouse()` was called
///   and its result ignored, then the flow advanced regardless. A guest whose join failed reached
///   the free-time screen with no public profile to write to, submitted nothing, and left the
///   admin's gate blocked on them indefinitely.
struct CreateProfileOnboardingView: View {

    // MARK: - Properties

    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    @State private var usernameText: String = ""

    /// Image chosen through the system photo picker, before it is converted.
    @State private var selectedItem: PhotosPickerItem? = nil

    // MARK: - Body

    var body: some View {
        VStack(alignment: .center, spacing: 58) {
            headerText

                EditableProfileImage(image: viewModel.userProfilePicture, isEditing: true, selection: $selectedItem)
                .layoutPriority(1)


            TextField("Nome", text: $viewModel.userName)
                .textFieldStyle(.plain)
                .font(.system(size: 43, weight: .bold))
                .foregroundColor(.primary)
                .accentColor(.blue)
                .multilineTextAlignment(.center)

            OnboardingProgressButton(
                            text: "Continuar",
                            isLoading: viewModel.isLoading,
                            isDisabled: viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            // 🚀 Removed manual isLoading assignments to prevent UI state crashes
                            await viewModel.createUser()

                            // Onboarding fix: `createUser()` now reports every failure through
                            // `errorMessage`, so a nil profile here always has a visible cause.
                            guard viewModel.currentUser != nil else { return }

                            if viewModel.stateMachine.flow == .invitedWithoutProfile {
                                // Onboarding fix: only advance when the guest actually became a
                                // member of the house. Advancing on a failed join is what sent
                                // people to the free-time screen with nowhere to save it.
                                guard await viewModel.joinHouse() else { return }
                            }

                            viewModel.goToNextView()
                        }

        }
        .navigationBarBackButtonHidden()
        .padding()
        .alert("Não deu para criar o perfil", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {

                    await MainActor.run {
                        viewModel.updateProfileImage(uiImage)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// Title and supporting copy for this onboarding step.
    private var headerText: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Para começarmos...")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))

            Text("Escolha uma foto e um nome para utilizar no app")
                .font(.callout)
                .foregroundStyle(.gray)
                .lineLimit(nil)
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    CreateProfileOnboardingView(viewModel: $viewModel)
        .environment(OnboardingViewModel())
}
