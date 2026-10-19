//
//  CouponCard.swift
//  Cognitive-Work
//
//  Created by Claude on 15/10/26.
//

import SwiftUI

/// One coupon on offer in a room: a ticket tile in the room's color, its name and level, and
/// its price in coins.
struct CouponCard: View {

    var coupon: CouponModel
    var roomColor: RoomColor

    /// Whether the user has enough coins; coupons out of reach are dimmed.
    var isAffordable: Bool

    /// Whether the coupon can be bought, is already the user's, or someone else's.
    var state: PurchaseState = .available

    /// Whether this coupon's purchase is in progress.
    var isBuying: Bool = false

    /// Called by the "Comprar" button; `nil` hides the button.
    var onBuy: (() -> Void)? = nil

    enum PurchaseState: Equatable {
        case available
        case ownedByMe
        case taken
    }

    private var stateText: String? {
        switch state {
        case .available: return nil
        case .ownedByMe: return L10n.tr("Seu cupom")
        case .taken: return L10n.tr("Já comprado")
        }
    }

    private var canBuy: Bool {
        state == .available && isAffordable && !isBuying && onBuy != nil
    }

    private var priceText: String {
        coupon.price == 1 ? L10n.tr("1 moeda") : L10n.tr("%lld moedas", coupon.price)
    }

    var body: some View {
        HStack(spacing: 15) {
            tile

            VStack(alignment: .leading, spacing: 6) {
                Text(coupon.name)
                    .font(.system(size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(.titleGray)
                    .lineLimit(2)

                CapsuleTag(
                    tagName: coupon.tier.displayName,
                    tagColor: roomColor.uiColor,
                    horizontalPadding: 10,
                    verticalPadding: 1.5
                )
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    Image("RetroCoin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)

                    Text("\(coupon.price)")
                        .font(.system(size: 18))
                        .fontWeight(.bold)
                        .foregroundStyle(.titleGray)
                }

                if let stateText {
                    Text(stateText)
                        .font(.system(size: 13))
                        .fontWeight(.semibold)
                        .foregroundStyle(.subTitleGray)
                } else if let onBuy {
                    Button(action: onBuy) {
                        if isBuying {
                            ProgressView()
                        } else {
                            Text("Comprar")
                                .font(.system(size: 14))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canBuy)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemGray6).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .opacity(state == .available && !isAffordable ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .voiceOverLabel(
            [coupon.name, coupon.tier.displayName, priceText, stateText,
             state == .available && !isAffordable ? L10n.tr("Moedas insuficientes") : nil]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
        .accessibilityActions {
            if canBuy, let onBuy {
                Button(L10n.tr("Comprar"), action: onBuy)
            }
        }
    }

    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(roomColor.lowOpacityColor)

            Image(systemName: "ticket.fill")
                .font(.system(size: 26))
                .foregroundStyle(roomColor.uiColor)
                .rotationEffect(.degrees(-12))
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack {
        CouponCard(
            coupon: CouponModel(name: "Escolher o filme da noite", isOnSale: true, price: 20, tier: .tier1),
            roomColor: .purple,
            isAffordable: true
        )
        CouponCard(
            coupon: CouponModel(name: "Folga da louça por um dia", isOnSale: true, price: 80, tier: .tier3),
            roomColor: .orange,
            isAffordable: false
        )
    }
    .padding()
}
