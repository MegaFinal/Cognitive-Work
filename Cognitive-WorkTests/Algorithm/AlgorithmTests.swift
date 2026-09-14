//
//  SchedulerIntegrationTests.swift
//  Cognitive-Work
//

import Testing
import Foundation
import CloudKit
@testable import Cognitive_Work

@MainActor
struct AlgorithmTests {
    
    var avalibleTime1Reference: [CKRecord.Reference] = []
    var avalibleTime2Reference: [CKRecord.Reference] = []
    var chores: [ChoreModel] = []
    
    let runID = String(UUID().uuidString.prefix(8))
    var aliceName: String { "Alice-\(runID)" }
    var bobName: String { "Bob-\(runID)" }
    
    var alice = UserModel(name: "Alice", tier: .tier1)
    var bob = UserModel(name: "Bob", tier: .tier1)
    
    // MARK: - Setup
    
    mutating func setup(chores: [ChoreModel]) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let avalibleTime1 = [
            AvailableTimeModel(capacityMinutes: 60, day: today, user: nil),
            AvailableTimeModel(capacityMinutes: 30, day: calendar.date(byAdding: .day, value: 1, to: today)!, user: nil),
            AvailableTimeModel(capacityMinutes: 120, day: calendar.date(byAdding: .day, value: 2, to: today)!, user: nil)
        ]
        let avalibleTime2 = [
            AvailableTimeModel(capacityMinutes: 20, day: calendar.date(byAdding: .day, value: 1, to: today)!, user: nil),
            AvailableTimeModel(capacityMinutes: 30, day: calendar.date(byAdding: .day, value: 2, to: today)!, user: nil),
            AvailableTimeModel(capacityMinutes: 60, day: calendar.date(byAdding: .day, value: 3, to: today)!, user: nil)
        ]
        
        for avt in avalibleTime1 {
            let saved = await CloudKitManager.shared.create(avt)
            let avtReference = CKRecord.Reference(recordID: (saved?.recordID!)!,
                                                  action: CKRecord.ReferenceAction.none)
            avalibleTime1Reference.append(avtReference)
        }
        
        for avt in avalibleTime2 {
            let saved = await CloudKitManager.shared.create(avt)
            let avtReference = CKRecord.Reference(recordID: (saved?.recordID!)!,
                                                  action: CKRecord.ReferenceAction.none)
            avalibleTime2Reference.append(avtReference)
        }
        
        alice.availableTimeReference = avalibleTime1Reference
        bob.availableTimeReference = avalibleTime2Reference
        
        alice.name = aliceName
        bob.name = bobName
        
        await CloudKitManager.shared.create(alice)
        await CloudKitManager.shared.create(bob)
        
        try? await Task.sleep(for: .seconds(1))
        
        let alicePredicate = NSPredicate(format: "name == %@", aliceName)
        let bobPredicate = NSPredicate(format: "name == %@", bobName)
        
        alice = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: alicePredicate).first!
        bob = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: bobPredicate).first!
        
        for chore in chores {
            let uniqueChore = chore
            uniqueChore.name = "\(chore.name)-\(runID)"
            self.chores.append(await CloudKitManager.shared.create(uniqueChore)!)
        }
    }
    
    // MARK: - Limpeza
    
    func deleteAll() async {
        await CloudKitManager.shared.delete(alice)
        await CloudKitManager.shared.delete(bob)
        
        for av in avalibleTime1Reference {
            await CloudKitManager.shared.delete(AvailableTimeModel.self, recordID: av.recordID)
        }
        for av in avalibleTime2Reference {
            await CloudKitManager.shared.delete(AvailableTimeModel.self, recordID: av.recordID)
        }
        for chore in chores {
            await CloudKitManager.shared.delete(chore)
        }
    }
    
    // MARK: - Teste Schedule
    
    @Test mutating func schedule() async {
        await setup(
            chores: [
                ChoreModel(name: "tarefa1", description: "description1", frequency: .daily, duration: 20, isPublic: true, priorityTag: .low),
                ChoreModel(name: "tarefa2", description: "description2", frequency: .fortnightly, duration: 40, isPublic: true, priorityTag: .medium),
                ChoreModel(name: "tarefa3", description: "description3", frequency: .monthly, duration: 30, isPublic: true, priorityTag: .high),
                ChoreModel(name: "tarefa4", description: "description4", frequency: .none, duration: 10, isPublic: true, priorityTag: .urgent),
                ChoreModel(name: "tarefa5", description: "description5", frequency: .weekly, duration: 15, isPublic: true, priorityTag: .low),
            ]
        )
        await TaskSchedulerEngine.schedule(chores: chores, users: [alice, bob])
        
        let alicePredicate = NSPredicate(format: "name == %@", aliceName)
        let bobPredicate = NSPredicate(format: "name == %@", bobName)
        
        alice = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: alicePredicate).first!
        bob = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: bobPredicate).first!
        
        #expect(alice.choresReference?.isEmpty == false)
        #expect(bob.choresReference?.isEmpty == false)
        
        await deleteAll()
    }
    
    // MARK: - Teste Incremental Scheduling and Reassignment
    
    @Test mutating func incrementalSchedulingAndReassignment() async {
        await setup(
            chores: [
                ChoreModel(name: "tarefa1", description: "description1", frequency: .daily, duration: 20, isPublic: true, priorityTag: .low),
                ChoreModel(name: "tarefa2", description: "description2", frequency: .fortnightly, duration: 40, isPublic: true, priorityTag: .medium),
                ChoreModel(name: "tarefa3", description: "description1", frequency: .none, duration: 20, isPublic: true, priorityTag: .low),
                ChoreModel(name: "tarefa4", description: "description2", frequency: .fortnightly, duration: 40, isPublic: true, priorityTag: .medium),
                ChoreModel(name: "tarefa5", description: "description3", frequency: .monthly, duration: 30, isPublic: true, priorityTag: .high),
                ChoreModel(name: "tarefa6", description: "description4", frequency: .daily, duration: 10, isPublic: true, priorityTag: .urgent),
                ChoreModel(name: "tarefa7", description: "description5", frequency: .weekly, duration: 15, isPublic: true, priorityTag: .low),
            ]
        )
        await TaskSchedulerEngine.schedule(chores: [chores[0], chores[1]], users: [alice])
        
        let alicePredicate = NSPredicate(format: "name == %@", aliceName)
        alice = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: alicePredicate).first!
        
        let aliceChores = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: ChoreModel.self,
            recordReferences: alice.choresReference!
        )
        for chore in aliceChores ?? [] {
            print("Alice chore: \(chore.name), duration: \(chore.duration), frequency: \(chore.frequency.rawValue)")
            if chore.frequency == .daily {
                let dailyAssignments = await CloudKitManager.shared.fetchRecordsByRecordReference(
                    for: RecurrentAssignmentModel.self,
                    recordReferences: chore.dailyAssignmentsReference!
                )
                
                for d in (dailyAssignments ?? []).filter({ $0.userReference?.recordID == alice.recordID }) {
                    print("     daily date: \(d.day)")
                }
            }
        }
        
        print("-------------------------------------------")

        let myChoreRefs = chores.compactMap { $0.recordID }
            .map { CKRecord.Reference(recordID: $0, action: CKRecord.ReferenceAction.none) }
        chores = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: ChoreModel.self,
            recordReferences: myChoreRefs
        ) ?? []
        
        await TaskSchedulerEngine.schedule(chores: chores, users: [alice, bob])
        alice = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: alicePredicate).first!
        
        let aliceChores2 = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: ChoreModel.self,
            recordReferences: alice.choresReference!
        )
        for chore in aliceChores2 ?? [] {
            print("Alice chore: \(chore.name), duration: \(chore.duration), frequency: \(chore.frequency.rawValue), dueDate: \(String(describing: chore.dueDate))")
            if chore.frequency == .daily {
                let dailyAssignments = await CloudKitManager.shared.fetchRecordsByRecordReference(
                    for: RecurrentAssignmentModel.self,
                    recordReferences: chore.dailyAssignmentsReference!
                )
                for d in (dailyAssignments ?? []).filter({ $0.userReference?.recordID == alice.recordID }) {
                    print("     daily date: \(d.day)")
                }
            }
        }
        
        let bobPredicate = NSPredicate(format: "name == %@", bobName)
        bob = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: bobPredicate).first!
        
        let bobChores = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: ChoreModel.self,
            recordReferences: bob.choresReference!
        )
        for chore in bobChores ?? [] {
            print("Bob chore: \(chore.name), duration: \(chore.duration), frequency: \(chore.frequency.rawValue), dueDate: \(String(describing: chore.dueDate))")
            if chore.frequency == .daily {
                let dailyAssignments = await CloudKitManager.shared.fetchRecordsByRecordReference(
                    for: RecurrentAssignmentModel.self,
                    recordReferences: chore.dailyAssignmentsReference!
                )
                for d in (dailyAssignments ?? []).filter({ $0.userReference?.recordID == bob.recordID }) {
                    print("     daily date: \(d.day)")
                }
            }
        }
        
        #expect(alice.choresReference?.isEmpty == false)
        #expect(bob.choresReference?.isEmpty == false)
        
        await deleteAll()
    }
    
    // MARK: - Teste Insufficient Capacity
        @Test mutating func insufficientCapacity() async {
            await setup(
                chores: [
                    ChoreModel(name: "tarefaGigante", description: "Muito longa", frequency: .none, duration: 999, isPublic: true, priorityTag: .urgent)
                ]
            )
            
            await TaskSchedulerEngine.schedule(chores: chores, users: [alice, bob])
            
            let taskRef = CKRecord.Reference(recordID: chores[0].recordID!, action: .none)
            let fetchedChore = await CloudKitManager.shared.fetchRecordsByRecordReference(
                for: ChoreModel.self,
                recordReferences: [taskRef]
            )?.first
            
            #expect(fetchedChore?.dueDate == nil)
            #expect(fetchedChore?.currentResponsibleReference == nil)
            
            await deleteAll()
        }
        
        // MARK: - Teste Idempotency / Re-scheduling
        @Test mutating func schedulingIdempotency() async {
            await setup(
                chores: [
                    ChoreModel(name: "tarefaRepetida", description: "Teste idempotencia", frequency: .daily, duration: 10, isPublic: true, priorityTag: .medium)
                ]
            )
            
            await TaskSchedulerEngine.schedule(chores: chores, users: [alice, bob])
            
            let alicePredicate = NSPredicate(format: "name == %@", aliceName)
            alice = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: alicePredicate).first!
            let choreCount = alice.choresReference?.count ?? 0
            
            let refreshedChores = await CloudKitManager.shared.fetchRecordsByRecordReference(
                for: ChoreModel.self,
                recordReferences: chores.compactMap { $0.recordID }.map { CKRecord.Reference(recordID: $0, action: .none) }
            ) ?? []
            
            await TaskSchedulerEngine.schedule(chores: refreshedChores, users: [alice, bob])
            
            alice = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: alicePredicate).first!
            let choreCount2 = alice.choresReference?.count ?? 0
            
            #expect(choreCount == choreCount2)
            
            await deleteAll()
        }
        
    // MARK: - Teste Fixed Responsible with No Capacity
        @Test mutating func fixedResponsibleWithoutCapacity() async {
            let aliceChore = ChoreModel(name: "AliceChore", description: "AliceChore no time", frequency: .none, duration: 500, isPublic: true, priorityTag: .high)
            
            await setup(chores: [aliceChore])
            
            let choreRef = CKRecord.Reference(recordID: chores[0].recordID!, action: .none)
            let savedChore = (await CloudKitManager.shared.fetchRecordsByRecordReference(for: ChoreModel.self, recordReferences: [choreRef]))!.first!
            savedChore.currentResponsibleReference = CKRecord.Reference(recordID: alice.recordID!, action: .none)
            
            _ = await CloudKitManager.shared.update(savedChore)
            
            await TaskSchedulerEngine.schedule(chores: [savedChore], users: [alice, bob])
            
            let choreFetched = await CloudKitManager.shared.fetchRecordsByRecordReference(for: ChoreModel.self, recordReferences: [choreRef])?.first
            
            #expect(choreFetched?.dueDate == nil)
            
            await deleteAll()
        }
}
