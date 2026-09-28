//
//  ScoringSystem.swift
//  Cognitive-Work
//
//  EXEMPLO de implementação da tabela "Ações no app consideradas cognitivas".
//  Padrões: Strategy (uma regra por linha da tabela) + eventos + ledger de transações.
//
//  O projeto usa SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, então tudo aqui roda no MainActor.
//

import Foundation

// MARK: - 1. Tabela de valores (um lugar só para ajustar os números)

enum ScoringTable {
    static let addChore = 7
    static let detailedChoreBonus = 5
    static let addShopItem = 3
    static let shopItemBeneficiaryBonus = 3
    static let dailyOpen = 2
    static let finishedEarlyBonus = 2
    static let linkCalendar = 10
    static let assignSomeoneElse = 3
    static let assignMyself = 5
    static let claimUnassignedChore = 7
    static let writeChecklist = 3
    static let perReceiptItem = 1
    // "Confirmar com o grupo": dividir automaticamente, adiantar tarefa de outra pessoa,
    // resolver pendências financeiras → basta adicionar aqui + criar a regra.
}

// MARK: - 2. Eventos (o que aconteceu no app)

/// Foto dos dados da tarefa que as regras precisam. As regras não dependem do ChoreModel
/// (nem do CloudKit), o que facilita os testes.
struct ChoreSnapshot {
    let id: String
    let hasRoom: Bool
    let hasDescription: Bool
    let hasChecklist: Bool
    /// prioridade + frequência + duração (o que o calculateDonePoints já soma hoje)
    let baseScore: Int
    let dueDate: Date?
}

extension ChoreSnapshot {
    init(_ chore: ChoreModel) {
        self.init(
            id: chore.recordID?.recordName ?? chore.id.uuidString,
            hasRoom: chore.roomReference != nil,
            hasDescription: !chore.description.trimmingCharacters(in: .whitespaces).isEmpty,
            hasChecklist: !(chore.checkListReference ?? []).isEmpty,
            baseScore: chore.priorityTag.scoreValue
                + chore.frequency.scoreValue
                + TimeScore.getPoints(time: chore.duration),
            dueDate: chore.dueDate
        )
    }
}

extension ChoreSnapshot {
    /// Para uma ocorrência de tarefa recorrente: o id e o prazo são os da ocorrência.
    init(_ chore: ChoreModel, occurrence: RecurrentAssignmentModel) {
        let base = ChoreSnapshot(chore)
        self.init(
            id: occurrence.recordID?.recordName ?? base.id,
            hasRoom: base.hasRoom,
            hasDescription: base.hasDescription,
            hasChecklist: base.hasChecklist,
            baseScore: base.baseScore,
            dueDate: occurrence.day
        )
    }
}

enum ScoringEvent {
    case choreCreated(ChoreSnapshot)
    case choreCompleted(ChoreSnapshot, completedAt: Date)
    case choreClaimed(choreID: String)
    case responsibleAssigned(choreID: String, isSelf: Bool)
    case checklistWritten(choreID: String)
    case shopItemAdded(itemID: String, hasBeneficiary: Bool)
    case receiptScanned(receiptID: String, itemCount: Int)
    case calendarLinked
    case appOpened(on: Date)

    /// Chave única do evento. O mesmo evento nunca pontua duas vezes
    /// (evita farm: marcar/desmarcar, abrir o app 10x no dia, etc.).
    var sourceID: String {
        switch self {
        case .choreCreated(let c):
            "create-\(c.id)"
        case .choreCompleted(let c, _):
            // Inclui o prazo: numa tarefa recorrente, cada ocorrência pontua uma vez.
            "done-\(c.id)-\(c.dueDate.map(Self.dayKey) ?? "no-due")"
        case .choreClaimed(let id):
            "claim-\(id)"
        case .responsibleAssigned(let id, _):
            "assign-\(id)"
        case .checklistWritten(let id):
            "checklist-\(id)"
        case .shopItemAdded(let id, _):
            "shop-\(id)"
        case .receiptScanned(let id, _):
            "receipt-\(id)"
        case .calendarLinked:
            "calendar-link"
        case .appOpened(let date):
            "open-\(Self.dayKey(date))"
        }
    }

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}

// MARK: - 3. Regras (Strategy): uma struct por linha da tabela

protocol ScoringRule {
    /// Texto mostrado ao usuário, ex.: "Tarefa bem detalhada".
    var name: String { get }
    /// Pontos que a regra dá para o evento, ou `nil` se ela não se aplica.
    func points(for event: ScoringEvent) -> Int?
}

// Planejamento e antecipação
struct AddChoreRule: ScoringRule {
    let name = "Criou uma tarefa"
    func points(for event: ScoringEvent) -> Int? {
        guard case .choreCreated = event else { return nil }
        return ScoringTable.addChore
    }
}

struct DetailedChoreBonusRule: ScoringRule {
    let name = "Tarefa bem detalhada"
    func points(for event: ScoringEvent) -> Int? {
        guard case .choreCreated(let c) = event,
              c.hasRoom, c.hasDescription, c.hasChecklist
        else { return nil }
        return ScoringTable.detailedChoreBonus
    }
}

struct AddShopItemRule: ScoringRule {
    let name = "Adicionou item na lista de compras"
    func points(for event: ScoringEvent) -> Int? {
        guard case .shopItemAdded = event else { return nil }
        return ScoringTable.addShopItem
    }
}

struct ShopItemBeneficiaryRule: ScoringRule {
    let name = "Definiu quem vai usar o item"
    func points(for event: ScoringEvent) -> Int? {
        guard case .shopItemAdded(_, true) = event else { return nil }
        return ScoringTable.shopItemBeneficiaryBonus
    }
}

// Monitoramento contínuo
struct DailyOpenRule: ScoringRule {
    let name = "Abriu o app hoje"
    func points(for event: ScoringEvent) -> Int? {
        guard case .appOpened = event else { return nil }
        return ScoringTable.dailyOpen
    }
}

// Memória e prazos
struct DeadlineRule: ScoringRule {
    let name = "Concluiu a tarefa"
    var calendar: Calendar = .current

    func points(for event: ScoringEvent) -> Int? {
        guard case .choreCompleted(let c, let completedAt) = event else { return nil }
        guard let due = c.dueDate else { return c.baseScore }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: completedAt),
            to: calendar.startOfDay(for: due)
        ).day ?? 0

        if days > 0 { return c.baseScore + ScoringTable.finishedEarlyBonus } // adiantou: +2
        if days == 0 { return c.baseScore }                                    // no dia: +0
        return c.baseScore >> min(-days, Int.bitWidth - 1)                     // -50% por dia de atraso
    }
}

struct CalendarLinkRule: ScoringRule {
    let name = "Conectou o calendário"
    func points(for event: ScoringEvent) -> Int? {
        guard case .calendarLinked = event else { return nil }
        return ScoringTable.linkCalendar
    }
}

// Coordenação logística
struct AssignResponsibleRule: ScoringRule {
    let name = "Atribuiu um responsável"
    func points(for event: ScoringEvent) -> Int? {
        guard case .responsibleAssigned(_, let isSelf) = event else { return nil }
        return isSelf ? ScoringTable.assignMyself : ScoringTable.assignSomeoneElse
    }
}

// Delegação e acompanhamento
struct ClaimChoreRule: ScoringRule {
    let name = "Pegou uma tarefa sem dono"
    func points(for event: ScoringEvent) -> Int? {
        guard case .choreClaimed = event else { return nil }
        return ScoringTable.claimUnassignedChore
    }
}

struct WriteChecklistRule: ScoringRule {
    let name = "Escreveu descrição/checklist"
    func points(for event: ScoringEvent) -> Int? {
        guard case .checklistWritten = event else { return nil }
        return ScoringTable.writeChecklist
    }
}

// Tomada de decisão constante
struct ReceiptScanRule: ScoringRule {
    let name = "Escaneou uma nota fiscal"
    func points(for event: ScoringEvent) -> Int? {
        guard case .receiptScanned(_, let count) = event, count > 0 else { return nil }
        return count * ScoringTable.perReceiptItem
    }
}

// MARK: - 4. Motor: aplica todas as regras e soma

struct ScoreLine: Identifiable {
    let id = UUID()
    let reason: String
    let points: Int
}

struct ScoringEngine {
    var rules: [any ScoringRule] = [
        AddChoreRule(), DetailedChoreBonusRule(),
        AddShopItemRule(), ShopItemBeneficiaryRule(),
        DailyOpenRule(),
        DeadlineRule(), CalendarLinkRule(),
        AssignResponsibleRule(),
        ClaimChoreRule(), WriteChecklistRule(),
        ReceiptScanRule(),
    ]

    /// Detalhamento por regra, útil para mostrar "+7 Criou uma tarefa, +5 Tarefa bem detalhada".
    func evaluate(_ event: ScoringEvent) -> [ScoreLine] {
        rules.compactMap { rule in
            rule.points(for: event).map { ScoreLine(reason: rule.name, points: $0) }
        }
    }

    func total(for event: ScoringEvent) -> Int {
        evaluate(event).reduce(0) { $0 + $1.points }
    }
}

// MARK: - 5. Ledger: registra cada pontuação para poder estornar e evitar duplicidade

struct PointsTransaction: Codable, Identifiable {
    var id = UUID()
    let userID: String
    let sourceID: String
    let points: Int
    let reasons: [String]
    let date: Date
}

protocol PointsLedger {
    func transaction(sourceID: String, userID: String) async -> PointsTransaction?
    func append(_ transaction: PointsTransaction) async
    func remove(sourceID: String, userID: String) async -> PointsTransaction?
}

/// Versão em memória, para testes e protótipo.
/// Em produção: um record type "PointsTransaction" no CloudKit, com referência ao usuário.
final class InMemoryPointsLedger: PointsLedger {
    private var storage: [String: PointsTransaction] = [:]
    private func key(_ sourceID: String, _ userID: String) -> String { "\(userID)|\(sourceID)" }

    func transaction(sourceID: String, userID: String) async -> PointsTransaction? {
        storage[key(sourceID, userID)]
    }
    func append(_ t: PointsTransaction) async {
        storage[key(t.sourceID, t.userID)] = t
    }
    func remove(sourceID: String, userID: String) async -> PointsTransaction? {
        storage.removeValue(forKey: key(sourceID, userID))
    }
}

// MARK: - 6. Quem recebe os pontos (protocolo para dar para testar sem CloudKit)

protocol PointsHolder: AnyObject {
    var pointsOwnerID: String? { get }
    func addScore(value: Int) async -> Bool
    func subtractScore(value: Int) async -> Bool
}

extension UserModel: PointsHolder {
    var pointsOwnerID: String? { recordID?.recordName }
}

// MARK: - 7. Serviço: a única porta de entrada usada pelas views/models

final class PointsService {
    static let shared = PointsService()

    private let engine: ScoringEngine
    private let ledger: PointsLedger

    init(engine: ScoringEngine = ScoringEngine(), ledger: PointsLedger = InMemoryPointsLedger()) {
        self.engine = engine
        self.ledger = ledger
    }

    /// Pontua o evento para o usuário. Retorna o detalhamento (vazio se já tinha pontuado).
    @discardableResult
    func register(_ event: ScoringEvent, for user: PointsHolder, at date: Date = .now) async -> [ScoreLine] {
        guard let userID = user.pointsOwnerID else { return [] }

        // Idempotência: o mesmo evento não pontua duas vezes.
        if await ledger.transaction(sourceID: event.sourceID, userID: userID) != nil { return [] }

        let lines = engine.evaluate(event)
        let total = lines.reduce(0) { $0 + $1.points }
        guard total != 0 else { return [] }

        await ledger.append(PointsTransaction(
            userID: userID,
            sourceID: event.sourceID,
            points: total,
            reasons: lines.map(\.reason),
            date: date
        ))
        await user.addScore(value: total)
        return lines
    }

    /// Desfaz a pontuação de um evento com o valor exato que foi dado (ex.: desmarcar tarefa,
    /// apagar tarefa recém-criada).
    @discardableResult
    func revert(_ event: ScoringEvent, for user: PointsHolder) async -> Int {
        guard let userID = user.pointsOwnerID,
              let t = await ledger.remove(sourceID: event.sourceID, userID: userID)
        else { return 0 }
        await user.subtractScore(value: t.points)
        return t.points
    }
}

extension PointsService {
    /// Atalho para quando a tela não tem o usuário atual em mãos.
    @discardableResult
    func registerForMe(_ event: ScoringEvent) async -> [ScoreLine] {
        guard let me = await CloudKitManager.shared.fetchMyHouseUser() else { return [] }
        return await register(event, for: me)
    }

    @discardableResult
    func revertForMe(_ event: ScoringEvent) async -> Int {
        guard let me = await CloudKitManager.shared.fetchMyHouseUser() else { return 0 }
        return await revert(event, for: me)
    }
}

/*
 MARK: - 8. Como ficaria o uso no projeto

 // ChoreModel.toggleAndAssignPointsToTheUser()
 // No lugar de calculateDonePoints() + addScore/subtractScore:
 let event = ScoringEvent.choreCompleted(ChoreSnapshot(self), completedAt: .now)
 if isDone {
     await PointsService.shared.register(event, for: myUser)
 } else {
     await PointsService.shared.revert(event, for: myUser)   // estorna exatamente o que deu
 }

 // Depois de salvar uma tarefa nova:
 let lines = await PointsService.shared.register(.choreCreated(ChoreSnapshot(chore)), for: me)
 // lines → [+7 "Criou uma tarefa", +5 "Tarefa bem detalhada"] → dá para mostrar num toast

 // Ao apagar a tarefa (evita criar/apagar para farmar pontos):
 await PointsService.shared.revert(.choreCreated(ChoreSnapshot(chore)), for: me)

 // Ao adicionar item na lista de compras:
 await PointsService.shared.register(
     .shopItemAdded(itemID: item.id, hasBeneficiary: !item.relatedUsers(in: houseUsers).isEmpty),
     for: me
 )

 // No App / ScenePhase .active:
 await PointsService.shared.register(.appOpened(on: .now), for: me)   // só pontua 1x por dia
*/
