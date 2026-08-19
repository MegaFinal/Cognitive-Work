//
//  OnboardingRoomCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import Foundation
import SwiftUI

struct OnboardingRoomCard: View {
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var text: String
    var symbol: String
    var isSelected: Bool = false
    
    var body: some View {
        ZStack {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.2, height: height * 0.1)
                .padding(.bottom, 20)
                .foregroundColor(isSelected ? .white : .black)
            
            Text(text)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 20)
                .foregroundColor(isSelected ? .white : .black)
        }
        .frame(width: width * 0.42, height: height * 0.2)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .foregroundColor(isSelected ? .blue : .white)
                .shadow(color: .black.opacity(0.25), radius: 6.85, x: 0, y: 4)
        )
    }
}

#Preview {
    OnboardingRoomCard(text: "Cozinha", symbol: "cooktop")
}
