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
        NavigationStack {
            VStack {
                Image("TocTocPurple")
                    .frame(width: width * 0.64, height: height * 0.19)
                    .padding(.bottom, height * 0.075)
                OnboardingHeader(
                    title: "Peça o convite para o administrador da casa",
                    description: "Quando receber o link, é só tocar nele para entrar na casa!"
                )
                .padding(.bottom, height * 0.052)
                
                
                
                ShareLink(item: "eai amigo, cade meu link 🤨🤨") {
                    Label("Pedir o convite por mensagem", systemImage: "square.and.arrow.up")
                        .fontWeight(.semibold)
                }
                .controlSize(.large)
                .buttonStyle(.glassProminent)
                .tint(.blue)
                
                
            }
            .ignoresSafeArea()
            .background{
                Image("purple.worms")
                    .resizable()
                    .frame(width: height * 1.09, height: height * 1.09)
                    .opacity(0.2)
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
                guard await viewModel.joinHouse() else { return }
                viewModel.goToNextView()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel.goToPreviousView()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    WaitAcceptLinkOnboardingView(viewModel: $viewModel)
}
