//
//  OnboardingRollbackJournal.swift
//  Cognitive-Work
//

import CloudKit
import Foundation

/// Records which CloudKit records each onboarding step created, so going back can undo
/// exactly that step and nothing else.
///
/// Persisted in `UserDefaults`, like ``OnboardingStateMachine``'s progress: a user who closes
/// the app mid-onboarding and taps "voltar" after relaunching still has the right records
/// deleted.
///
/// Which step owns which field:
/// - ``OnboardingNavigationSteps/createProfile``: ``createdProfile`` (and ``joinedMembership``
///   when the invited user joins right after creating the profile)
/// - ``OnboardingNavigationSteps/chooseFreeTime``: ``freeTimeRecords`` (only when the user
///   already belongs to a house; otherwise free time is kept locally as pending)
/// - ``OnboardingNavigationSteps/createOrEnterHome``: ``createdHouse`` (its whole hierarchy)
/// - ``OnboardingNavigationSteps/chooseRooms``: ``createdRooms``
struct OnboardingRollbackJournal: Codable {

    /// A `CKRecord.ID` in a form that can be encoded.
    struct StoredRecordID: Codable, Hashable {
        var recordName: String
        var zoneName: String
        var zoneOwnerName: String

        init(_ recordID: CKRecord.ID) {
            recordName = recordID.recordName
            zoneName = recordID.zoneID.zoneName
            zoneOwnerName = recordID.zoneID.ownerName
        }

        var recordID: CKRecord.ID {
            CKRecord.ID(
                recordName: recordName,
                zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwnerName)
            )
        }
    }

    /// Private profile created by `OnboardingViewModel.createUser()`.
    var createdProfile: StoredRecordID?

    /// In-house member record created by `OnboardingViewModel.joinHouse()`.
    var joinedMembership: StoredRecordID?

    /// House created by `OnboardingViewModel.createHouseAndLinkUser()`.
    var createdHouse: StoredRecordID?

    /// Availability slots saved straight on the in-house user by the free-time step.
    var freeTimeRecords: [StoredRecordID] = []

    /// Rooms created by `OnboardingViewModel.saveSelectedRooms()`.
    var createdRooms: [StoredRecordID] = []

    /// Last free time the user picked (minutes per day, Monday first). Lets the choice be
    /// restored as pending when the house it was written to is deleted.
    var lastFreeTimeMinutes: [Int]?

    // MARK: - Persistence

    private static let storageKey = "onboarding.rollbackJournal"

    static func load() -> OnboardingRollbackJournal {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let journal = try? JSONDecoder().decode(OnboardingRollbackJournal.self, from: data)
        else { return OnboardingRollbackJournal() }
        return journal
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
