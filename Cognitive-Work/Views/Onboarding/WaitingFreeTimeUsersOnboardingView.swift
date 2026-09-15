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
/// ## Sync fix
/// - The roster was refreshed only by `.task` (once) and `.cloudKitDidChange`. If the admin
///   opened this screen *before* the guest submitted, and the silent push was throttled or
///   dropped, the guest stayed "Ainda preenchendo" forever. A foreground re-check and a
///   polling fallback now close that gap.
/// - `updateUsers()` can now run several times concurrently (push + foreground + poll). Each
///   run performs slow network reads, so an older run could finish *after* a newer one and
///   overwrite fresh data with a stale roster. Only the latest run may publish its result.
struct WaitUsersFreeTimeOnboardingView: View {

    // MARK: - Properties

    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    @State private var houseUsers: [UserModel] = []
    @State private var completedUsers: [UserModel] = []
    @State private var pendingUsers: [UserModel] = []
    
    /// Sync fix: identifies the most recent `updateUsers()` run; older runs discard their result.
    @State private var refreshGeneration: Int = 0
    
    /// Sync fix: interval of the polling fallback used when no push arrives.
    private let pollingInterval: Duration = .seconds(15)

    var width: CGFloat = UIScreen.main.bounds.width
    var height: CGFloat = UIScreen.main.bounds.height

    var isFromSettings: Bool

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
                    isSystemImage: true
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
            await updateUsers()
            
            // Sync fix: polling fallback, cancelled automatically when the view disappears.
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)
                guard !Task.isCancelled else { break }
                await updateUsers()
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task {
                await updateUsers()
            }
        }
        
        // Sync fix: re-check when the app returns to the foreground, since pushes received
        // (or dropped) in the background never reach this view.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
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
    
    private func updateUsers() async {
        // Sync fix: tag this run so a slower, older run can't overwrite a newer result.
        refreshGeneration += 1
        let generation = refreshGeneration
        
        let fetchedUsers = await viewModel.fetchHouseUsers()

        var completed: [UserModel] = []
        var pending: [UserModel] = []

        for user in fetchedUsers {
            let availableTimes = await user.availableTime

            if availableTimes.isEmpty {
                pending.append(user)
            } else {
                completed.append(user)
            }
        }

        // Sync fix: publish only if no newer refresh started meanwhile.
        guard generation == refreshGeneration else { return }
        houseUsers = fetchedUsers
        completedUsers = completed
        pendingUsers = pending
    }
}


#Preview {

    @Previewable @State var mockViewModel = OnboardingViewModel()

    WaitUsersFreeTimeOnboardingView(
        viewModel: $mockViewModel,
        isFromSettings: false
    )
}
