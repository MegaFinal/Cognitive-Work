//
//  DashboardModel.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 28/08/26.
//

import Foundation
import SwiftUI
import CloudKit

@Observable
class DashboardModel: Identifiable {
    
    var users: [UserModel]
    var allChores: [ChoreModel] = []
    var averageTime: Double
    
    func setup() async {
        for user in users {
            allChores.append(contentsOf: await user.chores)
        }
    }
    
    init(users: [UserModel], allChores: [ChoreModel], averageTime: Double) {
        self.users = users
        self.allChores = allChores
        self.averageTime = averageTime
    }
}
