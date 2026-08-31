//
//  ResponsibleUserPicker.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

/// Lets the user pick which house members are responsible for a chore.
///
/// Selected users are shown as a stack of overlapping avatars; tapping one removes it from the
/// selection. The trailing "+" button opens a menu listing every user still available to add.
struct ResponsibleUserPicker: View {
    
    /// Every user in the house that can be assigned to the chore.
    let availableUsers: [UserModel]
    
    /// Users currently assigned to the chore.
    @Binding var selectedUsers: [UserModel]

    private func isSelected(_ user: UserModel) -> Bool {
        selectedUsers.contains { $0.id == user.id }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(selectedUsers) { selectedUser in
                UserProfilePictureTag(imageData: selectedUser.profilePicture, widthMultiplier: 0.05)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .onTapGesture {
                        selectedUsers.removeAll { $0.id == selectedUser.id }
                    }
            }
            
            Menu {
                ForEach(availableUsers) { user in
                    Button {
                        if isSelected(user) {
                            selectedUsers.removeAll { $0.id == user.id }
                        } else {
                            selectedUsers.append(user)
                        }
                    } label: {
                        if isSelected(user) {
                            Label(user.name, systemImage: "checkmark")
                        } else {
                            Text(user.name)
                        }
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
        }
    }
}
