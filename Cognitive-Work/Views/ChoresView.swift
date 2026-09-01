//
//  UserChoresView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI
import CloudKit

/// The primary view for displaying and managing the user's chores.
///
/// `ChoresView` coordinates the display of chores in either a carousel (grid) or a vertical list format.
/// It integrates a progress section, layout toggles, and floating action buttons for creating new chores.
struct ChoresView: View {
    
    /// The view model controlling the state and data of the chores carousel.
    @State var carouselVM = CarouselViewModel()
    
    /// The dominant color derived from the currently focused chore's room.
    @State private var activeRoomColor: Color = .gray
    
    /// Namespace used for matched geometry effect transitions between the list and carousel layouts.
    @Namespace private var cardAnimation
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Header, progress cards and action buttons
                VStack(spacing: 3) {
                    VStack(spacing: 15) {
                        ChoresViewHeader(carouselVM: $carouselVM)
                        
                        if carouselVM.layoutMode == .grid {
                            ChoresViewProgressSection(activeRoomColor: activeRoomColor)
                        } else {
                            ChoresViewProgressSection(activeRoomColor: .black)
                        }
                    }
                    
                    Spacer()
                        .matchedGeometryEffect(id: "Spawnpoint", in: cardAnimation)
                    
                    if carouselVM.layoutMode != .grid {
                        ChoreListLayout(
                            viewModel: carouselVM,
                            onSwipeDown: carouselVM.toggleLayout, namespace: cardAnimation
                        )
                        .zIndex(1000)
                    }
                    
                    ChoresViewButtonsSection()
                }
                
                // MARK: - Darkening the view if there's a focused card
                if carouselVM.hasFocusedCard {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .zIndex(1)
                        .transition(.opacity)
                        .onTapGesture {
                            dismissFocusedCard()
                        }
                }
                
                // MARK: - Chore Card layout conditionals
                if carouselVM.layoutMode == .grid {
                    VStack {
                        Spacer()
                        Carousel(
                            viewModel: carouselVM,
                            isBackgroundClear: true,
                            onSwipeDown: carouselVM.toggleLayout, namespace: cardAnimation
                        )
                        Spacer()
                    }
                    .zIndex(2)
                } else if let focusedChore = carouselVM.focusedChoreForDetails {
                    VStack {
                        Spacer()
                        CarouselCardFrame(
                            chore: focusedChore,
                            carouselViewModel: carouselVM,
                            namespace: cardAnimation,
                            isFocused: true,
                            rotation: 180,
                            isShowingBack: true
                        )
                        Spacer()
                    }
                    .zIndex(2)
                    .transition(.scale)
                }
            }
            .background(
                Color(.white)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissFocusedCard()
                    }
            )
        }
        .task(id: [carouselVM.activeIndex, carouselVM.cardModels.count]) {
            await updateActiveRoomColor()
        }
        .onAppear {
            Task {
                await carouselVM.fetchUsers()
            }
        }
    }
    
    /// Dismisses the currently focused card based on the active layout mode.
    private func dismissFocusedCard() {
        if carouselVM.layoutMode == .grid {
            carouselVM.clearFocus()
        } else {
            carouselVM.clearFocusedDetails()
        }
    }
    
    /// Updates the background color of the progress section to match the focused chore's room color.
    private func updateActiveRoomColor() async {
        guard !carouselVM.cardModels.isEmpty,
              carouselVM.cardModels.indices.contains(carouselVM.activeIndex) else {
            activeRoomColor = .gray
            return
        }
        
        let centeredChore = carouselVM.cardModels[carouselVM.activeIndex]
        
        if let room = await centeredChore.room {
            activeRoomColor = room.color.uiColor
        } else {
            activeRoomColor = .gray
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
    chore1.recordID = CKRecord.ID(recordName: "chore_1")
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
    chore2.recordID = CKRecord.ID(recordName: "chore_2")
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
    chore3.recordID = CKRecord.ID(recordName: "chore_3")
    chore3.mockUsers = [user1, user2, user3]
    chore3.mockChecklist = [
        CheckItemModel(name: "Cortar legumes", isDone: true),
        CheckItemModel(name: "Temperar carne", isDone: false),
        CheckItemModel(name: "Fazer o arroz", isDone: false),
        CheckItemModel(name: "Limpar a bancada", isDone: false)
    ]
    chore3.mockRoom = room3
    
    mockVM.cardModels = [chore1, chore2, chore3]
    mockVM.userModels = [user1, user2, user1]
    
    return ChoresView(carouselVM: mockVM)
}
