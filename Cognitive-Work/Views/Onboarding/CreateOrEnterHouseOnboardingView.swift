//
//  ThirdOnboardingView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI
import CloudKit

/// The step where the user chooses whether to join an existing house
/// or create a new one
/// On success the flow advances to ``FourthOnboardingView``
struct CreateOrEnterHouseOnboardingView: View {
    
    // MARK: - Properties
    
    /// The shared onboarding view model, read from the environment
    @Binding var viewModel: OnboardingViewModel
    
    @State private var isCreatingHouse = false
    
    /// An invite is being accepted or the house joined (shown on the "Entrar" card).
    private var isEnteringHouse: Bool { viewModel.isAcceptingInvite || viewModel.isJoiningHouse }
    
    private var isBusy: Bool { isCreatingHouse || isEnteringHouse || viewModel.isLoading }
    
    // MARK: - Body
    //
    // Two branching actions: joining an existing house switches the flow to
    // `.invitedWithProfile`, creating one saves the house before advancing.
    
    var body: some View {
        VStack(alignment: .center) {
            OnboardingHeader(
                title: "Bem vindo, \(viewModel.currentUser?.name ?? viewModel.userName)!",
                description: "Sua casa já está no Pipa?"
            )
            
            
            Spacer()
            
            Button {
                Task {
                    isCreatingHouse = true
                    defer { isCreatingHouse = false }
                    await viewModel.createHouseAndLinkUser()
                    
                    if viewModel.currentHouse != nil {
                        viewModel.stateMachine.flow = .houseCreator
                        viewModel.goToNextView()
                    }
                }
            } label: {
                VStack(alignment: .center){
                    if isCreatingHouse {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    } else {
                        Image("HousePlus")
                            .resizable()
                            .frame(width: width * 0.297, height: height * 0.13)
            
                        VStack(alignment: .leading) {
                            Text("Criar uma casa")
                                .bold()
                                .font(.title2)
                            Text("Você será o administrador")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, width * 0.04)
                        .frame(minWidth: width * 0.854, alignment: .leading)
                    }
                }
                .foregroundColor(.white)
                .frame(width: width * 0.854, height: height * 0.255)
                
            }
            .background {
                Color(.chorePurple)
                Image("purple.clouds")
                    .opacity(0.15)
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 24))
            // `clipShape` only clips drawing, not hit testing: the texture (~566×753 pt, not
            // resizable) kept an invisible touch area far outside the card.
            .contentShape(.rect(cornerRadius: 24))
            .disabled(isBusy)
            
            Button {
                viewModel.stateMachine.flow = .invitedWithProfile
                viewModel.goToNextView()
            } label: {
                VStack{
                    // While an invite is accepted, only the icon becomes a spinner (same frame,
                    // so the card doesn't jump).
                    Group {
                        if isEnteringHouse {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.chorePurple)
                        } else {
                            Image("TocToc")
                                .resizable()
                        }
                    }
                    .frame(width: width * 0.414, height: height * 0.123)
                    .padding(.bottom, height * 0.018)
                    
                    VStack(alignment: .leading) {
                        Text("Entrar em uma casa")
                            .bold()
                            .font(.title2)
                        Text("A casa já foi criada por outro morador")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.chorePurple)
                    .padding(.horizontal, width * 0.04)
                    .frame(minWidth: width * 0.854, alignment: .leading)
                }
                .frame(width: width * 0.854, height: height * 0.255)
            }
            .background {
                Color(.lowOpacityPink)
                Image("purple.worms")
                    .opacity(0.15)
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 24))
            // Same as above: this card's oversized texture was covering "Criar uma casa" and
            // swallowing its taps (it's later in the VStack, so it sits on top).
            .contentShape(.rect(cornerRadius: 24))
            .disabled(isBusy)
            
            Spacer()
        }
        .onboardingBackButton(viewModel: viewModel, isDisabled: isBusy)
        .alert("Não deu para criar a casa", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    CreateOrEnterHouseOnboardingView(viewModel: $viewModel)
}
