//
//  ChoreDetailsCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

/// Represents the detailed back-face view of a chore card.
///
/// This view is revealed when the user flips or taps a card, providing full details, checklist progress,
/// postponement actions, and a completion swipe toggle.
struct ChoreDetailsCard: View {
    
    /// The room associated with the current chore.
    @State var room: RoomModel? = nil
    
    /// All users designated as responsible for this chore.
    @State var allResponsibleUsers: [UserModel] = []
    
    /// The core data model of the chore being displayed.
    @Bindable var chore: ChoreModel
    
    /// The view model governing the carousel's state.
    @Bindable var carouselViewModel: CarouselViewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ChoreDetailsCardHeader(chore: chore, width: width, height: height)
                
                ChoreDetailsCardInfo(chore: chore, width: width, height: height)
                
                VStack {
                    ChoreDetailsCardPostponeButtons(chore: chore, width: width)
                    
                    SwipeToCompleteButton(action:  {
                        Task {
                            await chore.toggle()
                        }
                    }, color: room?.color.uiColor ?? .gray)
                    .padding(.horizontal, 30)
                }
            }
            .padding(.top, 8)
            
            HStack {
                Button {
                    carouselViewModel.clearFocus()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                }
                .padding(12)
                .clipShape(Circle())
                .glassEffect()
                
                Spacer()
                
                if allResponsibleUsers.count == 1 {
                    UserProfilePictureTag(imageData: allResponsibleUsers.first?.profilePicture, widthMultiplier: 0.05)
                } else {
                    UserProfilePictureList(chore: chore)
                }
                
                NavigationLink {
                    CreateAndEditChoreView(
                        originalModel: chore,
                        availableHouseUsers: allResponsibleUsers
                    )
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(.blue)
                .clipShape(Circle())
                .glassEffect()
            }
            .padding(.horizontal)
            .padding(.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task {
            room = await chore.room
            allResponsibleUsers = await chore.allResponsibleUsers
        }
        .frame(width: width * 0.88, height: height * 0.599)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.14), radius: 20.39595, x: 0, y: 5.80668)
    }
}

#Preview("ChoreDetails") {
    let mockChore = ChoreModel(
        name: "Lavar o Banheiro",
        description: "Esfregar o chão do box, limpar os espelhos com limpa-vidros, lavar a pia e o vaso sanitário. Tarefa essencial para manter a higiene da suíte.",
        isDone: false,
        frequency: .weekly,
        duration: 1800,
        isPublic: true,
        priorityTag: .urgent
    )
    mockChore.symbolName = "toilet"
    
    let carouselVM = CarouselViewModel()
    
    return ChoreDetailsCard(chore: mockChore, carouselViewModel: carouselVM)
}
