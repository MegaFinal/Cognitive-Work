# Onboarding Flow Diagnosis — Round 2

Root-cause analysis of the three reported failures, and the change set that makes the flow
deterministic: the admin owns house creation, rooms and chores; the guest only declares free
time and waits; the division runs once, on the admin's device, and reaches everyone.

## Overview

Every failure below was traced to a specific line, not inferred. Three of them are *deterministic*
— they happen 100% of the time under the described conditions — which is why the flow feels
random: several independent bugs overlap, and which one bites first depends on timing.

One finding sits underneath two of the three reports and deserves to be stated on its own:

> **`Info.plist` declares no `UIBackgroundModes`.**
> Both waiting screens refresh themselves exclusively from `.cloudKitDidChange`, which is posted
> only by `AppDelegate.application(_:didReceiveRemoteNotification:)`. That callback requires a
> silent push (`content-available`), and iOS only delivers silent pushes to a target that
> declares the `remote-notification` background mode. This target does not declare it, so the
> notification is **never posted** — not late, not unreliably: never. Both screens were built on
> a signal that cannot arrive.

The fix does not just add the key. Every waiting screen now polls CloudKit directly and re-checks
when the app returns to the foreground, so the flow works with push delivery broken, disabled, or
denied. The Info.plist key turns polling into a fast path instead of a lifeline.

## Bug 1 — The guest never leaves "waiting for the admin"

**Reported:** the admin waits, generates the division, and the guest stays on the waiting screen
forever.

**Root causes, in order of severity:**

| # | Cause | Where |
|---|---|---|
| 1.1 | `.cloudKitDidChange` is never posted (no `remote-notification` background mode) | `Info.plist` |
| 1.2 | `.task` runs once per view insertion and never again — returning from the background re-checks nothing | `WaitHouseCreatorSheduleView` |
| 1.3 | `Onboarding.task` called `deleteAllRecords()`, which **leaves every shared house**; after any relaunch the guest was no longer a participant, so the division became permanently unreachable | `Onboarding.swift` |
| 1.4 | `fetchAll(DailyAssignmentModel.self)` runs a `CKQuery`; a missing *Queryable* index throws, the error is swallowed, and `[]` is indistinguishable from "not ready yet" | `OnboardingViewModel.checkAndAdvanceIfScheduleReady()` |
| 1.5 | No manual control — the screen had no way for the person to act | `WaitHouseCreatorSheduleView` |

**Fixes:** the destructive reset is gone; the screen polls every 10 s while visible and re-checks
on `scenePhase == .active`; readiness is read by scanning the house zone
(`CloudKitManager.fetchZoneRecords(_:inZone:)`, index-free, built on `recordZoneChanges` the way
`fetchDescendantLevels(of:)` already was), with the guest's own `choresReference` as a secondary
signal; and a "Verificar agora" button guarantees the screen is never a one-way door.

## Bug 2 — The admin's "waiting for roomies" screen traps the flow

**Reported:** if the admin leaves the app on this screen, it behaves as though nobody filled in
their free time, and the flow is stuck permanently.

**Root cause 2.1 is the deterministic one, and it is a single character of arithmetic:**

```swift
// OnboardingViewModel.setAvailableTimeToUser(daysOfWeekDTO:)
capacityMinutes: Int(dayOfWeek.freeTime.timeInHours) * 60   // ← Int(0.5) == 0
```

`FreeTimeEnum.thirtyMinutes.timeInHours` is `0.5`. The conversion truncates **before** the
multiplication, so "Até 30 minutos" becomes `0 * 60 = 0` minutes. `UserModel.setAvailableTimes(_:forWeeks:)`
then skips every slot (`guard time.capacityMinutes > 0 else { continue }`), writes
`availableTimeReference` as an **empty array**, and the admin's gate — which only checked whether
that array was non-empty — counted the person as *still filling in*, forever. A guest who picked
30 minutes for every day submitted nothing at all, and had no way to discover it.

Corrected to `Int((timeInHours * 60).rounded())`.

**The rest:**

| # | Cause | Where |
|---|---|---|
| 2.2 | The screen advanced **unconditionally** after `setAvailableTimeToUser`, even when nothing was saved — so the guest believed they had submitted | `SelectFreeTimeOnboardingView` |
| 2.3 | `joinHouse()` fed `houseUserRecordID(for:)` the record in `currentUser`, which on any resumed session is already the *house copy* → `"…-house-house"`, a record `fetchMyHouseUser()` never looks for. Free time then had nowhere to be written | `OnboardingViewModel.joinHouse()` |
| 2.4 | The roster never refreshed (same dead `.cloudKitDidChange` as Bug 1), so killing the app was the only "refresh" — which ran the wipe and destroyed the house | `WaitUsersFreeTimeOnboardingView` |
| 2.5 | `isDisabled: !pendingUsers.isEmpty` **unlocks** when the fetch fails and returns zero users, letting the admin run the scheduler against nobody | `WaitUsersFreeTimeOnboardingView` |
| 2.6 | `fetchHouseUsers(of:)` filters on the `house` reference via `CKQuery`; without that index it silently returns `[]` | `CloudKitManager` |

**Fixes:** the arithmetic; the screen refuses to advance unless the write succeeded (and now has an
error alert — it had none); `joinHouse()` always derives from the private profile and
`houseUserRecordID(for:inHouseZone:)` is idempotent; the roster polls and refreshes on foreground;
completeness is measured by *actually reading the slots* and requiring at least one with real
capacity inside the scheduling window; the gate requires a loaded, non-empty roster; and member
reads fall back to an index-free zone scan.

## Bug 3 — Creating a house fails (and sometimes closes the app) after interrupting the flow

**Reported:** interrupt the flow right after creating the profile; on return, "create house" does
nothing, and lately the app closes.

**"Does nothing" is fully explained and deterministic:**

1. `Onboarding.task` ran `deleteAllRecords()` → the private zone (including the profile just
   created) was dropped on the next launch.
2. `createUser()` never called `CloudKitManager.setCurrentUser(_:)`, so the fast ID-based lookup in
   `fetchMyUser()` had nothing to read; recovery depended entirely on the `ownerRecordName`
   *Queryable* index existing in the CloudKit schema.
3. `fetchMyUser()` therefore returned `nil`, `currentUser` stayed `nil`, and
   `createHouseAndLinkUser()` hit `guard let user = currentUser else { errorMessage = …; return }`.
4. That alert appeared on a screen with `navigationBarBackButtonHidden` and no other route — an
   actual dead end.

There is also a fourth, independent way to reach "nothing happens", on the *previous* screen:
`createUser()`'s entire body was nested inside `if let imageData = userProfilePicture?.jpegData(...)`.
The picture is optional in the UI (the button only requires a name), so **a person who skipped the
photo created no record and saw no error** — "Continuar" simply did nothing.

**The crash** cannot be attributed to a single line from static reading alone, so every
code-visible hazard on that path was removed instead:

- `saveSelectedRooms()` ran a `withTaskGroup` that captured the non-`Sendable`, `@Observable`
  `HouseModel` in several concurrent child tasks, all of which could write
  `CloudKitManager.errorMessage` while SwiftUI observed it — a data race on the observation
  registrar, which is the classic shape of an intermittent SwiftUI crash. Replaced with a serial
  loop. *(The scheduler's `commitScheduleResults` still writes `errorMessage` from a `TaskGroup`;
  isolating that property to the main actor is the recommended follow-up.)*
- A restored `onboarding.index` that fell outside the restored flow made
  `OnboardingStateMachine.current` return `nil`, which the router rendered as `EmptyView()` — a
  blank, inescapable screen that reads as "the app died". Progress is now persisted as the step
  itself, and `current` never returns `nil`.
- Both buttons were tappable while the startup task was still running, racing the restore (and,
  before the reset was removed, racing a concurrent zone deletion). They are now disabled until the
  session settles.
- `shareURL!` on the invite screen was rewritten as `if let`.

## Required project change (not a source file)

Add to `Cognitive-Work/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

Without it, `AppDelegate.application(_:didReceiveRemoteNotification:)` is never called and
`.cloudKitDidChange` is never posted. The updated screens no longer depend on it, but every
cross-device update stays on the polling interval until it is added.

While there: `CKSubscription.NotificationInfo` currently sets only `shouldSendContentAvailable`,
which is a *silent* push by definition. The user-visible notification promised in
`WaitingAlgorithmView` ("Enviaremos uma notificação quando a divisão estiver pronta") and in
`StartChoreDivisionOnboardingView` still does not exist — it needs
`UNUserNotificationCenter.requestAuthorization` plus a local notification raised when the division
starts and finishes.

## CloudKit schema checklist

Several "silently empty" results trace back to missing indexes rather than to code. In the
CloudKit Console, for the development environment, confirm:

| Record type | Field | Index |
|---|---|---|
| `UserModel` | `recordName` | Queryable |
| `UserModel` | `ownerRecordName` | Queryable |
| `UserModel` | `house` | Queryable |
| `HouseModel` | `recordName` | Queryable |
| `RoomModel` | `recordName`, `house` | Queryable |
| `ChoreModel` | `recordName`, `room`, `name` | Queryable |
| `DailyAssignmentModel` | `recordName` | Queryable |
| `AvailableTimeModel` | `recordName` | Queryable |

The updated code degrades gracefully when these are missing — that is what the index-free zone
scans are for — but queries remain the faster path.

## Changed files

| File | What changed |
|---|---|
| `Enums/OnboardingNavigationSteps.swift` | `String`-backed + `CaseIterable`, so progress can be persisted by identity |
| `Models/OnboardingStateMachine.swift` | Persists the *step*, not an index; realigns on flow change; `current` never nil; legacy index migrated |
| `Manager/CloudKitManager/CloudKitManager.swift` | Idempotent house-user ID derivation; index-free zone reads; resilient subscriptions; `switchHouse` honours the leave result; destructive helpers behind `#if DEBUG` |
| `ViewModels/OnboardingViewModel.swift` | Optional photo; persists the profile; capacity arithmetic; self-healing house creation; serial room saves; validated free-time gate; index-free readiness |
| `Views/Onboarding.swift` | Destructive reset removed; foreground refresh; verified share acceptance; CloudKit-backed admin detection |
| `Views/Onboarding/WaitHouseCreatorSheduleView.swift` | Polling, foreground re-check, manual "check now" |
| `Views/Onboarding/WaitUsersFreeTimeOnboardingView.swift` | Polling, foreground re-check, real slot validation, empty-roster state |
| `Views/Onboarding/SelectFreeTimeOnboardingView.swift` | Advances only on a confirmed save; error alert; slider restores its value |
| `Views/Onboarding/CreateProfileOnboardingView.swift` | Advances only on a real profile; verified join for invited guests |
| `Views/Onboarding/CreateOrEnterHouseOnboardingView.swift` | Profile recovery instead of a dead end; buttons wait for bootstrap |
| `Views/Onboarding/WaitAcceptLinkOnboardingView.swift` | Polling, foreground re-check, verified join, manual confirmation |
| `Views/Onboarding/InviteUsersOnboardingView.swift` | Polling roster, foreground refresh, no force unwrap, share retry |

## Verification script

Run this end to end, twice — once normally, once **force-quitting both apps at every step**:

1. Admin: create profile *without a photo* (this alone used to be a silent dead stop) → create
   house → rooms → chores → free time, picking **"Até 30 minutos"** on at least one day.
2. Admin: invite. Guest: accept the link, create profile, declare free time — again with
   **"Até 30 minutos"** somewhere.
3. Admin's waiting screen must move the guest from red to green **without the app being killed**,
   within one polling interval.
4. Admin: generate the division. The guest's screen must advance on its own, with the app merely
   backgrounded — no relaunch.
5. Relaunch both apps at every stage and confirm each resumes on the correct step, with the house,
   rooms, chores and availability all still present.
