//
//  WifiCredentialsView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

/// Collects the home WiFi credentials and sends them to the ESP32 while the phone is on its network.
struct WifiCredentialsView: View {
    /// The device connection's view model.
    @Bindable var viewModel: HardwareViewModel
    /// Closes the sheet.
    @Environment(\.dismiss) private var dismiss

    /// Whether both fields are filled.
    private var canSubmit: Bool {
        !viewModel.userWifiName.isEmpty &&
        !viewModel.userWifiPassord.isEmpty
    }
    
    /// Side margin of the whole screen, the same as the onboarding steps.
    private var sideMargin: CGFloat { width * 0.0565 }

    var body: some View {
        NavigationStack {
            VStack (spacing: 64) {
                // MARK: - Title and instructions
                OnboardingHeader(
                    title: "Agora, digite o Wi-Fi da sua casa",
                    description: "É por ele que o Harvii vai receber as tarefas.",
                    containerInset: sideMargin
                )
                
                
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Skip to pairing (Wi-Fi already sent), or the Wi-Fi fields
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
                            title: "Nome da sua rede",
                            spokenAlternatives: [L10n.tr("Nome da rede"), L10n.tr("Rede")]
                        ) {
                            TextField("Ex.: Casa da Bela", text: $viewModel.userWifiName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .characterLimit(TextLimits.wifiName, text: $viewModel.userWifiName)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 20))
                        
                        // TODO: Colocar aquele negócio de olho pra ver a senha ou deixar bolina
                        LabeledInput(
                            title: "Sua senha",
                            spokenAlternatives: [L10n.tr("Senha")]
                        ) {
                            SecureField("Senha do Wi-Fi", text: $viewModel.userWifiPassord)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .characterLimit(TextLimits.wifiPassword, text: $viewModel.userWifiPassord)
                                
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 20))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, sideMargin)
            .padding(.bottom, height * 0.02)
            .overlay(alignment: .bottomTrailing) {
                OnboardingProgressButton(
                    width: width * 0.15,
                    height: width * 0.15,
                    text: "chevron.right",
                    isSystemImage: true
                ) {
                    // TODO: go to the next Harvii step.
                }
                .padding(.bottom, height * 0.02)
                .padding(.trailing, width * 0.061)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)

            
            .navigationTitle("Conectar com WiFi")
            .navigationBarTitleDisplayMode(.inline)
            // MARK: - Toolbar: close / continue (spinner while sending)
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
            // MARK: - Pairing step, result alert and keyboard
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

/// A form field with its title above it, used for the Wi-Fi name and password.
struct LabeledInput<Content: View>: View {
    /// The field's title (also its accessibility label).
    let title: LocalizedStringKey
    /// Extra Voice Control names after the visible title ("Toque em Senha").
    var spokenAlternatives: [String] = []
    /// The field itself.
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
            // MARK: Title
            Text(title)
                .font(.body)
                .padding(.leading, 12)
                // The field below reads this title as its own label.
                .accessibilityHidden(true)
            
            // MARK: Field in a rounded box
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
//    Text("Perfil")
//        .sheet(isPresented: .constant(true)) {
            WifiCredentialsView(viewModel: HardwareViewModel())
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
//        }
}
