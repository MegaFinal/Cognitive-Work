//
//  ScoringSystemTests.swift
//  Cognitive-WorkTests
//
//  EXEMPLO de testes para o ScoringSystem.swift
//

import Testing
import Foundation
@testable import Cognitive_Work

/// Usuário falso: evita CloudKit nos testes.
final class FakeUser: PointsHolder {
    var pointsOwnerID: String? = "user-1"
    var points = 0
    func addScore(value: Int) async -> Bool { points += value; return true }
    func subtractScore(value: Int) async -> Bool { points -= value; return true }
}

@MainActor
struct ScoringSystemTests {

    let today = Calendar.current.startOfDay(for: .now)
    func day(_ offset: Int) -> Date { Calendar.current.date(byAdding: .day, value: offset, to: today)! }

    func chore(due: Date?, detailed: Bool = false) -> ChoreSnapshot {
        ChoreSnapshot(id: "c1", hasRoom: detailed, hasDescription: detailed,
                      hasChecklist: detailed, baseScore: 20, dueDate: due)
    }

    // MARK: Regras isoladas

    @Test func criarTarefaSimplesDa7() {
        #expect(ScoringEngine().total(for: .choreCreated(chore(due: nil))) == 7)
    }

    @Test func criarTarefaDetalhadaDa7Mais5() {
        #expect(ScoringEngine().total(for: .choreCreated(chore(due: nil, detailed: true))) == 12)
    }

    @Test func adiantarDaBonus() {
        #expect(DeadlineRule().points(for: .choreCompleted(chore(due: day(2)), completedAt: today)) == 22)
    }

    @Test func noDiaDaBase() {
        #expect(DeadlineRule().points(for: .choreCompleted(chore(due: today), completedAt: today)) == 20)
    }

    @Test func atrasoPerde50PorCentoPorDia() {
        let rule = DeadlineRule()
        #expect(rule.points(for: .choreCompleted(chore(due: day(-1)), completedAt: today)) == 10)
        #expect(rule.points(for: .choreCompleted(chore(due: day(-2)), completedAt: today)) == 5)
    }

    @Test func itemComBeneficiarioDa3Mais3() {
        #expect(ScoringEngine().total(for: .shopItemAdded(itemID: "i1", hasBeneficiary: true)) == 6)
        #expect(ScoringEngine().total(for: .shopItemAdded(itemID: "i2", hasBeneficiary: false)) == 3)
    }

    @Test func atribuirResponsavel() {
        #expect(ScoringEngine().total(for: .responsibleAssigned(choreID: "c1", isSelf: true)) == 5)
        #expect(ScoringEngine().total(for: .responsibleAssigned(choreID: "c1", isSelf: false)) == 3)
    }

    // MARK: Serviço + ledger

    @Test func abrirAppDuasVezesNoDiaPontuaUmaVez() async {
        let service = PointsService()
        let user = FakeUser()
        await service.register(.appOpened(on: today), for: user)
        await service.register(.appOpened(on: today.addingTimeInterval(3600)), for: user)
        #expect(user.points == 2)
    }

    @Test func desmarcarEstornaOValorExato() async {
        let service = PointsService()
        let user = FakeUser()
        let event = ScoringEvent.choreCompleted(chore(due: day(3)), completedAt: today)

        await service.register(event, for: user)
        #expect(user.points == 22)

        // Mesmo que o completedAt mude, o sourceID é o mesmo e o estorno é o valor original.
        await service.revert(.choreCompleted(chore(due: day(3)), completedAt: day(5)), for: user)
        #expect(user.points == 0)
    }

    @Test func marcarDesmarcarNaoFarmaPontos() async {
        let service = PointsService()
        let user = FakeUser()
        let event = ScoringEvent.choreCompleted(chore(due: today), completedAt: today)
        for _ in 0..<5 {
            await service.register(event, for: user)
            await service.revert(event, for: user)
        }
        await service.register(event, for: user)
        #expect(user.points == 20)
    }
}
