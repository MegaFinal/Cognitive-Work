//
//  DebtSummaryCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI

/// One of the two big totals on the "Pendências" screen ("Você deve" / "Te devem").
struct DebtSummaryCard: View {

    /// "Você deve" or "Te devem".
    let title: String
    /// The total, split into currency, whole part and cents.
    let amount: PendingPaymentsViewModel.AmountParts
    /// Whether this card is the selected side.
    let isSelected: Bool
    /// Color and texture shown when the card is selected (the user's profile banner).
    let banner: ProfileBanner
    /// Runs when the card is tapped (selects this side).
    let onTap: () -> Void
    /// What VoiceOver reads for the card ("Você deve, 350 reais"); title and amount when `nil`.
    var accessibilityText: String? = nil

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // MARK: - Title
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // MARK: - Amount: "R$" "350" ",00"
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(amount.currency)
                        .font(.system(size: 20, weight: .semibold))

                    Text(amount.whole)
                        .font(.system(size: 30, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)

                    Text(amount.cents)
                        .font(.system(size: 20, weight: .semibold))
                }
                .foregroundStyle(isSelected ? .white : .black)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            // MARK: - Background: the user's banner when selected, gray otherwise
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.clear)
                        .overlay {
                            RoomTextureBackground(color: banner.color, pattern: banner.pattern, zoom: 1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.systemGray6))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
        .accessibilityElement(children: .combine)
        .voiceOverLabel(accessibilityText ?? "\(title), \(amount.currency)\(amount.whole)\(amount.cents)")
        .voiceOverTraits(.isSelected, when: isSelected)
        .voiceControlNames([title])
    }
}

#Preview("Cards") {
    let viewModel = ShopListPreviewData.debtsViewModel

    HStack(spacing: 12) {
        DebtSummaryCard(
            title: viewModel.title(for: .youOwe),
            amount: viewModel.amountParts(viewModel.total(for: .youOwe)),
            isSelected: true,
            banner: viewModel.banner,
            onTap: {}
        )
        DebtSummaryCard(
            title: viewModel.title(for: .owedToYou),
            amount: viewModel.amountParts(viewModel.total(for: .owedToYou)),
            isSelected: false,
            banner: viewModel.banner,
            onTap: {}
        )
    }
    .padding()
}
