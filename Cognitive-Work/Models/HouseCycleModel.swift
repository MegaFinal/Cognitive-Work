//
//  HouseCycleModel.swift
//  Cognitive-Work
//
//  Created by Claude on 16/10/26.
//

import Foundation
import CloudKit

/// One division cycle of a house: the days a chore division covers.
///
/// Written by ``TaskSchedulerEngine/schedule(chores:users:)`` every time it generates a division,
/// so the end of a cycle is read instead of guessed. Everything that depends on "which cycle is
/// this" uses ``key``: coin payouts, the rank history, and coupon purchases.
///
/// Rules:
/// - A cycle covers `startDate...endDate`, both days included.
/// - The **latest** cycle is the one with the most recent start. Coupons bought now belong to it.
/// - A cycle is **closed** once today is after its `endDate`; closed cycles get paid.
/// - Generating a division before the latest cycle ended cuts that cycle short: it ends the day
///   before the new one starts.
struct HouseCycleModel: CloudKitSyncable, Equatable {

    static var recordType: String = "HouseCycleModel"

    var recordID: CKRecord.ID?

    /// First day of the cycle (start of day).
    var startDate: Date

    /// Last day of the cycle (start of day), included.
    var endDate: Date

    /// Stable identifier, `yyyy-MM-dd` of ``startDate``. Stored, so every device reads the same
    /// value whatever its time zone. Keys sort chronologically as plain strings.
    var key: String

    init(startDate: Date, endDate: Date, key: String? = nil, calendar: Calendar = .current) {
        self.startDate = calendar.startOfDay(for: startDate)
        self.endDate = calendar.startOfDay(for: endDate)
        self.key = key ?? Self.key(for: startDate, calendar: calendar)
    }

    init?(record: CKRecord) {
        guard
            let startDate = record["startDate"] as? Date,
            let endDate = record["endDate"] as? Date,
            let key = record["key"] as? String
        else { return nil }

        self.recordID = record.recordID
        self.startDate = startDate
        self.endDate = endDate
        self.key = key
    }

    func populate(record: CKRecord) {
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["key"] = key
    }

    // MARK: - Keys

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0
        )
    }

    static func recordID(forKey key: String, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "cycle-\(key)", zoneID: zoneID)
    }

    // MARK: - Rules

    func isClosed(asOf today: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: endDate) < calendar.startOfDay(for: today)
    }

    /// Cycles sorted by start, oldest first.
    static func sorted(_ cycles: [HouseCycleModel]) -> [HouseCycleModel] {
        cycles.sorted { $0.key < $1.key }
    }

    /// The cycle with the most recent start.
    static func latest(_ cycles: [HouseCycleModel]) -> HouseCycleModel? {
        sorted(cycles).last
    }

    /// The cycle right before ``latest(_:)``.
    static func previous(_ cycles: [HouseCycleModel]) -> HouseCycleModel? {
        let sorted = sorted(cycles)
        return sorted.count >= 2 ? sorted[sorted.count - 2] : nil
    }

    /// Every cycle that already ended, oldest first.
    static func closed(_ cycles: [HouseCycleModel], asOf today: Date, calendar: Calendar = .current) -> [HouseCycleModel] {
        sorted(cycles).filter { $0.isClosed(asOf: today, calendar: calendar) }
    }

    /// The cycles to write when a new division covering `start...end` is generated: the new
    /// cycle and, when the latest one is still running past `start`, that one cut short.
    ///
    /// Re-generating on the day a cycle was created (same start) just rewrites that cycle.
    static func cyclesToSave(
        newStart start: Date,
        newEnd end: Date,
        existing: [HouseCycleModel],
        calendar: Calendar = .current
    ) -> [HouseCycleModel] {
        var new = HouseCycleModel(startDate: start, endDate: end, calendar: calendar)
        var result: [HouseCycleModel] = []

        if let latest = latest(existing) {
            if latest.key == new.key {
                new.recordID = latest.recordID
            } else if latest.endDate >= new.startDate,
                      let dayBefore = calendar.date(byAdding: .day, value: -1, to: new.startDate) {
                var shortened = latest
                shortened.endDate = max(calendar.startOfDay(for: dayBefore), latest.startDate)
                result.append(shortened)
            }
        }

        result.append(new)
        return result
    }
}

// MARK: - Persistence

extension HouseCycleModel {

    /// Every cycle of the house in `zoneID`.
    static func fetchAll(inHouseZone zoneID: CKRecordZone.ID) async -> [HouseCycleModel] {
        await CloudKitManager.shared.fetchAll(HouseCycleModel.self)
            .filter { $0.recordID?.zoneID == zoneID }
    }

    /// Records the cycle of a division just generated. See ``cyclesToSave(newStart:newEnd:existing:calendar:)``.
    ///
    /// Not contended (only the device generating the division writes it), so it saves with
    /// `.allKeys`.
    @discardableResult
    static func recordNewDivision(start: Date, end: Date, houseID: CKRecord.ID) async -> Bool {
        let zoneID = houseID.zoneID
        let existing = await fetchAll(inHouseZone: zoneID)
        let toSave = cyclesToSave(newStart: start, newEnd: end, existing: existing)

        let records: [CKRecord] = toSave.map { cycle in
            let recordID = cycle.recordID ?? Self.recordID(forKey: cycle.key, zoneID: zoneID)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            cycle.populate(record: record)
            record.parent = CKRecord.Reference(recordID: houseID, action: .none)
            return record
        }

        return await CloudKitManager.shared.batchSave(records: records, zoneID: zoneID, savePolicy: .allKeys)
    }
}
