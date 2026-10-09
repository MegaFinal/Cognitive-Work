//
//  QuantityStepper.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI

/// A large "−  3  +" quantity control whose number can also be typed.
///
/// Replaces the system `Stepper`, whose tiny buttons are hard to hit. The buttons use the same
/// interactive glass as the app's floating buttons and give haptic feedback. The number is a
/// text field with the numeric keypad (digits only, no symbols), clamped to ``range``. Tapping
/// anywhere outside the field (or on a button) closes the keypad.
///
/// While the field is empty (or "0") ``value`` is 0, which the form reports as a missing
/// quantity; tapping "+" from there goes straight to the range's lower bound.
struct QuantityStepper: View {

    /// The quantities an item can have.
    static let allowedRange = 1...1000

    @Binding var value: Int
    var range: ClosedRange<Int> = Self.allowedRange

    /// What the field shows. Kept apart from ``value`` so an empty field stays empty while typing.
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var maxDigits: Int { String(range.upperBound).count }

    var body: some View {
        HStack(spacing: 18) {
            stepButton(systemImage: "minus", delta: -1)

            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.titleGray)
                .frame(width: 110)
                .focused($isFocused)
                .accessibilityLabel("Quantidade")
                .onChange(of: text) { _, newText in
                    applyTyped(newText)
                }

            stepButton(systemImage: "plus", delta: 1)
        }
        .onAppear { text = displayText(for: value) }
        .onChange(of: value) { _, newValue in
            // Changed from outside (buttons, editing an item): mirror it in the field.
            if Int(text) ?? 0 != newValue { text = displayText(for: newValue) }
        }
        .animation(.snappy, value: value)
    }

    // MARK: - Buttons

    private func stepButton(systemImage: String, delta: Int) -> some View {
        let isEnabled = range.contains(value + delta)

        return Button {
            change(by: delta)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .opacity(isEnabled ? 1 : 0.35)
        .disabled(!isEnabled)
        .accessibilityLabel(delta > 0 ? "Aumentar quantidade" : "Diminuir quantidade")
    }

    private func change(by delta: Int) {
        let next = value + delta
        guard range.contains(next) else { return }
        HapticsManager.selection()
        isFocused = false
        value = next
    }

    // MARK: - Typing

    private func displayText(for number: Int) -> String {
        number == 0 ? "" : String(number)
    }

    /// Keeps only digits (the keypad can still paste anything), limits their count and the
    /// value, and publishes the number.
    private func applyTyped(_ newText: String) {
        let digits = String(newText.filter { $0 >= "0" && $0 <= "9" }.prefix(maxDigits))
        let number = min(Int(digits) ?? 0, range.upperBound)
        let cleaned = displayText(for: number)

        if text != cleaned { text = cleaned }
        if value != number { value = number }
    }
}

#Preview("Quantidades") {
    @Previewable @State var low = 1
    @Previewable @State var middle = 12
    @Previewable @State var high = 1000
    @Previewable @State var empty = 0

    VStack(spacing: 28) {
        QuantityStepper(value: $low)
        QuantityStepper(value: $middle)
        QuantityStepper(value: $high)
        QuantityStepper(value: $empty)
    }
    .padding()
}
