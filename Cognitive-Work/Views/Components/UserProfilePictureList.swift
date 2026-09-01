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
    
    var widthMultiplier: Double
    
    /// Internally fetches active assignees representing the picture data points.
    @State var responsibleUsers: [UserModel] = []
    
    var body: some View {
        HStack(spacing: -35) {
            ForEach($responsibleUsers, id: \.recordID) { $user in
                UserProfilePictureTag(imageData: user.profilePicture, widthMultiplier: widthMultiplier)
                    .shadow(color: .black.opacity(0.24), radius: 1.83087, x: 1.71644, y: 1.14429)
            }
        }
        .task {
            responsibleUsers = await chore.allResponsibleUsers
        }
    }
}

// MARK: - Mock class for preview
fileprivate class MockChoreModel: ChoreModel {
    var mockUsers: [UserModel] = []
    override var allResponsibleUsers: [UserModel] { get async { mockUsers } }
}

#Preview {
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    
    let user1 = UserModel(name: "Dayô", profilePicture: mockImageData, tier: .tier1)
    let user2 = UserModel(name: "João", profilePicture: mockImageData, tier: .tier2)

    let mockChore = MockChoreModel(
        name: "Lavar o Banheiro",
        description: "Esfregar o chão do box, limpar os espelhos com limpa-vidros, lavar a pia e o vaso sanitário. Não esquecer de repor o papel higiênico e esvaziar a lixeira no final.",
        isDone: false, frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent
    )
    mockChore.mockUsers = [user1, user2]
    
    return UserProfilePictureList(chore: mockChore, widthMultiplier: 0.12)
}
