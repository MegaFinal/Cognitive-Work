//
//  ResponsibleUserPicker.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI
import CloudKit

/// Lets the user visually pick which house members are responsible for a chore.
///
/// Selected users are presented as a stack of overlapping avatars. Tapping an avatar removes it from the
/// active selection. The trailing "+" button invokes a `Menu` listing every available user to add.
struct ResponsibleUserPicker: View {
    
    /// Every user in the house that can be assigned to the chore.
    let availableUsers: [UserModel]
    
    /// The collection of users currently bound to the chore.
    @Binding var selectedUsers: [UserModel]
    
    /// Evaluates if a given user is already present in the active selection.
    private func isSelected(_ user: UserModel) -> Bool {
        selectedUsers.contains { $0.id == user.id }
    }
    
    var body: some View {
        HStack(spacing: 5) {
            ForEach(selectedUsers) { selectedUser in
                UserProfilePictureTag(imageData: selectedUser.profilePicture?.fileURL?.dataRepresentation, widthMultiplier: 0.1)
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
