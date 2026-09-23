//
//  DevicePairView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

import SwiftUI

/// Pairs the phone with the device using the IP shown on its screen.
struct DevicePairView: View {
    @Bindable var hardwareViewModel: HardwareViewModel

    /// Closes the whole sheet, not just this step.
    var onClose: () -> Void

    @State private var isPairing = false
    @State private var pairingResult: PairingResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Parear dispositivo")
                        .font(.largeTitle)
                        .bold()

                    Text("Para que seja possível conectar o seu celular com o hardware, digite o código dele aqui e clique para confirmar.")
                        .foregroundStyle(.secondary)
                }

                LabeledInput(title: "Código do dispositivo") {
                    TextField("", text: $hardwareViewModel.deviceIP)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Parear dispositivo")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) { onClose() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isPairing {
                    ProgressView()
                } else {
                    Button(role: .confirm) {
                        pair()
                    }
                        .disabled(hardwareViewModel.deviceIP.isEmpty)
                }
            }
        }
        .onAppear {
            // The device gets a new IP after joining the home WiFi
            hardwareViewModel.deviceIP = ""
        }
        .alert(
            pairingResult?.title ?? "",
            isPresented: Binding(
                get: { pairingResult != nil },
                set: { if !$0 { pairingResult = nil } }
            ),
            presenting: pairingResult
        ) { result in
            Button("Voltar", role: .cancel) {
                if result == .success { onClose() }
            }
        } message: { result in
            Text(result.message)
        }
        .dismissKeyboardOnTap()
    }

    // MARK: - Actions

    /// Asks the device for its hash, saves the IP and shows the result alert.
    private func pair() {
        isPairing = true

        Task {
            defer { isPairing = false }
            do {
                let connected = try await hardwareViewModel.askForParingCode()
                guard connected, await hardwareViewModel.createIp() else {
                    pairingResult = .failure
                    return
                }
                pairingResult = .success
            } catch {
                pairingResult = .failure
                return
            }
            try await hardwareViewModel.sendChartToESP32()
        }
    }
}

/// Outcome of a pairing attempt, used to drive the result alert.
enum PairingResult {
    case success
    case failure

    var title: String {
        switch self {
        case .success: "Conexão completa!"
        case .failure: "Falha na conexão"
        }
    }

    var message: String {
        switch self {
        case .success: "Sua conexão foi concluída com sucesso, nos próximos minutos o seu hardware estará pronto!"
        case .failure: "Certifique-se que o código que você está escrevendo está correto e tente novamente."
        }
    }
}

#Preview {
    Text("Perfil")
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                DevicePairView(hardwareViewModel: HardwareViewModel(), onClose: {})
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
}
