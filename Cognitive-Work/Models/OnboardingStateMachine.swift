//
//  OnboardingStateMachine.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 31/08/26.
//

import SwiftUI

@Observable
class OnboardingStateMachine {

    // MARK: - Persistence

    /// UserDefaults keys used to persist onboarding progress across app launches.
    private enum StorageKey {
        static let index = "onboarding.index"
        static let flow = "onboarding.flow"
    }

    // MARK: - Properties

    var user: UserModel? = nil
    var house: HouseModel? = nil

    /// Current position in ``steps``. Persisted so relaunching the app resumes onboarding
    /// where the user left off instead of restarting from the first step.
    private(set) var index: Int {
        didSet { UserDefaults.standard.set(index, forKey: StorageKey.index) }
    }

    /// Which branch of onboarding the user is in. Persisted alongside ``index``, since the
    /// meaning of a given index depends on which flow it belongs to.
    var flow: NavigationFlowsOnboarding {
        didSet { UserDefaults.standard.set(flow.rawValue, forKey: StorageKey.flow) }
    }

    // MARK: - Init

    init() {
        self.index = UserDefaults.standard.integer(forKey: StorageKey.index)

        let savedFlow = UserDefaults.standard.string(forKey: StorageKey.flow)
        self.flow = savedFlow.flatMap(NavigationFlowsOnboarding.init(rawValue:)) ?? .notDefined
    }

    var isOwner: Bool? {
        if let recordID = house?.recordID {
            return CloudKitManager.shared.isOwner(HouseModel.self, recordID: recordID)
        }
        return nil
    }
    
    var steps: [OnboardingNavigationSteps] {
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
                .setUpScheduleChores,
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
                .chooseFreeTime,
                .waitAdminScheduling,
                .scheduleChores
            ]
        case .invitedWithoutProfile:
            return [
                .welcome,
                .createProfile,
                .inviteAndConfirmJoin,
                .setUpScheduleChores,
                .chooseFreeTime,
                .waitAdminScheduling,
                .scheduleChores
            ]
        case .notDefined:
            return [.welcome, .createProfile, .createOrEnterHome]
        }
    }
    
    var current: OnboardingNavigationSteps? {
        steps.indices.contains(index) ? steps[index] : nil
    }
    
    // MARK: - Navigation

    func setUser(user: UserModel) {
        self.user = user
    }
    
    func next() { index = min(index + 1, steps.count - 1) }
    func back() { index = max(index - 1, 0) }

    /// Clears the persisted progress. Call once onboarding finishes (or is skipped) so a
    /// future run doesn't try to resume in the middle of a flow that no longer applies.
    func resetProgress() {
        index = 0
        flow = .notDefined
    }
}
