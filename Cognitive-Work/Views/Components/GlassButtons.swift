//
//  GlassButtons.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/09/26.
//

import SwiftUI

/// Standard sizes for the app's circular icon buttons, so every screen uses the same geometry.
enum GlassCircleSize {
    /// Header/card actions (layout toggle, filters, sort, close, edit).
    static let regular: CGFloat = 44
    /// Floating action buttons (create chore, pick chore, add shopping item).
    static let floating: CGFloat = 64
}

private struct GlassCircleModifier: ViewModifier {
    let diameter: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .glassEffect(glass, in: .circle)
    }

    private var glass: Glass {
        if let tint {
            return .regular.tint(tint).interactive()
        }
        return .regular.interactive()
    }
}

extension View {
    /// Renders an icon-only control as a perfect liquid-glass circle.
    ///
    /// The frame is square *before* the glass is applied, so the shape is always a circle no
    /// matter how wide the SF Symbol is (applying padding + `.circle` to a non-square symbol
    /// produced ovals/capsules), and the hit area matches the visible circle.
    func glassCircle(diameter: CGFloat = GlassCircleSize.regular, tint: Color? = nil) -> some View {
        modifier(GlassCircleModifier(diameter: diameter, tint: tint))
    }
}

/// The app-wide confirmation button: a prominent glass checkmark placed in the navigation bar's
/// `.confirmationAction` slot (top-right), with the loading state built in.
struct ConfirmToolbarButton: View {
    var systemImage: String = "checkmark"
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: systemImage)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.glassProminent)
        .tint(.blue)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(Text("Confirmar"))
    }
}

extension View {
    /// Adds the standard ``ConfirmToolbarButton`` to the top-right of the navigation bar.
    func confirmToolbar(
        systemImage: String = "checkmark",
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        toolbar {
            ToolbarItem(placement: .confirmationAction) {
                ConfirmToolbarButton(
                    systemImage: systemImage,
                    isLoading: isLoading,
                    isDisabled: isDisabled,
                    action: action
                )
            }
        }
    }
}
