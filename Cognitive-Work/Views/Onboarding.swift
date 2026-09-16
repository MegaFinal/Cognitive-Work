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
            // Session-restore fix: after a relaunch the persisted step is rendered immediately,
            // while `currentUser`/`currentHouse` are still being reloaded. Steps could then run
            // their own `.task`s or accept taps with empty state ("Seu perfil ainda não foi
            // salvo", "Não foi possível salvar seus horários"). Hold them back until the
            // session is restored. Fresh starts (step 0) are not affected.
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
            // Session-restore fix: this guard had been commented out again, which made the app
            // erase every profile, house and share on each launch while the onboarding progress
            // (kept in UserDefaults) survived — exactly the "data disappears when I close the
            // app" behaviour. To reset CloudKit while testing, add `RESET_CLOUDKIT_ON_LAUNCH` to
            // Build Settings → Active Compilation Conditions (Debug) instead of editing this.
//            #if DEBUG && RESET_CLOUDKIT_ON_LAUNCH
//            await CloudKitManager.shared.deleteAllRecords()
            // Session-restore fix: after a reset the saved step points at data that no longer
            // exists, so start the flow from the beginning too.
            viewModel.stateMachine.resetProgress()
//            #endif
            await viewModel.checkExistingAccount()

            if !viewModel.isOnboardingSkipped {
                await viewModel.restoreProgressIfNeeded()
            }
            
            // Session-restore fix: release the steps now that the session is loaded.
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
