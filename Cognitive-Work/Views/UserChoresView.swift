//
//  UserChoresView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI

struct UserChoresView: View {
    @State var carouselVM = CarouselViewModel()
    var height = UIScreen.main.bounds.width
    @Namespace private var cardAnimation
    
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
    
                        LayoutToggleButton(viewModel: carouselVM)
                            .padding(.top, 20)
                            .padding(.trailing, 30)
                    }
                    
                    HStack(spacing: 10) {
                        ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min")
                        ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min")
                        ProgressIndicatorCard(title: "Tempo médio", data: "1h 30min")
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    .matchedGeometryEffect(id: "Spawnpoint", in: cardAnimation)
                    
                    if carouselVM.layoutMode != .grid {
                       ChoreListLayout(
                           viewModel: carouselVM,
                           onSwipeDown: carouselVM.toggleLayout, namespace: cardAnimation
                       )
                       .zIndex(1000)
                   }
                    RoundedRectangle(cornerRadius: 30)
                        .frame(width: 25, height: 25)
                }
                
                if carouselVM.layoutMode == .grid {
                    Spacer()
                    Carousel(
                        viewModel: carouselVM,
                        isBackgroundClear: true,
                        onSwipeDown: carouselVM.toggleLayout, namespace: cardAnimation
                    )
                    Spacer()
                    
                }
            }
            .background(
                Color(.white)
                    .ignoresSafeArea()
                    .onTapGesture {
                        carouselVM.clearFocus()
                    }
            )
            .task {
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
                
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
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    
    let user1 = UserModel(name: "Dayô", profilePicture: mockImageData, tier: .tier1)
    let user2 = UserModel(name: "João", profilePicture: mockImageData, tier: .tier2)
    let user3 = UserModel(name: "Maria", profilePicture: mockImageData, tier: .tier1)

    let mockVM = CarouselViewModel()
    
    let chore1 = ChoreModel(
        name: "Lavar Banheiro",
        description: "Esfregar o chão do box, limpar os espelhos com limpa-vidros, lavar a pia e o vaso sanitário. Não esquecer de repor o papel higiênico e esvaziar a lixeira no final.",
        frequency: .weekly,
        duration: 1800,
        isPublic: true,
        priorityTag: .urgent
    )
    let card1 = ChoreViewModel.mock(
        chore: chore1,
        roomName: "Banheiro da Suíte",
        color: .blue,
        responsibleUsers: [user1, user2]
    )
    card1.cardSymbol = "toilet"
    card1.checklistItems = [
        CheckItemModel(name: "Lavar o vaso sanitário", isDone: true),
        CheckItemModel(name: "Limpar o espelho sem deixar manchas", isDone: false),
        CheckItemModel(name: "Esfregar o chão do box com água sanitária", isDone: false),
        CheckItemModel(name: "Esvaziar a lixeira", isDone: false)
    ]
    
    let chore2 = ChoreModel(
        name: "Varrer a Sala",
        description: "Afastar o sofá e a mesa de centro para varrer os cantos. Passar um pano úmido no chão e limpar o pó da estante e da TV.",
        frequency: .weekly,
        duration: 1200,
        isPublic: true,
        priorityTag: .urgent
    )
    let card2 = ChoreViewModel.mock(
        chore: chore2,
        roomName: "Sala de Estar",
        color: .yellow,
        responsibleUsers: [user3]
    )
    card2.cardSymbol = "sofa"
    card2.checklistItems = [
        CheckItemModel(name: "Afastar o sofá e varrer embaixo", isDone: true),
        CheckItemModel(name: "Tirar o pó da TV e estante", isDone: true),
        CheckItemModel(name: "Passar pano úmido no chão", isDone: false)
    ]
    
    let chore3 = ChoreModel(
        name: "Lavar a Louça",
        description: "Ensabuar e enxaguar todos os pratos, panelas e talheres usados no jantar. Secar e guardar tudo nos armários corretos. Limpar a pia no final.",
        frequency: .daily,
        duration: 900,
        isPublic: true,
        priorityTag: .low
    )
    let card3 = ChoreViewModel.mock(
        chore: chore3,
        roomName: "Cozinha",
        color: .red,
        responsibleUsers: [user1, user2, user3]
    )
    card3.cardSymbol = "fork.knife"
    card3.checklistItems = [
        CheckItemModel(name: "Lavar os copos e taças", isDone: false),
        CheckItemModel(name: "Lavar os pratos e talheres", isDone: false),
        CheckItemModel(name: "Lavar as panelas engorduradas", isDone: false),
        CheckItemModel(name: "Secar a pia com o rodinho", isDone: false)
    ]
    
    mockVM.cardViewModels = [card1, card2, card3]
    
    return UserChoresView(carouselVM: mockVM)
}
