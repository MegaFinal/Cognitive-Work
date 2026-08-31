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
                    ProfileImage(image: image, isEditing: isEditing)
                }
            }
            .buttonStyle(.plain)
        } else {
            ProfileImage(image: image, isEditing: isEditing)
        }
    }
}

#Preview("Visualização") {
    EditableProfileImage(image: nil, isEditing: false, selection: .constant(nil))
}

#Preview("Edição") {
    EditableProfileImage(image: nil, isEditing: true, selection: .constant(nil))
}
