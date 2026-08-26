//
//  PriorityDurationTag.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI

struct PriorityDurationTag: View {
    var text: String
    var color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal)
            .padding(.vertical, 2.5)
            .background(color)
            .clipShape(Capsule())
    }
}
