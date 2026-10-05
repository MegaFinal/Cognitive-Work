//
//  WaitingAlgorithmView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 26/08/26.
//

import SwiftUI

struct WaitingAlgorithmView: View {
    // Were multi-line literals whose indentation leaked into the UI (leading spaces and
    // trailing blanks in centered text) and made unstable localization keys.
    let description1: LocalizedStringKey = "Estamos ponderando, sorteando e dividindo as tarefas entre os moradores"
    
    let description2: LocalizedStringKey = "Enviaremos uma notificação quando a divisão estiver pronta"
    
    
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Image(systemName: "circle.bottomrighthalf.pattern.checkered")
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.4)
                .padding(.bottom)
            Text("Levantando escalas...")
                .font(.system(size: 34))
                .bold()
            
            VStack(alignment: .center, spacing: 5){
                Text(description1)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Text(description2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
        .navigationBarBackButtonHidden()
        .hidesTabBar()
    }
}

#Preview {
    WaitingAlgorithmView()
}
