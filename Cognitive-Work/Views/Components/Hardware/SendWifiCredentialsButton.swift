//
//  SendWifiCredentialsButton.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

struct SendWifiCredentialsButton: View {
    @Bindable var viewModel: WifiConnectionViewModel
    var action: () -> Void
    
    var body: some View {
        Button {
            if viewModel.userWifiName != "" && viewModel.userWifiPassord != "" && viewModel.deviceIP != "" {
                Task {
//                    do {
                        try? await viewModel.sendWifiCredentials()
                        action()
//                    } catch APIErrors.invalidURL {
//                        viewModel.errorMessage = "IP inválido. Verifique e tente de novo."
//                    } catch let apiError as APIErrors {
//                        viewModel.errorMessage = apiError.errorDescription
//                    } catch {
//                        viewModel.errorMessage = "Erro inesperado: \(error.localizedDescription)"
//                    }
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
                    .font(.title2)
            }
        }
    }
}

#Preview {
    SendWifiCredentialsButton(viewModel: WifiConnectionViewModel(), action: {})
}
