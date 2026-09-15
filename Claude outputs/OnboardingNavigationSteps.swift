//
//  OnboardingStep.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 31/08/26.
//

/// One screen of the onboarding flow.
///
/// ## Onboarding audit — what changed and why
///
/// The enum is now backed by `String` and conforms to `CaseIterable` so that
/// ``OnboardingStateMachine`` can persist *which step* the user reached instead of the raw
/// array index it used to store.
///
/// Persisting an index made resumed progress meaningless the moment
/// ``NavigationFlowsOnboarding`` changed, because the same number points at a different screen
/// in every flow — and at *no* screen in some of them. Index `5` is `.waitAdminScheduling` in
/// `invitedWithProfile`, but `notDefined` only has three steps, so a restored index of `5` made
/// `OnboardingStateMachine.current` return `nil`, which the router in `Onboarding.swift`
/// renders as `EmptyView()`. To the person holding the phone that is a blank white screen with
/// no way out — one of the "the app freezes / closes" reports this audit set out to explain.
///
/// Raw values are spelled explicitly rather than relying on the case names so that a future
/// rename cannot silently invalidate progress that is already persisted on someone's device.
enum OnboardingNavigationSteps: String, CaseIterable {
    case welcome = "welcome"
    case createProfile = "createProfile"
    case createOrEnterHome = "createOrEnterHome"
    case waitAcceptLink = "waitAcceptLink"
    case chooseRooms = "chooseRooms"
    case inviteAndConfirmJoin = "inviteAndConfirmJoin"
    case setUpScheduleChores = "setUpScheduleChores"
    case chooseChores = "chooseChores"
    case chooseFreeTime = "chooseFreeTime"
    case scheduleChores = "scheduleChores"
    case waitAdminScheduling = "waitAdminScheduling"
    case waitGuestsFreeTime = "waitGuestsFreeTime"
}
