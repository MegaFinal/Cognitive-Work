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
///
/// ## Onboarding audit — what changed and why
///
/// - **The destructive reset is gone.** This view's `.task` opened with
///   `await CloudKitManager.shared.deleteAllRecords()`, which drops the device's entire private
///   `HomeEnvironment` zone *and* leaves every shared house. `Onboarding` is presented on every
///   launch until `didOnboard` flips to `true`, so any relaunch before the flow finished — a
///   force quit, a crash, iOS reclaiming the app while the person waited on someone else —
///   destroyed the house, its rooms, its chores, every guest's availability and the profile that
///   had just been created. All three reported bugs have this as a contributing cause, and the
///   "I create the profile, come back, and creating a house does nothing" report is entirely
///   explained by it.
/// - **Progress is re-derived on foreground.** `.task` runs once per view insertion, so a person
///   returning to a backgrounded app never re-checked anything. Combined with the silent pushes
///   that this target cannot receive (see ``CloudKitManager/createSharedSubscription()``), that
///   left both waiting screens permanently stale. A `scenePhase` observer now refreshes.
/// - **Share acceptance is verified.** `joinHouse()` used to be called and its outcome ignored,
///   so the flow advanced past `.waitAcceptLink` whether or not the public profile had actually
///   been created.
/// - **Admin detection no longer depends on `stateMachine.house` being populated.** It is
///   resolved from CloudKit through ``OnboardingViewModel/isCurrentUserAdmin()`` before the final
///   step renders, because `stateMachine.isOwner` silently answered `nil` on resumed sessions and
///   the admin's division was consequently never generated.
struct Onboarding: View {

    // MARK: - Properties

    /// Flips to `true` when onboarding ends, releasing the main app.
    @Binding var didOnboard: Bool

    /// State shared by every step of the flow.
    @State var viewModel = OnboardingViewModel()

    /// Whether this device owns the house, resolved from CloudKit.
    ///
    /// - Note: **Onboarding fix:** replaces `viewModel.stateMachine.isOwner == true`, which
    ///   degraded to `false` whenever the state machine's `house` mirror had not been populated.
    @State private var isHouseAdmin: Bool = false

    /// Drives the refresh that used to depend entirely on undelivered silent pushes.
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some View {
        ZStack {
            stepView(for: viewModel.stateMachine)
                .onChange(of: viewModel.isOnboardingSkipped) {
                    didOnboard = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .didAcceptShare)) { _ in
                    Task {
                        await handleAcceptedShare()
                    }
                }
        }
        .task {
            await bootstrap()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Onboarding fix: coming back from the background must re-read CloudKit. `.task`
            // does not fire again on foreground, and the push that was supposed to cover this
            // case is never delivered by iOS for this target.
            guard newPhase == .active else { return }
            Task { await refreshAfterForeground() }
        }
    }

    // MARK: - Lifecycle

    /// Restores the session from CloudKit and decides which step to resume on.
    ///
    /// - Note: **Onboarding fix:** `checkExistingAccount()` is authoritative about *where* to
    ///   resume, so `restoreProgressIfNeeded()` now only fills in whatever it did not load —
    ///   and, crucially, neither of them destroys anything on the way in.
    ///
    /// - Important: Explicitly `@MainActor`. The closure `.task` takes is `@Sendable` and carries
    ///   no isolation of its own, so helpers that touch `@State` have to declare it themselves.
    @MainActor
    private func bootstrap() async {
        await viewModel.checkExistingAccount()

        if !viewModel.isOnboardingSkipped {
            await viewModel.restoreProgressIfNeeded()
        }

        isHouseAdmin = await viewModel.isCurrentUserAdmin()
    }

    /// Re-reads the state the current step depends on after the app returns to the foreground.
    @MainActor
    private func refreshAfterForeground() async {
        await viewModel.restoreProgressIfNeeded()
        isHouseAdmin = await viewModel.isCurrentUserAdmin()

        if viewModel.stateMachine.current == .waitAdminScheduling {
            await viewModel.checkAndAdvanceIfScheduleReady()
        }
    }

    /// Reacts to the system telling us a CloudKit share invitation was accepted.
    ///
    /// - Note: **Onboarding fix:** the previous implementation advanced the flow unconditionally
    ///   after calling `joinHouse()`. When joining failed — which it did routinely, because the
    ///   derived record name was double-suffixed — the guest landed on the free-time screen with
    ///   no public profile to write to, submitted nothing, and the admin waited on them forever.
    @MainActor
    private func handleAcceptedShare() async {
        guard viewModel.currentUser != nil || viewModel.hasStoredProfile else {
            // No profile on this device yet: send the person through profile creation first,
            // which then joins the house on their behalf.
            viewModel.stateMachine.flow = .invitedWithoutProfile
            return
        }

        viewModel.stateMachine.flow = .invitedWithProfile

        guard await viewModel.joinHouse() else { return }

        isHouseAdmin = await viewModel.isCurrentUserAdmin()

        // Jump by identity rather than by "one step forward": the notification can arrive while
        // the person is on any screen of the flow.
        viewModel.stateMachine.jump(to: .chooseFreeTime)
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
            // Onboarding fix: `shouldGenerate` comes from a CloudKit-backed ownership check
            // instead of `stateMachine.isOwner == true`, which returned nil (→ false) whenever
            // the state machine's house mirror had not been restored.
            FortnightlyScheduleView(shouldGenerate: isHouseAdmin) {
                viewModel.finishOnboarding()
            }

        case .waitGuestsFreeTime:
            WaitUsersFreeTimeOnboardingView(viewModel: $viewModel, isFromSettings: false)

            //        case .choreScheduleResult:
            //            FortnightlyView()

        case .none:
            // Onboarding fix: `current` no longer returns nil while a flow has steps, so this
            // branch is now genuinely unreachable — it used to be how a mismatched persisted
            // index turned into a blank, inescapable screen.
            ProgressView()
        }
    }
}

#Preview {
    @Previewable @State var didOnboard = false
    Onboarding(didOnboard: $didOnboard)
}
