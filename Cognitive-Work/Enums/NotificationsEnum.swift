//
//  NotificationsEnum.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 30/09/26.
//

import SwiftUI

enum Notifications: String {
    case grabChore = " tarefas a pegar hoje"
    case retrospective = "Sua retrospectiva chegou"
    // [newUser] Disabled until we define what tapping it should do.
    // case newUser = " entrou na casa"
    case newDivision = "Nova divisão pronta"
    case yourDelayedChore = " está atrasado"
    case noUserDelayedChore = "Ninguém pegou "
    
    var subTitle: String {
        switch self {
        case .grabChore: return "Escolha as que couberem no seu tempo"
        case .retrospective: return "Veja como foram os seus últimos 15 dias da casa"
        // case .newUser: return "Veja como foram os seus últimos 15 dias da casa"
        case .newDivision: return "Suas tarefas dos próximos 15 dias já estão na escala"
        case .yourDelayedChore: return ""
        case .noUserDelayedChore: return ""
        }
    }
    
    var color: Color {
        switch self {
        case .grabChore: return .lowOpacityBlue
        case .retrospective: return .lowOpacityYellow
        // case .newUser: return .lowOpacityPurple
        case .newDivision: return .lowOpacityGreen
        case .yourDelayedChore: return .lowOpacityOrange
        case .noUserDelayedChore: return .lowOpacityOrange
        }
    }
    
    var symbol: String {
        switch self {
        case .grabChore: return "hand.rays"
        case .retrospective: return "chart.bar.xaxis"
        // case .newUser: return "person"
        case .newDivision: return "chart.bar.horizontal.page"
        case .yourDelayedChore: return "exclamationmark.triangle"
        case .noUserDelayedChore: return "exclamationmark.triangle"
        }
    }
}
