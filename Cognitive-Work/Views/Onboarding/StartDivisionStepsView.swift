//
//  StartDivisionStepsView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 05/10/26.
//

import SwiftUI

struct StartDivisionStepsView: View {
    @Binding var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            OnboardingHeader(
                title: "Hora de começar a divisão de tarefas",
                description: "Como administrador, você deverá selecionar as tarefas que serão divididas entre todos"
            )
            
            VStack(spacing: 15) {
                InfoCard(
                    number: "1",
                    title: "Defina os cômodos",
                    description: "Escolha os cômodos que existem na sua casa",
                    tagColor: .choreBlue,
                    backgroundColor: .lowOpacityBlue
                )
                
                InfoCard(
                    number: "2",
                    title: "Escolha as tarefas",
                    description: "Selecione as tarefas que serão divididas igualmente entre todos",
                    tagColor: .choreYellow,
                    backgroundColor: .lowOpacityYellow
                )
                
                InfoCard(
                    number: "3",
                    title: "O Pipa divide!",
                    description: "O Pipa pega as informações de todos e divide as tarefas da melhor forma possivel!",
                    tagColor: .chorePurple,
                    backgroundColor: .lowOpacityPurple
                )
            }
            
            Spacer()
            
            OnboardingProgressButton(
            text: "Iniciar divisão"
            ) {
                viewModel.goToNextView()
            }
        }
    }
}

private struct InfoCard: View {
    var number: String
    var title: String
    var description: String
    var tagColor: Color
    var backgroundColor: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Text(number)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding()
                .background(
                    Circle()
                        .foregroundStyle(tagColor)
                )
            
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 20))
                    .bold()
                
                Text(description)
            }
        }
        .frame(width: width * 0.8)
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .foregroundColor(backgroundColor.opacity(0.2))
        )
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    StartDivisionStepsView(viewModel: $viewModel)
}
