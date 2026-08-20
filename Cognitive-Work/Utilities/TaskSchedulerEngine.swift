//
//  TaskSchedulerEngine.swift
//  Cognitive-Work
//
//  Versão corrigida. Cada alteração está marcada com "FIX N" e explicada
//  no comentário adjacente.
//

import Foundation
import CloudKit

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
