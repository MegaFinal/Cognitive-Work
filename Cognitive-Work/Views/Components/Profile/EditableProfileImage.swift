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
    
    var body: some View {
        
        if isEditing {
            PhotosPicker(selection: $selection, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    profileImage
                }
            }
            .buttonStyle(.plain)
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
                    .background(Color(.systemBackground))
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 285, height: 285)
                    .overlay {
                        Image(systemName: isEditing ? "person.fill.badge.plus" : "person.fill" )
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
