////
////  FortnightlyViewModel.swift
////  Cognitive-Work
////
////  Created by anshu Li on 24/08/26.
////
import SwiftUI
import CloudKit

struct DailyUsageEntry {
    let day: Date
    let userID: CKRecord.ID
    let choreID: CKRecord.ID
    let minutes: Double
    let choreName: String
    var tier: ChoreDurationTier { ChoreDurationTier.from(minutes: minutes) }
}

@Observable
class FortnightlyViewModel {
    var houseModel: HouseModel?
    var users: [UserModel] = []
    var chores: [ChoreModel] = []
    var dailyAssignments: [DailyAssignmentModel] = []
    var startDate: Date = Date()
    var isLoading: Bool = false
    var errorMessage: String?

    
    func setup(users: [UserModel], chores: [ChoreModel]) async {
        self.houseModel = try? await CloudKitManager.shared.fetchFirst(HouseModel.self)
//        self.users = await CloudKitManager.shared.fetchAll(UserModel.self)
//        for user in users {
//            let chores = await user.chores
//            self.chores.append(contentsOf: chores)
//        }
        self.users = users
        self.chores = chores
        
//        for chore in chores {
//            if chore.dailyAssignmentsReference == nil { continue }
//            dailyAssignments.append(contentsOf: await chore.dailyAssignments)
//        }
        
//        let allAssignmentRefs = allChores.flatMap { $0.dailyAssignmentsReference ?? [] }
        print("antes do fetch")
        dailyAssignments = await CloudKitManager.shared.fetchAll(DailyAssignmentModel.self)
        print("depois do fetch")

        
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
        self.startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today

        isLoading = true
        
    }
//        func loadFortnightlyData() async {
//            isLoading = true
//            defer { isLoading = false }
//
////            let userPredicate = NSPredicate(format: "house == %@", houseReference)
////            let fetchedUsers = await CloudKitManager.shared.fetchAll(UserModel.self, predicate: userPredicate)
//
//            guard !fetchedUsers.isEmpty else {
//                errorMessage = "No users found"
//                return
//            }
//
//            var allChores: [ChoreModel] = []
//            for user in fetchedUsers {
//                guard let choreRefs = user.choresReference, !choreRefs.isEmpty else { continue }
//                let userChores = await CloudKitManager.shared.fetchRecordsByRecordReference(
//                    for: ChoreModel.self,
//                    recordReferences: choreRefs
//                ) ?? []
//                allChores.append(contentsOf: userChores)
//            }
//
//            var uniqueChores: [CKRecord.ID: ChoreModel] = [:]
//            for chore in allChores {
//                if let id = chore.recordID {
//                    uniqueChores[id] = chore
//                }
//            }
//            allChores = Array(uniqueChores.values)
//
//            let allAssignmentRefs = allChores.flatMap { $0.dailyAssignmentsReference ?? [] }
//            let allAssignments = allAssignmentRefs.isEmpty ? [] : (await CloudKitManager.shared.fetchRecordsByRecordReference(
//                for: DailyAssignmentModel.self,
//                recordReferences: allAssignmentRefs
//            ) ?? [])
//
//            let calendar = Calendar.current
//            let today = Date()
//            let weekday = calendar.component(.weekday, from: today)
//            let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
//
//            self.users = fetchedUsers
//            self.chores = allChores
//            self.dailyAssignments = allAssignments
//            self.startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
//        }
    
    var usageEntries: [DailyUsageEntry] {
        get async {
            var entries: [DailyUsageEntry] = []
            
            for chore in chores {
                // Chore ainda não salva no CloudKit não tem ID → não dá para referenciar.
                guard let choreID = chore.recordID else { continue }
                
                if let refs = chore.dailyAssignmentsReference, !refs.isEmpty {
                    // Cruza as referências da chore com os assignments já carregados.
                    let relatedAssignments = dailyAssignments.filter { assignment in
                        refs.contains { $0.recordID == assignment.recordID }
                    }
                    // Um assignment = um usuário nesta chore em um dia → uma entrada cada.
                    for assignment in relatedAssignments {
                        guard let userID = await assignment.user?.recordID else { continue }
                        entries.append(DailyUsageEntry(
                            day: assignment.day,
                            userID: userID,
                            choreID: choreID,
                            minutes: chore.duration, // duração vem da chore, não do assignment
                            choreName: chore.name
                        ))
                    }
                } else {
                    // Sem escala diária: cai para vencimento + responsável atual da própria chore.
                    guard let dueDate = chore.dueDate,
                          let user = await chore.currentResponsible
                    else { continue }
                    
                    entries.append(DailyUsageEntry(
                        day: dueDate,
                        userID: user.recordID!,
                        choreID: choreID,
                        minutes: chore.duration,
                        choreName: chore.name
                    ))
                }
            }
            
            return entries
        }
    }
}
