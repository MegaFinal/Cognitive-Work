//
//  WifiCredentialsView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

/// Collects the home WiFi credentials and sends them to the ESP32 while the phone is on its network.
struct WifiCredentialsView: View {
    @Bindable var viewModel: HardwareViewModel
    @Environment(\.dismiss) private var dismiss

    private var canSubmit: Bool {
        !viewModel.userWifiName.isEmpty &&
        !viewModel.userWifiPassord.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conectar Harvi")
                            .font(.largeTitle)
                            .bold()

                        Text("Para que seja possível conectar o Harvi ao WiFi da sua casa, entre no WiFi ESP32, com senha 12345678, retorne ao app e envie o nome e senha do WiFi.")
                            .foregroundStyle(.secondary)
                    }
                    
                    if !viewModel.hostName.isEmpty {
                        Button("Já enviei o WiFi, ir para o pareamento") {
                            viewModel.navigateToParingView = true
                        }
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    } else {
                        LabeledInput(title: "Nome do Wi-Fi") {
                            TextField("", text: $viewModel.userWifiName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .characterLimit(TextLimits.wifiName, text: $viewModel.userWifiName)
                        }
                        LabeledInput(title: "Senha do Wi-Fi") {
                            SecureField("", text: $viewModel.userWifiPassord)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .characterLimit(TextLimits.wifiPassword, text: $viewModel.userWifiPassord)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Conectar com WiFi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmToolbarButton(
                        systemImage: "chevron.right",
                        isLoading: viewModel.isSending,
                        isDisabled: !canSubmit
                    ) {
                        Task { await viewModel.sendWifiCredentials() }
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.navigateToParingView) {
                DevicePairView(hardwareViewModel: viewModel, onClose: { dismiss() })
            }
            .resultAlert($viewModel.wifiResult)
            .dismissKeyboardOnTap()
        }
    }
}

struct LabeledInput<Content: View>: View {
    let title: LocalizedStringKey
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
    Text("Perfil")
        .sheet(isPresented: .constant(true)) {
            WifiCredentialsView(viewModel: HardwareViewModel())
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
}
