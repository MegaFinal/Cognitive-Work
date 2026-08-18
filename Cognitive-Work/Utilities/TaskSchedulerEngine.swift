//
//  TaskSchedulerEngine.swift
//  POC_Automatic_Task
//
//  Created by anshu Li on 29/07/26.
//

import Foundation
import CloudKit

struct TaskSchedulerEngine {
    
    // MARK: 调度主方法
    static func schedule(chores: [ChoreModel], users: [UserModel]) async {
        // 如果系统里一个用户也没有，则直接返回，不进行后续调度
        guard !users.isEmpty else { return }
        
        // 获取今天开始的时间 (0点) 和 7 天后的时间，用来界定本周的范围
        let now = Calendar.current.startOfDay(for: Date())
        let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now)!
         
        // 筛选出所有未完成且未分配日期的任务
        let unassignedChores = chores.filter { !$0.isDone && $0.dueDate == nil }
        
        // 筛选出所有循环类型为每天（daily）的任务
        let dailyChores = chores.filter { !$0.isDone && $0.frequency == .daily }
        
        // 筛选出所有不是每天重复的普通任务
        let nonDailyChores = unassignedChores.filter { $0.frequency != .daily }
        
        // 将普通任务按归一化权重从高到低排序，权重越高的任务越优先分配
        let sortedChores = nonDailyChores.sorted { normalizedWeight(chore: $0) > normalizedWeight(chore: $1) }
        // 把普通任务拆分成两批：已经指定负责人的任务和自由分配的任务
        var assignedChores = sortedChores.filter { $0.currentResponsible != nil }
        let freeChores = sortedChores.filter { $0.currentResponsible == nil }
        
        
        // 初始化两个字典：
        var userTotalCapacity: [CKRecord.ID: Int] = [:]    // 记录每个用户这周的总空闲容量（分钟）
        var remainingCapacity: [CKRecord.ID: Double] = [:]    // 记录每个时间槽（slot）在分配过程中的剩余容量
        
        // 遍历所有用户，计算并初始化他们这周的容量数据
        for user in users {
            var userAvailableTime: [AvailableTimeModel]? = await CloudKitManager.shared.fetchRecordsByRecordReference(for: AvailableTimeModel.self, recordReferences: user.availableTime!)
            // 过滤出只落在今天到 7 天以内的有效时间槽
            let validSlots = userAvailableTime!.filter { slot in
                let slotDay = Calendar.current.startOfDay(for: slot.day)
                return slotDay >= now && slotDay < oneWeekLater
            }
            
            // 将该用户这周所有有效时间槽的分钟数加总，作为这周的总空闲时间
            let total = validSlots.reduce(0) { $0 + $1.capacityMinutes }
            userTotalCapacity[user.recordID!] = total
            
            // 为每个有效的时间槽初始化其剩余容量
            for slot in validSlots {
                remainingCapacity[slot.recordID!] = Double(slot.capacityMinutes)
            }
        }
        
        // 取所有用户这周总容量中的最小值，作为衡量公平性的基准线（baseline）
        let minimumCapacity = userTotalCapacity.values.min() ?? 0
        print(minimumCapacity)
        
        // 记录每个用户目前已被分配的总分钟数，初始值全部为 0
        var userAssignedMinutes: [CKRecord.ID: Int] = Dictionary(
            uniqueKeysWithValues: users.map { ($0.recordID, 0) } as! [(CKRecord.ID, Int)]
        )
        
        // Daily 任务
        for chore in dailyChores {
            // 清掉这周范围内旧的分配记录，避免重复调度时堆积
            var choreDailyAssignments: [DailyAssignmentModel] = await CloudKitManager.shared.fetchRecordsByRecordReference(for: DailyAssignmentModel.self, recordReferences: chore.dailyAssignments!)!
            
            choreDailyAssignments.removeAll { $0.day >= now && $0.day < oneWeekLater }

            for dayOffset in 0..<7 {
                guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                
                var choreCurrentResponsible: UserModel? = await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [chore.currentResponsible!])?.first

                let targetUsers = choreCurrentResponsible.map { [$0] } ?? users

                var availableToday: [UserModel] = []
                for user in targetUsers {
                    var userAvailableTime: [AvailableTimeModel]? = await CloudKitManager.shared.fetchRecordsByRecordReference(for: AvailableTimeModel.self, recordReferences: user.availableTime!)
                    
                    if let slot = userAvailableTime!.first(where: { Calendar.current.startOfDay(for: $0.day) == day }) {
                        let remaining = remainingCapacity[slot.recordID!] ?? 0.0
                        if remaining >= chore.duration {
                            availableToday.append(user)
                        }
                    }
                }

                let pool = availableToday.isEmpty ? targetUsers : availableToday

                guard let chosenUser = pool.min(by: { u1, u2 in
                    let u1Assigned = userAssignedMinutes[u1.recordID!] ?? 0
                    let u2Assigned = userAssignedMinutes[u2.recordID!] ?? 0
                    return u1Assigned < u2Assigned
                }) else { continue }
                                
                var chosenUserAvailableTime: [AvailableTimeModel]? = await CloudKitManager.shared.fetchRecordsByRecordReference(for: AvailableTimeModel.self, recordReferences: chosenUser.availableTime!)

                if let slot = chosenUserAvailableTime!.first(where: { Calendar.current.startOfDay(for: $0.day) == day }) {
                    let remaining = remainingCapacity[slot.recordID!] ?? 0
                    remainingCapacity[slot.recordID!] = max(remaining - chore.duration, 0)
                }

                userAssignedMinutes[chosenUser.recordID!, default: 0] += Int(chore.duration)
                
                let chosenUserReference = CKRecord.Reference(recordID: chosenUser.recordID!, action: .none)
                let choreReference = CKRecord.Reference(recordID: chore.recordID!, action: .none)
                
                let assignment = DailyAssignmentModel(day: day, isCompleted: false, user: chosenUserReference, chore: choreReference)
                let savedAssignment = await CloudKitManager.shared.create(assignment)
                
                let savedAssignmentReference = CKRecord.Reference(recordID: (savedAssignment?.recordID)!, action: .none)
                
                var updatableChore = chore
                (updatableChore.dailyAssignments?.append(savedAssignmentReference)) ?? (updatableChore.dailyAssignments = [savedAssignmentReference])
                
                let updatedChore = await CloudKitManager.shared.update(updatableChore)
            }
        }
        
        
        // 处理已指定负责人的普通任务
        for (index, chore) in assignedChores.enumerated() {
            guard let user = await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [chore.currentResponsible!])?.first else { continue }
            
            var userAvailableTime: [AvailableTimeModel]? = await CloudKitManager.shared.fetchRecordsByRecordReference(for: AvailableTimeModel.self, recordReferences: user.availableTime!)
            
            // 筛选出该用户这周内剩余容量足够装下该任务的所有时间槽
            let distributables = userAvailableTime!.filter { slot in
                let slotDay = Calendar.current.startOfDay(for: slot.day)
                guard slotDay >= now && slotDay < oneWeekLater else { return false }
                let remaining = remainingCapacity[slot.recordID!] ?? 0
                return remaining >= chore.duration
            }
            
            // 如果连一个合适的时间槽都找不到，就清空分配状态并跳过
            guard let chosenSlot = distributables.min(by: { $0.day < $1.day }) else {
                assignedChores[index].dueDate = nil
                continue
            }
            
            // 将任务分配到选中的时间槽中，并扣减容量
            await assign(chore: chore, to: user, slot: chosenSlot, remainingCapacityMap: &remainingCapacity)
            // 累加该用户的已分配分钟数
            userAssignedMinutes[user.recordID!, default: 0] += Int(assignedChores[index].duration)
        }
        
        // 处理自由分配的普通任务（按公平原则挑人）
        for chore in freeChores {
            // 确定候选人：如果任务指定了负责人就只选他，否则选择全部用户
            var updatableChore = chore
            
            let targetUser = await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [chore.currentResponsible!]) ?? users
            
            // 收集所有候选人、所有落在本周范围内且容量足够的 (用户, 时间槽) 选项
            var distributable: [(user: UserModel, slot: AvailableTimeModel)] = []
            for user in targetUser {
                
                var userAvailableTime: [AvailableTimeModel]? = await CloudKitManager.shared.fetchRecordsByRecordReference(for: AvailableTimeModel.self, recordReferences: user.availableTime!)
                
                for slot in userAvailableTime ?? []{
                    let slotDay = Calendar.current.startOfDay(for: slot.day)
                    guard slotDay >= now && slotDay < oneWeekLater else { continue }
                    
                    let remaining = remainingCapacity[slot.recordID!] ?? 0
                    if remaining >= chore.duration {
                        distributable.append((user, slot))
                    }
                }
            }
            
            // 如果所有候选人在所有天数都装不下该任务，则清空状态并跳过
            guard !distributable.isEmpty else {
                updatableChore.currentResponsible = nil
                updatableChore.currentResponsible = nil
                continue
            }
            
            //筛选出那些加上这次任务后，总工作量依然低于基准线（minimumCapacity）的候选选项
            let baselineUsers = distributable.filter { option in
                let used = userAssignedMinutes[option.user.recordID!] ?? 0
                return (used + Int(chore.duration)) < minimumCapacity
            }
            
            
            //从基准线之下的选项中，挑出已分配分钟数最少的那个；如果分钟数相同，则选时间槽日期更早的
            guard let chosen = baselineUsers.min(by: { u1, u2 in
                let u1Assigned = userAssignedMinutes[u1.user.recordID!] ?? 0
                let u2Assigned = userAssignedMinutes[u2.user.recordID!] ?? 0
                if u1Assigned != u2Assigned { return u1Assigned < u2Assigned }
                return u1.slot.day < u2.slot.day
            }) else {
                updatableChore.currentResponsible = nil
                updatableChore.currentResponsible = nil
                continue
            }
            
            // 正式把任务分配给选中的用户和时间槽
            await assign(chore: chore, to: chosen.user, slot: chosen.slot, remainingCapacityMap: &remainingCapacity)
            // 更新该用户的已分配分钟数账本
            userAssignedMinutes[chosen.user.recordID!, default: 0] += Int(chore.duration)
        }
    }
    
    // MARK: - 辅助方法：指派任务并扣减时间槽容量
    static func assign(chore: ChoreModel, to user: UserModel, slot: AvailableTimeModel, remainingCapacityMap: inout [CKRecord.ID: Double]) async {
        var updatableChore = chore
        let userReference = CKRecord.Reference(recordID: user.recordID!, action: .none)
        updatableChore.currentResponsible = userReference
        updatableChore.dueDate = slot.day
        let remaining = remainingCapacityMap[slot.recordID!] ?? 0
        // 将指定时间槽的剩余容量减去任务耗时
        remainingCapacityMap[slot.recordID!] = remaining - chore.duration
        
        await CloudKitManager.shared.update(updatableChore)
    }
    
    // MARK: - 重置并重新调度所有任务的方法
//    static func rescheduleAll(tasks: [TaskModel], users: [UserProfileModel], modelContext: ModelContext) {
//        // 遍历所有未完成的任务，清空它们的负责人和分配日期
//        for task in tasks where !task.isCompleted {
//            task.assignedDate = nil
//            task.assignedUser = nil
//        }
//        // 重新调用调度算法进行全局排班
//        schedule(tasks: tasks, users: users, modelContext: modelContext)
//    }
    
    static func normalizedWeight(chore: ChoreModel) -> Double {
        let priorityNormalized = normalization(value: Double(chore.priorityTag.intValue), max: Double(PriorityTag.urgent.intValue), min: Double(PriorityTag.low.intValue))
        
        let timeNormalized = normalization(value: chore.duration, max: 1 * 60, min: 8 * 60)
        
        return  (priorityNormalized * 0.7) + (timeNormalized * 0.3)
    }
    
    static func normalization(value: Double, max: Double, min: Double) -> Double {
        return abs((value - min) / (max - min))
    }
}
