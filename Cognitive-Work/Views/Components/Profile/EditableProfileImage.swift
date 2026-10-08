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
    
    var isLoading: Bool = false
    
    var banner: ProfileBanner? = nil
    
    var onEditBanner: (() -> Void)? = nil
    
    /// Size the empty-state circle is drawn at (from the handoff).
    fileprivate var elipseSize: CGFloat { width * 0.8 }

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
        .overlay {
            if banner != nil, let onEditBanner {
                bannerEditButton(action: onEditBanner)
            }
        }
    }
    
    /// The avatar: inside the banner ring when there is a banner, otherwise the plain circle.
    @ViewBuilder
    private var profileImage: some View {
        if let banner {
            bannerAvatar(banner)
        } else {
            plainProfileImage
        }
    }
    
    /// The circular avatar, falling back to a placeholder when no picture was chosen yet.
    private var plainProfileImage: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 285, height: 285)
                    .clipped()
                    .background(Color(.systemBackground))
            } else {
                placeholderRing
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

extension EditableProfileImage {
    fileprivate var placeholderRing: some View {
        Image("OnboardingElipse")
            .resizable()
            .frame(width: elipseSize, height: elipseSize)
    }
    
    fileprivate var innerSize: CGFloat { elipseSize * 0.7 }
    
    fileprivate func bannerAvatar(_ banner: ProfileBanner) -> some View {
        ZStack {
            RoomTextureBackground(color: banner.color, pattern: banner.pattern, zoom: 2)
                .frame(width: elipseSize, height: elipseSize)
            
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white
                    if !isLoading {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 65))
                            .foregroundStyle(.gray)
                    }
                }
                
                if isLoading {
                    Color.black.opacity(image == nil ? 0 : 0.3)
                    ProgressView()
                        .controlSize(.large)
                        .tint(image == nil ? .gray : .white)
                }
            }
            .frame(width: innerSize, height: innerSize)
            .clipShape(Circle())
        }
        .frame(width: elipseSize, height: elipseSize)
        .clipShape(Circle())
        .shadow(radius: 5)
    }
    
    fileprivate func bannerEditButton(action: @escaping () -> Void) -> some View {
        let offset = elipseSize / 2 * 0.7071
        return Button {
            HapticsManager.selection()
            action()
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 28))
                .foregroundColor(.white)
                .padding(18)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.interactive().tint(.black),
            in: .circle
        )
        .disabled(isLoading)
        .offset(x: offset, y: offset)
    }
}

#Preview("Visualização") {
    EditableProfileImage(image: nil, isEditing: false, selection: .constant(nil))
}

#Preview("Edição") {
    EditableProfileImage(image: nil, isEditing: true, selection: .constant(nil))
}
