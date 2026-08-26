//
//  SixthOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI

struct SixthOnboardingView: View {
    @Environment(OnboardingViewModel.self) var viewModel

    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "circle.dotted")
                .resizable()
                .frame(width: 148, height: 148)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Criar divisão de tarefas")
                    .font(.title.bold())
                    .foregroundStyle(.titleGray)
                
                Text("Para que possamos ajudar no seu dia a dia em sua casa precisamos saber um pouco mais sobre ela!")
                
                Text("Criamos um formulário curto, com duração de cerca de 5 minutos, você precisa apenas nos dizer mais serão as tarefas que serão divididas por todos da casa e qual sua carga horária por semana, o resto é com a gente!")
                
                Text("Assim que todos os moradores preencherem enviaremos uma notificação avisando que a escala de tarefas foi dividida de uma forma justa por todos da casa!\n")
            }
            
            OnboardingProgressButton(text: "Continuar", action: {})
            OnboardingSkipButton(action: {viewModel.onboardingFinished = true})

        }
        .frame(width: width * 0.8)
        .foregroundColor(.gray)
        .padding(.horizontal, 30)
        .transition(.opacity)
    }
}
#Preview {
    SixthOnboardingView()
}
