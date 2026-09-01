//
//  Onboarding.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 31/08/26.
//

import SwiftUI

struct Onboarding: View {
    @Binding var didOnboard: Bool
    @State var viewModel = OnboardingViewModel()
    
    var body: some View {
        stepView(for: viewModel.stateMachine)
            .onChange(of: viewModel.isOnboardingSkipped) {
                didOnboard = true
            }
    }
    
    @ViewBuilder
    private func stepView(for stateMachine: OnboardingStateMachine) -> some View {
        switch stateMachine.current {
        case .welcome:
            WelcomeOnboardingView(viewModel: $viewModel)
        case .createProfile:
            CreateProfileOnboardingView(viewModel: $viewModel)
        case .createOrEnterHome:
            CreateOrEnterHouseOnboardingView(viewModel: $viewModel)
        case .waitAcceptLink:
            EmptyView()
        case .chooseRooms:
            SelectRoomsOnboardingView(viewModel: $viewModel)
        case .inviteAndConfirmJoin:
            InviteUsersOnboardingView(viewModel: $viewModel)
        case .setUpScheduleChores:
            StartChoreDivisionOnboardingView(viewModel: $viewModel)
        case .chooseChores:
            SelectChoresOnboardingView(viewModel: $viewModel)
        case .chooseFreeTime:
            SelectFreeTimeOnboardingView(viewModel: $viewModel)
        case .scheduleChores:
            FortnightlyScheduleView() {
                viewModel.finishOnboarding()
            }
        case .none:
            EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var didOnboard = false
    Onboarding(didOnboard: $didOnboard)
}
