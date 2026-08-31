//
//  CapsuleTag.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI

struct CapsuleTag: View {
    var tagName: String
    var tagColor: Color
    var horizontalPadding: Double
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
