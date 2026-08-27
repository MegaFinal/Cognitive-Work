//
//  ChoreCardBackFace.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

struct ChoreDetails: View {
    @Bindable var viewModel: ChoreViewModel
    @Bindable var carouselViewModel: CarouselViewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ChoreDetailsHeader(viewModel: viewModel, width: width, height: height)
                
                ChoreDetailsInfo(viewModel: viewModel, width: width, height: height)
                
                VStack {
                    ChoreDetailsPostponeButtons(viewModel: viewModel, width: width)
                    
                    SwipeToCompleteButton(action:  {
                        Task {
                            await viewModel.completeChore()
                        }
                    }, color: viewModel.roomColor)
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
                
                if viewModel.responsibleUsers.count == 1 {
                    UserProfilePictureTag(user: $viewModel.responsibleUsers.first!)
                } else {
                    UserProfilePictureList(viewModel: viewModel)
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
    
    let mockVM = ChoreViewModel.mock(
        chore: mockChore,
        roomName: "Banheiro da Suíte",
        color: Color.blue
    )
    
    mockVM.cardSymbol = "toilet"
    
    mockVM.checklistItems = [
        CheckItemModel(name: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor", isDone: true),
        CheckItemModel(name: "Lorem ipsum dolor sit amet", isDone: false),
        CheckItemModel(name: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor", isDone: false),
    ]
    
    mockVM.responsibleUsers = [
        UserModel(
            name: "Dayô",
            profilePicture: mockImageData, tier: .tier1
        ),
        UserModel(
            name: "Dayô",
            profilePicture: mockImageData, tier: .tier1
        ),
        UserModel(
            name: "Dayô",
            profilePicture: mockImageData, tier: .tier1
        )
    ]
    
    var carouselVM = CarouselViewModel()
    
    return ChoreDetails(viewModel: mockVM, carouselViewModel: carouselVM)
}
