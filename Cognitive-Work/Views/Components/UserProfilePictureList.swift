//
//  UserProfilePictureList.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 27/08/26.
//

import SwiftUI

struct UserProfilePictureList: View {
    @Bindable var viewModel: ChoreViewModel
    
    var body: some View {
        HStack(spacing: -20) {
            ForEach($viewModel.responsibleUsers, id: \.id) { user in
                UserProfilePictureTag(user: user)
                    .shadow(color: .black.opacity(0.24), radius: 1.83087, x: 1.71644, y: 1.14429)
            }
        }
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
    
    return UserProfilePictureList(viewModel: mockVM)
}
