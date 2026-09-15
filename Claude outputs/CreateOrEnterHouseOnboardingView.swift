//
//  ThirdOnboardingView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// The step where the user chooses whether to join an existing house
/// or create a new one
/// On success the flow advances to ``FourthOnboardingView``
///
/// ## Onboarding audit — what changed and why
///
/// This is the screen behind "I interrupted the flow right after creating my profile and now
/// creating a house does nothing / the app closes".
///
/// - **The profile is reloaded before the action runs.** `createHouseAndLinkUser()` opened with
///   `guard let user = currentUser`, and `currentUser` is only populated in memory — a relaunch
///   arrives here with it `nil`. The view model now recovers the profile from CloudKit first
///   (see ``OnboardingViewModel/createHouseAndLinkUser()``), and this screen warms it up on
///   appear so the very first tap already has what it needs.
/// - **The dead end is gone.** When the profile genuinely cannot be recovered the user used to
///   get an alert on a screen with no back button and no other control: the flow was over. There
///   is now an explicit route back to profile creation, and the alert text distinguishes "you
///   never created a profile" from "we cannot reach iCloud right now".
/// - **The buttons wait for the bootstrap.** Both were tappable while `Onboarding`'s startup work
///   was still running. Tapping "Criar uma casa" during that window raced the restore — and,
///   before the destructive reset was removed from `Onboarding.swift`, raced a zone deletion that
///   was concurrently destroying the records being written. They are now disabled until the
///   session has settled.
struct CreateOrEnterHouseOnboardingView: View {

    // MARK: - Properties

    /// The shared onboarding view model, read from the environment
    @Binding var viewModel: OnboardingViewModel

    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height

    /// Whether the "your profile is missing" recovery alert is showing.
    ///
    /// - Note: **Onboarding fix:** kept separate from the generic error alert so the recovery
    ///   action (go back and create the profile) can be offered as a real button.
    @State private var showsProfileRecovery = false

    /// Whether the buttons are usable yet.
    ///
    /// - Note: **Onboarding fix:** guards against acting before `Onboarding`'s bootstrap has
    ///   restored the session.
    private var isBusy: Bool {
        viewModel.isLoading || viewModel.isCheckingAccount
    }

    // MARK: - Body
    //
    // Two branching actions: joining an existing house switches the flow to
    // `.invitedWithProfile`, creating one saves the house before advancing.

    var body: some View {
        VStack {
            OnboardingHeader(
                title: "Para começarmos",
                description: "Você pode entrar em uma casa existente através de um convite, ou criar uma nova."
            )

            Spacer()

            HStack(spacing: 15) {
                Button {
                    viewModel.stateMachine.flow = .invitedWithProfile
                    viewModel.goToNextView()
                } label: {
                    VStack (spacing: 40){
                        Image(systemName: "figure.walk.arrival")
                            .resizable()
                            .frame(width: width * 0.22, height: height * 0.11)

                        VStack {
                            Text("Entrar")
                                .bold()
                            Text("em uma casa")
                        }
                    }
                    .foregroundColor(.blue)
                    .frame(width: width * 0.4, height: height * 0.4)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.25), radius: 5.95, x: 0, y: 4)
                    )
                }
                .disabled(isBusy)

                Button {
                    Task {
                        await createHouse()
                    }
                } label: {
                    VStack (spacing: 40){
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        } else {
                            Image(systemName: "house")
                                .resizable()
                                .frame(width: width * 0.24, height: height * 0.1)

                            VStack {
                                Text("Criar")
                                    .bold()
                                Text("uma casa")
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: width * 0.4, height: height * 0.4)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .foregroundColor(isBusy ? .gray : .blue)
                            .shadow(color: .black.opacity(0.25), radius: 5.95, x: 0, y: 4)
                    )
                }
                .disabled(isBusy)
            }
            Spacer()
        }
        .task {
            // Onboarding fix: pull the private profile into memory before the person can tap
            // anything, so a resumed session does not fail its first attempt.
            if viewModel.privateUser == nil {
                await viewModel.fetchCurrentUser()
            }
        }
        .alert("Não deu para criar a casa", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // MARK: - Profile recovery
        //
        // Onboarding fix: the only exit this screen used to offer was an alert with a single
        // "OK" button, on a screen with the navigation bar's back button hidden.
        .alert("Seu perfil não foi encontrado", isPresented: $showsProfileRecovery) {
            Button("Criar perfil") {
                viewModel.goToPreviousView()
            }
            Button("Tentar novamente") {
                Task { await createHouse() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Precisamos do seu perfil para criar a casa. Você pode voltar e criá-lo agora.")
        }
    }

    // MARK: - Actions

    /// Creates the house, recovering the profile first when it is not loaded.
    ///
    /// - Important: Explicitly `@MainActor`, because the closures `.task` and `Button` take are
    ///   `@Sendable` and carry no isolation of their own.
    @MainActor
    private func createHouse() async {
        // Last-chance recovery before bothering the person about it.
        if viewModel.privateUser == nil {
            await viewModel.fetchCurrentUser()
        }

        guard viewModel.privateUser != nil || viewModel.currentUser != nil else {
            showsProfileRecovery = true
            return
        }

        await viewModel.createHouseAndLinkUser()

        if viewModel.currentHouse != nil {
            viewModel.stateMachine.flow = .houseCreator
            viewModel.goToNextView()
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    CreateOrEnterHouseOnboardingView(viewModel: $viewModel)
}
