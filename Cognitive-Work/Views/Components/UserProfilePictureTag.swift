//
//  UserProfilePictureTag.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI
import CloudKit

/// Singular isolated component to portray an explicit image string into an aligned circle badge.
struct UserProfilePictureTag: View {
    
    /// Encoded PNG string data mapping back into a UIImage context.
    let imageData: Data?

    var width = UIScreen.main.bounds.width
    
    /// Scaling parameter controlling absolute size derivations.
    var widthMultiplier: Double
    
    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * widthMultiplier, height: width * widthMultiplier)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.gray)
                    .frame(width: width * widthMultiplier, height: width * widthMultiplier)
                    .background(.white)
                    .clipShape(Circle())
            }
        }
    }
}

#Preview {
    //TODO: make preview work because now profilePicture is a CKAsset
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    
    var mockUser = UserModel(
        name: "Dayô",
        profilePicture: nil, tier: .tier1
    )
    
    UserProfilePictureTag(imageData: mockUser.profilePicture?.fileURL?.dataRepresentation, widthMultiplier: 0.15)
}
