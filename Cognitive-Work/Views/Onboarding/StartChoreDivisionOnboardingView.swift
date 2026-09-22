//
//  SixthOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI

struct StartChoreDivisionOnboardingView: View {
    @Binding var viewModel: OnboardingViewModel

    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "circle.dotted")
                .resizable()
                .frame(width: 148, height: 148)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Criar divisão de tarefas")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.titleGray)
//               TODO: if isAdmin
                Text("Para que possamos ajudar no seu dia a dia em sua casa precisamos saber um pouco mais sobre ela!")
                
                Text("Criamos um formulário curto, com duração de cerca de 5 minutos, você precisa apenas nos dizer mais serão as tarefas que serão divididas por todos da casa e qual sua carga horária por semana, o resto é com a gente!")
                
                Text("Assim que todos os moradores preencherem enviaremos uma notificação avisando que a escala de tarefas foi dividida de uma forma justa por todos da casa!\n")
                
//                TODO: else
            }
            
            OnboardingProgressButton(
            text: viewModel.stateMachine.isOwner == true
                    ? "Fazer divisão"
                    : "Continuar"
            ) {
                viewModel.goToNextView()
            }
            
//            OnboardingSkipButton() {
//                viewModel.finishOnboarding()
//            }

        }
        .frame(width: width * 0.8)
        .foregroundColor(.gray)
        .padding(.horizontal, 30)
        .transition(.opacity)
        .navigationBarBackButtonHidden()
    }
}
#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    StartChoreDivisionOnboardingView(viewModel: $viewModel)
}
