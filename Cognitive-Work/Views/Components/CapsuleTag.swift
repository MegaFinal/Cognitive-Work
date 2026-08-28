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
    
    var body: some View {
        Text(tagName)
            .font(.footnote)
            .foregroundColor(.white)
            .padding(.horizontal)
            .padding(.vertical, 1.5)
            .background(tagColor)
            .clipShape(Capsule())
    }
}
