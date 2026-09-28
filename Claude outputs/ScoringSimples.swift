//
//  ScoringSimples.swift
//  Cognitive-Work
//
//  Exemplo simples: eventos como structs + regras (Strategy) com o próprio valor.
//

import Foundation

// MARK: - 1. Eventos: cada ação do app é uma struct

protocol ScoringEvent {
    /// Chave única: o mesmo evento não pontua duas vezes.
    var id: String { get }
}

struct ChoreCreated: ScoringEvent {
    let choreID: String
    let isDetailed: Bool          // tem cômodo, descrição e checklist
    var id: String { "create-\(choreID)" }
}

struct ShopItemAdded: ScoringEvent {
    let itemID: String
    let hasBeneficiary: Bool
    var id: String { "shop-\(itemID)" }
}

// MARK: - 2. Regras: cada uma trata um tipo de evento e guarda o próprio valor

protocol ScoringRule {
    associatedtype Event: ScoringEvent
    func points(for event: Event) -> Int
}

extension ScoringRule {
    /// Se o evento não é do tipo da regra, ela dá 0.
    func evaluate(_ event: any ScoringEvent) -> Int {
        guard let event = event as? Event else { return 0 }
        return points(for: event)
    }
}

struct AddChoreRule: ScoringRule {
    var value = 7
    func points(for event: ChoreCreated) -> Int { value }
}

struct DetailedChoreRule: ScoringRule {
    var value = 5
    func points(for event: ChoreCreated) -> Int { event.isDetailed ? value : 0 }
}

struct AddShopItemRule: ScoringRule {
    var value = 3
    func points(for event: ShopItemAdded) -> Int { value }
}

struct BeneficiaryRule: ScoringRule {
    var value = 3
    func points(for event: ShopItemAdded) -> Int { event.hasBeneficiary ? value : 0 }
}

// MARK: - 3. Serviço: soma as regras e credita no usuário

final class PointsService {
    static let shared = PointsService()

    /// Todas as regras do app. Regra nova = uma linha aqui.
    private let rules: [any ScoringRule] = [
        AddChoreRule(),
        DetailedChoreRule(),
        AddShopItemRule(),
        BeneficiaryRule(),
    ]

    /// Quanto cada evento já deu (para não repetir e para estornar o valor certo).
    /// Em produção, salvar isso no CloudKit.
    private var awarded: [String: Int] = [:]

    func register(_ event: any ScoringEvent, for user: UserModel) async {
        guard awarded[event.id] == nil else { return }

        let total = rules.reduce(0) { $0 + $1.evaluate(event) }
        guard total > 0 else { return }

        awarded[event.id] = total
        await user.addScore(value: total)
    }

    func revert(_ event: any ScoringEvent, for user: UserModel) async {
        guard let total = awarded.removeValue(forKey: event.id) else { return }
        await user.subtractScore(value: total)
    }
}

/*
 MARK: - 4. Uso

 // CreateAndEditChoreView.confirmAndSave(), depois do save:
 if isNewChore, let id = originalModel.recordID?.recordName,
    let me = await CloudKitManager.shared.fetchMyHouseUser() {
     let detailed = originalModel.roomReference != nil
         && !originalModel.description.isEmpty
         && !(originalModel.checkListReference ?? []).isEmpty
     await PointsService.shared.register(ChoreCreated(choreID: id, isDetailed: detailed), for: me)
     // → +7, ou +12 se detalhada
 }

 // ShopListViewModel.addItem(...), depois do items.append(created):
 if let addedBy {
     await PointsService.shared.register(
         ShopItemAdded(itemID: created.id, hasBeneficiary: !relatedUsers.isEmpty),
         for: addedBy
     )
     // → +3, ou +6 com beneficiário
 }

 // Nova ação no app?
 // 1. struct NovoEvento: ScoringEvent
 // 2. struct NovaRegra: ScoringRule
 // 3. adicionar NovaRegra() no array `rules`
 // Nada do que já existe precisa mudar.
*/
