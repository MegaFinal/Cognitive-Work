//
//  OnboardingAppDescription.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// The expanded pitch shown on the welcome screen after the user swipes up
struct OnboardingAppDescription: View {
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                Text("O HouseHouse veio para facilitar \na vida de quem divide moradia!")
                
                Text("Nosso intuito é remover a carga mental da organização de \ntarefas de maneira justa e visual para todos os moradores.")
                
                Text("Através da nossa escala de atividades e recorrência de \ntarefas automatizada, basta \nolhar o calendário e saber o que você precisa fazer!")
                
                Text("Mas antes, precisamos saber um pouco mais sobre a rotina na \ncasa...")
            }
            
            OnboardingProgressButton(text: "Começar", action: action)
        }
        .frame(width: width * 0.8)
        .foregroundColor(.gray)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 30)
        .transition(.opacity)
    }
}

#Preview {
    OnboardingAppDescription(action: {})
}
