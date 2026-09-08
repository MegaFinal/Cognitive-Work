//
//  GlobalFunctions.swift
//  Cognitive-Work
//

import Foundation
import CloudKit

// MARK: - Context Construction

/// Builds the scheduling context containing user available times, capacities, and responsible maps.
///
/// - Parameters:
///   - users: An array of ``UserModel`` instances representing the household members.
///   - chores: An array of ``ChoreModel`` instances to evaluate.
///   - now: The start date of the scheduling period (today).
///   - windowEnd: The end date of the scheduling period (14 days later).
/// - Returns: A ``ScheduleContext`` instance containing aggregated scheduling metadata.
func buildScheduleContext(
    users: [UserModel],
    chores: [ChoreModel],
    now: Date,
    windowEnd: Date
) async -> ScheduleContext {

    // Initialize a dictionary to store the list of available time slots for each user ID
    var userAvailableTimeMap: [CKRecord.ID: [AvailableTimeModel]] = [:]
    // Initialize a dictionary to store the total capacity (in minutes) for each user ID
    var userTotalCapacity: [CKRecord.ID: Int] = [:]

    // Iterate through each user
    for user in users {
        // Ensure the user's recordID exists and that they have available time slot references
        guard let userID = user.recordID, let refs = user.availableTimeReference else { continue }
        // Fetch all available time slot records for this user from CloudKit, or default to an empty array if it fails
        let slots = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: AvailableTimeModel.self,
            recordReferences: refs
        ) ?? []

        // Filter for valid time slots between today (inclusive) and window end (exclusive)
        let validSlots = slots.filter { slot in
            let day = Calendar.current.startOfDay(for: slot.day)
            return day >= now && day < windowEnd
        }

        // Store valid time slots in the user's available time map
        userAvailableTimeMap[userID] = validSlots
        // Calculate the total capacity in minutes for this user during this period and store it in the total capacity dictionary
        userTotalCapacity[userID] = validSlots.reduce(0) { $0 + $1.capacityMinutes }
    }

    // Initialize a dictionary to store the mapping from chore ID to its corresponding responsible user model
    var choreResponsibleMap: [CKRecord.ID: UserModel] = [:]
    // Iterate through each chore
    for chore in chores {
        // Ensure the chore has a current responsible reference and a chore ID
        guard let ref = chore.currentResponsibleReference, let choreID = chore.recordID else { continue }

        // If the corresponding user is found in the locally loaded users array, reuse it directly to avoid unnecessary CloudKit network requests
        if let local = users.first(where: { $0.recordID == ref.recordID }) {
            choreResponsibleMap[choreID] = local
            continue
        }

        // If not found locally, fetch the user model from CloudKit using the remote reference and store it in the mapping
        if let fetched = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: UserModel.self,
            recordReferences: [ref]
        )?.first {
            choreResponsibleMap[choreID] = fetched
        }
    }

    // Get the minimum total capacity among all users, defaulting to 0 if none exists (used for subsequent baseline capacity calculations)
    let minimumCapacity = userTotalCapacity.values.min() ?? 0

    // Return the constructed scheduling context object
    return ScheduleContext(
        userAvailableTimeMap: userAvailableTimeMap,
        choreResponsibleMap: choreResponsibleMap,
        userTotalCapacity: userTotalCapacity,
        minimumCapacity: minimumCapacity
    )
}

// MARK: - Recurring Chores

/// Helper function to determine which day offsets a recurring frequency should appear on within the window.
func occurrenceOffsets(for frequency: Recurrence, windowDays: Int) -> [Int] {
    switch frequency {
    case .daily:
        return Array(0..<windowDays)
    case .weekly:
        return Swift.stride(from: 0, to: windowDays, by: 7).map { $0 }
    case .fortnightly:
        return Swift.stride(from: 0, to: windowDays, by: 14).map { $0 }
    case .monthly, .none:
        return []
    }
}

/// Schedules recurring chores across the 14-day period for appropriate users based on their frequency.
///
/// - Parameters:
///   - recurringChores: An array of recurring chores to schedule.
///   - users: An array of available household members.
///   - context: The current scheduling context.
///   - now: The start date.
///   - remainingCapacity: A mutable reference to remaining capacity per time slot.
///   - userAssignedMinutes: A mutable reference to total assigned minutes per user.
/// - Returns: An array of ``ScheduleResult`` containing the newly generated assignments.
func scheduleRecurringChores(
    _ recurringChores: [ChoreModel],
    users: [UserModel],
    context: ScheduleContext,
    now: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {

    // Initialize the scheduling results array
    var results: [ScheduleResult] = []

    // Iterate through each recurring chore
    for chore in recurringChores {
        // Ensure the chore ID exists
        guard let choreID = chore.recordID else { continue }
        // Create a scheduling result object for the current chore
        var result = ScheduleResult(chore: chore)

        // Check if this chore has a fixed responsible user; if so, target only that user, otherwise target all users
        let fixedUser = context.choreResponsibleMap[choreID]
        let targetUsers = fixedUser.map { [$0] } ?? users

        // Loop through the specific occurrence offsets for this chore's frequency within the 14-day window
        for dayOffset in occurrenceOffsets(for: chore.frequency, windowDays: 14) {
            // Calculate the specific date for the current offset day, skipping if it fails
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            // Initialize the list of users capable of undertaking this chore today
            var availableToday: [UserModel] = []
            for user in targetUsers {
                // Ensure the user ID exists
                guard let userID = user.recordID else { continue }
                // Get the user's available time slots
                let slots = context.userAvailableTimeMap[userID] ?? []
                // Find the time slot for the corresponding date where the remaining capacity is greater than or equal to the chore duration
                if let slot = slots.first(where: { Calendar.current.startOfDay(for: $0.day) == day }),
                   let slotID = slot.recordID {
                    let remaining = remainingCapacity[slotID] ?? 0

                    // If remaining capacity is sufficient, add the user to today's available list
                    if remaining >= chore.duration {
                        availableToday.append(user)
                    }
                }
            }

            // Recurring chores must be assigned to someone on their scheduled days, even if everyone lacks sufficient capacity
            let pool = availableToday.isEmpty ? targetUsers : availableToday

            // Select the user from the candidate pool who currently has the fewest assigned minutes (to achieve load balancing)
            guard let chosenUser = pool.min(by: { u1, u2 in
                let a1 = u1.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
                let a2 = u2.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
                return a1 < a2
            }), let chosenUserID = chosenUser.recordID else { continue }

            // Get the selected user's available time slots and deduct the corresponding capacity
            let slots = context.userAvailableTimeMap[chosenUserID] ?? []
            if let slot = slots.first(where: { Calendar.current.startOfDay(for: $0.day) == day }),
               let slotID = slot.recordID {
                let remaining = remainingCapacity[slotID] ?? 0

                // Update the remaining capacity of the time slot (cannot be less than 0)
                remainingCapacity[slotID] = max(remaining - chore.duration, 0)
            }

            // Accumulate the assigned minutes for the selected user
            userAssignedMinutes[chosenUserID, default: 0] += Int(chore.duration)

            // Create cloud references and generate the daily assignment model (DailyAssignmentModel)
            let chosenUserRef = CKRecord.Reference(recordID: chosenUserID, action: CKRecord.ReferenceAction.none)
            let choreRef = CKRecord.Reference(recordID: choreID, action: CKRecord.ReferenceAction.deleteSelf)
            let assignment = DailyAssignmentModel(
                day: day,
                isCompleted: false,
                user: chosenUserRef,
                chore: choreRef
            )
            // Append the assignment record to the current chore's results
            result.newAssignments.append(assignment)
        }

        // Add the complete scheduling result of the current chore to the total results set
        results.append(result)
    }

    return results
}

// MARK: - Assigned Chores

/// Schedules chores that already have a specific responsible user assigned.
///
/// - Parameters:
///   - assignedChores: An array of chores with predetermined assignees.
///   - context: The scheduling context.
///   - now: The start date.
///   - windowEnd: The end date.
///   - remainingCapacity: Mutable slot capacity dictionary.
///   - userAssignedMinutes: Mutable user assigned minutes dictionary.
/// - Returns: An array of ``ScheduleResult``.
func scheduleAssignedChores(
    _ assignedChores: [ChoreModel],
    context: ScheduleContext,
    now: Date,
    windowEnd: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {

    var results: [ScheduleResult] = []

    // Iterate through each chore that already has a responsible user
    for chore in assignedChores {
        // Ensure the chore ID, responsible user, and user ID all exist
        guard let choreID = chore.recordID,
              let user = context.choreResponsibleMap[choreID],
              let userID = user.recordID else { continue }

        let updatable = chore
        let slots = context.userAvailableTimeMap[userID] ?? []

        // Filter for available time slots within the validity period with sufficient capacity
        let distributables = slots.filter { slot in
            let day = Calendar.current.startOfDay(for: slot.day)
            guard day >= now && day < windowEnd, let slotID = slot.recordID else { return false }
            let remaining = remainingCapacity[slotID] ?? 0

            return remaining >= chore.duration
        }

        // Find the earliest day to schedule this chore; if no suitable time slot exists, clear the due date and save
        guard let chosenSlot = distributables.min(by: { $0.day < $1.day }),
              let slotID = chosenSlot.recordID else {
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }

        // Set the chore's due date to the selected time slot's date
        updatable.dueDate = chosenSlot.day

        // Deduct the remaining capacity of the corresponding time slot and increase the user's assigned minutes
        remainingCapacity[slotID] = (remainingCapacity[slotID] ?? 0) - chore.duration
        userAssignedMinutes[userID, default: 0] += Int(chore.duration)

        // Wrap the result and add it to the set
        results.append(ScheduleResult(chore: updatable))
    }

    return results
}

// MARK: - Free Chores

/// Automatically assigns and schedules chores that do not have a pre-assigned responsible user.
///
/// - Parameters:
///   - freeChores: An array of unassigned chores.
///   - users: All available household users.
///   - context: The scheduling context.
///   - now: The start date.
///   - windowEnd: The end date.
///   - remainingCapacity: Mutable slot capacity dictionary.
///   - userAssignedMinutes: Mutable user assigned minutes dictionary.
/// - Returns: An array of ``ScheduleResult``.
func scheduleFreeChores(
    _ freeChores: [ChoreModel],
    users: [UserModel],
    context: ScheduleContext,
    now: Date,
    windowEnd: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {

    var results: [ScheduleResult] = []

    // Iterate through each free chore (chores without a pre-assigned responsible user)
    for chore in freeChores {
        let updatable = chore

        // Collect all (user, time slot) combinations capable of undertaking this chore
        var distributable: [(user: UserModel, slot: AvailableTimeModel)] = []
        for user in users {
            guard let userID = user.recordID else { continue }
            let slots = context.userAvailableTimeMap[userID] ?? []
            for slot in slots {
                let day = Calendar.current.startOfDay(for: slot.day)
                guard day >= now && day < windowEnd, let slotID = slot.recordID else { continue }
                let remaining = remainingCapacity[slotID] ?? 0

                // If capacity is sufficient, add to the optional distribution list
                if remaining >= chore.duration {
                    distributable.append((user, slot))
                }
            }
        }

        // If there are no available combinations, clear the responsible user and due date, and return
        guard !distributable.isEmpty else {
            updatable.currentResponsibleReference = nil
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }

        // Prioritize filtering users to avoid pushing tasks to those already near or over the household minimum capacity limit, preventing overload on capable members
        let baselineUsers = distributable.filter { option in
            guard let userID = option.user.recordID else { return false }
            let used = userAssignedMinutes[userID] ?? 0

            return Double(used) + chore.duration < Double(context.minimumCapacity)
        }

        // If the baseline user list is empty (everyone would exceed or there is no room for extreme distribution), fall back to all available combinations
        let pool = baselineUsers.isEmpty ? distributable : baselineUsers

        // Select the combination with the lightest load and earliest date from the candidate pool as the optimal solution
        guard let chosen = pool.min(by: { o1, o2 in
            let a1 = o1.user.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
            let a2 = o2.user.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
            if a1 != a2 { return a1 < a2 }
            return o1.slot.day < o2.slot.day
        }), let chosenUserID = chosen.user.recordID, let slotID = chosen.slot.recordID else {
            updatable.currentResponsibleReference = nil
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }

        // Set the selected user as the current responsible person for the chore
        updatable.currentResponsibleReference = CKRecord.Reference(
            recordID: chosenUserID,
            action: CKRecord.ReferenceAction.none
        )

        // Update the historical responsible rotation list (allResponsibleUsers), ensuring no duplicate additions
        var rotation = updatable.allResponsibleUsersReference ?? []
        if !rotation.contains(where: { $0.recordID == chosenUserID }) {
            rotation.append(CKRecord.Reference(recordID: chosenUserID, action: CKRecord.ReferenceAction.none))
        }
        updatable.allResponsibleUsersReference = rotation

        // Set the due date of the chore
        updatable.dueDate = chosen.slot.day

        // Deduct the capacity of the corresponding time slot and accumulate the user's assigned minutes
        remainingCapacity[slotID] = (remainingCapacity[slotID] ?? 0) - chore.duration
        userAssignedMinutes[chosenUserID, default: 0] += Int(chore.duration)

        results.append(ScheduleResult(chore: updatable))
    }

    return results
}

// MARK: - Repair

/// Clears stale ``ChoreModel/dailyAssignmentsReference`` lists left behind by the zone bug
/// fixed in ``commitScheduleResults(_:users:houseZoneID:)``: before that fix, whichever
/// device ran the scheduler first saved the `DailyAssignmentModel` records into its own
/// private zone instead of the house's, so nobody else — including the house owner — could
/// ever read them back.
///
/// Because ``TaskSchedulerEngine/schedule(chores:users:)`` only reschedules a recurring
/// chore whose reference list is empty, a chore stuck pointing at unreadable records would
/// otherwise never be rescheduled again. This checks whether the referenced records are
/// actually readable and, if none of them are, clears the list so the caller's own
/// `recurringChores` filter picks the chore back up this run.
///
/// - Parameter chores: Every chore currently loaded, as passed into ``TaskSchedulerEngine/schedule(chores:users:)``.
func repairOrphanedRecurringAssignments(in chores: [ChoreModel]) async {
    let recurringFrequencies: Set<Recurrence> = [.daily, .weekly, .fortnightly]

    for chore in chores {
        guard !chore.isDone,
              recurringFrequencies.contains(chore.frequency),
              let refs = chore.dailyAssignmentsReference,
              !refs.isEmpty
        else { continue }

        // `fetchRecordsByRecordReference` bails out (returns `nil`) the moment a single
        // reference fails to fetch, rather than returning the ones that did resolve. That's
        // fine here: every reference for a given chore was written by the same
        // `commitScheduleResults` call, so they're either all in the wrong zone or all fine
        // — there's no realistic case where only some of them are orphaned.
        let resolved = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: DailyAssignmentModel.self,
            recordReferences: refs
        )

        if resolved?.isEmpty ?? true {
            chore.dailyAssignmentsReference = nil
            await CloudKitManager.shared.update(chore)
        }
    }
}

// MARK: - Persistence

/// Commits all schedule results by saving them to CloudKit and updating user relationships.
///
/// - Parameters:
///   - results: An array of ``ScheduleResult`` to commit.
///   - users: An array of ``UserModel`` to update.
///   - houseZoneID: The house's actual record zone, so the new `DailyAssignmentModel`
///     records land where every housemate (owner included) can read them, rather than in
///     whichever device happens to run this. `nil` falls back to the old, zone-unsafe
///     behavior if the house couldn't be resolved.
func commitScheduleResults(_ results: [ScheduleResult], users: [UserModel], houseZoneID: CKRecordZone.ID?) async {

    // Create and save each chore and its corresponding daily assignment records in the cloud
    for result in results {
        guard let choreID = result.chore.recordID else { continue }

        var savedRefs: [CKRecord.Reference] = []
        for assignment in result.newAssignments {
            // Create a single daily assignment record in CloudKit, explicitly inside the
            // house's zone rather than the calling device's own private zone.
            if let saved = await CloudKitManager.shared.create(assignment, zoneID: houseZoneID),
               let savedID = saved.recordID {
                savedRefs.append(CKRecord.Reference(recordID: savedID, action: CKRecord.ReferenceAction.none))
            }
        }

        // Merge newly generated daily assignment references into the chore object and update the chore once
        let updatableChore = result.chore
        updatableChore.recordID = choreID
        if !savedRefs.isEmpty {
            updatableChore.dailyAssignmentsReference = (updatableChore.dailyAssignmentsReference ?? []) + savedRefs
        }
        await CloudKitManager.shared.update(updatableChore)
    }

    // Associate the scheduled chores into the corresponding user's personal task list
    var choresByUser: [CKRecord.ID: [CKRecord.Reference]] = [:]

    for result in results {
        guard let choreID = result.chore.recordID else { continue }
        let choreRef = CKRecord.Reference(recordID: choreID, action: CKRecord.ReferenceAction.none)

        // Collect all user IDs involved in this chore
        var userIDs = Set<CKRecord.ID>()
        if let responsibleID = result.chore.currentResponsibleReference?.recordID {
            userIDs.insert(responsibleID)
        }
        for assignment in result.newAssignments {
            if let assignedID = assignment.user?.recordID {
                userIDs.insert(assignedID)
            }
        }

        // Categorize chore references into the dictionary corresponding to user IDs
        for userID in userIDs {
            choresByUser[userID, default: []].append(choreRef)
        }
    }

    // Iterate through all users, append new tasks to the user's tasks field, and sync to the cloud
    for user in users {
        guard let userID = user.recordID,
              let newRefs = choresByUser[userID],
              !newRefs.isEmpty else { continue }

        var updatableUser = user

        let existingRefs = updatableUser.choresReference ?? []
        let existingIDs = Set(existingRefs.map { $0.recordID })
        let dedupedNewRefs = newRefs.filter { !existingIDs.contains($0.recordID) }

        guard !dedupedNewRefs.isEmpty else { continue }

        updatableUser.choresReference = existingRefs + dedupedNewRefs
        await CloudKitManager.shared.update(updatableUser)
    }
}
