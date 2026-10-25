//
//  RankProgressionTests.swift
//  Cognitive-WorkTests
//
//  Created by Jonas Melo on 16/10/26.
//

import Testing
import Foundation
@testable import Cognitive_Work

@MainActor
struct RankProgressionTests {

    /// 25 points per division.
    let step = Tier.pointsPerDivision

    @Test func startsAtBronzeOne() {
        #expect(Tier(points: 0) == .bronze1)
        #expect(Tier(points: -50) == .bronze1)
    }

    @Test func climbsOneDivisionEveryStep() {
        #expect(Tier(points: step - 1) == .bronze1)
        #expect(Tier(points: step) == .bronze2)
        #expect(Tier(points: step * 2 - 1) == .bronze2)
        #expect(Tier(points: step * 2) == .bronze3)
    }

    @Test func lastDivisionLeadsToNextRanksFirstDivision() {
        #expect(Tier(points: step * 3 - 1) == .bronze3)
        #expect(Tier(points: step * 3) == .silver1)
        #expect(Tier(points: step * 6 - 1) == .silver3)
        #expect(Tier(points: step * 6) == .gold1)
    }

    @Test func masterHasNoDivisionsAndIsFinal() {
        #expect(Tier(points: step * 15 - 1) == .diamond3)
        #expect(Tier(points: step * 15) == .master)
        #expect(Tier(points: 1_000_000) == .master)
        #expect(Tier.master.next == nil)
    }

    @Test func everyTierIsOneStepOfTheLadder() {
        for (index, tier) in Tier.allCases.enumerated() {
            #expect(tier.minimumPoints == index * step)
            #expect(Tier(points: index * step) == tier)
        }
    }

    @Test func surplusCarriesOverIntoTheNextDivision() {
        let progress = Tier.progress(forPoints: step * 3 + 10)
        #expect(progress.tier == .silver1)
        #expect(progress.pointsIntoDivision == 10)
        #expect(progress.pointsToNext == step - 10)
        #expect(progress.nextTier == .silver2)
    }

    @Test func masterProgressHasNoNextStep() {
        let progress = Tier.progress(forPoints: step * 15 + 500)
        #expect(progress.tier == .master)
        #expect(progress.pointsIntoDivision == 500)
        #expect(progress.pointsToNext == nil)
    }

    @Test func userTierFollowsPoints() {
        let user = UserModel(name: "Ana", tier: .bronze1, ownerRecordName: "ana")
        user.points = step * 3
        #expect(user.tier == .silver1)
        user.points = 0
        #expect(user.tier == .bronze1)
    }
}
