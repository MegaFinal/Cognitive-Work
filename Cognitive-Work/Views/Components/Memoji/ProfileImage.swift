//
//  ProfileImage.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import SwiftUI

struct ProfileImage: View {
    let image: UIImage?
    
    var body: some View {        
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(15)
                    .background(Color(.systemBackground))
            }
            else {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 85))
                            .foregroundStyle(.gray)
                    }
            }
        }
        .frame(width: 285)
        .clipShape(Circle())
        .shadow(radius: 5)
    }
}

//#Preview {
//    ProfileImage()
//}
