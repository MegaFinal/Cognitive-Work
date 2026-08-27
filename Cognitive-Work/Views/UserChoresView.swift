//
//  UserChoresView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI

import SwiftUI

struct UserChoresView: View {
    @State var carouselVM = CarouselViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 15) {
                    HStack {
                        Text("Suas Tarefas")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                        
                        Spacer()
                    }
                    
                    HStack (spacing: 10){
                        ProgressIndicatorCard(
                            title: "Tempo médio",
                            data: "1h 30min"
                        )
                        
                        ProgressIndicatorCard(
                            title: "Tempo médio",
                            data: "1h 30min"
                        )
                        
                        ProgressIndicatorCard(
                            title: "Tempo médio",
                            data: "1h 30min"
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                Carousel(viewModel: carouselVM, isBackgroundClear: true)
            }
            .background(
                Color(.white)
                    .ignoresSafeArea()
                    .onTapGesture {
                        carouselVM.clearFocus()
                    }
            )
            .task {
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    return
                }
                
                await carouselVM.fetchChores()
                
                await withTaskGroup(of: Void.self) { group in
                    for cardVM in carouselVM.cardViewModels {
                        group.addTask {
                            await cardVM.loadDependencies()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let mockVM = CarouselViewModel()
    
    let chore1 = ChoreModel(name: "Lavar Banheiro", description: "Limpar espelhos e chão", frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent)
    
    let chore2 = ChoreModel(name: "Varrer Sala", description: "Limpar espelhos e chão", frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent)
    
    let chore3 = ChoreModel(name: "Lavar a Louça", description: "Secar e guardar também", frequency: .daily, duration: 900, isPublic: true, priorityTag: .low)
    
    let card1 = ChoreViewModel.mock(chore: chore1, roomName: "Banheiro da Suíte", color: .blue)
    card1.cardSymbol = "toilet"
    
    let card2 = ChoreViewModel.mock(chore: chore2, roomName: "Sala", color: .yellow)
    card2.cardSymbol = "sofa"
    
    let card3 = ChoreViewModel.mock(chore: chore3, roomName: "Cozinha", color: .red)
    card3.cardSymbol = "fork.knife"
    
    mockVM.cardViewModels = [card1, card2, card3]
    
    return UserChoresView(carouselVM: mockVM)
}
