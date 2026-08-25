//
//  CustomColorPicker.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 24/08/26.
//

import SwiftUI


/// A single color swatch used to pick a room's accent color
///
/// Renders as a filled circle in ``item``'s color, with a blue selection ring
struct CustomColorPicker: View {
    let item: RoomColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(item.uiColor)
            .frame(width: 34, height: 34)
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(.blue, lineWidth: 2.5)
                        .padding(-3)
                }
            }
            .onTapGesture(perform: action)
    }
}

#Preview {
    CustomColorPicker(item: .green, isSelected: true, action: {})
}
