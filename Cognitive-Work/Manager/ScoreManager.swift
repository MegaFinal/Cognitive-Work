//
//  ScoreManager.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 28/09/26.
//

import SwiftUI

@Observable
class ScoreManager {
    
    static let shared = ScoreManager()
    
    private init() {
        
    }
    
    //MARK: private funcs
    //MARK: Score Calculate
    private func choreScore(
        for chore: ChoreModel,
        completedAt date: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard let dueDate = chore.dueDate else { return chore.score }

        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0

        return chore.score >> max(daysUntilDue, 0)
    }
    
    //MARK: Assign Score to any User
    
    @discardableResult
    func assignScore(score: Int, for user: UserModel) async -> Bool {
        user.points += score
        return await CloudKitManager.shared.update(user)
    }

    @discardableResult
    func assignScore(chore: ChoreModel, for user: UserModel) async -> Bool {
        let earned = choreScore(for: chore)
        guard earned != 0 else { return true }

        user.points += earned
        let success = await CloudKitManager.shared.update(user)
        if !success {
            user.points -= earned
        }
        return success
    }
    
    @discardableResult
    func assignScore(recurrentAssignmentModel: RecurrentAssignmentModel, for user: UserModel) async -> Bool {
        guard let chore = await recurrentAssignmentModel.chore
        else { return false }
        
        let earned = choreScore(for: chore)
        guard earned != 0 else { return true }

        user.points += earned
        let success = await CloudKitManager.shared.update(user)
        if !success {
            user.points -= earned
        }
        return success
    }
        
    //MARK: Assign Score to My User
    
    @discardableResult
    func assignScoreForMyUser(chore: ChoreModel) async -> Bool {
        if let myUser = await CloudKitManager.shared.fetchMyHouseUser() {
            let earned = choreScore(for: chore)
            guard earned != 0 else { return true }
            
            myUser.points += earned
            let success = await CloudKitManager.shared.update(myUser)
            if !success {
                myUser.points -= earned
            }
            return success
        }
        return false
    }
    
    @discardableResult
    func assignScoreForMyUser(score: Int) async -> Bool {
        if let myUser = await CloudKitManager.shared.fetchMyHouseUser() {
            myUser.points += score
            return await CloudKitManager.shared.update(myUser)
        }
        return false
    }
    
    @discardableResult
    func assignScoreForMyUser(assignment: RecurrentAssignmentModel) async -> Bool {
        if let myUser = await CloudKitManager.shared.fetchMyHouseUser() {
            guard let chore = await assignment.chore
            else { return false }
            
            let earned = choreScore(for: chore)
            guard earned != 0 else { return true }
            
            myUser.points += earned
            let success = await CloudKitManager.shared.update(myUser)
            if !success {
                myUser.points -= earned
            }
            return success
        }
        return false
    }
    
    //MARK: Remove Score Funcions
    
    @discardableResult
    func removeScore(score: Int, for user: UserModel) async -> Bool {
        user.points -= score
        return await CloudKitManager.shared.update(user)
    }
    
    @discardableResult
    func removeScoreForMyUser(score: Int) async -> Bool {
        if let myUser = await CloudKitManager.shared.fetchMyHouseUser() {
            myUser.points -= score
            return await CloudKitManager.shared.update(myUser)
        }
        return false
    }
    
    //MARK: from Chore
    
    @discardableResult
    func removeScore(chore: ChoreModel, for user: UserModel) async -> Bool {
        user.points -= choreScore(for: chore)
        return await CloudKitManager.shared.update(user)
    }
    
    @discardableResult
    func removeScoreForMyUser(chore: ChoreModel) async -> Bool {
        if let myUser = await CloudKitManager.shared.fetchMyHouseUser() {
            myUser.points -= choreScore(for: chore)
            return await CloudKitManager.shared.update(myUser)
        }
        return false
    }
    
    //MARK: from Assignment
    
    @discardableResult
    func removeScore(assignment: RecurrentAssignmentModel, for user: UserModel) async -> Bool {
        guard let chore = await assignment.chore
        else { return false }
        
        user.points -= choreScore(for: chore)
        
        return await CloudKitManager.shared.update(user)
    }
    
    @discardableResult
    func removeScoreForMyUser(assignment: RecurrentAssignmentModel) async -> Bool {
        if let myUser = await CloudKitManager.shared.fetchMyHouseUser() {
            guard let chore = await assignment.chore
            else { return false }
            myUser.points -= choreScore(for: chore)
            return await CloudKitManager.shared.update(myUser)
        }
        return false
    }
}
