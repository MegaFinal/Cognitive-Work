//
//  StatesForOnboarding.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 31/08/26.
//

/// Which branch of onboarding the user is going through.
///
/// `String` raw values let ``OnboardingStateMachine`` persist the current flow
/// across app launches.
enum NavigationFlowsOnboarding: String {
    case houseCreator
    case invitedWithProfile
    case invitedWithoutProfile
    case notDefined
}
