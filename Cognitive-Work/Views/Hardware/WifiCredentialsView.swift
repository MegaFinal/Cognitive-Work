//
//  WifiCredentialsView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

struct WifiCredentialsView: View {
    @State private var viewModel = WifiConnectionViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Conecte o quadro à sua rede!")
                    .font(.title3)
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
                SendWifiCredentialsButton(viewModel: viewModel) {
                    viewModel.navigateToParingView = true
                    print(viewModel.navigateToParingView)
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding()
            .navigationDestination(isPresented: $viewModel.navigateToParingView) {
                DevicePairView(viewModel: viewModel)
            }
//            .alert("Ops", isPresented: .constant(viewModel.errorMessage != nil)) {
//                Button("OK") { viewModel.errorMessage = nil }
//            } message: {
//                Text(viewModel.errorMessage ?? "Deu algum erro.")
//            }
        }
    }
}

#Preview {
    WifiCredentialsView()
}
