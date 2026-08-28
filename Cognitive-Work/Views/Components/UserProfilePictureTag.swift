//
//  UserProfilePictureTag.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI

struct UserProfilePictureTag: View {
    let imageData: Data?

    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.045)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .padding(7)
        .background(.gray)
        .clipShape(Circle())
    }
}

#Preview {
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    
    var mockUser = UserModel(
        name: "Dayô",
        profilePicture: mockImageData, tier: .tier1
    )
    
    UserProfilePictureTag(imageData: mockUser.profilePicture)
}
