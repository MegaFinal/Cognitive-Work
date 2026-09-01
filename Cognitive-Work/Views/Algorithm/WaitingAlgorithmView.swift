//
//  WaitingAlgorithmView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 26/08/26.
//

import SwiftUI

struct WaitingAlgorithmView: View {
    let description1: String = """
        Estamos ponderando, sorteando e 
    dividindo as tarefas entre os moradores 
    """
    
    let description2: String =  """
        Enviaremos uma notificação 
    quando a divisão estiver pronta
    """
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
//    var schedule: TaskSchedulerEngine
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Image(systemName: "circle.bottomrighthalf.pattern.checkered")
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.4)
                .padding(.bottom)
            Text("Levantando escalas...")
                .font(.largeTitle)
                .bold()
            
            VStack(alignment: .center, spacing: 5){
                Text(description1)
                    .foregroundColor(.gray)
                Text(description2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
        .navigationBarBackButtonHidden()

    }
}

#Preview {
    WaitingAlgorithmView()
}
