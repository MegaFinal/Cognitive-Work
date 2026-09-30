//
//  Tier.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 13/08/26.
//

enum Tier: String {
    case tier1 = "tier1"
    case tier2 = "tier2"
    case tier3 = "tier3"
    
    /// Label shown on the profile (the raw "tier1" used to be displayed as-is).
    var displayName: String {
        switch self {
        case .tier1: return L10n.tr("Nível 1")
        case .tier2: return L10n.tr("Nível 2")
        case .tier3: return L10n.tr("Nível 3")
        }
    }
}
