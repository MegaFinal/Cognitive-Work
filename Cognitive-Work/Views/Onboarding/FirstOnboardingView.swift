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
/// the screen into a longer app description (``OnboardingAppDescription``)
/// and reveals the "Continuar" action that pushes the user into the rest of the
/// onboarding flow
///
/// The view owns the shared ``OnboardingViewModel`` for the onboarding flow
/// and injects it into the environment so that subsequent screens can
/// read and mutate it without it being passed down explicitly
struct FirstOnboardingView: View {
    /// Whether the description panel is expanded, replacing the initial tagline
    @State private var isExpanded = false
    /// Whether the "swipe up" hint indicator is currently visible
    @State private var isSwipeVisible = false
    
    /// The shared view model for navigation and state across the onboarding flow
    @State private var viewModel = OnboardingViewModel()
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
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
                            OnboardingAppDescription {
                                viewModel.navigateToSecond = true
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: isExpanded ? .top : .center)
                .ignoresSafeArea(edges: isExpanded ? .top : [])
                .padding(.top, 5)
                
                if isSwipeVisible {
                    OnboardingSwipeIndicator()
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
            .navigationDestination(isPresented: $viewModel.navigateToSecond) {
                CreateProfileOnboardingView()
            }
            .navigationDestination(isPresented: $viewModel.navigateToThird) {
                CreateOrEnterHouseOnboardingView()
            }
            .navigationDestination(isPresented: $viewModel.navigateToFourth) {
                SelectRoomsOnboardingView()
            }
            .navigationDestination(isPresented: $viewModel.navigateToFifth) {
                FifthOnboardingView()
            }
            .navigationDestination(isPresented: $viewModel.navigateToSixth) {
                SixthOnboardingView()
            }
        }
        .environment(viewModel)
    }
}

#Preview {
    FirstOnboardingView()
}
