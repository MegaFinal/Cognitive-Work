//
//  ColorIconTagLabel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/08/26.
//

import SwiftUI

/// A UI label paired with a custom-rendered colored circular icon.
///
/// Generally used inside dropdown menus and pickers to represent tagged properties visually.
struct ColorIconTagLabel: View {
    
    /// The string to be displayed next to the icon.
    let title: String
    
    /// The background color for the circular icon shape.
    let color: Color
    
    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: .coloredCircle(color: color))
                .renderingMode(.original)
        }
    }
}
