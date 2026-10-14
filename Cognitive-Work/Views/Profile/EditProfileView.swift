//
//  EditProfileView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 03/09/26.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Bindable var viewModel: UserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    /// Whether the banner picker sheet is open.
    @State private var isPickingBanner = false
    
    var body: some View {
        VStack(spacing: 40) {
            // MARK: - Photo + banner
            EditableProfileImage(
                image: viewModel.displayedImageData.flatMap(UIImage.init(data:)),
                isEditing: true,
                selection: $viewModel.selectedPhotoItem,
                banner: viewModel.editedBanner,
                onEditBanner: { isPickingBanner = true }
            )
            .disabled(viewModel.isSaving)
            
            // MARK: - Name Textfield
            HStack {
                Spacer()
                TextField(
                    "",
                    text: $viewModel.editedName,
                    prompt: Text("Seu Nome")
                        .foregroundStyle(.gray)
                )
                .font(.system(size: 34))
                .frame(width: width * 0.8)
                .multilineTextAlignment(.center)
                .bold()
                .characterLimit(TextLimits.userName, text: $viewModel.editedName)
                .submitLabel(.done)
                .disabled(viewModel.isSaving)
                // The title is empty (only a placeholder), so name the field explicitly.
                .voiceOverLabel(L10n.tr("Nome"))
                // Voice Control: the visible placeholder first ("Toque em Seu Nome").
                .voiceControlNames([L10n.tr("Seu Nome"), L10n.tr("Nome")])
                Spacer()
            }
            
            Spacer()
        }
        .padding(.top, 70)
        .onChange(of: viewModel.isSaving) { _, isSaving in
            if isSaving { VoiceOver.announce(L10n.tr("Salvando")) }
        }
        .sheet(isPresented: $isPickingBanner) {
            ProfileBannerSheet(
                banner: viewModel.editedBanner,
                image: viewModel.displayedImageData.flatMap(UIImage.init(data:))
            ) { banner in
                viewModel.editedBanner = banner
            }
        }
        .navigationTitle("Editar Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSaving)
        .onAppear {
            viewModel.startEditing()
        }
        .dismissKeyboardOnTap()
        // MARK: - Success Feedback
        .overlay(alignment: .top) {
            if viewModel.didSaveSuccessfully {
                SuccessToast(text: "Perfil atualizado")
                    .padding(.top, 12)
                    .accessibilityHidden(true) // announced in onChange below
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: viewModel.didSaveSuccessfully)
        .onChange(of: viewModel.didSaveSuccessfully) { _, didSave in
            guard didSave else { return }
            VoiceOver.announce(L10n.tr("Perfil atualizado"))
            Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                viewModel.didSaveSuccessfully = false
                dismiss()
            }
        }
        .toolbar {
            // MARK: - Save Button
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await viewModel.saveChanges()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .bold()
                        .foregroundColor(.white)
                }
                .tint(Color.blue)
                .buttonStyle(.glassProminent)
                .disabled(!viewModel.canSave)
                .voiceOverLabel(L10n.tr("Salvar"))
                .voiceControlNames([L10n.tr("Confirmar"), L10n.tr("Salvar"), L10n.tr("OK")])
            }
        }
        .hidesTabBar()
        // MARK: - Error Alert
        .alert(
            "Erro ao salvar",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Success Toast

/// A small confirmation pill shown briefly over ``EditProfileView`` after a successful save.
private struct SuccessToast: View {
    let text: LocalizedStringKey

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(
                .regular.interactive().tint(.green),
                in: .capsule
            )
    }
}

#Preview {
    let mockUser = UserModel(
        name: "Dayô Araújo",
        tier: .tier1,
        ownerRecordName: "preview-owner"
    )
    let mockViewModel = UserProfileViewModel(user: mockUser)

    return NavigationStack {
        EditProfileView(viewModel: mockViewModel)
    }
}
