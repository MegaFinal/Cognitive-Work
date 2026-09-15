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
            stepView(for: viewModel.stateMachine)
                .onChange(of: viewModel.isOnboardingSkipped) {
                    didOnboard = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .didAcceptShare)) { _ in
                    Task {
                        if viewModel.currentUser != nil {
                            viewModel.stateMachine.flow = .invitedWithProfile
                            // Sync fix: only advance once the guest's in-house record really
                            // exists. Advancing unconditionally let the guest fill in free time
                            // with no public record to write it to, so the admin never saw it.
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
            // Sync fix: this debug reset ran on *every* launch of the onboarding flow. For the
            // guest, `deleteAllRecords()` leaves every shared house, so relaunching the app while
            // waiting silently removed them from the house and the admin's division could never
            // reach them. For the admin it wiped the house zone, so the guest's free time had
            // nowhere to land. Whether sync "worked" therefore depended on whether anyone had
            // relaunched the app. It now only runs when explicitly opted in for debugging by
            // adding the `RESET_CLOUDKIT_ON_LAUNCH` compilation condition.
//            #if DEBUG && RESET_CLOUDKIT_ON_LAUNCH
            await CloudKitManager.shared.deleteAllRecords()
//            #endif
            await viewModel.checkExistingAccount()

            if !viewModel.isOnboardingSkipped {
                await viewModel.restoreProgressIfNeeded()
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
