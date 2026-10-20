//
//  CouponCard.swift
//  Cognitive-Work
//
//  Created by Jonas Melo on 15/10/26.
//

import SwiftUI

/// One coupon on offer in a room, drawn as a ticket in the room's color: "Passe de tarefa" and the
/// room's icon on the left, the chore's name and the coupon's rank on the right, and a stub past
/// the perforation with a star and the price in coins.
///
/// Tapping an available ticket asks for confirmation, then calls ``onBuy``.
struct CouponCard: View {

    var coupon: CouponModel
    var roomColor: RoomColor

    /// SF Symbol of the coupon's room (``RoomModel/symbol``).
    var roomSymbol: String = "house"

    /// Whether the user has enough coins; coupons out of reach are dimmed.
    var isAffordable: Bool

    /// Whether the coupon can be bought, is already the user's, or someone else's.
    var state: PurchaseState = .available

    /// Whether this coupon's purchase is in progress.
    var isBuying: Bool = false

    /// Called once the purchase is confirmed; `nil` makes the ticket read-only.
    var onBuy: (() -> Void)? = nil

    enum PurchaseState: Equatable {
        case available
        case ownedByMe
        case taken
    }

    @State private var isConfirming = false

    /// Width of the stub, right of the perforation.
    private let stubWidth: CGFloat = 78

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
        Button {
            isConfirming = true
        } label: {
            ticket
        }
        .buttonStyle(.plain)
        .disabled(!canBuy)
        .opacity(state == .available && !isAffordable ? 0.55 : 1)
        .saturation(state == .taken ? 0.2 : 1)
        .confirmationDialog(
            L10n.tr("Comprar o cupom \"%@\"?", coupon.name),
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("Comprar por %@", priceText)) { onBuy?() }
            Button(L10n.tr("Cancelar"), role: .cancel) {}
        }
        .voiceOverLabel(
            [coupon.name, coupon.tier.displayName, priceText, stateText,
             state == .available && !isAffordable ? L10n.tr("Moedas insuficientes") : nil]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }

    // MARK: - Ticket

    private var ticket: some View {
        HStack(spacing: 0) {
            mainSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            stub
                .frame(width: stubWidth)
        }
        .foregroundStyle(.white)
        .frame(height: 148)
        .background {
            TicketShape(stubWidth: stubWidth)
                .fill(roomColor.uiColor)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        }
        .overlay(alignment: .trailing) {
            Perforation()
                .stroke(.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .frame(width: 1.5)
                .padding(.vertical, TicketShape.notchRadius + 4)
                .padding(.trailing, stubWidth)
        }
        .contentShape(TicketShape(stubWidth: stubWidth))
    }

    /// Left of the perforation: the pass label, the chore, the room icon and the rank.
    private var mainSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: L10n.tr("Passe de tarefa"))
                        .font(.system(size: 14, weight: .semibold))
                    Text(verbatim: L10n.tr("uso único"))
                        .font(.system(size: 11))
                        .padding(.leading, 12)
                }
                .fixedSize()

                Spacer(minLength: 0)

                Text(verbatim: coupon.name)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 6)

            HStack(alignment: .bottom, spacing: 8) {
                Image(systemName: roomSymbol)
                    .font(.system(size: 38, weight: .regular))
                    .accessibilityHidden(true)

                Spacer(minLength: 0)

                footer
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.leading, 26)
        .padding(.trailing, 14)
        .padding(.vertical, 18)
    }

    /// The coupon's rank, or who holds it once bought.
    @ViewBuilder
    private var footer: some View {
        if let stateText {
            Text(verbatim: stateText).fontWeight(.bold)
        } else {
            Text("\(Text(verbatim: L10n.tr("nível"))) \(Text(verbatim: coupon.tier.displayName).fontWeight(.bold))")
        }
    }

    private var stub: some View {
        VStack(spacing: 8) {
            ZStack {
                if isBuying {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: state == .ownedByMe ? "star.fill" : "star")
                        .font(.system(size: 36, weight: .medium))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(height: 40)

            HStack(spacing: 4) {
                Image("RetroCoin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)

                Text(verbatim: "\(coupon.price)")
                    .font(.system(size: 15, weight: .bold))
            }
        }
        // The stub sits right of the perforation; nudge the content off the notches.
        .padding(.leading, 4)
    }
}

// MARK: - Shapes

/// A ticket: a rectangle with a round bite out of each corner, and two notches (top and bottom)
/// where the stub is torn off, ``stubWidth`` from the right edge.
struct TicketShape: Shape {

    var stubWidth: CGFloat

    static let cornerRadius: CGFloat = 16
    static let notchRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let perforationX = rect.maxX - stubWidth

        var cutouts = Path()
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        for corner in corners {
            cutouts.addEllipse(in: Self.circle(at: corner, radius: Self.cornerRadius))
        }
        for notch in [CGPoint(x: perforationX, y: rect.minY), CGPoint(x: perforationX, y: rect.maxY)] {
            cutouts.addEllipse(in: Self.circle(at: notch, radius: Self.notchRadius))
        }

        return Path(rect).subtracting(cutouts)
    }

    private static func circle(at center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

/// The vertical line of the perforation, stroked dashed by the caller.
private struct Perforation: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

#Preview {
    VStack(spacing: 16) {
        CouponCard(
            coupon: CouponModel(name: "Arrumar a cama", isOnSale: true, price: 20, tier: .tier1),
            roomColor: .purple,
            roomSymbol: "bed.double.fill",
            isAffordable: true,
            onBuy: {}
        )
        CouponCard(
            coupon: CouponModel(name: "Lavar a louça", isOnSale: true, price: 80, tier: .tier3),
            roomColor: .orange,
            roomSymbol: "fork.knife",
            isAffordable: true,
            state: .ownedByMe
        )
        CouponCard(
            coupon: CouponModel(name: "Limpar o banheiro", isOnSale: true, price: 120, tier: .tier3),
            roomColor: .blue,
            roomSymbol: "toilet.fill",
            isAffordable: false,
            onBuy: {}
        )
    }
    .padding(30)
}
