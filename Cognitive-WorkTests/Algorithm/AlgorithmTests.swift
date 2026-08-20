//
//  SchedulerIntegrationTests.swift
//  Cognitive-Work
//
//  Testes de integração: exercitam o agendador contra o CloudKit real,
//  criando registros de verdade e verificando o que foi persistido.
//
//  Requisitos para rodar:
//   - simulador/dispositivo com conta iCloud ativa
//   - container do CloudKit acessível (Development)
//   - conexão de rede
//
//  A suíte é `.serialized` de propósito: os testes compartilham o mesmo banco
//  remoto e capacidade de slots, então rodar em paralelo produz interferência.
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
    
    var alice = UserModel(name: "Alice", tier: .tier1)
    var bob = UserModel(name: "Bob", tier: .tier1)
    
    
    mutating func setup() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var avalibleTime1 = [
            AvailableTimeModel(capacityMinutes: 60, day: today, user: nil),
            AvailableTimeModel(capacityMinutes: 30, day: calendar.date(byAdding: .day, value: 1, to: today)!, user: nil),
            AvailableTimeModel(capacityMinutes: 120, day: calendar.date(byAdding: .day, value: 2, to: today)!, user: nil)
        ]
        var avalibleTime2 = [
            AvailableTimeModel(capacityMinutes: 20, day: calendar.date(byAdding: .day, value: 1, to: today)!, user: nil),
            AvailableTimeModel(capacityMinutes: 30, day: calendar.date(byAdding: .day, value: 2, to: today)!, user: nil),
            AvailableTimeModel(capacityMinutes: 60, day: calendar.date(byAdding: .day, value: 3, to: today)!, user: nil)
        ]
        
        for avt in avalibleTime1{
            let saved = await CloudKitManager.shared.create(avt)
            let avtReference = CKRecord.Reference(recordID: (saved?.recordID!)!, action: .none)
            avalibleTime1Reference.append(avtReference)
        }
        
        for avt in avalibleTime2{
            let saved = await CloudKitManager.shared.create(avt)
            let avtReference = CKRecord.Reference(recordID: (saved?.recordID!)!, action: .none)
            avalibleTime2Reference.append(avtReference)
        }
        alice.availableTime = avalibleTime1Reference
        bob.availableTime = avalibleTime2Reference
        
        await CloudKitManager.shared.create(alice)
        await CloudKitManager.shared.create(bob)
        
        try? await Task.sleep(for: .seconds(1))
        let alicePredicate = NSPredicate(format: "name == %@", "Alice")
        let bobPredicate = NSPredicate(format: "name == %@", "Bob")
        
        alice = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: alicePredicate).first!
        bob = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: bobPredicate).first!
        
        var chores: [ChoreModel] = [
            ChoreModel(name: "tarefa1", description: "description1", frequency: .daily, duration: 20, isPublic: true, priorityTag: .low),
            ChoreModel(name: "tarefa2", description: "description2", frequency: .fortnightly, duration: 40, isPublic: true, priorityTag: .medium),
            ChoreModel(name: "tarefa3", description: "description3", frequency: .montly, duration: 30, isPublic: true, priorityTag: .high),
            ChoreModel(name: "tarefa4", description: "description4", frequency: .none, duration: 10, isPublic: true, priorityTag: .urgent),
            ChoreModel(name: "tarefa5", description: "description5", frequency: .weekly, duration: 15, isPublic: true, priorityTag: .low),
        ]
        for chore in chores {
            self.chores.append(await CloudKitManager.shared.create(chore)!)
        }
    }
    
    @Test mutating func test() async {
        await setup()
        await TaskSchedulerEngine.schedule(chores: chores, users: [alice,bob])
        
        let alicePredicate = NSPredicate(format: "name == %@", "Alice")
        let bobPredicate = NSPredicate(format: "name == %@", "Bob")
        
        alice = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: alicePredicate).first!
        bob = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: bobPredicate).first!
        
        #expect(alice.chores != nil)
        #expect(bob.chores != nil)
    }
}
