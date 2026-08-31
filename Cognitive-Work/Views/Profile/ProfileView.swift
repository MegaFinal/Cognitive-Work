//
//  ProfileView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI

struct ProfileView: View {
    let imageData: Data?

    var body: some View {
//        ProfileImage(image: <#UIImage?#>)
        UserProfilePictureTag(imageData: imageData, widthMultiplier: 0.5)
        Text("Nome")

    }
}

#Preview {
    
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    
    var mockUser = UserModel(
        name: "Dayô",
        profilePicture: mockImageData, tier: .tier1
    )
    
    ProfileView(imageData: mockImageData)
}
