//
//  ProfileBannerSheet.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI

/// Sheet where the user picks their profile banner: a color and a texture, the same ones rooms use.
struct ProfileBannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let image: UIImage?
    
    let onConfirm: (ProfileBanner) -> Void
    
    @State private var selectedColor: RoomColor
    @State private var selectedPattern: RoomTexturePattern
    
    init(banner: ProfileBanner, image: UIImage? = nil, onConfirm: @escaping (ProfileBanner) -> Void) {
        self.image = image
        self.onConfirm = onConfirm
        _selectedColor = State(initialValue: banner.color)
        _selectedPattern = State(initialValue: banner.pattern)
    }
    
    private var pattern: RoomTexturePattern {
        selectedPattern.resolved(for: selectedColor)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    hero
                    colorPicker
                    patternPicker
                }
                .padding(.bottom, 30)
            }
            .ignoresSafeArea(edges: .top)
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Banner do perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .voiceOverLabel(L10n.tr("Cancelar"))
                    .voiceControlNames([L10n.tr("Fechar"), L10n.tr("Cancelar")])
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticsManager.notify(.success)
                        onConfirm(ProfileBanner(color: selectedColor, pattern: pattern))
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .voiceOverLabel(L10n.tr("Confirmar"))
                    .voiceControlNames([L10n.tr("Confirmar"), L10n.tr("Salvar"), L10n.tr("OK")])
                }
            }
        }
    }
    
    // MARK: - Hero
    
    /// The banner across the top of the sheet, with the profile picture over it.
    private var hero: some View {
        ZStack {
            RoomTextureBackground(color: selectedColor, pattern: pattern, zoom: 3)
                .id("\(selectedColor.rawValue).\(pattern.rawValue)")
                .transition(.opacity)
            
            avatar
                .padding(.top, 50)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: selectedColor)
        .animation(.easeInOut(duration: 0.3), value: pattern)
        // One summary of the live preview (the photo itself isn't informative here).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("Pré-visualização do banner: %@, %@",
                                    selectedColor.voiceOverName,
                                    pattern.displayName))
        .accessibilityAddTraits(.isImage)
    }
    
    private var avatar: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.gray)
                    .background(.white)
            }
        }
        .frame(width: 140, height: 140)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 3))
        .shadow(color: .black.opacity(0.25), radius: 6.85, x: 0, y: 4)
    }
    
    // MARK: - Color
    
    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Cor")
            
            HStack(spacing: 0) {
                ForEach(RoomColor.allCases) { color in
                    ColorSwatch(color: color, pattern: pattern, isSelected: selectedColor == color) {
                        HapticsManager.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            selectedColor = color
                            selectedPattern = selectedPattern.resolved(for: color)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Pattern
    
    /// One textured tile per pattern, in the selected color. Patterns the asset catalog
    private var patternPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Grafismo")
            
            HStack(spacing: 10) {
                ForEach(RoomTexturePattern.allCases, id: \.self) { option in
                    PatternSwatch(
                        color: selectedColor,
                        pattern: option,
                        isSelected: pattern == option,
                        isAvailable: option.isAvailable(for: selectedColor)
                    ) {
                        HapticsManager.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            selectedPattern = option
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    ProfileBannerSheet(banner: .default) { _ in }
}
