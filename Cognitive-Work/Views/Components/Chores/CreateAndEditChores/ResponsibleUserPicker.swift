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
            // MARK: - Selected members (tap one to remove it)
            ForEach(selectedUsers) { selectedUser in
                UserProfilePictureTag(user: selectedUser, widthMultiplier: 0.1)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .onTapGesture {
                        selectedUsers.removeAll { $0.id == selectedUser.id }
                    }
                    // VoiceOver: the avatar is a "remove this person" button.
                    .accessibilityElement(children: .ignore)
                    .voiceOverLabel(selectedUser.name)
                    .voiceOverHint(L10n.tr("Toque duas vezes para remover dos responsáveis."))
                    .accessibilityAddTraits(.isButton)
                    .voiceControlNames([selectedUser.name, L10n.tr("Remover %@", selectedUser.name)])
                    .accessibilityAction {
                        selectedUsers.removeAll { $0.id == selectedUser.id }
                        VoiceOver.announce(L10n.tr("%@ removido", selectedUser.name))
                    }
            }
            
            // MARK: - "+" menu to add or remove members
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
                    .font(.system(size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .voiceOverLabel(L10n.tr("Adicionar responsável"))
            .voiceControlNames([L10n.tr("Adicionar responsável"), L10n.tr("Adicionar"), L10n.tr("Mais")])
            .accessibilityValue(selectedUsers.isEmpty
                                ? L10n.tr("Sem responsável")
                                : selectedUsers.map(\.name).formatted(.list(type: .and).locale(L10n.locale)))
        }
    }
}
