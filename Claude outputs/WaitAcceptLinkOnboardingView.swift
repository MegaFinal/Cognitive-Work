//
//  WaitAcceptLinkOnboardingView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 01/09/26.
//


import SwiftUI

/// Step shown after the user chooses to join an existing house.
///
/// The app cannot advance on its own here: the user has to open the invite link
/// they received, which triggers the system share-acceptance flow. ``Onboarding``
/// listens for `.didAcceptShare` and moves the flow forward once that happens.
///
/// ## Onboarding audit — what changed and why
///
/// - **The "already accepted" check ran once.** `.task` fires when the view is inserted, which
///   is *before* the person leaves to open the link. Accepting the invite while the app was in
///   the background therefore relied entirely on `.didAcceptShare` — and that notification is
///   posted from `AppDelegate`/`SceneDelegate`, which only run their handler when iOS routes the
///   share back into a live process. When it did not (app relaunched cold from the link, handler
///   raced the view's construction), this screen waited forever. It now re-checks on foreground
///   and on a timer.
/// - **The join result was ignored.** The flow advanced with `goToNextView()` whether or not the
///   public profile had been created, which is how guests reached the free-time screen with no
///   record to write to.
/// - **There was no way back that worked.** "Voltar" calls `goToPreviousView()`, which is correct,
///   but the screen offered nothing when the invite simply never arrived. The copy now explains
///   the state and the manual check is available.
struct WaitAcceptLinkOnboardingView: View {
    // MARK: - Properties

    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    /// Drives an immediate re-check when the person returns from the share sheet.
    @Environment(\.scenePhase) private var scenePhase

    /// How often the screen re-checks whether the share has become reachable.
    private static let pollInterval: Duration = .seconds(5)

    /// Whether a manual check is in flight.
    @State private var isCheckingNow = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeader(
                title: "Aguardando o convite",
                description: "Abra o link que enviaram para você e toque em entrar. Assim que aceitar, voltamos automaticamente por aqui."
            )
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 8)
            Text("Esperando você aceitar o convite...")
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            // Onboarding fix: a manual check, for the case where the system never routes the
            // acceptance back into the running process.
            Button {
                Task {
                    isCheckingNow = true
                    await attemptJoin()
                    isCheckingNow = false
                }
            } label: {
                if isCheckingNow {
                    ProgressView()
                } else {
                    Text("Já aceitei o convite")
                        .font(.system(size: 15))
                        .underline()
                        .foregroundStyle(.gray)
                }
            }
            .disabled(isCheckingNow)

            Spacer()
            OnboardingProgressButton(text: "Voltar") {
                viewModel.goToPreviousView()
            }
        }
        .padding(.horizontal, 10)
        .navigationBarBackButtonHidden()
        .task {
            // Covers the case where the invite was already accepted while the app was closed.
            // Check whether the house is already reachable (only true once the share
            // has been accepted) and advance the flow the same way the notification
            // handler in Onboarding.swift does.
            //
            // Onboarding fix: this is now a loop rather than a single attempt, because the
            // person leaves this screen to open the link and comes back to it.
            await pollWhileVisible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await attemptJoin() }
        }
        .alert("Não deu para entrar na casa", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Joining

    /// Re-checks for an accepted share for as long as this screen is visible.
    ///
    /// - Important: Explicitly `@MainActor`, because the closure `.task` takes is `@Sendable` and
    ///   carries no isolation of its own.
    @MainActor
    private func pollWhileVisible() async {
        while !Task.isCancelled {
            await attemptJoin()

            if viewModel.currentHouse != nil { return }

            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    /// Joins the house if the share has been accepted, and only then advances.
    ///
    /// - Note: **Onboarding fix:** errors raised while joining are left in
    ///   `viewModel.errorMessage` on purpose while polling — the alert surfaces them, and the
    ///   loop keeps trying rather than stranding the person on a silent screen.
    @MainActor
    private func attemptJoin() async {
        // Nothing to join until the share has actually been accepted.
        guard (try? await CloudKitManager.shared.fetchFirst(HouseModel.self)) != nil else { return }

        guard viewModel.currentUser != nil || viewModel.hasStoredProfile else { return }

        viewModel.stateMachine.flow = .invitedWithProfile

        // Onboarding fix: advance only on a confirmed join.
        guard await viewModel.joinHouse() else { return }

        viewModel.goToNextView()
    }
}
