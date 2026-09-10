//
//  WaitHouseCreatorShedule.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 09/09/26.
//

import SwiftUI

struct WaitHouseCreatorShedule: View {
    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel
    
    let description1: String = "Estamos apenas esperando que o criador da casa gere a divisão das tarefas."
    let description2: String = "Isso acontecerá de forma automática assim que todos os membros entrarem na casa e definirem seus horários de tempo livre."
    let description3: String = "Enviaremos uma notificação quando a divisão estiver pronta."
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 40) {
                Image(systemName: "circle.hexagonpath")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.4)
                    .padding(.bottom)
                
                Text("Aguardando divisão de tarefas...")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text(description1)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    Text(description2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)
                    
                    Text(description3)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 30)
        }
        .navigationBarBackButtonHidden()
        .task {
            await viewModel.checkAndAdvanceIfScheduleReady()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task { await viewModel.checkAndAdvanceIfScheduleReady() }
        }
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()
    WaitHouseCreatorShedule(viewModel: $mockViewModel)
}
