//
//  OnboardingStateMachine.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 31/08/26.
//

import SwiftUI
import CloudKit

/// A state machine responsible for managing the user's progression through the onboarding process.
///
/// It persists the current state across app launches to ensure users can resume exactly where they left off.
///
/// ## Onboarding audit — what changed and why
///
/// Three problems were fixed here, all of which could strand the flow permanently:
///
/// 1. **Progress was persisted as an array index.** An index only means something relative to
///    one `steps` array, and ``flow`` can change *after* the index was written (for example
///    ``OnboardingViewModel/checkExistingAccount()`` resetting a guest to `.notDefined` when no
///    house is reachable). A restored index that falls outside the restored flow made
///    ``current`` return `nil`, and `Onboarding.swift` renders that as `EmptyView()` — a blank
///    screen with no controls. Progress is now stored as the ``OnboardingNavigationSteps`` value
///    itself, and the legacy index key is migrated once on first launch after the update.
/// 2. **Changing ``flow`` left the machine pointing at a step that flow does not contain.**
///    ``realignStepForCurrentFlow()`` now runs on every flow change and lands the user on the
///    first step of the new flow they have not completed yet, instead of on a dead index.
/// 3. **``current`` could be `nil`.** It now falls back to the first step of the active flow, so
///    the router always has something to render. A blank screen is never a valid state.
///
/// ``isOwner`` is also no longer the only way to answer "am I the admin?" — see
/// ``OnboardingViewModel/isCurrentUserAdmin()``, which re-derives it from CloudKit rather than
/// from ``house``, because ``house`` is only populated on the paths that create or explicitly
/// restore it and was left `nil` by `restoreProgressIfNeeded()`.
@Observable
class OnboardingStateMachine {

    private enum StorageKey {
        /// Legacy key, kept only so existing installs can be migrated once. See ``migrateLegacyIndexIfNeeded(for:)``.
        static let index = "onboarding.index"
        static let flow = "onboarding.flow"

        /// Replaces ``index`` as the source of truth for resumed progress.
        static let step = "onboarding.step"

        /// Steps the user has already finished, used to realign the flow safely.
        static let completed = "onboarding.completedSteps"
    }

    var user: UserModel? = nil
    var house: HouseModel? = nil

    /// The step currently being presented, and the value that is persisted across launches.
    ///
    /// - Note: **Onboarding fix:** this replaces the previous `index` storage. `index` is still
    ///   exposed (derived) so existing call sites keep compiling.
    private(set) var step: OnboardingNavigationSteps {
        didSet { persistProgress() }
    }

    /// Steps the user already completed, across every flow they passed through.
    ///
    /// Kept so that switching flows mid-onboarding (guest accepts an invite while sitting on a
    /// screen that only exists in the creator flow, say) can resume at the right place instead
    /// of restarting at `.welcome`.
    private(set) var completed: Set<OnboardingNavigationSteps> {
        didSet { persistProgress() }
    }

    var flow: NavigationFlowsOnboarding {
        didSet {
            UserDefaults.standard.set(flow.rawValue, forKey: StorageKey.flow)
            realignStepForCurrentFlow()
        }
    }

    init() {
        let savedFlow = UserDefaults.standard.string(forKey: StorageKey.flow)
        let resolvedFlow = savedFlow.flatMap(NavigationFlowsOnboarding.init(rawValue:)) ?? .notDefined

        let savedCompleted = UserDefaults.standard.stringArray(forKey: StorageKey.completed) ?? []

        self.flow = resolvedFlow
        self.completed = Set(savedCompleted.compactMap(OnboardingNavigationSteps.init(rawValue:)))
        self.step = Self.restoredStep(for: resolvedFlow)

        // Property observers do not fire during initialization, so the realignment that
        // `flow.didSet` would normally perform has to be requested explicitly once.
        realignStepForCurrentFlow()
    }

    // MARK: - Steps

    /// The dynamic array of sequential steps dictated by the currently active ``flow``.
    ///
    /// > Important: Guest flows (`invitedWithProfile`, `invitedWithoutProfile`) strictly omit administrative steps
    /// > like `.inviteAndConfirmJoin` or `.setUpScheduleChores`, routing them safely to `.waitAdminScheduling`.
    var steps: [OnboardingNavigationSteps] {
        Self.steps(for: flow)
    }

    /// The step list for a flow, as a type method so ``init()`` can use it before `self` is
    /// fully formed.
    ///
    /// - Note: **Onboarding fix:** the bodies below are unchanged from the original
    ///   implementation; only the enclosing declaration moved from an instance property to a
    ///   static function.
    static func steps(for flow: NavigationFlowsOnboarding) -> [OnboardingNavigationSteps] {
        switch flow {
        case .houseCreator:
            return [
                .welcome,
                .createProfile,
                .createOrEnterHome,
                .chooseRooms,
                .chooseChores,
                .chooseFreeTime,
                .inviteAndConfirmJoin,
                .waitGuestsFreeTime, // Admin waits here until guests input their free time
                .setUpScheduleChores, // Admin triggers the algorithm here
                .scheduleChores
            ]
        case .invitedWithProfile:
            return [
                .welcome,
                .createProfile,
                .createOrEnterHome,
                .waitAcceptLink,
                .chooseFreeTime,      // Guest inputs free time
                .waitAdminScheduling, // Guest waits here for Admin to generate schedule
                .scheduleChores
            ]
        case .invitedWithoutProfile:
            return [
                .welcome,
                .createProfile,
                .chooseFreeTime,      // Guest inputs free time
                .waitAdminScheduling, // Guest waits here for Admin
                .scheduleChores
            ]
        case .notDefined:
            return [.welcome, .createProfile, .createOrEnterHome]
        }
    }

    /// The step the router should render.
    ///
    /// - Note: **Onboarding fix:** never returns `nil` while the flow has at least one step.
    ///   The previous implementation returned `nil` for any out-of-range index, which the router
    ///   turned into a blank screen the user could not leave.
    var current: OnboardingNavigationSteps? {
        steps.contains(step) ? step : steps.first
    }

    /// Position of ``step`` inside ``steps``.
    ///
    /// Derived rather than stored — see the change log on this type.
    var index: Int {
        steps.firstIndex(of: step) ?? 0
    }

    /// Evaluates if the current user is the administrator/creator of the linked house.
    ///
    /// > Important: this only answers correctly when ``house`` has been populated. Paths that
    /// > restore progress without loading the house (the old `restoreProgressIfNeeded()`) left it
    /// > `nil`, which silently degraded to "not the owner" and stopped the admin's schedule from
    /// > ever being generated. Prefer ``OnboardingViewModel/isCurrentUserAdmin()``, which asks
    /// > CloudKit directly.
    var isOwner: Bool? {
        if let recordID = house?.recordID {
            return CloudKitManager.shared.isOwner(HouseModel.self, recordID: recordID)
        }
        return nil
    }

    // MARK: - Navigation

    func setUser(user: UserModel) { self.user = user }

    func next() {
        completed.insert(step)

        guard let position = steps.firstIndex(of: step), position + 1 < steps.count else { return }
        step = steps[position + 1]
    }

    func back() {
        guard let position = steps.firstIndex(of: step), position > 0 else { return }

        let previous = steps[position - 1]
        completed.remove(previous)
        step = previous
    }

    func resetProgress() {
        completed.removeAll()
        step = .welcome
        flow = .notDefined
    }

    /// Jumps straight to a named step of the active flow.
    ///
    /// - Note: **Onboarding fix:** prefer this over ``jumpToStep(index:)``. Resolving the target
    ///   by identity removes the "index means a different screen in a different flow" class of
    ///   bug entirely, and it silently does nothing when the step does not belong to the active
    ///   flow instead of landing on an unrelated screen.
    /// - Parameter step: The step to present. Ignored when the active ``flow`` does not contain it.
    func jump(to step: OnboardingNavigationSteps) {
        guard steps.contains(step) else { return }

        // Everything before the target is, by definition, behind the user now.
        if let position = steps.firstIndex(of: step) {
            for passed in steps.prefix(position) {
                completed.insert(passed)
            }
        }

        self.step = step
    }

    /// Jumps to a positional step of the active flow.
    ///
    /// - Note: Kept for source compatibility with existing call sites. ``jump(to:)`` is safer.
    func jumpToStep(index: Int) {
        let clamped = min(max(index, 0), max(steps.count - 1, 0))
        guard steps.indices.contains(clamped) else { return }
        jump(to: steps[clamped])
    }

    // MARK: - Persistence

    private func persistProgress() {
        UserDefaults.standard.set(step.rawValue, forKey: StorageKey.step)
        UserDefaults.standard.set(completed.map(\.rawValue), forKey: StorageKey.completed)

        // Kept in sync so a build rollback does not resume at a nonsensical position.
        UserDefaults.standard.set(index, forKey: StorageKey.index)
    }

    /// Reads persisted progress, migrating installs that still only have the legacy index key.
    private static func restoredStep(for flow: NavigationFlowsOnboarding) -> OnboardingNavigationSteps {
        let availableSteps = steps(for: flow)

        if let raw = UserDefaults.standard.string(forKey: StorageKey.step),
           let saved = OnboardingNavigationSteps(rawValue: raw) {
            return saved
        }

        return migrateLegacyIndexIfNeeded(for: availableSteps)
    }

    /// Translates the pre-audit `onboarding.index` value into a step, once.
    ///
    /// - Parameter availableSteps: Steps of the flow that was persisted alongside the index.
    /// - Returns: The step the index used to point at, or `.welcome` when it pointed nowhere.
    private static func migrateLegacyIndexIfNeeded(
        for availableSteps: [OnboardingNavigationSteps]
    ) -> OnboardingNavigationSteps {
        let legacyIndex = UserDefaults.standard.integer(forKey: StorageKey.index)

        guard availableSteps.indices.contains(legacyIndex) else {
            return availableSteps.first ?? .welcome
        }

        return availableSteps[legacyIndex]
    }

    /// Moves ``step`` back into the active flow whenever a flow change orphaned it.
    ///
    /// Lands on the first step of the new flow the user has not completed yet, so switching
    /// flows resumes forward progress instead of restarting at `.welcome`.
    private func realignStepForCurrentFlow() {
        let availableSteps = steps
        guard !availableSteps.isEmpty else { return }
        guard !availableSteps.contains(step) else { return }

        step = availableSteps.first { !completed.contains($0) } ?? availableSteps[availableSteps.count - 1]
    }
}
