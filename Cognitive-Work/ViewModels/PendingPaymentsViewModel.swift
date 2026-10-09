//
//  PendingPaymentsViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import Foundation
import CloudKit

/// Drives the "Pendências" screen: who owes whom for the things bought for the house.
@MainActor
@Observable
final class PendingPaymentsViewModel {

    /// An amount split for the big summary cards: "R$" "350" ",00".
    struct AmountParts {
        let currency: String
        let whole: String
        let cents: String
    }

    private let shopList: ShopListViewModel

    /// Which side of the debts is listed. The matching summary card is highlighted.
    var selectedDirection: DebtDirection = .youOwe

    /// The debt waiting for the user to confirm settling it, or `nil`.
    private(set) var settlementRequest: DebtGroup?

    /// True while a settlement is being saved.
    private(set) var isSettling = false

    private(set) var errorMessage: String?

    /// See ``ShopListViewModel``: previews can't reach CloudKit.
    @ObservationIgnored
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init(shopList: ShopListViewModel) {
        self.shopList = shopList
    }

    // MARK: - Reading

    /// Shares settled during this visit, remembered here too so the totals drop right away and a
    /// refresh that still carries the old record can't bring a paid debt back.
    private var settledKeys: Set<String> = []

    private var ledger: DebtLedger {
        DebtCalculator.ledger(
            items: shopList.items,
            users: shopList.houseUsers,
            me: shopList.currentUser?.recordID,
            settledOverrides: settledKeys
        )
    }

    /// What the house owes you minus what you owe: positive when you are ahead.
    var balance: Double {
        let value = total(for: .owedToYou) - total(for: .youOwe)
        return (value * 100).rounded() / 100
    }

    var balanceTitle: String { L10n.tr("Saldo") }

    var balanceCaption: String {
        if balance > 0 { return L10n.tr("A casa te deve") }
        if balance < 0 { return L10n.tr("Você deve à casa") }
        return L10n.tr("Tudo certo por aqui")
    }

    /// "+R$12,00", "-R$12,00" or "R$0,00".
    var balanceText: String {
        let sign = balance > 0 ? "+" : (balance < 0 ? "-" : "")
        return sign + currencyText(abs(balance))
    }

    /// Green when you are ahead, orange when you are behind, yellow when even.
    var balanceColor: RoomColor {
        if balance > 0 { return .green }
        if balance < 0 { return .orange }
        return .yellow
    }

    /// Debts settled a moment ago. A settled debt leaves the ledger, so its last state is kept here
    /// to keep showing the card, with a "Pago!" button, until ``markPaid(_:debtorID:)`` removes it.
    private var paidGroups: [String: DebtGroup] = [:]

    /// The debts of the selected side, one group per housemate: the open ones, plus the ones just
    /// settled, in the order of the house members.
    var groups: [DebtGroup] {
        let open = ledger.groups(for: selectedDirection)
        let openIDs = Set(open.map(\.id))
        let paid = paidGroups.values.filter { $0.direction == selectedDirection && !openIDs.contains($0.id) }

        let order = shopList.houseUsers.compactMap(\.recordID)
        func position(_ group: DebtGroup) -> Int {
            group.counterparty.recordID.flatMap(order.firstIndex(of:)) ?? .max
        }
        return (open + paid).sorted { position($0) < position($1) }
    }

    func isPaid(_ group: DebtGroup) -> Bool {
        paidGroups[group.id] != nil
    }

    func total(for direction: DebtDirection) -> Double {
        ledger.total(for: direction)
    }

    /// The signed-in user's profile banner (color and texture), used to highlight the selected card.
    var banner: ProfileBanner {
        shopList.currentUser?.banner ?? .default
    }

    // MARK: - Texts

    func title(for direction: DebtDirection) -> String {
        switch direction {
        case .youOwe: return L10n.tr("Você deve")
        case .owedToYou: return L10n.tr("Te devem")
        }
    }

    /// Just the person's name: the selected card already says which way the money goes.
    func title(for group: DebtGroup) -> String {
        group.counterparty.name
    }

    var emptyTitle: String {
        switch selectedDirection {
        case .youOwe: return L10n.tr("Você não deve nada")
        case .owedToYou: return L10n.tr("Ninguém te deve")
        }
    }

    var emptyMessage: String {
        L10n.tr("Quando uma compra com valor for dividida entre os moradores, ela aparece aqui.")
    }

    // MARK: - Formatting

    /// "R$55,50", in the app's language.
    func currencyText(_ value: Double) -> String {
        "R$" + value.formatted(.number.precision(.fractionLength(2)).locale(L10n.locale))
    }

    /// The pieces of an amount for the big summary cards.
    func amountParts(_ value: Double) -> AmountParts {
        let totalCents = Int((max(value, 0) * 100).rounded())
        let separator = L10n.locale.decimalSeparator ?? ","

        return AmountParts(
            currency: "R$",
            whole: (totalCents / 100).formatted(.number.locale(L10n.locale)),
            cents: separator + String(format: "%02d", totalCents % 100)
        )
    }

    func settleButtonTitle(for group: DebtGroup) -> String {
        isPaid(group) ? L10n.tr("Pago!") : L10n.tr("Pagar")
    }

    var confirmationTitle: String {
        guard let group = settlementRequest else { return "" }
        return L10n.tr("Marcar %@ de %@ como pago?", currencyText(group.total), group.counterparty.name)
    }

    var confirmationMessage: String {
        switch settlementRequest?.direction {
        case .owedToYou: return L10n.tr("Isso marca que a pessoa já te pagou. Não dá para desfazer.")
        default: return L10n.tr("Isso marca que você já pagou. Não dá para desfazer.")
        }
    }

    // MARK: - Paying with Pix

    /// The Pix being paid, or `nil`. The view shows the payment sheet while it is set.
    var pixPayment: PixPayment?

    /// Name of the housemate who has no Pix key yet, or `nil`. The view explains it in an alert.
    var missingPixKeyName: String?

    var missingPixKeyMessage: String {
        L10n.tr("%@ ainda não cadastrou uma chave Pix. Peça para a pessoa cadastrar em Perfil > Chave Pix.", missingPixKeyName ?? "")
    }

    /// What the "Pagar" / "Pago!" button does. When you owe, it opens the Pix payment sheet for
    /// the housemate; when you are owed, it confirms that they paid you.
    func settleTapped(for group: DebtGroup) {
        guard !isPaid(group) else { return }

        switch group.direction {
        case .youOwe: startPixPayment(for: group)
        case .owedToYou: requestSettlement(of: group)
        }
    }

    private func startPixPayment(for group: DebtGroup) {
        guard let key = group.counterparty.pixKey.flatMap(PixPayload.normalizedKey) else {
            missingPixKeyName = group.counterparty.name
            return
        }

        pixPayment = PixPayment(
            code: PixPayload.copyAndPaste(
                key: key,
                amount: group.total,
                receiverName: group.counterparty.name
            ),
            amount: amountParts(group.total),
            receiver: group.counterparty
        )
    }

    // MARK: - Settling

    func requestSettlement(of group: DebtGroup) {
        guard !isPaid(group) else { return }
        settlementRequest = group
    }

    func cancelSettlement() {
        settlementRequest = nil
    }

    func clearError() {
        errorMessage = nil
    }

    /// Marks every item of the requested debt as paid by the debtor.
    func confirmSettlement() async {
        guard let group = settlementRequest, let me = shopList.currentUser?.recordID else {
            settlementRequest = nil
            return
        }

        let debtorID = group.direction == .youOwe ? me : group.counterparty.recordID
        guard let debtorID else {
            settlementRequest = nil
            return
        }

        isSettling = true
        defer {
            isSettling = false
            settlementRequest = nil
        }

        if isPreview {
            group.entries.forEach { $0.item.settleLocally(for: debtorID) }
            markPaid(group, debtorID: debtorID)
            return
        }

        for entry in group.entries {
            guard await entry.item.markSettled(for: debtorID) else {
                errorMessage = CloudKitManager.shared.errorMessage ?? L10n.tr("Não foi possível quitar. Tente novamente.")
                return
            }
            settledKeys.insert(DebtCalculator.settlementKey(item: entry.item, debtor: debtorID))
        }
        markPaid(group, debtorID: debtorID)
    }

    /// How long the card says "Pago!" before it leaves the screen.
    private let paidDisplayDuration: Duration = .milliseconds(1400)

    /// Updates the totals now, keeps the card with a "Pago!" button for a moment, then removes it.
    private func markPaid(_ group: DebtGroup, debtorID: CKRecord.ID) {
        for entry in group.entries {
            settledKeys.insert(DebtCalculator.settlementKey(item: entry.item, debtor: debtorID))
        }
        paidGroups[group.id] = group

        Task { [weak self, paidDisplayDuration] in
            try? await Task.sleep(for: paidDisplayDuration)
            self?.paidGroups[group.id] = nil
        }
    }
}
