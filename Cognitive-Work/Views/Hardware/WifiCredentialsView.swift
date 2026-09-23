//
//  WifiCredentialsView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

/// A view that allows users to input their network credentials (IP, Wi-Fi name, and password)
/// to configure and connect an ESP32 hardware device.
struct WifiCredentialsView: View {
    @State private var viewModel = HardwareViewModel()
    @Environment(\.dismiss) private var dismiss
    
    private var canSubmit: Bool {
        !viewModel.deviceIP.isEmpty &&
        !viewModel.userWifiName.isEmpty &&
        !viewModel.userWifiPassord.isEmpty
    }
    
    @State private var isSending = false
    @State private var showTimeoutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LabeledInput(title: "Código do dispositivo") {
                        TextField("", text: $viewModel.deviceIP)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    LabeledInput(title: "Nome do Wi-Fi") {
                        TextField("", text: $viewModel.userWifiName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledInput(title: "Senha do Wi-Fi") {
                        SecureField("", text: $viewModel.userWifiPassord)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Conectar com Hardware")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continuar", systemImage: "chevron.right") { sendCredentials()
                    }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSubmit)
                }
            }
            .navigationDestination(isPresented: $viewModel.navigateToParingView) {
                DevicePairView(hardwareViewModel: viewModel, onClose: { dismiss() })
            }
            .alert("Ops", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Deu algum erro.")
            }
            .dismissKeyboardOnTap()
        }
    }
    
    // MARK: - Functions
    
    /// Sends the typed credentials to the device and navigates to the pairing step on success,
    /// while safely handling network errors and invalid IP inputs.
    private func sendCredentials() {
        Task {
            do {
                try await viewModel.sendWifiCredentials()
                viewModel.navigateToParingView = true
                print(viewModel.navigateToParingView)
            } catch APIErrors.invalidURL {
                viewModel.errorMessage = "Código inválido. Verifique e tente novamente."
            } catch let apiError as APIErrors {
                viewModel.errorMessage = apiError.errorDescription
            } catch {
                viewModel.errorMessage = "Erro inesperado. Tente novamente"
            }
        }
    }
}

struct LabeledInput<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body)
                .padding(.leading, 12)
            
            content()
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(.secondarySystemGroupedBackground),
                            in: .rect(cornerRadius: 16))
        }
    }
}

#Preview {
    WifiCredentialsView()
}
