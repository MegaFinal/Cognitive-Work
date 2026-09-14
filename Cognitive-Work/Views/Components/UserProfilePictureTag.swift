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
    let user: UserModel?

    var width = UIScreen.main.bounds.width
    
    /// Scaling parameter controlling absolute size derivations.
    var widthMultiplier: Double
    
    var displayedImageData: Data? {
        if let fileURL = user?.profilePicture?.fileURL {
            do {
                return try Data(contentsOf: fileURL)
            }
            catch {
                print("error to convert Image no data")
                return nil
            }
        }
        return nil
    }
    
    var body: some View {
        Group {
            Group {
                if let data = displayedImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width:width * widthMultiplier, height: width * widthMultiplier)
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
}

//TODO: fix preview
//#Preview {
//    let mockImageData = UIImage(named: "defaultUser")?.pngData()
//    
//    var mockUser = UserModel(
//        name: "Dayô",
//        profilePicture: nil, tier: .tier1
//    )
//    
//    UserProfilePictureTag(user: mockUser, widthMultiplier: 0.15)
//}
