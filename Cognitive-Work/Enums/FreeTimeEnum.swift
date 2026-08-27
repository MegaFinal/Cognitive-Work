//
//  FreeTimeEnum.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//


enum FreeTimeEnum: String{
    case none = ""
    case thirtyMinutes = "Até 30 minutos"
    case oneHour = "Até 1 hora"
    case twoHours = "Até 2 horas"
    case threeHours = "Até 3 horas"
    case fourHours = "Até 4 horas"
    case fiveHours = "5 horas ou mais"
    
    var timeInHours: Double {
        switch self {
        case .none:
            return 0.0
        case .thirtyMinutes:
            return 0.5
        case .oneHour:
            return 1.0
        case .twoHours:
            return 2.0
        case .threeHours:
            return 3.0
        case .fourHours:
            return 4.0
        case .fiveHours:
            return 5.0
        }
    }
    
    init(_ num: Int) {
        switch num {
        case 0 :
            self = .none
        case 1 :
            self = .thirtyMinutes
        case 2 :
            self = .oneHour
        case 3 :
            self = .twoHours
        case 4 :
            self = .threeHours
        case 5 :
            self = .fourHours
        case 6 :
            self = .fiveHours
        default:
            self = .none
        }
    }
}