//
//  ShopDebt.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import Foundation
import CloudKit

/// Whose side of a debt the screen is showing.
enum DebtDirection: CaseIterable, Identifiable {
    /// Items bought by a housemate for the signed-in user (the user owes them).
    case youOwe

    /// Items bought by the signed-in user for a housemate (the housemate owes the user).
    case owedToYou

    var id: Self { self }
}

/// One item's share of a debt.
struct DebtEntry: Identifiable {
    let item: ShopListItem

    /// What the debtor owes for this item: its price split equally between everyone it was for.
    let amount: Double

    var id: String { item.id }
    var name: String { item.name }
}

/// Everything owed between the signed-in user and one housemate, in one direction.
struct DebtGroup: Identifiable {
    let direction: DebtDirection

    /// The other housemate: the buyer when ``direction`` is ``DebtDirection/youOwe``, the debtor
    /// when it is ``DebtDirection/owedToYou``.
    let counterparty: UserModel

    let entries: [DebtEntry]

    var id: String { "\(direction)-\(counterparty.id)" }

    var total: Double { entries.reduce(0) { $0 + $1.amount } }
}

/// The result of ``DebtCalculator``: debts grouped by housemate, plus the two totals.
struct DebtLedger {
    var youOwe: [DebtGroup] = []
    var owedToYou: [DebtGroup] = []

    func groups(for direction: DebtDirection) -> [DebtGroup] {
        switch direction {
        case .youOwe: return youOwe
        case .owedToYou: return owedToYou
        }
    }

    func total(for direction: DebtDirection) -> Double {
        groups(for: direction).reduce(0) { $0 + $1.total }
    }
}

/// Works out who owes whom from the shopping list. Pure, so it can be tested without CloudKit.
enum DebtCalculator {

    /// - Parameters:
    ///   - items: Every item of the list.
    ///   - users: Every house member, used to resolve names and avatars.
    ///   - me: The signed-in user's house record id. Without it the ledger is empty.
    static func ledger(
        items: [ShopListItem],
        users: [UserModel],
        me: CKRecord.ID?,
        settledOverrides: Set<String> = []
    ) -> DebtLedger {
        guard let me else { return DebtLedger() }

        var youOwe: [CKRecord.ID: [DebtEntry]] = [:]
        var owedToYou: [CKRecord.ID: [DebtEntry]] = [:]

        for item in items.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard
                item.isBought,
                item.hasPrice,
                let price = item.totalValue,
                let buyer = item.buyerRecordID
            else { continue }

            let consumers = item.consumerRecordIDs
            guard !consumers.isEmpty else { continue }

            let share = (price / Double(consumers.count) * 100).rounded() / 100
            let settled = item.settledUserIDs
            let entry = DebtEntry(item: item, amount: share)

            for consumer in consumers
        where consumer != buyer
            && !settled.contains(consumer)
            && !settledOverrides.contains(settlementKey(item: item, debtor: consumer)) {
                if buyer == me {
                    owedToYou[consumer, default: []].append(entry)
                } else if consumer == me {
                    youOwe[buyer, default: []].append(entry)
                }
            }
        }

        return DebtLedger(
            youOwe: groups(from: youOwe, direction: .youOwe, users: users),
            owedToYou: groups(from: owedToYou, direction: .owedToYou, users: users)
        )
    }

    /// Identifies "`debtor` paid their share of `item`" for the screen's own bookkeeping.
    static func settlementKey(item: ShopListItem, debtor: CKRecord.ID) -> String {
        "\(item.id)|\(debtor.recordName)"
    }

    /// Turns the per-housemate entries into groups, in the order of `users`.
    private static func groups(
        from entries: [CKRecord.ID: [DebtEntry]],
        direction: DebtDirection,
        users: [UserModel]
    ) -> [DebtGroup] {
        users.compactMap { user in
            guard let id = user.recordID, let list = entries[id], !list.isEmpty else { return nil }
            return DebtGroup(direction: direction, counterparty: user, entries: list)
        }
    }
}
