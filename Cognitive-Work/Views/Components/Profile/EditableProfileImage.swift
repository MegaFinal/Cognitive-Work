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
    
    /// Shows a spinner over the circle while a picked photo is still loading.
    var isLoading: Bool = false
    
    /// Size the empty-state circle is drawn at (from the handoff).
    private var elipseSize: CGFloat { width * 0.88 }

    /// Space the component claims in its parent's layout. The placeholder is
    /// larger and overflows this slot visually, so it never pushes or squeezes
    /// the views around it.
    private let layoutSize: CGFloat = 285

    var body: some View {
        Group {
            if isEditing {
                PhotosPicker(selection: $selection, matching: .images) {
                    profileImage
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            } else {
                profileImage
            }
        }
        .frame(width: layoutSize, height: layoutSize)
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
                        if !isLoading {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 65))
                                .foregroundStyle(.gray)
                        }
                    }
            }
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(image == nil ? 0 : 0.3)
                    ProgressView()
                        .controlSize(.large)
                        .tint(image == nil ? .gray : .white)
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
