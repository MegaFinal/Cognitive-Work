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
}
