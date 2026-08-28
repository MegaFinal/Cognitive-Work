//
//  ChoreCardBackFace.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

struct ChoreDetails: View {
    @State var room: RoomModel? = nil
    @State var allResponsibleUsers: [UserModel] = []
    @Bindable var chore: ChoreModel
    @Bindable var carouselViewModel: CarouselViewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ChoreDetailsHeader(chore: chore, width: width, height: height)
                
                ChoreDetailsInfo(chore: chore, width: width, height: height)
                
                VStack {
                    ChoreDetailsPostponeButtons(chore: chore, width: width)
                    
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
                }
                label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                }
                .padding(12)
                .clipShape(Circle())
                .glassEffect()
                
                Spacer()
                
                if allResponsibleUsers.count == 1 {
                    UserProfilePictureTag(imageData: allResponsibleUsers.first?.profilePicture)
                } else {
                    UserProfilePictureList(chore: chore)
                }
                
                Button {}
                label: {
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

#Preview {
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    
    let mockChore = ChoreModel(
        name: "Lavar Banheiro",
        description: "Lorem ipsum dolor sit amet, consectetur adipisc ing eliLorem ipsum dolor sit amet, conse ctetur adipiscing eli",
        frequency: .weekly,
        duration: 1800,
        isPublic: true,
        priorityTag: .urgent
    )
    
    var carouselVM = CarouselViewModel()
    
    ChoreDetails(chore: mockChore, carouselViewModel: carouselVM)
}
