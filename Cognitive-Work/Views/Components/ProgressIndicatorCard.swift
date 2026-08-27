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
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray.opacity(0.7))
                .padding(.top, 10)
            
            Spacer()
            
            Text(data)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.bottom, 25)
        }
        .frame(width: width * 0.28, height: height * 0.088)
        .background(.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 21))
    }
}

#Preview {
    ProgressIndicatorCard(title: "Tempo Médio", data: "1h 30min")
}
