//
//  AlgorithmTests.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 19/08/26.
//


import Testing
import Foundation
@testable import Cognitive_Work
import CloudKit

@MainActor
class AlgorithmTests {
    var localAlice: UserModel! = nil
    var localBob: UserModel! = nil
    var localCarol: UserModel! = nil
    
    var localChores: [ChoreModel] = []
    
    func setup() async {
        localAlice = await CloudKitManager.shared.create(alice)
        localBob = await CloudKitManager.shared.create(bob)
        localCarol = await CloudKitManager.shared.create(carol)
        
        for chore in chores {
            localChores.append(await CloudKitManager.shared.create(chore)!)
        }
    }
    
    @Test func scheduleTest() async {
        await setup()
        
        let alice = TestFixtures.makeUser(name: "Alice")
        let bob = TestFixtures.makeUser(name: "Bob")
        
        let aliceSlots = [
            TestFixtures.makeSlot(user: alice, dayOffset: 0, capacityMinutes: 60),
            TestFixtures.makeSlot(user: alice, dayOffset: 1, capacityMinutes: 60)
        ]
        let bobSlots = [
            TestFixtures.makeSlot(user: bob, dayOffset: 0, capacityMinutes: 60),
            TestFixtures.makeSlot(user: bob, dayOffset: 2, capacityMinutes: 150)
        ]
        
        let userAvailableTimeMap: [CKRecord.ID: [AvailableTimeModel]] = [
            alice.recordID!: aliceSlots,
            bob.recordID!: bobSlots
        ]
        let userTotalCapacity: [CKRecord.ID: Int] = [
            alice.recordID!: aliceSlots.reduce(0) { $0 + $1.capacityMinutes },
            bob.recordID!: bobSlots.reduce(0) { $0 + $1.capacityMinutes }
        ]
        
        let context = ScheduleContext(
            userAvailableTimeMap: userAvailableTimeMap,
            choreResponsibleMap: [:],
            userTotalCapacity: userTotalCapacity,
            minimumCapacity: userTotalCapacity.values.min() ?? 0
        )
        
        var remainingCapacity = context.initialRemainingCapacity()
        var userAssignedMinutes = context.initialUserAssignedMinutes(users: [alice, bob])
        
        let chore = ChoreModel(name: "Wash Dishes", description: "", isDone: false, frequency: .daily, duration: 20, isPublic: true, priorityTag: .medium)
        
        let results = scheduleDailyChores(
            [chore], users: [alice, bob], context: context,
            now: Calendar.current.startOfDay(for: Date()),
            remainingCapacity: &remainingCapacity,
            userAssignedMinutes: &userAssignedMinutes
        )
        
        #expect(results.count == 1)
        #expect(results.first?.newAssignments.count == 7)
    }
}

let alice: UserModel = UserModel(name: "Alice", tier: .tier1, coins: 120, points: 340, couponLimit: 3)
let bob: UserModel = UserModel(name: "Bob", tier: .tier1, coins: 40, points: 90, couponLimit: 3)
let carol: UserModel = UserModel(name: "Carol", tier: .tier1, coins: 60, points: 150, couponLimit: 3)

// MARK: - Chores

let chores: [ChoreModel] = [
    
    // Urgentes
    
    //AliceRef
    ChoreModel(
        name: "Cook Dinner",
        description: "Prepare the evening meal for the house.",
        isDone: false,
        frequency: .daily,
        duration: 20 * 60,
        isPublic: false,
        priorityTag: .urgent
    ),
    //bobRef
    ChoreModel(
        name: "Pick Up Prescription",
        description: "Collect the pending prescription at the pharmacy.",
        isDone: false,
        frequency: .daily,
        duration: 40 * 60,
        isPublic: false,
        priorityTag: .urgent
    ),
    ChoreModel(
        name: "Pay Utility Bills",
        description: "Settle electricity, water and internet.",
        isDone: false,
        frequency: .none,
        duration: 25 * 60,
        isPublic: true,
        priorityTag: .urgent
    ),
    
    // Alta
    
    ChoreModel(
        name: "Vacuum & Mop Floors",
        description: "Vacuum and mop the shared areas.",
        isDone: false,
        frequency: .daily,
        duration: 20 * 60,
        isPublic: true,
        priorityTag: .high
    ),
    ChoreModel(
        name: "Grocery Shopping",
        description: "Buy the items on the shared list.",
        isDone: false,
        frequency: .none,
        duration: 20 * 60,
        isPublic: true,
        priorityTag: .high
    ),
    ChoreModel(
        name: "Laundry",
        description: "Wash, dry and fold the clothes.",
        isDone: false,
        frequency: .none,
        duration: 120 * 60,
        isPublic: true,
        priorityTag: .high
    ),
    ChoreModel(
        name: "Clean Bathroom",
        description: "Scrub the sink, toilet, shower and mirror.",
        isDone: false,
        frequency: .none,
        duration: 150 * 60,
        isPublic: true,
        priorityTag: .high
    ),
    ChoreModel(
        name: "Meal Prep for Week",
        description: "Cook and portion meals for the coming week.",
        isDone: false,
        frequency: .none,
        duration: 20 * 60,
        isPublic: true,
        priorityTag: .high
    ),
    
    // Média
    
    ChoreModel(
        name: "Wash Dishes",
        description: "Clean the dishes and wipe the counter.",
        isDone: false,
        frequency: .daily,
        duration: 20 * 60,
        isPublic: true,
        priorityTag: .medium
    ),
    ChoreModel(
        name: "Water Plants",
        description: "Water the indoor and balcony plants.",
        isDone: false,
        frequency: .none,
        duration: 15 * 60,
        isPublic: true,
        priorityTag: .medium
    ),
    ChoreModel(
        name: "Change Bed Sheets",
        description: "Swap the sheets and pillowcases.",
        isDone: false,
        frequency: .none,
        duration: 30 * 60,
        isPublic: true,
        priorityTag: .medium
    ),
    ChoreModel(
        name: "Organize Pantry",
        description: "Sort the pantry and discard expired items.",
        isDone: false,
        frequency: .none,
        duration: 20 * 60,
        isPublic: true,
        priorityTag: .medium
    ),
    ChoreModel(
        name: "Deep Clean Fridge",
        description: "Empty the fridge, clean the shelves and restock.",
        isDone: false,
        frequency: .none,
        duration: 10 * 60,
        isPublic: true,
        priorityTag: .medium
    ),
    ChoreModel(
        name: "Iron Clothes",
        description: "Iron the clothes waiting in the basket.",
        isDone: false,
        frequency: .none,
        duration: 40 * 60,
        isPublic: true,
        priorityTag: .medium
    ),
    
    // Baixa
    
    ChoreModel(
        name: "Take Out Trash",
        description: "Take the bags out and replace the liners.",
        isDone: false,
        frequency: .none,
        duration: 10 * 60,
        isPublic: true,
        priorityTag: .low
    ),
    ChoreModel(
        name: "Dust Shelves",
        description: "Dust the shelves and living room surfaces.",
        isDone: false,
        frequency: .none,
        duration: 25 * 60,
        isPublic: true,
        priorityTag: .low
    ),
    ChoreModel(
        name: "Sort Mail",
        description: "Go through the mail and discard what is not needed.",
        isDone: false,
        frequency: .none,
        duration: 15 * 60,
        isPublic: true,
        priorityTag: .low
    ),
    ChoreModel(
        name: "Wash Car",
        description: "Wash the car inside and out.",
        isDone: false,
        frequency: .none,
        duration: 160 * 60,
        isPublic: true,
        priorityTag: .low
    ),
    ChoreModel(
        name: "Reorganize Closet",
        description: "Reorganize the closet and set aside clothes to donate.",
        isDone: false,
        frequency: .none,
        duration: 50 * 60,
        isPublic: true,
        priorityTag: .low
    ),
    
    //Alice ref
    ChoreModel(
        name: "Clean Windows",
        description: "Clean the windows and frames.",
        isDone: false,
        frequency: .none,
        duration: 80 * 60,
        isPublic: false,
        priorityTag: .low
    )
]

enum TestFixtures {
    
    static func fakeRecordID(_ name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: name)
    }
    
    static func day(offset: Int, from base: Date = Date()) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: base)
        return calendar.date(byAdding: .day, value: offset, to: today)!
    }
    
    static func makeUser(name: String) -> UserModel {
        var user = UserModel(name: name, tier: .tier1)
        user.recordID = fakeRecordID("user-\(name)")
        return user
    }
    
    static func makeSlot(user: UserModel, dayOffset: Int, capacityMinutes: Int) -> AvailableTimeModel {
        var slot = AvailableTimeModel(capacityMinutes: capacityMinutes, day: day(offset: dayOffset))
        slot.recordID = fakeRecordID("slot-\(user.name)-\(dayOffset)")
        slot.user = CKRecord.Reference(recordID: user.recordID!, action: .none)
        return slot
    }
}

