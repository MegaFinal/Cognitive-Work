//
//  Tier.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 13/08/26.
//

import Foundation

/// Ranks, from lowest to highest, in the order of ``allCases``. Each rank's raw value is the name
/// of its image in the asset catalog (`Assets.xcassets/Tiers`), so it is also what is stored.
enum Tier: String, CaseIterable {
    /// Bronze, division 1 (the lowest rank, where every cycle starts).
    case bronze1
    case bronze2
    case bronze3
    /// Silver (Prata), division 1.
    case silver1
    case silver2
    case silver3
    /// Gold (Ouro), division 1.
    case gold1
    case gold2
    case gold3
    /// Platinum (Platina), division 1.
    case platinum1
    case platinum2
    case platinum3
    /// Diamond (Diamante), division 1.
    case diamond1
    case diamond2
    case diamond3
    /// Master (Mestre): the top rank, with no divisions.
    case master = "Master"
    
    // MARK: - Legacy
    
    // Records saved before the ranks had names hold "tier1", "tier2" or "tier3"; these keep
    // existing code that still says `.tier1` compiling. See ``init(stored:)``.
    static let tier1 = Tier.bronze1
    static let tier2 = Tier.bronze2
    static let tier3 = Tier.bronze3
    
    /// Decodes a tier stored in CloudKit, including the old "tier1"…"tier3" values.
    ///
    /// Unknown or missing values become ``bronze1``.
    init(stored value: String?) {
        switch value {
        case "tier1": self = .bronze1
        case "tier2": self = .bronze2
        case "tier3": self = .bronze3
        default: self = value.flatMap(Tier.init(rawValue:)) ?? .bronze1
        }
    }
    
    // MARK: - Presentation
    
    /// Name of the rank's image in the asset catalog.
    var imageName: String { rawValue }
    
    /// "Bronze 1", "Ouro 3", "Mestre"… shown on the profile.
    var displayName: String {
        switch self {
        case .bronze1: return "\(L10n.tr("Bronze")) 1"
        case .bronze2: return "\(L10n.tr("Bronze")) 2"
        case .bronze3: return "\(L10n.tr("Bronze")) 3"
        case .silver1: return "\(L10n.tr("Prata")) 1"
        case .silver2: return "\(L10n.tr("Prata")) 2"
        case .silver3: return "\(L10n.tr("Prata")) 3"
        case .gold1: return "\(L10n.tr("Ouro")) 1"
        case .gold2: return "\(L10n.tr("Ouro")) 2"
        case .gold3: return "\(L10n.tr("Ouro")) 3"
        case .platinum1: return "\(L10n.tr("Platina")) 1"
        case .platinum2: return "\(L10n.tr("Platina")) 2"
        case .platinum3: return "\(L10n.tr("Platina")) 3"
        case .diamond1: return "\(L10n.tr("Diamante")) 1"
        case .diamond2: return "\(L10n.tr("Diamante")) 2"
        case .diamond3: return "\(L10n.tr("Diamante")) 3"
        case .master: return L10n.tr("Mestre")
        }
    }
}

// MARK: - Progression

/// The 16 cases form one ladder: five ranks of three divisions each (Bronze → Diamante) plus
/// Mestre, which has no divisions. Every step costs ``pointsPerDivision`` points:
/// - Inside a rank, reaching the threshold moves to the next division (Bronze 1 → Bronze 2).
/// - From a rank's last division the next step is the next rank's first division
///   (Bronze 3 → Prata 1), at the same cost. Points above a threshold carry over.
/// - Mestre is reached at `15 × pointsPerDivision` points and is the top of the ladder: points
///   keep adding up, the rank no longer changes.
/// - Every cycle starts over: when a cycle is settled, its rank goes to the history and the
///   points go back to 0 (see ``CycleSettlementService``).
///
/// The rank is always derived from the current points, so undoing a completed chore (which
/// removes its points) can also bring the rank back down.
extension Tier {

    /// Points needed to climb one division (Bronze 1 → Bronze 2, or Bronze 3 → Prata 1).
    static let pointsPerDivision = 25

    /// Rank for `points`. Negative points count as zero.
    init(points: Int) {
        let ladder = Tier.allCases
        let step = max(points, 0) / Tier.pointsPerDivision
        self = ladder[min(step, ladder.count - 1)]
    }

    /// Position of this rank on the ladder, from 0 (Bronze 1) to 15 (Mestre).
    private var step: Int { Tier.allCases.firstIndex(of: self) ?? 0 }

    /// Points at which this rank starts.
    var minimumPoints: Int { step * Tier.pointsPerDivision }

    /// The step after this rank, or `nil` for Mestre.
    var next: Tier? {
        let ladder = Tier.allCases
        return step + 1 < ladder.count ? ladder[step + 1] : nil
    }

    /// Where `points` stand inside the current division.
    struct Progress: Equatable {
        /// The rank for these points.
        let tier: Tier
        /// Points earned since the current division started.
        let pointsIntoDivision: Int
        /// Points still missing for the next step, or `nil` at Mestre.
        let pointsToNext: Int?
        /// The rank after ``tier``, or `nil` at Mestre.
        let nextTier: Tier?
    }

    /// The rank of `points` and how far they are from the next rank.
    /// - Parameter points: The member's points in the current cycle. Negative values count as zero.
    /// - Returns: The rank, the points inside its division and the points missing for the next one.
    static func progress(forPoints points: Int) -> Progress {
        let points = max(points, 0)
        let tier = Tier(points: points)
        let next = tier.next
        return Progress(
            tier: tier,
            pointsIntoDivision: points - tier.minimumPoints,
            pointsToNext: next.map { $0.minimumPoints - points },
            nextTier: next
        )
    }
}

// MARK: - Coins

extension Tier {

    /// Coins paid at the end of each cycle to someone at this rank. A higher rank never pays
    /// less than a lower one.
    var cycleCoins: Int {
        switch self {
        case .bronze1: return 10
        case .bronze2: return 12
        case .bronze3: return 14
        case .silver1: return 18
        case .silver2: return 21
        case .silver3: return 24
        case .gold1: return 30
        case .gold2: return 34
        case .gold3: return 38
        case .platinum1: return 45
        case .platinum2: return 50
        case .platinum3: return 55
        case .diamond1: return 65
        case .diamond2: return 72
        case .diamond3: return 80
        case .master: return 100
        }
    }
}
