//
//  CouponCard.swift
//  Cognitive-Work
//
//  Created by Jonas Melo on 15/10/26.
//

import SwiftUI

/// One coupon on offer in a room, in the rewards tab's list. Tapping it brings the ticket to the
/// center of the screen (``FocusedCouponView``), where it can be bought.
struct CouponCard: View {

    /// The coupon shown.
    var coupon: CouponModel
    /// The color of the coupon's room.
    var roomColor: RoomColor

    /// SF Symbol of the coupon's room (``RoomModel/symbol``).
    var roomSymbol: String = "house"

    /// Whether the user has enough coins; coupons out of reach are dimmed.
    var isAffordable: Bool

    /// Whether the coupon can be bought, is already the user's, or someone else's.
    var state: PurchaseState = .available

    /// Whether this coupon's purchase is in progress.
    var isBuying: Bool = false

    /// Called when the ticket is tapped.
    var onSelect: () -> Void = {}

    /// Whether a coupon can be bought by the user, or why not.
    enum PurchaseState: Equatable {
        /// For sale and free to buy.
        case available
        /// The user already bought it this cycle.
        case ownedByMe
        /// Someone else already bought it this cycle.
        case taken
        /// For sale, but the user already holds another coupon of this room this cycle.
        case roomLimitReached
    }

    var body: some View {
        Button(action: onSelect) {
            CouponTicket(
                coupon: coupon,
                roomColor: roomColor,
                roomSymbol: roomSymbol,
                isAffordable: isAffordable,
                state: state,
                isBuying: isBuying
            )
        }
        .buttonStyle(.plain)
        .voiceOverLabel(CouponTicket.accessibilityText(coupon: coupon, state: state, isAffordable: isAffordable))
        .accessibilityHint(Text(verbatim: L10n.tr("Abre o cupom em destaque")))
    }
}

// MARK: - Ticket

/// A coupon drawn as a ticket in the room's color: "Passe de tarefa" and the room's icon on the
/// left, the chore's name and the coupon's rank on the right, and a stub past the perforation with
/// a star and the price in coins.
///
/// The two parts are separate shapes that meet at the perforation, so the stub can be pulled away
/// (``stubOffset``, ``stubRotation``) as if torn off.
struct CouponTicket: View {

    /// The coupon shown.
    var coupon: CouponModel
    /// The ticket's color (the room's color).
    var roomColor: RoomColor
    /// The room's SF Symbol.
    var roomSymbol: String
    /// Whether the user has enough coins (dimmed when not).
    var isAffordable: Bool
    /// Whether it can be bought, or why not.
    var state: CouponCard.PurchaseState
    /// Shows a spinner instead of the star while buying.
    var isBuying: Bool = false

    /// How far the stub has been pulled from the rest of the ticket.
    var stubOffset: CGSize = .zero

    /// The stub's tilt while it is pulled, around its top-right corner.
    var stubRotation: Angle = .zero

    /// The ticket's height.
    static let height: CGFloat = 148
    /// The stub's width.
    static let stubWidth: CGFloat = 78
    /// The radius of the round bites on the outer corners.
    static let cornerRadius: CGFloat = 16
    /// The radius of the notches at the perforation.
    static let notchRadius: CGFloat = 14

    /// Dash and gap of the perforation's line.
    static let perforationDash: [CGFloat] = [5, 4]

    /// Space between the perforation's line and each notch.
    private static let perforationInset: CGFloat = 4

    /// How many dashes the perforation has, between the two notches.
    static var perforationDashCount: Int {
        let length = height - 2 * (notchRadius + perforationInset)
        let period = perforationDash.reduce(0, +)
        return max(Int((length / period).rounded(.up)), 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Main part with the perforation
            mainSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    TicketPartShape(leadingRadius: Self.cornerRadius, trailingRadius: Self.notchRadius)
                        .fill(roomColor.uiColor)
                }
                .overlay(alignment: .trailing) {
                    Perforation()
                        .stroke(.white, style: StrokeStyle(lineWidth: 1.5, dash: Self.perforationDash))
                        .frame(width: 1.5)
                        .padding(.vertical, Self.notchRadius + Self.perforationInset)
                }

            // MARK: - Stub (can be pulled away)
            stub
                .frame(width: Self.stubWidth)
                .frame(maxHeight: .infinity)
                .background {
                    TicketPartShape(leadingRadius: Self.notchRadius, trailingRadius: Self.cornerRadius)
                        .fill(roomColor.uiColor)
                }
                .rotationEffect(stubRotation, anchor: .topTrailing)
                .offset(stubOffset)
        }
        // MARK: - Shadow and dimming
        .foregroundStyle(.white)
        .frame(height: Self.height)
        // One shadow for the whole silhouette, so the seam between the parts doesn't darken.
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        .opacity((state == .available && !isAffordable) || state == .roomLimitReached ? 0.55 : 1)
        .saturation(state == .taken ? 0.2 : 1)
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
                SymbolImage(name: roomSymbol)
                    .frame(width: 54, height: 54)
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
        if let stateText = Self.stateText(state) {
            Text(verbatim: stateText).fontWeight(.bold)
        } else {
            Text("\(Text(verbatim: L10n.tr("nível"))) \(Text(verbatim: coupon.tier.displayName).fontWeight(.bold))")
        }
    }

    /// The stub: the star (or a spinner) and the price in coins.
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
        // Nudges the content off the notches.
        .padding(.leading, 4)
    }

    // MARK: - Texts

    /// The text for a coupon that isn't for sale ("Seu cupom", "Já comprado", ...), or `nil` when it is.
    static func stateText(_ state: CouponCard.PurchaseState) -> String? {
        switch state {
        case .available: return nil
        case .ownedByMe: return L10n.tr("Seu cupom")
        case .taken: return L10n.tr("Já comprado")
        case .roomLimitReached: return L10n.tr("Limite do cômodo")
        }
    }

    /// The price as text: "1 moeda" or "N moedas".
    static func priceText(_ coupon: CouponModel) -> String {
        coupon.price == 1 ? L10n.tr("1 moeda") : L10n.tr("\(coupon.price) moedas")
    }

    /// The whole ticket as one VoiceOver sentence: name, rank, price and state.
    static func accessibilityText(coupon: CouponModel, state: CouponCard.PurchaseState, isAffordable: Bool) -> String {
        [coupon.name, coupon.tier.displayName, priceText(coupon), stateText(state),
         state == .available && !isAffordable ? L10n.tr("Moedas insuficientes") : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

// MARK: - Shapes

/// One part of a ticket: a rectangle with a round bite out of each corner, `leadingRadius` on the
/// left corners and `trailingRadius` on the right ones. The main part has the corner bites on the
/// left and half notches on the right; the stub, the other way round, so together they form the
/// ticket with its notches at the perforation.
struct TicketPartShape: Shape {

    /// The radius of the bites on the left corners.
    var leadingRadius: CGFloat
    /// The radius of the bites on the right corners.
    var trailingRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var cutouts = Path()
        for corner in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY)] {
            cutouts.addEllipse(in: Self.circle(at: corner, radius: leadingRadius))
        }
        for corner in [CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)] {
            cutouts.addEllipse(in: Self.circle(at: corner, radius: trailingRadius))
        }
        return Path(rect).subtracting(cutouts)
    }

    /// A square around a circle of `radius` centered at `center`.
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
            isAffordable: true
        )
        CouponCard(
            coupon: CouponModel(name: "Lavar a louça", isOnSale: true, price: 80, tier: .tier3),
            roomColor: .orange,
            roomSymbol: "fork.knife",
            isAffordable: true,
            state: .ownedByMe
        )
        CouponTicket(
            coupon: CouponModel(name: "Limpar o banheiro", isOnSale: true, price: 120, tier: .tier3),
            roomColor: .blue,
            roomSymbol: "toilet.fill",
            isAffordable: true,
            state: .available,
            stubOffset: CGSize(width: 6, height: 40),
            stubRotation: .degrees(8)
        )
    }
    .padding(30)
}
