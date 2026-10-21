//
//  PurchasePricePopUp.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI

/// Asks how much an item cost when it's checked off without a price.
struct PurchasePricePopUp: View {

    /// The item's name.
    let itemName: String
    /// How many were bought (to show the total).
    let quantity: Int
    /// Runs with the typed price on ✓.
    let onConfirm: (String) -> Void
    /// Runs on "Comprar sem valor".
    let onSkip: () -> Void
    /// Runs on ✕ (doesn't buy).
    let onCancel: () -> Void

    /// The typed price.
    @State private var text = ""
    /// Whether the price field has the keyboard.
    @FocusState private var isFocused: Bool

    /// Whether the typed text is a valid price.
    private var isValid: Bool { ShopListViewModel.isValidPrice(text) }

    /// "3 × R$5,00 = R$15,00" once a price is typed; otherwise how the price is used.
    private var totalCaption: String {
        guard let unit = ShopListViewModel.parsePrice(text), unit > 0 else {
            return L10n.tr("O preço é por unidade. O total é dividido entre quem vai consumir e aparece em Pendências.")
        }
        let format = FloatingPointFormatStyle<Double>.Currency(code: "BRL").locale(L10n.locale)
        return "\(quantity) × \(unit.formatted(format)) = \((unit * Double(quantity)).formatted(format))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - ✕ and ✓ buttons
            toolbar

            // MARK: - Title and item name
            VStack(alignment: .leading, spacing: 6) {
                Text("Quanto custou cada um?")
                    .font(.system(size: 28))
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                Text(itemName)
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                    .lineLimit(2)
            }

            // MARK: - Price field
            HStack(spacing: 8) {
                Text("R$")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.subTitleGray)
                    .accessibilityHidden(true)

                TextField("0,00", text: $text)
                    .font(.system(size: 32, weight: .bold))
                    .priceInput(text: $text)
                    .focused($isFocused)
                    .voiceOverLabel(L10n.tr("Preço por unidade"))
                    .voiceOverValue(ShopListViewModel.accessibilityPrice(text))
                    // Voice Control: "Toque em Preço", then dictate the value.
                    .voiceControlNames([L10n.tr("Preço"), L10n.tr("Preço por unidade"), L10n.tr("Valor")])
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemGray6))
            )

            // MARK: - Total or explanation
            Text(totalCaption)
                .font(.system(size: 14))
                .foregroundStyle(.subTitleGray)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(
                    ShopListViewModel.accessibilityPurchaseTotal(text: text, quantity: quantity) ?? totalCaption
                )

            // MARK: - "Comprar sem valor"
            Button(action: onSkip) {
                Text("Comprar sem valor")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.subTitleGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(width: width * 0.87)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 3.2, x: 0, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .onTapGesture { isFocused = false }
        // VoiceOver stays inside the popup; the two-finger "Z" scrub cancels it like the xmark.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onCancel() }
        .onAppear {
            isFocused = true
            VoiceOver.screenChanged()
        }
    }

    /// The ✕ (cancel) and ✓ (confirm) buttons.
    private var toolbar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel("Cancelar")
            .voiceControlNames([L10n.tr("Fechar"), L10n.tr("Cancelar")])

            Spacer()

            Button {
                onConfirm(text)
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive().tint(.blue), in: .capsule)
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.4)
            .accessibilityLabel("Confirmar")
            .voiceControlNames([L10n.tr("Confirmar"), L10n.tr("Salvar"), L10n.tr("OK")])
        }
        .padding(.top, 5)
    }
}

#Preview("Preço") {
    ZStack {
        Color.black.opacity(0.45).ignoresSafeArea()
        PurchasePricePopUp(itemName: "Amaciante", quantity: 3, onConfirm: { _ in }, onSkip: {}, onCancel: {})
    }
}
