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

    
    /// Scaling parameter controlling absolute size derivations.
    var widthMultiplier: Double
    
    var displayedImageData: Data? {
        guard let asset = user?.profilePicture else {
            print("[\(user?.name ?? "?")] asset nulo")
            return nil
        }
        guard let fileURL = asset.fileURL else {
            print("[\(user?.name ?? "?")] asset sem fileURL")
            return nil
        }
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("[\(user?.name ?? "?")] falha ao ler \(fileURL.lastPathComponent): \(error)")
            return nil
        }
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

#Preview("Com foto") {
    let user: UserModel = {
        let user = UserModel(name: "Dayô", tier: .tier1, ownerRecordName: "preview-owner")

        if let image = UIImage(systemName: "figure.wave")?.withTintColor(.systemBlue),
           let data = image.pngData() {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("fish")
            try? data.write(to: url)
            user.profilePicture = CKAsset(fileURL: url)
        }

        return user
    }()

    return UserProfilePictureTag(user: user, widthMultiplier: 0.15)
}
