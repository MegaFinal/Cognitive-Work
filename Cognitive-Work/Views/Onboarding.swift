//
//  Onboarding.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 31/08/26.
//

import SwiftUI

/// Router for the whole onboarding flow.
///
/// Renders whichever step ``OnboardingStateMachine`` currently points at, and
/// hands control over to ``ContentView`` once the flow is finished or skipped.
struct Onboarding: View {

    // MARK: - Properties

    /// Flips to `true` when onboarding ends, releasing the main app.
    @Binding var didOnboard: Bool

    /// State shared by every step of the flow.
    @State var viewModel = OnboardingViewModel()

    // MARK: - Body

    var body: some View {
        stepView(for: viewModel.stateMachine)
            .onChange(of: viewModel.isOnboardingSkipped) {
                didOnboard = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .didAcceptShare)) { _ in
                Task {
                    await viewModel.fetchHouse()
                    viewModel.stateMachine.flow = .invitedWithoutProfile
                }
            }
    }
    
    // MARK: - Steps

    /// Maps the state machine's current step to its screen.
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
            WaitAcceptLinkOnboardingView(viewModel: $viewModel)
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
