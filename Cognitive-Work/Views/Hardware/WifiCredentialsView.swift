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
                        Text("Conectar Harvii")
                            .font(.largeTitle)
                            .bold()
                            .accessibilityAddTraits(.isHeader)

                        Text("Para que seja possível conectar o Harvii ao WiFi da sua casa, entre no WiFi HARVII, com senha 12345678, retorne ao app e envie o nome e senha do WiFi.")
                            .foregroundStyle(.secondary)
                    }
                    
                    if !viewModel.hostName.isEmpty {
                        Button("Já enviei o WiFi, ir para o pareamento") {
                            viewModel.navigateToParingView = true
                        }
                        .voiceControlNames([
                            L10n.tr("Já enviei o WiFi, ir para o pareamento"),
                            L10n.tr("Pareamento"),
                            L10n.tr("Ir para o pareamento")
                        ])
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    } else {
                        LabeledInput(
                            title: "Nome do Wi-Fi",
                            spokenAlternatives: [L10n.tr("Nome da rede"), L10n.tr("Rede")]
                        ) {
                            TextField("", text: $viewModel.userWifiName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .characterLimit(TextLimits.wifiName, text: $viewModel.userWifiName)
                        }
                        LabeledInput(
                            title: "Senha do Wi-Fi",
                            spokenAlternatives: [L10n.tr("Senha")]
                        ) {
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
                        .voiceControlNames([L10n.tr("Fechar"), L10n.tr("Cancelar")])
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSending {
                        ProgressView()
                            .voiceOverLabel(L10n.tr("Enviando dados do WiFi"))
                    } else {
                        Button("Continuar", systemImage: "chevron.right") {
                            Task { await viewModel.sendWifiCredentials() }
                        }
                        .buttonStyle(.glassProminent)
                        // Icon-only in the toolbar: "Toque em Continuar" / "Enviar".
                        .voiceControlNames([L10n.tr("Continuar"), L10n.tr("Enviar"), L10n.tr("Conectar")])
                        .disabled(!canSubmit)
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.navigateToParingView) {
                DevicePairView(hardwareViewModel: viewModel, onClose: { dismiss() })
            }
            .resultAlert($viewModel.wifiResult)
            .dismissKeyboardOnTap()
            // Sending takes a few seconds behind a spinner; the result arrives as an alert.
            .onChange(of: viewModel.isSending) { _, isSending in
                if isSending { VoiceOver.announce(L10n.tr("Enviando dados do WiFi para o Harvii…")) }
            }
        }
    }
}

struct LabeledInput<Content: View>: View {
    let title: LocalizedStringKey
    /// Extra Voice Control names after the visible title ("Toque em Senha").
    var spokenAlternatives: [String] = []
    @ViewBuilder var content: () -> Content

    /// Voice Control names: the visible title first, then the alternatives.
    private var inputLabelTexts: [Text] {
        var texts: [Text] = [Text(title)]
        for name in spokenAlternatives {
            texts.append(Text(verbatim: name))
        }
        return texts
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body)
                .padding(.leading, 12)
                // The field below reads this title as its own label.
                .accessibilityHidden(true)
            
            content()
                .accessibilityLabel(Text(title))
                // Voice Control: the visible title first, then shorter alternatives.
                .accessibilityInputLabels(inputLabelTexts)
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
