//
//  FitfhOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI
import CloudKit

/// Onboarding step where the house owner shares the invite link.
///
/// Resolves the CloudKit share on appear and keeps the list of members who
/// already joined up to date through `.cloudKitDidChange`.
///
/// ## Onboarding audit — what changed and why
///
/// - **The member list only refreshed on a notification that is never posted.**
///   `.cloudKitDidChange` comes exclusively from
///   `AppDelegate.application(_:didReceiveRemoteNotification:)`, and iOS does not deliver the
///   silent pushes that trigger it because this target declares no `remote-notification`
///   background mode. The admin watched an empty circle row while guests were joining. The screen
///   now polls and refreshes when the app returns to the foreground.
/// - **`shareURL!` was force-unwrapped.** Guarded by a `!= nil` check in the same expression, so
///   safe in practice, but there is no reason to keep a crash-shaped construct on the critical
///   path of the flow. Rewritten as `if let`.
/// - **A failed share was indistinguishable from a slow one.** When `resolveShare(for:)` returned
///   nil the button stayed a grey spinner forever with no explanation and no retry.
struct InviteUsersOnboardingView: View {

    // MARK: - Properties

    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    @State private var houseShare: CKShare? = nil
    @State private var showSheet = false
    @State private var resolvendoShare = false
    @State private var shareURL: URL? = nil
    @State private var isLoading = true
    @State private var houseUsers: [UserModel] = []

    /// Set when the invite link could not be produced, so the UI can offer a retry.
    ///
    /// - Note: **Onboarding fix:** replaces an indefinite grey spinner.
    @State private var shareFailed = false

    /// Drives a refresh of the joined-members list when the app comes back.
    @Environment(\.scenePhase) private var scenePhase

    /// How often the joined-members list is re-read while this screen is visible.
    private static let pollInterval: Duration = .seconds(10)

    var width: CGFloat = UIScreen.main.bounds.width
    var height: CGFloat = UIScreen.main.bounds.height
    var isFromSettings: Bool

    // MARK: - Body

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Adicione seus \nroomies!")
                    .bold()
                    .font(.title)
                    .foregroundColor(.black)

                VStack(alignment: .leading) {
                    Text("Envie o convite para os outros moradores da sua casa se juntarem com você no app!")

                    Text("Aceite o pedido dos moradores que estão em vermelho!")
                }
            }
            .frame(width: width * 0.84)
            .foregroundColor(.secondary)
            .padding(.top, 30)

            Spacer()

            if !houseUsers.isEmpty {
                joinedUsers
            }

            Spacer()

            Text("Assim que todos os moradores estiverem no app, clique em continuar. ")
                .frame(width: width * 0.8)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)

            HStack {
                if resolvendoShare {
                    ProgressView("Preparando chaves de acesso...")
                        .frame(width: width * 0.55)
                } else {
                    shareControl
                }

                if !isFromSettings {
                    OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true) {
                        viewModel.goToNextView()
                    }
                    .multilineTextAlignment(.trailing)
                }
            }
            .padding(.top)

//            if !isFromSettings {
//                OnboardingSkipButton() {
//                    viewModel.finishOnboarding()
//                }
//            }
        }
        .frame(width: width * 0.84)
        .navigationBarBackButtonHidden(!isFromSettings)
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task {
                //                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
                houseUsers = await viewModel.fetchHouseUsers()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Onboarding fix: guests typically join while the admin has the app in the
            // background (they are sending the link from another app).
            guard newPhase == .active else { return }
            Task { houseUsers = await viewModel.fetchHouseUsers() }
        }
        .task(id: viewModel.currentHouse?.recordID) {
            guard let house = viewModel.currentHouse else { return }

            resolvendoShare = true
            shareFailed = false
            houseShare = await CloudKitManager.shared.resolveShare(for: house)

            do {
                if let share = houseShare {
                    let url = try await CloudKitManager.shared.generateShareLink(share: share)
                    self.shareURL = url
                } else {
                    // Onboarding fix: make the failure visible instead of spinning forever.
                    shareFailed = true
                }
            } catch {
                print("Erro ao gerar link: \(error.localizedDescription)")
                shareFailed = true
            }

            houseUsers = await viewModel.fetchHouseUsers()
            resolvendoShare = false
        }
        .task {
            // Onboarding fix: keep the roster fresh without depending on push delivery.
            await pollJoinedUsers()
        }
    }

    // MARK: - Subviews

    /// The share button, or a retry when the link could not be produced.
    ///
    /// - Note: **Onboarding fix:** replaces `ShareLink(item: shareURL!)`, and gives the failure
    ///   path an action instead of a permanent grey placeholder.
    @ViewBuilder
    private var shareControl: some View {
        if let shareURL {
            ShareLink(item: shareURL) {
                Text("Compartilhar Convite")
                    .font(.system(size: 17))
                    .frame(width: width * 0.5, height: height * 0.065, alignment: .center)
                    .foregroundColor(.white)
                    .background {
                        Capsule()
                            .foregroundColor(.blue)
                            .glassEffect()
                    }
            }
        } else if shareFailed {
            Button {
                Task { await regenerateShare() }
            } label: {
                Text("Tentar gerar convite")
                    .font(.system(size: 17))
                    .frame(width: width * 0.5, height: height * 0.065, alignment: .center)
                    .foregroundColor(.white)
                    .background(Capsule().foregroundStyle(.red))
            }
        } else {
            Button {
            } label: {
                ProgressView().tint(.white)
            }
            .frame(width: width * 0.5, height: height * 0.065, alignment: .center)
            .foregroundColor(.white)
            .background(Capsule().foregroundStyle(.gray))
            .disabled(true)
        }
    }

    private var joinedUsers: some View {
        HStack(spacing: 20) {
            ForEach(houseUsers) { user in
                ZStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: width * 0.17)
                    UserProfilePictureTag(user: user, widthMultiplier: 0.15)
                }
            }
        }
    }

    // MARK: - Actions

    /// Re-reads the joined members for as long as this screen is visible.
    ///
    /// - Important: Explicitly `@MainActor`, because the closure `.task` takes is `@Sendable` and
    ///   carries no isolation of its own.
    @MainActor
    private func pollJoinedUsers() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pollInterval)
            houseUsers = await viewModel.fetchHouseUsers()
        }
    }

    /// Retries share creation after a failure.
    @MainActor
    private func regenerateShare() async {
        guard let house = viewModel.currentHouse else { return }

        resolvendoShare = true
        shareFailed = false
        defer { resolvendoShare = false }

        houseShare = await CloudKitManager.shared.resolveShare(for: house)

        guard let share = houseShare else {
            shareFailed = true
            return
        }

        do {
            shareURL = try await CloudKitManager.shared.generateShareLink(share: share)
        } catch {
            print("Erro ao gerar link: \(error.localizedDescription)")
            shareFailed = true
        }
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()

    InviteUsersOnboardingView(viewModel: $mockViewModel, isFromSettings: false)
}
