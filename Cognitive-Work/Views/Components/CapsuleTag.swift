//
//  CapsuleTag.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI

/// Forms a textual UI element encapsulated within a pill shape.
struct CapsuleTag: View {
    
    /// Central display string.
    var tagName: String
    
    /// Defines background aesthetics.
    var tagColor: Color
    
    /// External layout horizontal constraints.
    var horizontalPadding: Double
    
    /// External layout vertical constraints.
    var verticalPadding: Double
    
    var body: some View {
        Text(tagName)
            .font(.footnote)
            .foregroundColor(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(tagColor)
            .clipShape(Capsule())
    }
}
