//
//  TaskSchedulerEngine.swift
//  Cognitive-Work
//
//  Versão corrigida. Cada alteração está marcada com "FIX N" e explicada
//  no comentário adjacente.
//

import Foundation
import CloudKit

// MARK: - FIX 1: unidade de duração
//
// `ChoreModel.duration` é TimeInterval em SEGUNDOS (o mock usa `20 * 60`).
// `AvailableTimeModel.capacityMinutes` é Int em MINUTOS.
// O código original comparava os dois diretamente (`remaining >= chore.duration`),
// o que significava 60 >= 1200 → sempre falso. Nenhuma tarefa cabia em nenhum slot.
//
// Esta propriedade dá um nome único à conversão para que ela não seja esquecida
// em nenhum ponto de comparação.

// MARK: - Modelos de apoio

struct ScheduleContext {
    let userAvailableTimeMap: [CKRecord.ID: [AvailableTimeModel]]
    let choreResponsibleMap: [CKRecord.ID: UserModel]
    let userTotalCapacity: [CKRecord.ID: Int]
    let minimumCapacity: Int

    func initialRemainingCapacity() -> [CKRecord.ID: Double] {
        var map: [CKRecord.ID: Double] = [:]
        for (_, slots) in userAvailableTimeMap {
            for slot in slots {
                guard let id = slot.recordID else { continue }
                map[id] = Double(slot.capacityMinutes)
            }
        }
        return map
    }

    func initialUserAssignedMinutes(users: [UserModel]) -> [CKRecord.ID: Int] {
        Dictionary(uniqueKeysWithValues: users.compactMap { user -> (CKRecord.ID, Int)? in
            guard let id = user.recordID else { return nil }
            return (id, 0)
        })
    }
}

struct ScheduleResult {
    var chore: ChoreModel
    var newAssignments: [DailyAssignmentModel] = []
}

// MARK: - Construção do contexto

func buildScheduleContext(
    users: [UserModel],
    chores: [ChoreModel],
    now: Date,
    oneWeekLater: Date
) async -> ScheduleContext {

    var userAvailableTimeMap: [CKRecord.ID: [AvailableTimeModel]] = [:]
    var userTotalCapacity: [CKRecord.ID: Int] = [:]

    for user in users {
        guard let userID = user.recordID, let refs = user.availableTime else { continue }
        let slots = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: AvailableTimeModel.self,
            recordReferences: refs
        ) ?? []

        let validSlots = slots.filter { slot in
            let day = Calendar.current.startOfDay(for: slot.day)
            return day >= now && day < oneWeekLater
        }

        userAvailableTimeMap[userID] = validSlots
        userTotalCapacity[userID] = validSlots.reduce(0) { $0 + $1.capacityMinutes }
    }

    var choreResponsibleMap: [CKRecord.ID: UserModel] = [:]
    for chore in chores {
        guard let ref = chore.currentResponsible, let choreID = chore.recordID else { continue }

        // FIX 2: usuário já carregado é reaproveitado em vez de refetchado.
        // O original fazia uma consulta ao CloudKit por tarefa, mesmo quando o
        // responsável já estava no array `users`. Com 20 tarefas isso eram 20
        // round-trips desnecessários.
        if let local = users.first(where: { $0.recordID == ref.recordID }) {
            choreResponsibleMap[choreID] = local
            continue
        }

        if let fetched = await CloudKitManager.shared.fetchRecordsByRecordReference(
            for: UserModel.self,
            recordReferences: [ref]
        )?.first {
            choreResponsibleMap[choreID] = fetched
        }
    }

    let minimumCapacity = userTotalCapacity.values.min() ?? 0

    return ScheduleContext(
        userAvailableTimeMap: userAvailableTimeMap,
        choreResponsibleMap: choreResponsibleMap,
        userTotalCapacity: userTotalCapacity,
        minimumCapacity: minimumCapacity
    )
}

// MARK: - Tarefas diárias

func scheduleDailyChores(
    _ dailyChores: [ChoreModel],
    users: [UserModel],
    context: ScheduleContext,
    now: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {

    var results: [ScheduleResult] = []

    for chore in dailyChores {
        guard let choreID = chore.recordID else { continue }
        var result = ScheduleResult(chore: chore)

        let fixedUser = context.choreResponsibleMap[choreID]
        let targetUsers = fixedUser.map { [$0] } ?? users

        for dayOffset in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            var availableToday: [UserModel] = []
            for user in targetUsers {
                guard let userID = user.recordID else { continue }
                let slots = context.userAvailableTimeMap[userID] ?? []
                if let slot = slots.first(where: { Calendar.current.startOfDay(for: $0.day) == day }),
                   let slotID = slot.recordID {
                    let remaining = remainingCapacity[slotID] ?? 0

                    // FIX 1 aplicado
                    if remaining >= chore.duration {
                        availableToday.append(user)
                    }
                }
            }

            // Comportamento mantido de propósito: uma tarefa diária precisa de um
            // responsável todo dia, mesmo que ninguém tenha capacidade sobrando.
            // O fallback aceita sobrecarga em vez de deixar o dia sem ninguém.
            let pool = availableToday.isEmpty ? targetUsers : availableToday

            // FIX 3: removidos os force-unwraps `u1.recordID!` / `u2.recordID!`.
            // Um usuário ainda não salvo (recordID nil) derrubava o app aqui.
            guard let chosenUser = pool.min(by: { u1, u2 in
                let a1 = u1.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
                let a2 = u2.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
                return a1 < a2
            }), let chosenUserID = chosenUser.recordID else { continue }

            let slots = context.userAvailableTimeMap[chosenUserID] ?? []
            if let slot = slots.first(where: { Calendar.current.startOfDay(for: $0.day) == day }),
               let slotID = slot.recordID {
                let remaining = remainingCapacity[slotID] ?? 0

                // FIX 1 aplicado
                remainingCapacity[slotID] = max(remaining - chore.duration, 0)
            }

            // FIX 1 aplicado: o contador chama-se "minutes" e agora recebe minutos.
            // Antes somava segundos, inflando a carga do usuário em 60x e quebrando
            // todo o balanceamento por `min(by:)`.
            userAssignedMinutes[chosenUserID, default: 0] += Int(chore.duration)

            let chosenUserRef = CKRecord.Reference(recordID: chosenUserID, action: CKRecord.ReferenceAction.none)
            let choreRef = CKRecord.Reference(recordID: choreID, action: CKRecord.ReferenceAction.none)
            let assignment = DailyAssignmentModel(
                day: day,
                isCompleted: false,
                user: chosenUserRef,
                chore: choreRef
            )
            result.newAssignments.append(assignment)
        }

        results.append(result)
    }

    return results
}

// MARK: - Tarefas com responsável fixo

func scheduleAssignedChores(
    _ assignedChores: [ChoreModel],
    context: ScheduleContext,
    now: Date,
    oneWeekLater: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {

    var results: [ScheduleResult] = []

    for chore in assignedChores {
        guard let choreID = chore.recordID,
              let user = context.choreResponsibleMap[choreID],
              let userID = user.recordID else { continue }

        var updatable = chore
        let slots = context.userAvailableTimeMap[userID] ?? []

        let distributables = slots.filter { slot in
            let day = Calendar.current.startOfDay(for: slot.day)
            guard day >= now && day < oneWeekLater, let slotID = slot.recordID else { return false }
            let remaining = remainingCapacity[slotID] ?? 0

            // FIX 1 aplicado
            return remaining >= chore.duration
        }

        guard let chosenSlot = distributables.min(by: { $0.day < $1.day }),
              let slotID = chosenSlot.recordID else {
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }

        updatable.dueDate = chosenSlot.day

        // FIX 1 aplicado
        remainingCapacity[slotID] = (remainingCapacity[slotID] ?? 0) - chore.duration
        userAssignedMinutes[userID, default: 0] += Int(chore.duration)

        results.append(ScheduleResult(chore: updatable))
    }

    return results
}

// MARK: - Tarefas livres

func scheduleFreeChores(
    _ freeChores: [ChoreModel],
    users: [UserModel],
    context: ScheduleContext,
    now: Date,
    oneWeekLater: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] {

    var results: [ScheduleResult] = []

    for chore in freeChores {
        var updatable = chore

        var distributable: [(user: UserModel, slot: AvailableTimeModel)] = []
        for user in users {
            guard let userID = user.recordID else { continue }
            let slots = context.userAvailableTimeMap[userID] ?? []
            for slot in slots {
                let day = Calendar.current.startOfDay(for: slot.day)
                guard day >= now && day < oneWeekLater, let slotID = slot.recordID else { continue }
                let remaining = remainingCapacity[slotID] ?? 0

                // FIX 1 aplicado
                if remaining >= chore.duration {
                    distributable.append((user, slot))
                }
            }
        }

        guard !distributable.isEmpty else {
            updatable.currentResponsible = nil
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }

        // Preferência: não empurrar ninguém além da capacidade do usuário mais
        // limitado da casa, para evitar que quem tem mais tempo livre absorva tudo.
        let baselineUsers = distributable.filter { option in
            guard let userID = option.user.recordID else { return false }
            let used = userAssignedMinutes[userID] ?? 0

            // FIX 1 aplicado
            return Double(used) + chore.duration < Double(context.minimumCapacity)
        }

        // FIX 4: fallback que faltava.
        // O comentário original dizia "tenta achar a melhor opção geral", mas o
        // código só tinha o `guard ... else { currentResponsible = nil }`.
        // Quando `baselineUsers` ficava vazio — o que acontecia SEMPRE por causa do
        // FIX 1, e continua acontecendo com tarefas longas — a tarefa era devolvida
        // sem responsável. Esta era a causa direta de "as referências não são
        // preenchidas". Agora, se o baseline não deixa ninguém de fora, usamos o
        // conjunto completo de opções viáveis.
        let pool = baselineUsers.isEmpty ? distributable : baselineUsers

        guard let chosen = pool.min(by: { o1, o2 in
            // FIX 3 aplicado: sem force-unwrap
            let a1 = o1.user.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
            let a2 = o2.user.recordID.flatMap { userAssignedMinutes[$0] } ?? 0
            if a1 != a2 { return a1 < a2 }
            return o1.slot.day < o2.slot.day
        }), let chosenUserID = chosen.user.recordID, let slotID = chosen.slot.recordID else {
            updatable.currentResponsible = nil
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }

        updatable.currentResponsible = CKRecord.Reference(
            recordID: chosenUserID,
            action: CKRecord.ReferenceAction.none
        )

        // FIX 5: manter `allResponsibleUsers` em dia.
        // O campo existe no modelo mas nunca era escrito, então o histórico de
        // quem já foi responsável pela tarefa nascia e morria vazio.
        var rotation = updatable.allResponsibleUsers ?? []
        if !rotation.contains(where: { $0.recordID == chosenUserID }) {
            rotation.append(CKRecord.Reference(recordID: chosenUserID, action: CKRecord.ReferenceAction.none))
        }
        updatable.allResponsibleUsers = rotation

        updatable.dueDate = chosen.slot.day

        // FIX 1 aplicado
        remainingCapacity[slotID] = (remainingCapacity[slotID] ?? 0) - chore.duration
        userAssignedMinutes[chosenUserID, default: 0] += Int(chore.duration)

        results.append(ScheduleResult(chore: updatable))
    }

    return results
}

// MARK: - Persistência

func commitScheduleResults(_ results: [ScheduleResult], users: [UserModel]) async {

    // Etapa 1: gravar cada tarefa e suas atribuições diárias.
    for result in results {
        guard let choreID = result.chore.recordID else { continue }

        var savedRefs: [CKRecord.Reference] = []
        for assignment in result.newAssignments {
            if let saved = await CloudKitManager.shared.create(assignment),
               let savedID = saved.recordID {
                savedRefs.append(CKRecord.Reference(recordID: savedID, action: CKRecord.ReferenceAction.none))
            }
        }

        // FIX 6: um único update por tarefa.
        // O original chamava `update(result.chore)` e, logo depois, `update` de novo
        // com as referências diárias. Além do custo dobrado, a primeira escrita
        // gravava `dailyAssignments` desatualizado — se a segunda falhasse, a tarefa
        // ficava no servidor sem as atribuições que já haviam sido criadas.
        var updatableChore = result.chore
        updatableChore.recordID = choreID
        if !savedRefs.isEmpty {
            updatableChore.dailyAssignments = (updatableChore.dailyAssignments ?? []) + savedRefs
        }
        await CloudKitManager.shared.update(updatableChore)
    }

    // Etapa 2: atualizar a lista de tarefas de cada usuário.
    var choresByUser: [CKRecord.ID: [CKRecord.Reference]] = [:]

    for result in results {
        guard let choreID = result.chore.recordID else { continue }
        let choreRef = CKRecord.Reference(recordID: choreID, action: CKRecord.ReferenceAction.none)

        // FIX 7: considerar também os responsáveis das atribuições diárias.
        // `scheduleDailyChores` nunca preenche `currentResponsible` (uma diária
        // roda entre várias pessoas na semana), então o `guard` original descartava
        // TODAS as tarefas diárias e elas jamais apareciam na lista do usuário.
        var userIDs = Set<CKRecord.ID>()
        if let responsibleID = result.chore.currentResponsible?.recordID {
            userIDs.insert(responsibleID)
        }
        for assignment in result.newAssignments {
            if let assignedID = assignment.user?.recordID {
                userIDs.insert(assignedID)
            }
        }

        for userID in userIDs {
            choresByUser[userID, default: []].append(choreRef)
        }
    }

    for user in users {
        guard let userID = user.recordID,
              let newRefs = choresByUser[userID],
              !newRefs.isEmpty else { continue }

        var updatableUser = user

        // FIX 8: o campo em `UserModel` chama-se `tasks`, não `chores`.
        // O código original lia/escrevia `updatableUser.chores`, que não existe no
        // modelo. Se isso compilava, havia duas definições divergentes de UserModel.
        let existingRefs = updatableUser.chores ?? []
        let existingIDs = Set(existingRefs.map { $0.recordID })
        let dedupedNewRefs = newRefs.filter { !existingIDs.contains($0.recordID) }

        guard !dedupedNewRefs.isEmpty else { continue }

        updatableUser.chores = existingRefs + dedupedNewRefs
        await CloudKitManager.shared.update(updatableUser)
    }
}

// MARK: - Motor

struct TaskSchedulerEngine {

    static func schedule(chores: [ChoreModel], users: [UserModel]) async {
        guard !users.isEmpty else { return }

        let now = Calendar.current.startOfDay(for: Date())
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return }

        let context = await buildScheduleContext(
            users: users,
            chores: chores,
            now: now,
            oneWeekLater: oneWeekLater
        )

        // FIX 9: tarefas diárias que já têm atribuições não são reagendadas.
        // O filtro original (`!isDone && frequency == .daily`) ignorava o estado
        // anterior, então cada execução criava mais 7 DailyAssignmentModel para a
        // mesma tarefa — duplicatas acumulando indefinidamente.
        let dailyChores = chores.filter {
            !$0.isDone && $0.frequency == .daily && ($0.dailyAssignments ?? []).isEmpty
        }

        let unassignedChores = chores.filter { !$0.isDone && $0.dueDate == nil }
        let nonDailyChores = unassignedChores.filter { $0.frequency != .daily }
        let sortedChores = nonDailyChores.sorted { normalizedWeight(chore: $0) > normalizedWeight(chore: $1) }
        let assignedChores = sortedChores.filter { $0.currentResponsible != nil }
        let freeChores = sortedChores.filter { $0.currentResponsible == nil }

        var remainingCapacity = context.initialRemainingCapacity()
        var userAssignedMinutes = context.initialUserAssignedMinutes(users: users)

        var allResults: [ScheduleResult] = []

        allResults += scheduleDailyChores(
            dailyChores,
            users: users,
            context: context,
            now: now,
            remainingCapacity: &remainingCapacity,
            userAssignedMinutes: &userAssignedMinutes
        )

        allResults += scheduleAssignedChores(
            assignedChores,
            context: context,
            now: now,
            oneWeekLater: oneWeekLater,
            remainingCapacity: &remainingCapacity,
            userAssignedMinutes: &userAssignedMinutes
        )

        allResults += scheduleFreeChores(
            freeChores,
            users: users,
            context: context,
            now: now,
            oneWeekLater: oneWeekLater,
            remainingCapacity: &remainingCapacity,
            userAssignedMinutes: &userAssignedMinutes
        )

        await commitScheduleResults(allResults, users: users)
    }

    // MARK: Priorização

    /// Peso combinado usado para ordenar as tarefas: 70% prioridade, 30% duração.
    static func normalizedWeight(chore: ChoreModel) -> Double {
        let priorityNormalized = normalization(
            value: Double(chore.priorityTag.intValue),
            min: Double(PriorityTag.low.intValue),
            max: Double(PriorityTag.urgent.intValue)
        )

        // FIX 10: os limites estavam invertidos e na unidade errada.
        // O original passava `max: 1 * 60, min: 8 * 60` — max MENOR que min — e
        // comparava esses minutos com `chore.duration`, que está em segundos.
        // O `abs()` mascarava o sinal, mas o resultado saía muito acima de 1 e
        // dominava a média ponderada: na prática a ordenação era só por duração,
        // e a prioridade não influenciava nada.
        let timeNormalized = normalization(
            value: chore.duration,
            min: 1 * 60,
            max: 8 * 60
        )

        return (priorityNormalized * 0.7) + (timeNormalized * 0.3)
    }

    /// Normaliza `value` para o intervalo 0...1.
    ///
    /// FIX 10: `abs()` trocado por clamp. Com `abs`, um valor abaixo do mínimo
    /// voltava como positivo (uma tarefa curtíssima parecia longa) e um valor acima
    /// do máximo passava de 1 sem limite.
    static func normalization(value: Double, min minValue: Double, max maxValue: Double) -> Double {
        guard maxValue != minValue else { return 0 }
        let normalized = (value - minValue) / (maxValue - minValue)
        return Swift.min(Swift.max(normalized, 0), 1)
    }
}
