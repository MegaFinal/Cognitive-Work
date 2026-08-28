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
        }
    }
}

// MARK: - Mock class for preview
fileprivate class MockChoreModel: ChoreModel {
    var mockUsers: [UserModel] = []
    var mockChecklist: [CheckItemModel] = []
    var mockRoom: RoomModel? = nil
    
    override var allResponsibleUsers: [UserModel] { get async { mockUsers } }
    override var checkList: [CheckItemModel] { get async { mockChecklist } }
    override var room: RoomModel? { get async { mockRoom } }
}

#Preview("UserChoresView") {
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    let user1 = UserModel(name: "Dayô", profilePicture: mockImageData, tier: .tier1)
    let user2 = UserModel(name: "João", profilePicture: mockImageData, tier: .tier2)
    let user3 = UserModel(name: "Maria", profilePicture: mockImageData, tier: .tier1)
    
    let room1 = RoomModel(name: "Banheiro", color: .blue)
    let room2 = RoomModel(name: "Cozinha", color: .red)
    let room3 = RoomModel(name: "Sofa", color: .yellow)

    let mockVM = CarouselViewModel()
    
    let chore1 = MockChoreModel(
        name: "Lavar o Banheiro",
        description: "Esfregar o chão do box, limpar os espelhos com limpa-vidros, lavar a pia e o vaso sanitário. Não esquecer de repor o papel higiênico e esvaziar a lixeira no final.",
        isDone: false, frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent
    )
    chore1.symbolName = "toilet"
    chore1.mockUsers = [user1, user2]
    chore1.mockChecklist = [
        CheckItemModel(name: "Lavar o vaso sanitário", isDone: true),
        CheckItemModel(name: "Limpar o espelho sem manchas", isDone: false),
        CheckItemModel(name: "Esvaziar a lixeira", isDone: false)
    ]
    chore1.mockRoom = room1
    
    let chore2 = MockChoreModel(
        name: "Varrer a Sala",
        description: "Afastar o sofá e a mesa de centro para varrer os cantos. Passar um pano úmido no chão e limpar o pó da estante e da TV.",
        isDone: false, frequency: .weekly, duration: 1200, isPublic: true, priorityTag: .urgent
    )
    chore2.symbolName = "sofa"
    chore2.mockUsers = [user3]
    chore2.mockChecklist = [
        CheckItemModel(name: "Afastar o sofá", isDone: true),
        CheckItemModel(name: "Passar pano úmido", isDone: false)
    ]
    chore2.mockRoom = room2
    
    let chore3 = MockChoreModel(
        name: "Preparar o Jantar",
        description: "Cortar os legumes, temperar a carne e deixar o arroz pronto. Limpar a bancada e guardar os temperos após o uso.",
        isDone: false, frequency: .daily, duration: 2400, isPublic: true, priorityTag: .low
    )
    chore3.symbolName = "frying.pan"
    chore3.mockUsers = [user1, user2, user3]
    chore3.mockChecklist = [
        CheckItemModel(name: "Cortar legumes", isDone: true),
        CheckItemModel(name: "Temperar carne", isDone: false),
        CheckItemModel(name: "Fazer o arroz", isDone: false),
        CheckItemModel(name: "Limpar a bancada", isDone: false)
    ]
    chore3.mockRoom = room3
    
    mockVM.cardModels = [chore1, chore2, chore3]
    
    return UserChoresView(carouselVM: mockVM)
}
