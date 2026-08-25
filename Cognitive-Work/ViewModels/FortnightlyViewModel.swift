//
//  FortnightlyViewModel.swift
//  Cognitive-Work
//
//  Created by anshu Li on 24/08/26.
//
import SwiftUI
import CloudKit

struct DailyUsageEntry {
    let day: Date
    let userID: CKRecord.ID
    let minutes: Double
    let choreName: String
}

@Observable
class FortnightlyViewModel {
    var users: [UserModel] = []
    var chores: [ChoreModel] = []
    var dailyAssignments: [DailyAssignmentModel] = []
    var startDate: Date = Date()
    var isLoading: Bool = false
    var errorMessage: String?
    
    func loadFortnightlyData(houseReference: CKRecord.Reference) async {
            isLoading = true
            defer { isLoading = false }

            let userPredicate = NSPredicate(format: "house == %@", houseReference)
            let fetchedUsers = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: userPredicate)

            guard !fetchedUsers.isEmpty else {
                errorMessage = "No users found"
                return
            }

            var allChores: [ChoreModel] = []
            for user in fetchedUsers {
                guard let choreRefs = user.chores, !choreRefs.isEmpty else { continue }
                let userChores = await CloudKitManager.shared.fetchRecordsByRecordReference(
                    for: ChoreModel.self,
                    recordReferences: choreRefs
                ) ?? []
                allChores.append(contentsOf: userChores)
            }

        var allAssignments: [DailyAssignmentModel] = []
            for chore in allChores {
                guard let refs = chore.dailyAssignments, !refs.isEmpty else { continue }
                let fetched = await CloudKitManager.shared.fetchRecordsByRecordReference(
                    for: DailyAssignmentModel.self,
                    recordReferences: refs
                ) ?? []
                allAssignments.append(contentsOf: fetched)
            }

            let calendar = Calendar.current
            let today = Date()
            let weekday = calendar.component(.weekday, from: today)
            let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)

            self.users = fetchedUsers
            self.chores = allChores
            self.dailyAssignments = allAssignments
            self.startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        }
    
    var usageEntries: [DailyUsageEntry] {
            var entries: [DailyUsageEntry] = []

            for chore in chores {
                if let refs = chore.dailyAssignments, !refs.isEmpty {
                    let relatedAssignments = dailyAssignments.filter { assignment in
                        refs.contains { $0.recordID == assignment.recordID }
                    }
                    for assignment in relatedAssignments {
                        guard let userID = assignment.user?.recordID else { continue }
                        entries.append(DailyUsageEntry(day: assignment.day, userID: userID, minutes: chore.duration, choreName: chore.name))
                    }
                } else {
                    guard let dueDate = chore.dueDate, let userID = chore.currentResponsible?.recordID else { continue }
                    entries.append(DailyUsageEntry(day: dueDate, userID: userID, minutes: chore.duration, choreName: chore.name))
                }
            }

            return entries
        }
    
}

extension FortnightlyViewModel {
    func loadMockData() {
        let user1ID = CKRecord.ID(recordName: "user-1")
        let user2ID = CKRecord.ID(recordName: "user-2")
        let user3ID = CKRecord.ID(recordName: "user-3")
        
        self.users = [
            UserModel(name: "Você", tier: .tier1),
            UserModel(name: "Alice", tier: .tier1),
            UserModel(name: "Bob", tier: .tier2)
        ]
        self.users[0].recordID = user1ID
        self.users[1].recordID = user2ID
        self.users[2].recordID = user3ID
        
        let today = Date()
        let calendar = Calendar.current
        
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
        self.startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        
        self.chores = [
            ChoreModel(
                name: "Lavar a louça",
                description: "Pratos e talheres do almoço",
                isDone: false,
                dueDate: today,
                frequency: .daily,
                duration: 30.0,
                isPublic: true,
                priorityTag: .medium,
                currentResponsible: CKRecord.Reference(recordID: user1ID, action: .none)
            ),
            ChoreModel(
                name: "Regar as plantas",
                description: "Varanda e sala",
                isDone: false,
                dueDate: today,
                frequency: .weekly,
                duration: 15.0,
                isPublic: true,
                priorityTag: .low,
                currentResponsible: CKRecord.Reference(recordID: user2ID, action: .none)
            ),
            
            ChoreModel(
                name: "Limpar a casa",
                description: "Passar aspirador e passar pano",
                isDone: false,
                dueDate: calendar.date(byAdding: .day, value: 1, to: today),
                frequency: .weekly,
                duration: 90.0,
                isPublic: true,
                priorityTag: .high,
                currentResponsible: CKRecord.Reference(recordID: user2ID, action: .none)
            ),
            ChoreModel(
                name: "Lavar a roupa",
                description: "Separar roupas brancas e coloridas",
                isDone: false,
                dueDate: calendar.date(byAdding: .day, value: 1, to: today),
                frequency: .weekly,
                duration: 45.0,
                isPublic: true,
                priorityTag: .medium,
                currentResponsible: CKRecord.Reference(recordID: user1ID, action: .none)
            ),
            
            // --- 后天 ---
            ChoreModel(
                name: "Fazer compras",
                description: "Supermercado (frutas e legumes)",
                isDone: false,
                dueDate: calendar.date(byAdding: .day, value: 2, to: today),
                frequency: .weekly,
                duration: 60.0,
                isPublic: true,
                priorityTag: .urgent,
                currentResponsible: CKRecord.Reference(recordID: user3ID, action: .none)
            ),
            
            ChoreModel(
                name: "Lovar o banheiro",
                description: "Limpeza profunda",
                isDone: false,
                dueDate: calendar.date(byAdding: .day, value: 3, to: today),
                frequency: .weekly,
                duration: 50.0,
                isPublic: true,
                priorityTag: .high,
                currentResponsible: CKRecord.Reference(recordID: user1ID, action: .none)
            ),
            
            ChoreModel(
                name: "Organizar a despensa",
                description: "Verificar validades",
                isDone: false,
                dueDate: calendar.date(byAdding: .day, value: 5, to: today),
                frequency: .monthly,
                duration: 40.0,
                isPublic: true,
                priorityTag: .low,
                currentResponsible: CKRecord.Reference(recordID: user2ID, action: .none)
            )
        ]
    }
}
