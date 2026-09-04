//
//  FirstOnboardingView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// The entry point of the onboarding flow.
///
/// `FirstOnboardingView` presents the app's welcome screen, swiping up expands
/// the screen into a longer app description (`appDescription`)
/// and reveals the "Continuar" action that pushes the user into the rest of the
/// onboarding flow
///
/// The view owns the shared ``OnboardingViewModel`` for the onboarding flow
/// and injects it into the environment so that subsequent screens can
/// read and mutate it without it being passed down explicitly
struct WelcomeOnboardingView: View {
    /// Whether the description panel is expanded, replacing the initial tagline
    @State private var isExpanded = false
    /// Whether the "swipe up" hint indicator is currently visible
    @State private var isSwipeVisible = false
    
    /// The shared view model for navigation and state across the onboarding flow
    @Binding var viewModel: OnboardingViewModel
        
    let width = UIScreen.main.bounds.width
    let height = UIScreen.main.bounds.height
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 30) {
                    Image("houseHouse")
                        .resizable()
                        .frame(width: width * 0.7, height: height * 0.32)
                    
                    ZStack(alignment: .top) {
                        if !isExpanded {
                            Text("Seu facilitador de organização doméstica!")
                                .foregroundColor(.gray)
                                .font(.title2)
                                .frame(width: width * 0.7)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                            
                        } else {
                            appDescription
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: isExpanded ? .top : .center)
                .ignoresSafeArea(edges: isExpanded ? .top : [])
                .padding(.top, 5)
                
                if isSwipeVisible {
                    swipeIndicator
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height < -50 && !isExpanded {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                isExpanded = true
                                isSwipeVisible = false
                            }
                        }
                    }
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if !isExpanded {
                        withAnimation(.easeIn(duration: 0.8)) {
                            isSwipeVisible = true
                        }
                    }
                }
            }

        }
    }
    
    // MARK: - Subviews
    
    /// The expanded pitch shown after the user swipes up.
    private var appDescription: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                Text("O HouseHouse veio para facilitar \na vida de quem divide moradia!")
                
                Text("Nosso intuito é remover a carga mental da organização de \ntarefas de maneira justa e visual para todos os moradores.")
                
                Text("Através da nossa escala de atividades e recorrência de \ntarefas automatizada, basta \nolhar o calendário e saber o que você precisa fazer!")
                
                Text("Mas antes, precisamos saber um pouco mais sobre a rotina na \ncasa...")
            }
            
            OnboardingProgressButton(text: "Começar") {
                viewModel.goToNextView()
            }
        }
        .frame(width: width * 0.8)
        .foregroundColor(.gray)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 30)
        .transition(.opacity)
    }
    
    /// A hint prompting the user to swipe up to continue.
    private var swipeIndicator: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.up")
                .font(.largeTitle)
            
            Text("Deslize para cima para continuar")
        }
        .foregroundColor(.gray)
        .opacity(0.7)
        .transition(.opacity)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 50)
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    WelcomeOnboardingView(viewModel: $viewModel)
}
