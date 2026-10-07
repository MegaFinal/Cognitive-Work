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
    /// Whether the iCloud alert is currently visible.
    @State private var showICloudAlert = false
    
    @State var bool = true
    
    /// The shared view model for navigation and state across the onboarding flow
    @Binding var viewModel: OnboardingViewModel
    
    
    var body: some View {
        ZStack {
            Color(.onboardingBackground)
            VStack(spacing: 30) {
                Image("pipaOnboarding")
                    .resizable()
                    .frame(width: width * 0.708, height: height * 0.208)
                
            }
            .frame(maxHeight: .infinity, alignment: isExpanded ? .top : .center)
            .ignoresSafeArea(edges: isExpanded ? .top : [])
            .padding(.top, 5)
            
            if isSwipeVisible {
                swipeIndicator
            }
            
            if isExpanded {
                WelcomeAnimatedOnboardingView(viewModel: $viewModel)
            }
        }
        .ignoresSafeArea(.all)
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
            Task {
                await viewModel.checkExistingAccount()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if !isExpanded {
                    withAnimation(.easeIn(duration: 0.8)) {
                        isSwipeVisible = true
                    }
                }
            }
        }
        .alert("Continue com seu iCloud", isPresented: $showICloudAlert) {
            Button("Continuar") {}
        } message: {
            Text("O Pipa usa a conta do iCloud do seu iPhone para guardar os dados da sua casa com segurança e sincronizar tudo entre você e os demais moradores. Verifique se você está conectado a uma conta do iCloud nos Ajustes do seu iPhone para continuar.")
        }
    }
    
    
    // MARK: - Subviews
    
    /// A hint prompting the user to swipe up to continue.
    private var swipeIndicator: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.up")
                .font(.system(size: 20))
            
            Text("deslize para continuar!")
            
        }
        .foregroundColor(.swipeWelcomeView)
        .transition(.opacity)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, height * 0.07)
        .fontWeight(.semibold)
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    WelcomeOnboardingView(viewModel: $viewModel)
}
