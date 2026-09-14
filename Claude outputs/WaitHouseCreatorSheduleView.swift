//
//  WaitHouseCreatorShedule.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 09/09/26.
//

import SwiftUI

/// The screen a guest waits on while the admin generates the chore division.
///
/// ## Onboarding audit — what changed and why
///
/// This screen is the "the guest stays here forever, even after the admin finished the
/// division" bug. It had exactly two ways to move forward and **both were dead**:
///
/// 1. `.task`, which runs once when the view is inserted. If the division was not ready at that
///    instant — and it never is, since the guest arrives here *before* the admin starts — it
///    never ran again.
/// 2. `.cloudKitDidChange`, which is only ever posted by
///    `AppDelegate.application(_:didReceiveRemoteNotification:)`. That callback requires a silent
///    push, and iOS only delivers silent pushes to a target that declares the
///    `remote-notification` background mode. `Info.plist` in this project has no
///    `UIBackgroundModes` key at all, so that notification is **never** posted — the listener
///    below could not fire even once.
///
/// The fixes, in order of importance:
///
/// - **Polling** (``pollWhileVisible()``): the screen asks CloudKit directly, on a timer, for as
///   long as it is on screen. This is what makes the flow work regardless of push delivery.
/// - **`scenePhase`**: an immediate check when the app returns to the foreground, which is
///   exactly when a waiting person looks at it again.
/// - **A manual "check now" control**: no waiting screen should ever be a one-way door. If
///   everything else fails the person can still act.
/// - The readiness check itself now scans the house zone instead of running a `CKQuery` that
///   silently returns an empty result when the CloudKit schema lacks a *Queryable* index — see
///   ``OnboardingViewModel/isScheduleAvailable()``.
///
/// The `.cloudKitDidChange` listener is kept: it costs nothing and becomes a fast path as soon
/// as the background mode is declared.
struct WaitHouseCreatorSheduleView: View {
    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    /// How often the screen re-asks CloudKit whether the division is ready.
    ///
    /// - Note: **Onboarding fix:** chosen to be responsive without hammering the service; the
    ///   admin's side of this handshake takes seconds to minutes.
    private static let pollInterval: Duration = .seconds(10)

    /// Drives an immediate re-check when the person comes back to the app.
    @Environment(\.scenePhase) private var scenePhase

    /// Whether a manual check is in flight, so the button can show progress.
    @State private var isCheckingNow = false

    let description1: String = "Estamos apenas esperando que o criador da casa gere a divisão das tarefas."
    let description2: String = "Isso acontecerá de forma automática assim que todos os membros entrarem na casa e definirem seus horários de tempo livre."
    let description3: String = "Enviaremos uma notificação quando a divisão estiver pronta."

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 40) {
                Image(systemName: "circle.hexagonpath")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.4)
                    .padding(.bottom)

                Text("Aguardando divisão de tarefas...")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 15) {
                    Text(description1)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)

                    Text(description2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)

                    Text(description3)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)
                }

                // MARK: - Manual escape hatch
                //
                // Onboarding fix: a waiting screen must never be the only thing standing between
                // the person and the rest of the app with no way to act on it.
                checkNowButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 30)
        }
        .navigationBarBackButtonHidden()
        .task {
            await pollWhileVisible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task(priority: .userInitiated) {
                await viewModel.checkAndAdvanceIfScheduleReady()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task(priority: .userInitiated) {
                await viewModel.checkAndAdvanceIfScheduleReady()
                print("Recebi mudança")
            }
        }
    }

    // MARK: - Subviews

    /// Lets the person force a check instead of trusting the timer.
    private var checkNowButton: some View {
        Button {
            Task {
                isCheckingNow = true
                await viewModel.checkAndAdvanceIfScheduleReady()
                isCheckingNow = false
            }
        } label: {
            if isCheckingNow {
                ProgressView()
            } else {
                Text("Verificar agora")
                    .font(.system(size: 15))
                    .underline()
                    .foregroundColor(.gray)
            }
        }
        .disabled(isCheckingNow)
    }

    // MARK: - Polling

    /// Re-checks CloudKit every ``pollInterval`` for as long as this screen is visible.
    ///
    /// - Note: **Onboarding fix:** SwiftUI cancels the task backing `.task` when the view goes
    ///   away, so the loop ends on its own — no timer to invalidate, no retain cycle. The check
    ///   runs immediately before the first sleep so arriving at an already-finished division
    ///   moves on at once.
    ///
    /// - Important: Explicitly `@MainActor`, because the closure `.task` takes is `@Sendable` and
    ///   carries no isolation of its own.
    @MainActor
    private func pollWhileVisible() async {
        while !Task.isCancelled {
            await viewModel.checkAndAdvanceIfScheduleReady()

            if viewModel.isScheduleReady { return }

            try? await Task.sleep(for: Self.pollInterval)
        }
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()
    WaitHouseCreatorSheduleView(viewModel: $mockViewModel)
}
