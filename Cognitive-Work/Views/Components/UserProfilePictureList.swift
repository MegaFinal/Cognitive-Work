//
//  UserProfilePictureList.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 27/08/26.
//

import SwiftUI

/// Visually renders a tight horizontal overlap grouping of target user avatars.
struct UserProfilePictureList: View {
    
    /// Target chore managing assigned users.
    @Bindable var chore: ChoreModel
    
    /// Internally fetches active assignees representing the picture data points.
    @State var responsibleUsers: [UserModel] = []
    
    var body: some View {
        HStack(spacing: -20) {
            ForEach($responsibleUsers, id: \.recordID) { $user in
                UserProfilePictureTag(imageData: user.profilePicture, widthMultiplier: 0.05)
                    .shadow(color: .black.opacity(0.24), radius: 1.83087, x: 1.71644, y: 1.14429)
            }
        }
        .task {
            responsibleUsers = await chore.allResponsibleUsers
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
    
    return UserProfilePictureList(chore: mockChore)
}
