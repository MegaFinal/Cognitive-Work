//
//  CoinsBalanceCard.swift
//  Cognitive-Work
//
//  Created by Claude on 15/10/26.
//

import SwiftUI

/// The user's coin balance: the coin piglet on a soft gray card, like the dashboard's points card.
struct CoinsBalanceCard: View {

    var coins: Int

    private var coinsText: String {
        coins == 1 ? L10n.tr("1 moeda") : L10n.tr("%lld moedas", coins)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image("RetroPigCoin")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Seu saldo")
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                    .foregroundStyle(.subTitleGray)

                Text(coinsText)
                    .font(.system(size: 28))
                    .fontWeight(.bold)
                    .foregroundStyle(.titleGray)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemGray6).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .animation(.snappy, value: coins)
        // "Seu saldo, 42 moedas" as one element.
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CoinsBalanceCard(coins: 42)
        .padding()
}
