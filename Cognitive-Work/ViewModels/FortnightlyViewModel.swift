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
    let choreID: CKRecord.ID
    let minutes: Double
    let choreName: String
    var tier: ChoreDurationTier { ChoreDurationTier.from(minutes: minutes) }
}

@Observable
class FortnightlyViewModel {
    let houseModel: HouseModel?
    var users: [UserModel] = []
    var chores: [ChoreModel] = []
    var dailyAssignments: [DailyAssignmentModel] = []
    var roomNameByChoreID: [CKRecord.ID: String] = [:]
    var startDate: Date = Date()
    var isLoading: Bool = false
    var errorMessage: String?
    
    init() async {
        self.houseModel = try? await CloudKitManager.shared.fetchFirst(HouseModel.self)
        self.users = await CloudKitManager.shared.fetchAll(UserModel.self)
        self.chores = await CloudKitManager.shared.fetchAll(ChoreModel.self)
        self.dailyAssignments = await CloudKitManager.shared.fetchAll(DailyAssignmentModel.self)
        self.startDate = startDate
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
    
    func roomName(for chore: ChoreModel) -> String {
            guard let choreID = chore.recordID else { return "" }
            return roomNameByChoreID[choreID] ?? ""
        }
    
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

        var uniqueChores: [CKRecord.ID: ChoreModel] = [:]
        for chore in allChores {
            if let id = chore.recordID {
                uniqueChores[id] = chore
            }
        }
        allChores = Array(uniqueChores.values)

        let allAssignmentRefs = allChores.flatMap { $0.dailyAssignments ?? [] }
        let allAssignments = allAssignmentRefs.isEmpty ? [] : (await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: DailyAssignmentModel.self,
            recordReferences: allAssignmentRefs
        ) ?? [])

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
            guard let choreID = chore.recordID else { continue }

            if let refs = chore.dailyAssignments, !refs.isEmpty {
                let relatedAssignments = dailyAssignments.filter { assignment in
                    refs.contains { $0.recordID == assignment.recordID }
                }
                for assignment in relatedAssignments {
                    guard let userID = assignment.user?.recordID else { continue }
                    entries.append(DailyUsageEntry(
                        day: assignment.day,
                        userID: userID,
                        choreID: choreID,
                        minutes: chore.duration,
                        choreName: chore.name
                    ))
                }
            } else {
                guard let dueDate = chore.dueDate, let userID = chore.currentResponsible?.recordID else { continue }
                entries.append(DailyUsageEntry(
                    day: dueDate,
                    userID: userID,
                    choreID: choreID,
                    minutes: chore.duration,
                    choreName: chore.name
                ))
            }
        }

        return entries
    }
    
}
// MARK: - Mock Data Extension
extension FortnightlyViewModel {
    func loadMockData() {
        let user1ID = CKRecord.ID(recordName: "user-1")
        let user2ID = CKRecord.ID(recordName: "user-2")
        let user3ID = CKRecord.ID(recordName: "user-3")

        self.users = [
            UserModel(name: "You", tier: .tier1),
            UserModel(name: "Alice", tier: .tier1),
            UserModel(name: "Bob", tier: .tier2)
        ]
        self.users[0].recordID = user1ID
        self.users[1].recordID = user2ID
        self.users[2].recordID = user3ID

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (weekday == 1) ? 6 : (weekday - 2)
        self.startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        var choreWashDishes = ChoreModel(
            name: "Wash Dishes",
            description: "Lunch plates and cutlery",
            isDone: false,
            dueDate: nil,
            frequency: .daily,
            duration: 30.0,
            isPublic: true,
            priorityTag: .medium,
            currentResponsible: nil
        )
        choreWashDishes.recordID = CKRecord.ID(recordName: "chore-wash-dishes")
        
        var choreWaterPlants = ChoreModel(
            name: "Water the Plants",
            description: "Balcony and living room",
            isDone: false,
            dueDate: nil,
            frequency: .weekly,
            duration: 15.0,
            isPublic: true,
            priorityTag: .low,
            currentResponsible: CKRecord.Reference(recordID: user2ID, action: .none)
        )
        choreWaterPlants.recordID = CKRecord.ID(recordName: "chore-water-plants")

        var choreCleanHouse = ChoreModel(
            name: "Clean the House",
            description: "Vacuum and mop",
            isDone: false,
            dueDate: day(1),
            frequency: .weekly,
            duration: 90.0,
            isPublic: true,
            priorityTag: .high,
            currentResponsible: CKRecord.Reference(recordID: user2ID, action: .none)
        )
        choreCleanHouse.recordID = CKRecord.ID(recordName: "chore-clean-house")

        var choreDoLaundry = ChoreModel(
            name: "Do the Laundry",
            description: "Sort whites and colors",
            isDone: false,
            dueDate: day(1),
            frequency: .weekly,
            duration: 45.0,
            isPublic: true,
            priorityTag: .medium,
            currentResponsible: CKRecord.Reference(recordID: user1ID, action: .none)
        )
        choreDoLaundry.recordID = CKRecord.ID(recordName: "chore-do-laundry")

        var choreGroceryShopping = ChoreModel(
            name: "Grocery Shopping",
            description: "Supermarket (fruits and vegetables)",
            isDone: false,
            dueDate: day(2),
            frequency: .weekly,
            duration: 60.0,
            isPublic: true,
            priorityTag: .urgent,
            currentResponsible: CKRecord.Reference(recordID: user3ID, action: .none)
        )
        choreGroceryShopping.recordID = CKRecord.ID(recordName: "chore-grocery-shopping")

        var choreCleanBathroom = ChoreModel(
            name: "Clean the Bathroom",
            description: "Deep clean",
            isDone: false,
            dueDate: day(3),
            frequency: .weekly,
            duration: 50.0,
            isPublic: true,
            priorityTag: .high,
            currentResponsible: CKRecord.Reference(recordID: user1ID, action: .none)
        )
        choreCleanBathroom.recordID = CKRecord.ID(recordName: "chore-clean-bathroom")

        var choreOrganizePantry = ChoreModel(
            name: "Organize the Pantry",
            description: "Check expiration dates",
            isDone: false,
            dueDate: day(5),
            frequency: .monthly,
            duration: 40.0,
            isPublic: true,
            priorityTag: .low,
            currentResponsible: CKRecord.Reference(recordID: user2ID, action: .none)
        )
        choreOrganizePantry.recordID = CKRecord.ID(recordName: "chore-organize-pantry")

        let dailyRotation: [CKRecord.ID] = [user1ID, user2ID, user1ID, user3ID, user2ID, user1ID, user3ID]
        var washDishesAssignments: [DailyAssignmentModel] = []
        var washDishesRefs: [CKRecord.Reference] = []

        for offset in 0..<14 {
            let assignedUser = dailyRotation[offset % dailyRotation.count]
            var assignment = DailyAssignmentModel(
                day: day(offset),
                isCompleted: false,
                user: CKRecord.Reference(recordID: assignedUser, action: .none),
                chore: CKRecord.Reference(recordID: choreWashDishes.recordID!, action: .deleteSelf)
            )
            assignment.recordID = CKRecord.ID(recordName: "assignment-wash-dishes-\(offset)")
            washDishesAssignments.append(assignment)
            washDishesRefs.append(CKRecord.Reference(recordID: assignment.recordID!, action: .none))
        }
        choreWashDishes.dailyAssignments = washDishesRefs

        var waterPlantsAssignments: [DailyAssignmentModel] = []
        var waterPlantsRefs: [CKRecord.Reference] = []

        for offset in [0, 7] {
            var assignment = DailyAssignmentModel(
                day: day(offset),
                isCompleted: false,
                user: CKRecord.Reference(recordID: user2ID, action: .none),
                chore: CKRecord.Reference(recordID: choreWaterPlants.recordID!, action: .deleteSelf)
            )
            assignment.recordID = CKRecord.ID(recordName: "assignment-water-plants-\(offset)")
            waterPlantsAssignments.append(assignment)
            waterPlantsRefs.append(CKRecord.Reference(recordID: assignment.recordID!, action: .none))
        }
        choreWaterPlants.dailyAssignments = waterPlantsRefs

        self.chores = [
            choreWashDishes,
            choreWaterPlants,
            choreCleanHouse,
            choreDoLaundry,
            choreGroceryShopping,
            choreCleanBathroom,
            choreOrganizePantry
        ]

        self.dailyAssignments = washDishesAssignments + waterPlantsAssignments

        self.roomNameByChoreID = [
            choreWashDishes.recordID!: "Kitchen",
            choreWaterPlants.recordID!: "Living Room",
            choreCleanHouse.recordID!: "Living Room",
            choreDoLaundry.recordID!: "Laundry Room",
            choreGroceryShopping.recordID!: "Outside the House",
            choreCleanBathroom.recordID!: "Master Bathroom",
            choreOrganizePantry.recordID!: "Kitchen"
        ]
    }
}
