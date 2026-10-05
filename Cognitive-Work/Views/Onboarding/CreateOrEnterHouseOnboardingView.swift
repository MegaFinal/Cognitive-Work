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
struct CreateOrEnterHouseOnboardingView: View {
    
    // MARK: - Properties
    
    /// The shared onboarding view model, read from the environment
    @Binding var viewModel: OnboardingViewModel
    
    @State private var isCreatingHouse = false
    
    private var isBusy: Bool { isCreatingHouse || viewModel.isJoiningHouse || viewModel.isLoading }
    
    // MARK: - Body
    //
    // Two branching actions: joining an existing house switches the flow to
    // `.invitedWithProfile`, creating one saves the house before advancing.
    
    var body: some View {
        VStack(alignment: .center) {
            OnboardingHeader(
                title: "Bem vindo, \(viewModel.currentUser?.name ?? "error no name")!",
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
            }
            .clipShape(.rect(cornerRadius: 24))
            .disabled(isBusy)
            
            Button {
                viewModel.stateMachine.flow = .invitedWithProfile
                viewModel.goToNextView()
            } label: {
                VStack{
                    if viewModel.isJoiningHouse {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                    } else {
                        Image("TocToc")
                            .resizable()
                            .frame(width: width * 0.414, height: height * 0.123)
                            .padding(.bottom, height * 0.018)
                        
                        VStack(alignment: .leading) {
                            Text("Entrar em uma casa")
                                .bold()
                                .font(.title2)
                            Text("A casa já foi criada por outro morador")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.chorePurple)
                        .padding(.horizontal, width * 0.04)
                        .frame(minWidth: width * 0.854, alignment: .leading)
                    }
                }
                .frame(width: width * 0.854, height: height * 0.255)
            }
            .background {
                Color(.lowOpacityPink)
                Image("purple.worms")
                    .opacity(0.15)
            }
            .clipShape(.rect(cornerRadius: 24))
            .disabled(isBusy)
            
            Spacer()
        }
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
