//
//  ProgressIndicatorCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct ProgressIndicatorCard: View {
    var title: String
    var data: String
    var color: Color = .gray
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 10)
            
            Spacer()
            
            Text(data)
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.bottom, 25)
                .foregroundColor(.white)
        }
        .frame(width: width * 0.28, height: height * 0.088)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 21))
    }
}

#Preview {
    ProgressIndicatorCard(title: "Tempo Médio", data: "1h 30min")
}
