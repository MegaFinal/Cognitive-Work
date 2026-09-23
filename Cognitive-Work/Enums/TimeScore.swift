//
//  TimeScore.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 22/09/26.
//

import Foundation

enum TimeScore: Int {
    case fiveMinutesScore = 3
    case tenMinutesScore = 6
    case twentyMinutesScore = 9
    case thirtyMinutesScore = 12
    case fortyMinutesScore = 15
    case fiftyMinutesScore = 18
    case sixtyMinutesScore = 21
    
    static func getPoints(time: Double) -> Int {
        if time <= 5 {
            return fiveMinutesScore.rawValue
        }
        else if time <= 10 {
            return tenMinutesScore.rawValue
        }
        else if time <= 20 {
            return twentyMinutesScore.rawValue
        }
        else if time <= 30 {
            return thirtyMinutesScore.rawValue
        }
        else if time <= 40 {
            return fortyMinutesScore.rawValue
        }
        else if time <= 50 {
            return fiftyMinutesScore.rawValue
        }
        else if time <= 60 {
            return sixtyMinutesScore.rawValue
        }
        return 0
    }
}
