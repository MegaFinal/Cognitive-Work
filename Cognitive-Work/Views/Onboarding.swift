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
        ZStack {
            Group {
                if viewModel.isRestoringSession && viewModel.stateMachine.index > 0 {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    stepView(for: viewModel.stateMachine)
                }
            }
                .onChange(of: viewModel.isOnboardingSkipped) {
                    didOnboard = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .didAcceptShare)) { _ in
                    Task {
                        if viewModel.currentUser != nil {
                            viewModel.stateMachine.flow = .invitedWithProfile
                            if await viewModel.joinHouse() {
                                viewModel.goToNextView()
                            }
                        } else {
                            viewModel.stateMachine.flow = .invitedWithoutProfile
                        }
                    }
                }
        }
        .task {
            #if DEBUG && RESET_CLOUDKIT_ON_LAUNCH
            await CloudKitManager.shared.deleteAllRecords()
            viewModel.stateMachine.resetProgress()
            #endif
            await viewModel.checkExistingAccount()

            if !viewModel.isOnboardingSkipped {
                await viewModel.restoreProgressIfNeeded()
            }
            
            viewModel.isRestoringSession = false
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
            InviteUsersOnboardingView(viewModel: $viewModel, isFromSettings: false)
            
        case .setUpScheduleChores:
            StartChoreDivisionOnboardingView(viewModel: $viewModel)
            
        case .chooseChores:
            SelectChoresOnboardingView(viewModel: $viewModel)
            
        case .chooseFreeTime:
            SelectFreeTimeOnboardingView(viewModel: $viewModel)
            
        case .waitAdminScheduling:
            WaitHouseCreatorSheduleView(viewModel: $viewModel)
            
        case .scheduleChores:
            FortnightlyScheduleView(shouldGenerate: viewModel.stateMachine.isOwner ?? false) {
                    viewModel.finishOnboarding()
                }
        case .waitGuestsFreeTime:
            WaitUsersFreeTimeOnboardingView(viewModel: $viewModel, isFromSettings: false)
            
//        case .choreScheduleResult:
//            FortnightlyView()
            
        case .none:
            EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var didOnboard = false
    Onboarding(didOnboard: $didOnboard)
}
