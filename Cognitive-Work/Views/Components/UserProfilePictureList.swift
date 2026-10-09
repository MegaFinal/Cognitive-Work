//
//  UserProfilePictureList.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 27/08/26.
//

import SwiftUI
import CloudKit

/// Visually renders a tight horizontal overlap grouping of target user avatars.
struct UserProfilePictureList: View {
    let users: [UserModel]
    var widthMultiplier: Double
    
    var body: some View {
        HStack(spacing: -18) {
            ForEach(users, id: \.recordID) { user in
                UserProfilePictureTag(user: user, widthMultiplier: widthMultiplier)
                    .shadow(color: .black.opacity(0.24), radius: 1.83, x: 1.71, y: 1.14)
            }
        }
        // Read as "Fulano, Ciclano e mais 2" instead of one stop per avatar.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ProfileAccessibility.memberList(users.map(\.name)))
        .accessibilityHidden(users.isEmpty)
    }
}
