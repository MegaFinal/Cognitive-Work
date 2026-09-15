//
//  DoneSelectingFreeTimeView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 10/09/26.
//

import SwiftUI

/// Onboarding step where the house owner waits for every member to finish
/// filling their free time availability.
///
/// ## Onboarding audit — what changed and why
///
/// This is the "if the admin leaves the app here, everyone looks like they never filled their
/// free time and the flow is stuck forever" bug. Four separate defects stacked up:
///
/// 1. **The member list never refreshed.** `updateUsers()` ran from `.task` (once) and from
///    `.cloudKitDidChange` — a notification that is only posted by
///    `AppDelegate.application(_:didReceiveRemoteNotification:)`, which iOS never calls here
///    because the target does not declare the `remote-notification` background mode. So a guest
///    could submit their free time and the admin's screen would keep showing them in red until
///    the app was killed and relaunched. The screen now polls and re-checks on foreground.
/// 2. **`Onboarding.swift` wiped the database on relaunch.** Killing the app to force a refresh
///    therefore deleted the house, taking every member and every availability record with it —
///    which is why the screen then showed nothing at all. Fixed at the source, in `Onboarding`.
/// 3. **Free time was measured by presence, not by content.** A member whose list was written as
///    *empty* by the truncation bug in
///    ``OnboardingViewModel/setAvailableTimeToUser(daysOfWeekDTO:)`` (`Int(0.5) * 60 == 0`)
///    counted as pending forever, with no way for them to fix it from their side. The gate now
///    asks ``OnboardingViewModel/houseMembersFreeTimeStatus()``, which validates the slots.
/// 4. **An empty roster unlocked the gate.** `isDisabled: !pendingUsers.isEmpty` is `false` when
///    *nobody* was loaded, so a failed fetch let the admin walk into the scheduler with zero
///    users — which produces an empty division in silence. The gate now requires at least one
///    loaded member and no pending ones.
struct WaitUsersFreeTimeOnboardingView: View {

    // MARK: - Properties

    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    @State private var houseUsers: [UserModel] = []
    @State private var completedUsers: [UserModel] = []
    @State private var pendingUsers: [UserModel] = []

    /// Whether at least one refresh has finished, so the UI can tell "loading" from "empty".
    ///
    /// - Note: **Onboarding fix:** without this the screen looked identical while loading and
    ///   while broken.
    @State private var hasLoadedOnce = false

    /// Drives an immediate refresh when the admin returns to the app.
    @Environment(\.scenePhase) private var scenePhase

    /// How often the roster is re-read while this screen is visible.
    private static let pollInterval: Duration = .seconds(10)

    var width: CGFloat = UIScreen.main.bounds.width
    var height: CGFloat = UIScreen.main.bounds.height

    var isFromSettings: Bool

    /// Whether the admin may proceed to generate the division.
    ///
    /// - Note: **Onboarding fix:** requires a loaded roster *and* no pending members. The
    ///   previous `!pendingUsers.isEmpty` check unlocked the button whenever the fetch failed.
    private var canStartDivision: Bool {
        hasLoadedOnce && !houseUsers.isEmpty && pendingUsers.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack {

            VStack(alignment: .leading, spacing: 10) {

                Text("Esperando os\nroomies!")
                    .bold()
                    .font(.title)
                    .foregroundColor(.black)

                VStack(alignment: .leading) {
                    Text("Cada morador precisa preencher seus horários de tempo livre antes da divisão das tarefas.")
                    Text("Os moradores em verde já finalizaram essa etapa.")
                }

            }
            .frame(width: width * 0.84)
            .foregroundColor(.secondary)
            .padding(.top, 30)

            Spacer()

            if !completedUsers.isEmpty {
                completedUsersView
            }

            Spacer()

            if !pendingUsers.isEmpty {
                pendingUsersView
            }

            // Onboarding fix: an empty roster is a real, distinct state and has to be visible
            // instead of silently looking like "everyone is done".
            if hasLoadedOnce && houseUsers.isEmpty {
                emptyRosterView
            }

            Spacer()

            Text("Assim que todos os moradores preencherem seus horários, a divisão das tarefas poderá ser realizada.")
                .frame(width: width * 0.8)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)

            if !isFromSettings {
                OnboardingProgressButton(
                    width: 50,
                    height: 50,
                    text: "chevron.forward",
                    isSystemImage: true,
                    isDisabled: !canStartDivision // CRITICAL FIX: Bloqueia o avanço do Admin
                ) {
                    viewModel.goToNextView()
                }
                .multilineTextAlignment(.trailing)
                .padding(.top)
            }
        }
        .frame(width: width * 0.84)
        .navigationBarBackButtonHidden(!isFromSettings)
        .task {
            await pollWhileVisible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Onboarding fix: the single most common way this screen went stale was the admin
            // backgrounding the app while waiting and coming back to untouched data.
            guard newPhase == .active else { return }
            Task { await updateUsers() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task {
                await updateUsers()
            }
        }
    }

    // MARK: - Subviews

    /// Members who already completed their free time.
    private var completedUsersView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Já finalizaram")
                .font(.headline)
                .foregroundStyle(.green)

            HStack(spacing: 20) {
                ForEach(completedUsers) { user in
                    ZStack {
                        Circle()
                            .foregroundColor(.green)
                            .frame(width: width * 0.17)

                        UserProfilePictureTag(user: user, widthMultiplier: 0.15)
                    }
                }
            }
        }
    }

    /// Members who still need to complete their free time.
    private var pendingUsersView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Ainda preenchendo")
                .font(.headline)
                .foregroundStyle(.red)

            HStack(spacing: 20) {
                ForEach(pendingUsers) { user in
                    ZStack {
                        Circle()
                            .foregroundColor(.red)
                            .frame(width: width * 0.17)

                        UserProfilePictureTag(user: user, widthMultiplier: 0.15)
                    }
                }
            }
        }
    }

    /// Shown when the house has no readable members.
    ///
    /// - Note: **Onboarding fix:** this state used to be invisible, and because it also unlocked
    ///   the "continue" button it let the admin run the scheduler against nobody.
    private var emptyRosterView: some View {
        VStack(spacing: 10) {
            Text("Não conseguimos carregar os moradores da casa.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.red)

            Button("Tentar novamente") {
                Task { await updateUsers() }
            }
            .font(.system(size: 15))
        }
        .frame(width: width * 0.8)
    }

    // MARK: - Validation

    /// Re-reads the roster every ``pollInterval`` for as long as this screen is visible.
    ///
    /// - Note: **Onboarding fix:** the loop is owned by `.task`, so SwiftUI cancels it when the
    ///   screen disappears. It keeps running after everyone is ready, because a late guest can
    ///   still join and must show up here.
    ///
    /// - Important: Explicitly `@MainActor`, because the closure `.task` takes is `@Sendable` and
    ///   carries no isolation of its own.
    @MainActor
    private func pollWhileVisible() async {
        while !Task.isCancelled {
            await updateUsers()
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    /// Fetches all members of the house and categorizes them based on their free time submission status.
    ///
    /// > Important: This used a synchronous check against `availableTimeReference` instead of an
    /// > asynchronous fetch of the actual records, to bypass network timeouts and cache misses.
    /// > That shortcut is what let a member with an *empty* (but present) list count as finished —
    /// > and, in the mirror case, gave the admin no way to tell a stale list from a usable one.
    ///
    /// - Note: **Onboarding fix:** delegates to
    ///   ``OnboardingViewModel/houseMembersFreeTimeStatus()``, which reads every referenced slot
    ///   in a single batch request and only counts a member as finished when they have at least
    ///   one slot with real capacity inside the scheduling window.
    @MainActor
    private func updateUsers() async {
        let status = await viewModel.houseMembersFreeTimeStatus()

        completedUsers = status.completed
        pendingUsers = status.pending
        houseUsers = status.completed + status.pending
        hasLoadedOnce = true
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()

    WaitUsersFreeTimeOnboardingView(
        viewModel: $mockViewModel,
        isFromSettings: false
    )
}
