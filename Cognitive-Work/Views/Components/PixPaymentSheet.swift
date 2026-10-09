//
//  PixPaymentSheet.swift
//  Cognitive-Work
//

import SwiftUI

/// What the user is about to pay with Pix.
struct PixPayment: Identifiable {
    /// The "copia e cola" code.
    let code: String
    let amount: PendingPaymentsViewModel.AmountParts
    let receiver: UserModel

    var id: String { code }
}

/// Sheet to pay a Pix, drawn as the same receipt as the "Pendências" cards: who gets the money and
/// how much on top, the code under the tear line, then the installed banks. Tapping a bank copies
/// the code and opens the app; "Mais opções" opens the system share sheet.
struct PixPaymentSheet: View {
    let payment: PixPayment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var yourBanks: [PixBankApp] = []
    @State private var otherBanks: [PixBankApp] = []
    @State private var isShowingOtherBanks = false
    /// The bank that didn't open, to say so under the grid.
    @State private var failedBank: String?
    @State private var isCopied = false
    @State private var showSystemShare = false
    @State private var notchY: CGFloat = 0

    private let notchRadius: CGFloat = 5

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    titleBlock
                    receipt
                    banksSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) { bottomButtons }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(.black)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .onAppear(perform: loadBanks)
        .sheet(isPresented: $showSystemShare) {
            ShareSheet(text: payment.code)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Pieces

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pagar com Pix")
                .bold()
                .font(.system(size: 32))

            Text("Escolha seu banco: o código já vai copiado.")
                .font(.system(size: 16))
                .foregroundStyle(.subTitleGray)
        }
    }

    /// Receiver and amount, a dotted tear line, then the code.
    private var receipt: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    UserProfilePictureTag(user: payment.receiver, widthMultiplier: 0.08)

                    Text(payment.receiver.name)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(payment.amount.currency)
                        .font(.system(size: 22, weight: .semibold))
                    Text(payment.amount.whole)
                        .font(.system(size: 40, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(payment.amount.cents)
                        .font(.system(size: 22, weight: .semibold))
                }
            }
            .foregroundStyle(.black)
            .padding(.bottom, 18)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                notchY = 20 + height + 18 + 1
            }

            TearLine()
                .stroke(.choreYellow, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 7]))
                .frame(height: 1.5)
                .padding(.horizontal, notchRadius - 6)
                .padding(.bottom, 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Pix copia e cola")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)

                Text(payment.code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.titleGray)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
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

    private var banksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Abrir no banco")
                .font(.system(size: 15))
                .fontWeight(.semibold)

            if yourBanks.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "building.columns")
                        .foregroundStyle(.subTitleGray)
                    Text("Não achamos seu banco sozinhos. Escolha ele abaixo: depois da primeira vez ele aparece aqui.")
                        .font(.system(size: 15))
                        .foregroundStyle(.subTitleGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.systemGray6).opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
            } else {
                bankGrid(yourBanks)
            }

            if let failedBank {
                Label(L10n.tr("Não conseguimos abrir o %@. O código já está copiado: abra o app e cole em Pix > Copia e Cola.", failedBank),
                      systemImage: "exclamationmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.choreOrange)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            } else if !yourBanks.isEmpty {
                Text("Se o banco não oferecer colar sozinho, use Pix > Copia e Cola.")
                    .font(.system(size: 14))
                    .foregroundStyle(.subTitleGray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !otherBanks.isEmpty {
                Button {
                    withAnimation(.snappy) { isShowingOtherBanks.toggle() }
                } label: {
                    HStack {
                        Text(yourBanks.isEmpty ? "Todos os bancos" : "Outros bancos")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .rotationEffect(.degrees(isShowingOtherBanks ? 180 : 0))
                    }
                    .foregroundStyle(.black)
                    .padding(.top, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isShowingOtherBanks {
                    bankGrid(otherBanks)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.snappy, value: failedBank)
    }

    private func bankGrid(_ banks: [PixBankApp]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(banks) { bank in
                bankTile(bank)
            }
        }
    }

    /// A card in the bank's own color, with its initial in a white circle.
    private func bankTile(_ bank: PixBankApp) -> some View {
        Button {
            open(bank)
        } label: {
            HStack(spacing: 10) {
                Text(String(bank.name.prefix(1)))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(bank.textHex == "FFFFFF" ? bank.color : bank.textColor)
                    .frame(width: 36, height: 36)
                    .background(.white, in: Circle())

                Text(bank.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(bank.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(bank.textColor.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(bank.color)
            )
            .shadow(color: bank.color.opacity(0.3), radius: 8, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.tr("Abrir %@", bank.name)))
    }

    /// "Copiar código" in the app's capsule style, with "Mais opções" under it.
    private var bottomButtons: some View {
        VStack(spacing: 4) {
            Button {
                copy()
            } label: {
                HStack(spacing: 8) {
                    Text(isCopied ? "Copiado!" : "Copiar código")
                        .font(.system(size: 18, weight: .bold))
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isCopied ? Color.choreGreen : Color.blue, in: Capsule())
                .shadow(color: (isCopied ? Color.choreGreen : Color.blue).opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)

            Button {
                showSystemShare = true
            } label: {
                Text("Mais opções")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.subTitleGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.bar)
        .animation(.snappy, value: isCopied)
    }

    // MARK: - Actions

    private func copy() {
        UIPasteboard.general.string = payment.code
        HapticsManager.selection()
        isCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            isCopied = false
        }
    }

    private func loadBanks() {
        let split = PixBankApp.split()
        yourBanks = split.yours
        otherBanks = split.others
    }

    private func open(_ bank: PixBankApp) {
        copy()
        failedBank = nil
        Task {
            if await bank.open() {
                loadBanks()
            } else {
                failedBank = bank.name
            }
        }
    }

    private struct TearLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PixPaymentSheet(payment: .init(
                code: "00020126290014br.gov.bcb.pix0107a@b.com520400005303986540512.505802BR5907ISABELA6006BRASIL62070503***63044A20",
                amount: .init(currency: "R$", whole: "12", cents: ",50"),
                receiver: ShopListPreviewData.isabela
            ))
        }
}
