//
//  PriorityDurationDotTag.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct PriorityDurationDotTag: View {
    var text: String
    var color: Color
    var width = UIScreen.main.bounds.width
    
    var body: some View {
        HStack {
            Circle()
                .frame(width: width * 0.019)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.black)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(.gray.opacity(0.3))
        .clipShape(Capsule())
    }
}

#Preview {
    PriorityDurationDotTag(text: "urgente", color: .blue)
}
