//
//  ExistingIPView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 02/09/26.
//

import SwiftUI

/// Shown when this phone is already paired: lets the user test the device, disconnect
/// this phone or reset the device for the whole house.
struct ExistingIPView: View {
    @Binding var viewModelHardware: HardwareViewModel
    @Environment(\.dismiss) private var dismiss

    var profileImage: UIImage?

    @State private var errorMessage: String?
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            avatarView
                .frame(width: 100, height: 100)

            Button {
                Task {
                    do {
                        try await viewModelHardware.prepareImageForESP32(view: avatarForDevice)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: 150, height: 44)
                        .foregroundStyle(.orange)
                    Text("Enviar imagem")
                        .foregroundStyle(.white)
                        .padding()
                }
            }

            Button("Desconectar este celular") {
                viewModelHardware.disconnectThisPhone()
                dismiss()
            }

            Button("Resetar o Harvi", role: .destructive) {
                showResetConfirmation = true
            }
        }
        .confirmationDialog(
            "Resetar o Harvi?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Resetar", role: .destructive) {
                Task {
                    do {
                        try await viewModelHardware.resetHardware()
                        dismiss()
                    } catch {
                        errorMessage = "Não foi possível falar com o Harvi. Segure o botão BOOT por 5 segundos para resetar direto no dispositivo."
                    }
                }
            }
        } message: {
            Text("O Harvi vai esquecer o WiFi e todos os celulares da casa precisarão configurar e parear de novo.")
        }
        .alert("Ops", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Ocorreu um erro.")
        }
    }

    private var avatarView: some View {
        Group {
            if let profileImage {
                Image(uiImage: profileImage)
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
        .clipShape(Circle())
    }

    private var avatarForDevice: some View {
        avatarView
            .frame(width: 100, height: 100)
    }
}
