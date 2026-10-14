//
//  DebtGroupSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI

/// What one housemate owes (or is owed) in the "Pendências" screen, drawn as a receipt: the
/// person and the total on top, a dotted tear line, then the items and the "Pagar" button.
/// It only renders what it's given.
struct DebtGroupSection: View {

    let user: UserModel?
    let title: String
    let totalText: String
    let rows: [Row]
    let settleTitle: String
    let isPaid: Bool
    let isSettling: Bool
    let onSettle: () -> Void

    struct Row: Identifiable {
        let id: String
        let name: String
        let amountText: String
    }

    private let notchRadius: CGFloat = 5

    @State private var notchY: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 18)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    notchY = 20 + height + 18 + 1
                }

            tearLine
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 18) {
                itemRows
                
                HStack {
                    Text("Total")
                    Spacer()
                    Text(totalText)
                }
                .font(.system(size: 22, weight: .bold))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ReceiptShape(notchRadius: notchRadius, notchY: notchY)
                .fill(.choreYellow.opacity(0.2))
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 12) {
            UserProfilePictureTag(user: user, widthMultiplier: 0.08)

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)
            
            settleButton
        }
        .foregroundStyle(.black)
    }

    /// The dotted line between the two bites.
    private var tearLine: some View {
        Line()
            .stroke(.choreYellow, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 7]))
            .frame(height: 1.5)
            .padding(.horizontal, notchRadius - 6)
            .accessibilityHidden(true)
    }

    private var itemRows: some View {
        VStack(spacing: 12) {
            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.name)
                        .font(.system(size: 17))
                        .lineLimit(2)

                    Spacer(minLength: 12)

                    Text(row.amountText)
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(.titleGray)
            }
        }
    }

    /// "Pagar" (blue) until it's tapped, then a black "Pago!". When you owe, `onSettle` copies the
    /// Pix "copia e cola".
    private var settleButton: some View {
        Button(action: onSettle) {
            settleLabel
        }
        .buttonStyle(.plain)
        .disabled(isPaid || isSettling)
        .opacity(isSettling && !isPaid ? 0.5 : 1)
        .animation(.snappy, value: isPaid)
    }

    private var settleLabel: some View {
        Text(settleTitle)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(Capsule().fill(isPaid ? Color.black : Color.blue))
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

#Preview("Seção") {
    DebtGroupSection(
        user: ShopListPreviewData.isabela,
        title: "Isabela",
        totalText: "R$45,00",
        rows: [
            .init(id: "1", name: "Pizza", amountText: "R$30,00"),
            .init(id: "2", name: "Sabão em pó", amountText: "R$21,00")
        ],
        settleTitle: "Pagar",
        isPaid: false,
        isSettling: false,
        onSettle: {}
    )
    .padding()
}
