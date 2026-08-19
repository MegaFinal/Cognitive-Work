//
//  ScheduleModels.swift
//

import Foundation // Importa o framework Foundation para utilidades básicas (datas, tipos, manipulação de dados, etc.)
import CloudKit // Importa o framework CloudKit para trabalhar com registros de banco de dados na nuvem

struct ScheduleContext { // Define uma estrutura que armazena o contexto atual do agendamento
    let userAvailableTimeMap: [CKRecord.ID: [AvailableTimeModel]] // Mapa de IDs de usuários para suas disponibilidades de tempo
    let choreResponsibleMap: [CKRecord.ID: UserModel]   // Mapa que vincula o ID de uma tarefa (chore) ao seu usuário responsável fixo
    let userTotalCapacity: [CKRecord.ID: Int] // Mapa com a capacidade total (em minutos) de cada usuário na semana
    let minimumCapacity: Int // A menor capacidade total encontrada entre todos os usuários
    
    func initialRemainingCapacity() -> [CKRecord.ID: Double] { // Função que calcula a capacidade restante inicial para cada slot de tempo disponível
        var map: [CKRecord.ID: Double] = [:] // Inicializa um dicionário vazio para armazenar a capacidade de cada slot
        for (_, slots) in userAvailableTimeMap { // Itera sobre todos os mapas de tempo disponível de cada usuário
            for slot in slots { // Itera sobre cada slot de tempo individual da lista
                guard let id = slot.recordID else { continue } // Garante que o slot possui um ID válido no CloudKit, senão pula para o próximo
                map[id] = Double(slot.capacityMinutes) // Define a capacidade inicial do slot convertida para Double
            }
        }
        return map // Retorna o mapa preenchido com as capacidades iniciais dos slots
    }
    
    func initialUserAssignedMinutes(users: [UserModel]) -> [CKRecord.ID: Int] { // Função que inicializa os minutos já atribuídos a cada usuário como zero
        Dictionary(uniqueKeysWithValues: users.compactMap { user -> (CKRecord.ID, Int)? in // Cria um dicionário a partir de um mapeamento de usuários
            guard let id = user.recordID else { return nil } // Garante que o usuário tem um ID válido, senão retorna nil
            return (id, 0) // Retorna uma tupla com o ID do usuário e 0 minutos atribuídos inicialmente
        })
    }
}

struct ScheduleResult { // Define uma estrutura para armazenar o resultado do agendamento de uma tarefa
    var chore: ChoreModel // A tarefa (chore) que foi processada/atualizada
    var newAssignments: [DailyAssignmentModel] = [] // Lista de novas atribuições diárias geradas para esta tarefa
}

//
//  ScheduleContextBuilder.swift
//

func buildScheduleContext(users: [UserModel], chores: [ChoreModel], now: Date, oneWeekLater: Date) async -> ScheduleContext { // Função assíncrona para construir o contexto do agendamento
    var userAvailableTimeMap: [CKRecord.ID: [AvailableTimeModel]] = [:] // Dicionário para armazenar os horários disponíveis válidos por usuário
    var userTotalCapacity: [CKRecord.ID: Int] = [:] // Dicionário para armazenar a capacidade total em minutos de cada usuário
    
    for user in users { // Itera por cada usuário na lista fornecida
        guard let userID = user.recordID, let refs = user.availableTime else { continue } // Obtém o ID do usuário e suas referências de tempo livre; se faltarem, pula
        let slots = await CloudKitManager.shared.fetchRecordsByRecordReference(for: AvailableTimeModel.self, recordReferences: refs) ?? [] // Busca no CloudKit os registros de disponibilidade usando as referências
        let validSlots = slots.filter { slot in // Filtra apenas os slots que estão dentro da janela de tempo válida da semana
            let day = Calendar.current.startOfDay(for: slot.day) // Normaliza a data do slot para o início do dia
            return day >= now && day < oneWeekLater // Verifica se o dia está entre 'now' (inclusive) e 'oneWeekLater' (exclusive)
        }
        userAvailableTimeMap[userID] = validSlots // Associa os slots válidos ao ID do usuário no mapa
        userTotalCapacity[userID] = validSlots.reduce(0) { $0 + $1.capacityMinutes } // Soma a capacidade em minutos de todos os slots válidos e guarda no dicionário
    }
    
    var choreResponsibleMap: [CKRecord.ID: UserModel] = [:] // Dicionário para mapear qual usuário é responsável por qual tarefa
    for chore in chores { // Itera por cada tarefa
        guard let ref = chore.currentResponsible, let choreID = chore.recordID else { continue } // Obtém a referência do responsável atual e o ID da tarefa; se não houver, pula
        if let user = await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [ref])?.first { // Busca o usuário responsável no CloudKit
            choreResponsibleMap[choreID] = user // Associa o ID da tarefa ao objeto UserModel encontrado
        }
    }
    
    let minimumCapacity = userTotalCapacity.values.min() ?? 0 // Encontra a menor capacidade total entre todos os usuários (ou 0 se estiver vazio)
    
    return ScheduleContext( // Retorna uma nova instância de ScheduleContext preenchida com os dados coletados
        userAvailableTimeMap: userAvailableTimeMap,
        choreResponsibleMap: choreResponsibleMap,
        userTotalCapacity: userTotalCapacity,
        minimumCapacity: minimumCapacity
    )
}

func scheduleDailyChores(
    _ dailyChores: [ChoreModel],
    users: [UserModel],
    context: ScheduleContext,
    now: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] { // Função para agendar tarefas diárias ao longo da semana
    var results: [ScheduleResult] = [] // Lista para armazenar os resultados dos agendamentos diários
    
    for chore in dailyChores { // Itera sobre cada tarefa diária
        guard let choreID = chore.recordID else { continue } // Obtém o ID da tarefa ou pula se não existir
        var result = ScheduleResult(chore: chore) // Inicializa o resultado para esta tarefa
        
        let fixedUser = context.choreResponsibleMap[choreID] // Verifica se existe um usuário fixo responsável por esta tarefa
        let targetUsers = fixedUser.map { [$0] } ?? users // Se houver responsável fixo, usa apenas ele; caso contrário, usa todos os usuários
        
        for dayOffset in 0..<7 { // Loop pelos 7 dias da semana (de 0 a 6)
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else { continue } // Calcula a data exata somando o deslocamento ao dia atual
            
            var availableToday: [UserModel] = [] // Lista temporária de usuários disponíveis no dia atual
            for user in targetUsers { // Itera pelos usuários alvo
                guard let userID = user.recordID else { continue } // Obtém o ID do usuário
                let slots = context.userAvailableTimeMap[userID] ?? [] // Obtém os slots de tempo do usuário
                if let slot = slots.first(where: { Calendar.current.startOfDay(for: $0.day) == day }), // Procura um slot correspondente ao dia atual
                   let slotID = slot.recordID { // Obtém o ID do slot
                    let remaining = remainingCapacity[slotID] ?? 0 // Vê a capacidade restante desse slot
                    if remaining >= chore.duration { // Se o slot tiver capacidade suficiente para a duração da tarefa...
                        availableToday.append(user) // ...adiciona o usuário à lista de disponíveis hoje
                    }
                }
            }
            
            let pool = availableToday.isEmpty ? targetUsers : availableToday // Se ninguém estiver disponível especificamente hoje, usa o grupo alvo completo como fallback
            
            guard let chosenUser = pool.min(by: { u1, u2 in // Escolhe o usuário com menos minutos já atribuídos (para equilibrar a carga)
                let a1 = userAssignedMinutes[u1.recordID!] ?? 0
                let a2 = userAssignedMinutes[u2.recordID!] ?? 0
                return a1 < a2
            }), let chosenUserID = chosenUser.recordID else { continue } // Obtém o ID do usuário escolhido
            
            let slots = context.userAvailableTimeMap[chosenUserID] ?? [] // Pega os slots do usuário escolhido
            if let slot = slots.first(where: { Calendar.current.startOfDay(for: $0.day) == day }), // Encontra o slot do dia para esse usuário
               let slotID = slot.recordID {
                let remaining = remainingCapacity[slotID] ?? 0
                remainingCapacity[slotID] = max(remaining - chore.duration, 0) // Atualiza a capacidade restante do slot subtraindo a duração da tarefa
            }
            
            userAssignedMinutes[chosenUserID, default: 0] += Int(chore.duration) // Incrementa os minutos atribuídos ao usuário escolhido
            
            let chosenUserRef = CKRecord.Reference(recordID: chosenUserID, action: .none) // Cria uma referência do CloudKit para o usuário escolhido
            let choreRef = CKRecord.Reference(recordID: choreID, action: .none) // Cria uma referência do CloudKit para a tarefa
            let assignment = DailyAssignmentModel(day: day, isCompleted: false, user: chosenUserRef, chore: choreRef) // Cria o modelo de atribuição diária
            result.newAssignments.append(assignment) // Adiciona a atribuição à lista de novos registros da tarefa
        }
        
        results.append(result) // Adiciona o resultado final da tarefa à lista global de resultados
    }
    
    return results // Retorna todos os resultados de agendamento diário
}

func scheduleAssignedChores(
    _ assignedChores: [ChoreModel],
    context: ScheduleContext,
    now: Date,
    oneWeekLater: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] { // Função para agendar tarefas que já possuem um responsável atribuído
    var results: [ScheduleResult] = [] // Lista de resultados do agendamento
    
    for chore in assignedChores { // Itera sobre cada tarefa já atribuída
        guard let choreID = chore.recordID,
              let user = context.choreResponsibleMap[choreID],
              let userID = user.recordID else { continue } // Valida se há ID da tarefa, responsável e ID do usuário
        
        var updatable = chore // Cria uma cópia mutável da tarefa para atualizar seus campos
        let slots = context.userAvailableTimeMap[userID] ?? [] // Pega os slots de tempo do usuário responsável
        let distributables = slots.filter { slot in // Filtra quais slots são elegíveis para receber esta tarefa
            let day = Calendar.current.startOfDay(for: slot.day)
            guard day >= now && day < oneWeekLater, let slotID = slot.recordID else { return false } // Valida o período e se o slot tem ID
            let remaining = remainingCapacity[slotID] ?? 0
            return remaining >= chore.duration // Verifica se o slot tem capacidade restante suficiente
        }
        
        guard let chosenSlot = distributables.min(by: { $0.day < $1.day }), let slotID = chosenSlot.recordID else { // Escolhe o slot mais próximo (menor data) que atenda aos critérios
            updatable.dueDate = nil // Se não houver slot disponível, remove a data de vencimento
            results.append(ScheduleResult(chore: updatable)) // Adiciona aos resultados com a tarefa atualizada
            continue
        }
        
        updatable.dueDate = chosenSlot.day // Define a data de vencimento da tarefa como o dia do slot escolhido
        remainingCapacity[slotID] = (remainingCapacity[slotID] ?? 0) - chore.duration // Deduz a duração da tarefa da capacidade do slot
        userAssignedMinutes[userID, default: 0] += Int(chore.duration) // Incrementa os minutos totais atribuídos ao usuário
        
        results.append(ScheduleResult(chore: updatable)) // Adiciona o resultado processado à lista
    }
    
    return results // Retorna os resultados do agendamento de tarefas atribuídas
}

func scheduleFreeChores(
    _ freeChores: [ChoreModel],
    users: [UserModel],
    context: ScheduleContext,
    now: Date,
    oneWeekLater: Date,
    remainingCapacity: inout [CKRecord.ID: Double],
    userAssignedMinutes: inout [CKRecord.ID: Int]
) -> [ScheduleResult] { // Função para distribuir tarefas livres (sem responsável fixo) entre os usuários
    var results: [ScheduleResult] = [] // Lista para armazenar os resultados
    
    for chore in freeChores { // Itera por cada tarefa livre
        var updatable = chore // Cria uma cópia mutável da tarefa
        
        var distributable: [(user: UserModel, slot: AvailableTimeModel)] = [] // Lista para acumular todas as combinações possíveis de (usuário, slot) onde a tarefa cabe
        for user in users { // Itera por cada usuário
            guard let userID = user.recordID else { continue }
            let slots = context.userAvailableTimeMap[userID] ?? []
            for slot in slots { // Itera por cada slot do usuário
                let day = Calendar.current.startOfDay(for: slot.day)
                guard day >= now && day < oneWeekLater, let slotID = slot.recordID else { continue } // Valida se o slot está na semana atual
                let remaining = remainingCapacity[slotID] ?? 0
                if remaining >= chore.duration { // Se houver capacidade suficiente no slot...
                    distributable.append((user, slot)) // ...adiciona a opção na lista de distribuíveis
                }
            }
        }
        
        guard !distributable.isEmpty else { // Se não houver nenhuma opção de slot/usuário disponível para esta tarefa...
            updatable.currentResponsible = nil // ...remove o responsável
            updatable.dueDate = nil // ...remove a data de vencimento
            results.append(ScheduleResult(chore: updatable)) // Registra o resultado com a tarefa limpa
            continue
        }
        
        let baselineUsers = distributable.filter { option in // Filtra opções considerando a capacidade mínima para evitar sobrecarregar quem já passou da média mínima
            guard let userID = option.user.recordID else { return false }
            let used = userAssignedMinutes[userID] ?? 0
            return Double(used) + chore.duration < Double(context.minimumCapacity)
        }
        
        guard let chosen = baselineUsers.min(by: { u1, u2 in // Escolhe a melhor opção priorizando quem tem menos minutos atribuídos e, em caso de empate, a data mais cedo
            let a1 = userAssignedMinutes[u1.user.recordID!] ?? 0
            let a2 = userAssignedMinutes[u2.user.recordID!] ?? 0
            if a1 != a2 { return a1 < a2 }
            return u1.slot.day < u2.slot.day
        }), let chosenUserID = chosen.user.recordID, let slotID = chosen.slot.recordID else { // Se falhar no filtro de baseline, tenta achar a melhor opção geral ou descarta
            updatable.currentResponsible = nil
            updatable.dueDate = nil
            results.append(ScheduleResult(chore: updatable))
            continue
        }
        
        updatable.currentResponsible = CKRecord.Reference(recordID: chosenUserID, action: .none) // Atribui o novo usuário responsável à tarefa
        updatable.dueDate = chosen.slot.day // Define a data de vencimento baseada no slot escolhido
        remainingCapacity[slotID] = (remainingCapacity[slotID] ?? 0) - chore.duration // Atualiza a capacidade restante do slot
        userAssignedMinutes[chosenUserID, default: 0] += Int(chore.duration) // Incrementa os minutos do usuário escolhido
        
        results.append(ScheduleResult(chore: updatable)) // Adiciona o resultado à lista
    }
    
    return results // Retorna os resultados do agendamento de tarefas livres
}

func commitScheduleResults(_ results: [ScheduleResult], users: [UserModel]) async { // Função assíncrona para salvar todas as alterações geradas no CloudKit
    // Primeira etapa: atualizar cada tarefa (chore) individualmente e suas atribuições diárias
    for result in results {
        await CloudKitManager.shared.update(result.chore) // Atualiza o registro principal da tarefa (chore) no CloudKit
        
        guard let choreID = result.chore.recordID else { continue }
        var savedRefs: [CKRecord.Reference] = [] // Lista de referências para as novas atribuições diárias salvas
        
        for assignment in result.newAssignments { // Itera sobre as novas atribuições diárias criadas (para tarefas diárias)
            if let saved = await CloudKitManager.shared.create(assignment), let savedID = saved.recordID { // Salva a atribuição diária no CloudKit
                savedRefs.append(CKRecord.Reference(recordID: savedID, action: .none)) // Guarda a referência do registro criado
            }
        }
        
        if !savedRefs.isEmpty { // Se houver novas referências diárias salvas...
            var updatableChore = result.chore
            updatableChore.recordID = choreID
            updatableChore.dailyAssignments = (updatableChore.dailyAssignments ?? []) + savedRefs // Adiciona as novas referências à lista de atribuições diárias da tarefa
            await CloudKitManager.shared.update(updatableChore) // Atualiza a tarefa novamente com as referências diárias
        }
    }
    
    // Segunda etapa: agrupar por currentResponsible e atualizar reversamente a lista de chores de cada usuário
    var choresByUser: [CKRecord.ID: [CKRecord.Reference]] = [:] // Dicionário para agrupar as referências de tarefas por ID de usuário
    for result in results {
        guard let userID = result.chore.currentResponsible?.recordID,
              let choreID = result.chore.recordID else { continue }
        let choreRef = CKRecord.Reference(recordID: choreID, action: .none)
        choresByUser[userID, default: []].append(choreRef) // Agrupa a tarefa ao respectivo usuário responsável
    }
    
    for user in users { // Atualiza a lista de tarefas (chores) em cada modelo de usuário
        guard let userID = user.recordID,
              let newRefs = choresByUser[userID],
              !newRefs.isEmpty else { continue }
        
        var updatableUser = user
        let existingRefs = updatableUser.chores ?? []
        let existingIDs = Set(existingRefs.map { $0.recordID })
        let dedupedNewRefs = newRefs.filter { !existingIDs.contains($0.recordID) } // Remove duplicatas para evitar adicionar a mesma tarefa duas vezes
        
        updatableUser.chores = existingRefs + dedupedNewRefs // Junta as tarefas existentes com as novas
        print("atribuindo chore ao user ")
        await CloudKitManager.shared.update(updatableUser) // Salva a atualização do usuário no CloudKit
    }
}

struct TaskSchedulerEngine { // Estrutura principal que coordena o motor de agendamento de tarefas
    
    static func schedule(chores: [ChoreModel], users: [UserModel]) async { // Método principal de entrada para executar o agendamento completo
        guard !users.isEmpty else { return } // Garante que há usuários cadastrados; se não houver, encerra a execução
        
        let now = Calendar.current.startOfDay(for: Date()) // Define o momento atual normalizado para o início do dia
        let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now)! // Define a data limite de uma semana à frente
        
        let context = await buildScheduleContext(users: users, chores: chores, now: now, oneWeekLater: oneWeekLater) // Constrói o contexto de agendamento assincronamente
        
        let unassignedChores = chores.filter { !$0.isDone && $0.dueDate == nil } // Filtra tarefas que não estão concluídas e não têm data de vencimento
        let dailyChores = chores.filter { !$0.isDone && $0.frequency == .daily } // Filtra tarefas ativas que possuem frequência diária
        let nonDailyChores = unassignedChores.filter { $0.frequency != .daily } // Filtra tarefas não concluídas, sem data e com frequência não diária
        let sortedChores = nonDailyChores.sorted { normalizedWeight(chore: $0) > normalizedWeight(chore: $1) } // Ordena as tarefas não diárias com base no peso normalizado (maior peso primeiro)
        let assignedChores = sortedChores.filter { $0.currentResponsible != nil } // Separa as tarefas que já têm um responsável atribuído
        let freeChores = sortedChores.filter { $0.currentResponsible == nil } // Separa as tarefas que estão livres (sem responsável)
        
        var remainingCapacity = context.initialRemainingCapacity() // Inicializa o controle de capacidade restante de cada slot de tempo
        var userAssignedMinutes = context.initialUserAssignedMinutes(users: users) // Inicializa o contador de minutos atribuídos por usuário
        
        var allResults: [ScheduleResult] = [] // Lista acumuladora de todos os resultados de agendamento
        
        allResults += scheduleDailyChores(dailyChores, users: users, context: context, now: now, remainingCapacity: &remainingCapacity, userAssignedMinutes: &userAssignedMinutes) // Agenda as tarefas diárias
        
        allResults += scheduleAssignedChores(assignedChores, context: context, now: now, oneWeekLater: oneWeekLater, remainingCapacity: &remainingCapacity, userAssignedMinutes: &userAssignedMinutes) // Agenda as tarefas que já tinham responsável
        
        allResults += scheduleFreeChores(freeChores, users: users, context: context, now: now, oneWeekLater: oneWeekLater, remainingCapacity: &remainingCapacity, userAssignedMinutes: &userAssignedMinutes) // Agenda as tarefas livres entre os usuários
        
        await commitScheduleResults(allResults, users: users) // Salva todas as alterações resultantes no CloudKit
    }
    
    static func normalizedWeight(chore: ChoreModel) -> Double { // Função para calcular o peso normalizado de uma tarefa para priorização
        let priorityNormalized = normalization(value: Double(chore.priorityTag.intValue), max: Double(PriorityTag.urgent.intValue), min: Double(PriorityTag.low.intValue)) // Normaliza a prioridade
        let timeNormalized = normalization(value: chore.duration, max: 1 * 60, min: 8 * 60) // Normaliza a duração do tempo da tarefa
        return (priorityNormalized * 0.7) + (timeNormalized * 0.3) // Retorna a média ponderada (70% prioridade, 30% duração)
    }
    
    static func normalization(value: Double, max: Double, min: Double) -> Double { // Função utilitária matemática para normalizar um valor dentro de um intervalo
        return abs((value - min) / (max - min)) // Retorna o valor normalizado em módulo
    }
}
