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
/// It persists the current state (both the active flow and the step index) across app launches
/// to ensure users can resume exactly where they left off if the app is closed.
@Observable
class OnboardingStateMachine {

    // MARK: - Persistence

    /// UserDefaults keys used to persist onboarding progress across app launches.
    private enum StorageKey {
        static let index = "onboarding.index"
        static let flow = "onboarding.flow"
    }

    // MARK: - Properties

    /// The user profile being created or utilized during the onboarding process.
    var user: UserModel? = nil
    
    /// The house record being created or joined during the onboarding process.
    var house: HouseModel? = nil

    /// The current position index within the active ``steps`` array.
    ///
    /// > Note: Whenever this property is updated, its new value is automatically
    /// > persisted to `UserDefaults` to prevent progress loss.
    private(set) var index: Int {
        didSet { UserDefaults.standard.set(index, forKey: StorageKey.index) }
    }

    /// The specific branching path the user is currently following.
    ///
    /// Since the meaning of a given index changes depending on the active flow, this
    /// is persisted alongside the ``index``.
    var flow: NavigationFlowsOnboarding {
        didSet { UserDefaults.standard.set(flow.rawValue, forKey: StorageKey.flow) }
    }

    // MARK: - Initialization

    /// Initializes the state machine, restoring the previous session's index and flow from `UserDefaults`.
    init() {
        self.index = UserDefaults.standard.integer(forKey: StorageKey.index)

        let savedFlow = UserDefaults.standard.string(forKey: StorageKey.flow)
        self.flow = savedFlow.flatMap(NavigationFlowsOnboarding.init(rawValue:)) ?? .notDefined
    }

    // MARK: - Computed Properties

    /// Evaluates if the current user is the administrator/creator of the linked house.
    ///
    /// - Returns: `true` if the user owns the house zone, `false` otherwise, or `nil` if no house exists yet.
    var isOwner: Bool? {
        if let recordID = house?.recordID {
            return CloudKitManager.shared.isOwner(HouseModel.self, recordID: recordID)
        }
        return nil
    }
    
    /// The dynamic array of sequential steps dictated by the currently active ``flow``.
    var steps: [OnboardingNavigationSteps] {
        switch flow {
        case .houseCreator:
            return [
                .welcome,
                .createProfile,
                .createOrEnterHome,
                .chooseRooms,
                .inviteAndConfirmJoin,
                .setUpScheduleChores,
                .chooseChores,
                .chooseFreeTime,
                .scheduleChores
            ]
        case .invitedWithProfile:
            return [
                .welcome,
                .createProfile,
                .createOrEnterHome,
                .waitAcceptLink,
                .inviteAndConfirmJoin,
                .setUpScheduleChores,
                .chooseChores,
                .chooseFreeTime,
                .scheduleChores
            ]
        case .invitedWithoutProfile:
            return [
                .welcome,
                .createProfile,
                .inviteAndConfirmJoin,
                .setUpScheduleChores,
                .chooseChores,
                .chooseFreeTime,
                .scheduleChores
            ]
        case .notDefined:
            return [.welcome, .createProfile, .createOrEnterHome]
        }
    }
    
    /// Returns the specific navigation step corresponding to the current ``index``.
    ///
    /// - Returns: The active `OnboardingNavigationSteps`, or `nil` if the index is out of bounds.
    var current: OnboardingNavigationSteps? {
        steps.indices.contains(index) ? steps[index] : nil
    }
    
    // MARK: - Navigation & Mutators

    /// Assigns a newly created or fetched user to the state machine's memory.
    ///
    /// - Parameter user: The `UserModel` instance to store.
    func setUser(user: UserModel) {
        self.user = user
    }
    
    /// Advances the state machine to the next step, safely bounded by the array limits.
    func next() {
        index = min(index + 1, steps.count - 1)
    }
    
    /// Retreats the state machine to the previous step, safely bounded to zero.
    func back() {
        index = max(index - 1, 0)
    }

    /// Clears the persisted progress completely.
    ///
    /// > Important: Call this once onboarding finishes (or is skipped) so a future run
    /// > doesn't attempt to resume in the middle of a flow that is no longer applicable.
    func resetProgress() {
        index = 0
        flow = .notDefined
    }
    
    func jumpToStep(index: Int) {
        self.index = min(max(index, 0), steps.count - 1)
    }
}
