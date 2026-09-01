//
//  OnboardingDelimiteTime.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 20/08/26.
//

import SwiftUI

struct SelectFreeTimeOnboardingView: View {
    @Binding var viewModel: OnboardingViewModel
    
    @State var weekOrder = [
        DayOfWeekDTO(name: "Segunda - Feira", nameAbbreviation: "Seg"),
        DayOfWeekDTO(name: "Terça - Feira", nameAbbreviation:"Ter"),
        DayOfWeekDTO(name: "Quarta - Feira", nameAbbreviation: "Qua"),
        DayOfWeekDTO(name: "Quinta - Feira", nameAbbreviation: "Qui"),
        DayOfWeekDTO(name: "Sexta - Feira", nameAbbreviation:"Sex"),
        DayOfWeekDTO(name: "Sabado -", nameAbbreviation: "Sab"),
        DayOfWeekDTO(name: "Domingo -",nameAbbreviation: "Dom")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            VStack(alignment: .leading) {
                Text("Delimite seu tempo")
                    .bold()
                    .font(.system(size: 32))
                    .foregroundStyle(.titleGray)
                    .padding(.top, height * 0.034)
                    .padding(.bottom, 10)
                
                Text("Defina seu tempo disponível para realizar tarefas domésticas durante a semana")
                    .bold()
                    .font(.system(size: 16))
                    .foregroundStyle(.subTitleGray)
                
                HStack(spacing: width * 0.073) {
                    Spacer()
                    Text("30’")
                    Text("1h")
                    Text("2h’")
                    Text("3h’")
                    Text("4h")
                    Text("5h")
                }
                .font(.system(size: 16))
                .fontWeight(.medium)
                .padding(.trailing, 10)
                .padding(.top, height * 0.023)
                
                ForEach($weekOrder, id: \.name) { $day in
                    OnboardingCustomSliderComponent(dayOfWeek: $day, width: width)
                }
                
                OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true) {
                    await viewModel.setAvailableTimeToUser(daysOfWeekDTO: weekOrder)
                    viewModel.goToNextView()
                }
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .padding(.horizontal, width * 0.0865)
            .navigationBarBackButtonHidden()
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    SelectFreeTimeOnboardingView(viewModel: $viewModel)
}
