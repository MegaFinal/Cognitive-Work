//
//  EditableProfileImage.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//


import SwiftUI
import PhotosUI

/// Displays the user's profile photo, optionally wrapped in a `PhotosPicker` for editing.
///
/// In read-only mode, shows the `ProfileImage` as static content. In editing mode, wraps it in
/// a `PhotosPicker` with a camera badge overlay so the user can select a new photo.

struct EditableProfileImage: View {
    let image: UIImage?
    let isEditing: Bool
    @Binding var selection: PhotosPickerItem?
    
    var elipseSize: CGFloat { width * 0.88 }

    var body: some View {
        
        if isEditing {
            PhotosPicker(selection: $selection, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    profileImage
                }
                .frame(width: 285, height: 285)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 285, height: 285)
            .contentShape(Circle())
        }
        else {
            profileImage
        }
    }
    
    /// The circular avatar, falling back to a placeholder when no picture was chosen yet.
    private var profileImage: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 285, height: 285)
                    .clipped()
                    .background(Color(.systemBackground))
            } else {
                Image("OnboardingElipse")
                    .resizable()
                    .frame(width: elipseSize, height: elipseSize)
                    .overlay {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 65))
                            .foregroundStyle(.gray)
                    }
            }
        }
        .clipShape(Circle())
        .shadow(radius: 5)
    }
}

#Preview("Visualização") {
    EditableProfileImage(image: nil, isEditing: false, selection: .constant(nil))
}

#Preview("Edição") {
    EditableProfileImage(image: nil, isEditing: true, selection: .constant(nil))
}
