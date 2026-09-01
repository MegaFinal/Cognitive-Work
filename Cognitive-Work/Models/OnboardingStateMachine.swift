//
//  OnboardingStateMachine.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 31/08/26.
//

import SwiftUI

@Observable
class OnboardingStateMachine {
    var user: UserModel? = nil
    var house: HouseModel? = nil
    
    private(set) var index: Int = 0
    
    var flow: NavigationFlowsOnboarding = .notDefined
    
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
    
    var current: OnboardingNavigationSteps? {
        steps.indices.contains(index) ? steps[index] : nil
    }
    
    func setUser(user: UserModel) {
        self.user = user
    }
    
    func next() { index = min(index + 1, steps.count) }
    func back() { index = max(index - 1, 0) }
}
