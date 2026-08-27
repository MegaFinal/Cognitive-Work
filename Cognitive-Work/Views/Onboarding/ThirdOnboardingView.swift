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
struct ThirdOnboardingView: View {
    /// The shared onboarding view model, read from the environment
    @Environment(OnboardingViewModel.self) var viewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        @Bindable var bindableViewModel = viewModel
        
        ZStack {
            OnboardingHeader(
                title: "Moradia",
                description: "Você pode entrar em uma casa existente através de um convite, ou criar uma nova."
            )
                        
            HStack(spacing: 15) {
                Button { } label: {
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
                .disabled(viewModel.isLoading)
                
                Button {
                    Task {
                        await viewModel.createHouseAndLinkUser()
                        viewModel.navigateToFourth = true
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
                                Text("em uma casa")
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: width * 0.4, height: height * 0.4)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .foregroundColor(.blue)
                            .shadow(color: .black.opacity(0.25), radius: 5.95, x: 0, y: 4)
                    )
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationBarBackButtonHidden(viewModel.isLoading)
    }
}

#Preview {
    ThirdOnboardingView()
        .environment(OnboardingViewModel())
}
