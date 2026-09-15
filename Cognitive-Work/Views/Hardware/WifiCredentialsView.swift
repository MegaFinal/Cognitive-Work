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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Conecte o quadro à sua rede!")
                    .font(.system(size: 20))
                    .bold()
                    .padding(.bottom, 20)
                 
                TextField("IP do device", text: $viewModel.deviceIP)
                TextField("Nome do Wifi", text: $viewModel.userWifiName)
                HStack {
                    if viewModel.isPasswordVisible {
                        TextField("Senha do Wifi", text: $viewModel.userWifiPassord)
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Senha do Wifi", text: $viewModel.userWifiPassord)
                            .textInputAutocapitalization(.never)
                    }
                    Button {
                        viewModel.isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: viewModel.isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                sendCredentialsButton
            }
            .textFieldStyle(.roundedBorder)
            .padding()
            .navigationDestination(isPresented: $viewModel.navigateToParingView) {
                DevicePairView(hardwareViewModel: viewModel)
            }
            .alert("Ops", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Deu algum erro.")
            }
        }
    }
     
    // MARK: - Subviews
     
    /// Sends the typed credentials to the device and navigates to the pairing step on success,
    /// while safely handling network errors and invalid IP inputs.
    private var sendCredentialsButton: some View {
        Button {
            if viewModel.userWifiName != "" && viewModel.userWifiPassord != "" && viewModel.deviceIP != "" {
                Task {
                    do {
                        try await viewModel.sendWifiCredentials()
                        viewModel.navigateToParingView = true
                        print(viewModel.navigateToParingView)
                    } catch APIErrors.invalidURL {
                        viewModel.errorMessage = "IP inválido. Verifique e tente de novo."
                    } catch let apiError as APIErrors {
                        viewModel.errorMessage = apiError.errorDescription
                    } catch {
                        viewModel.errorMessage = "Erro inesperado: \(error.localizedDescription)"
                    }
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .frame(width: 100, height: 44)
                    .foregroundStyle(.indigo)
                 
                Text("Enviar")
                    .frame(width: 100, height: 44)
                    .foregroundStyle(.white)
                    .font(.system(size: 22))
            }
        }
    }
}

#Preview {
    WifiCredentialsView()
}
