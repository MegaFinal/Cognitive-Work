//
//  FreeTimeEnum.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//

enum FreeTimeEnum: String{
    case none = ""
    case thirtyMinutes = "30 minutos"
    case oneHour = "1 hora"
    case twoHours = "2 horas"
    case threeHours = "3 horas"
    case fourHours = "4 horas"
    case fiveHours = "5 horas ou mais"
    
    /// Label shown to the user, in the app's language. (`rawValue` is kept as the stable
    /// Portuguese identifier.)
    var displayName: String {
        rawValue.isEmpty ? "" : L10n.tr(rawValue)
    }
    
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
    
    var level: Int {
        switch self {
        case .none: return 0
        case .thirtyMinutes: return 1
        case .oneHour: return 2
        case .twoHours: return 3
        case .threeHours: return 4
        case .fourHours: return 5
        case .fiveHours: return 6
        }
    }
    
    init(minutes: Int) {
        switch minutes {
        case ..<1: self = .none
        case ...30: self = .thirtyMinutes
        case ...60: self = .oneHour
        case ...120: self = .twoHours
        case ...180: self = .threeHours
        case ...240: self = .fourHours
        default: self = .fiveHours
        }
    }
}
