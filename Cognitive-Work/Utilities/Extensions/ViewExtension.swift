//
//  TextFieldExtension.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 15/09/26.
//

import SwiftUI

struct CharacterLimit: ViewModifier {
    @Binding var text: String
    let limit: Int
    
    func body(content: Content) -> some View {
        content.onChange(of: text) { _, newValue in
            if newValue.count > limit {
                text = String(newValue.prefix(limit))
            }
        }
    }
}

extension View {
    func characterLimit(_ limit: Int, text: Binding<String>) -> some View {
        modifier(CharacterLimit(text: text, limit: limit))
    }

    /// Dismisses the keyboard when the user taps anywhere else on the screen.
    ///
    /// Uses `simultaneousGesture` (not `.onTapGesture`, which would consume the tap) so it
    /// never blocks buttons, steppers, pickers or other controls underneath — it just also
    /// resigns first responder alongside whatever else that tap does.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}

extension View {
    var width: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .zero
            }
        return windowScene.screen.bounds.size.width
    }
    var height: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .zero
            }
        return windowScene.screen.bounds.size.height
    }
}
