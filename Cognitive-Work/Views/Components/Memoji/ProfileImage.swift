//
//  ProfileImage.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import SwiftUI
// MARK: UIKIT PROFILE IMAGE FOR MEMOJI
//struct ProfileImage: View {
//    let image: UIImage?
//    
//    var body: some View {
//        Group {
//            if let image {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .padding(15)
//                    .background(Color(.systemBackground))
//            }
//            else {
//                Circle()
//                    .fill(Color(.systemGray5))
//                    .overlay {
//                        Image(systemName: "person.fill.badge.plus")
//                            .font(.system(size: 65))
//                            .foregroundStyle(.gray)
//                    }
//            }
//        }
//        .frame(width: 285)
//        .clipShape(Circle())
//        .shadow(radius: 5)
//    }
//}

struct ProfileImage: View {
    let image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill() // Mudado para fill para preencher o círculo perfeitamente
                    .frame(width: 285, height: 285)
                    .background(Color(.systemBackground))
            }
            else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 285, height: 285)
                    .overlay {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 65))
                            .foregroundStyle(.gray)
                    }
            }
        }
        .clipShape(Circle())
        .shadow(radius: 5)
    }
}

//#Preview {
//    ProfileImage()
//}
