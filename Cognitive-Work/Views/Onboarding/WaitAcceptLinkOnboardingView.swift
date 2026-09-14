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
struct WaitAcceptLinkOnboardingView: View {
    // MARK: - Properties
    
    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel
    
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
            
            let houseFetched = await Task.detached(priority: .utility) {
                return (try? await CloudKitManager.shared.fetchFirst(HouseModel.self)) != nil
            }.value

            guard houseFetched, viewModel.currentUser != nil else { return }
            
            viewModel.stateMachine.flow = .invitedWithProfile
            await viewModel.joinHouse()
            viewModel.goToNextView()
        }
    }
}
