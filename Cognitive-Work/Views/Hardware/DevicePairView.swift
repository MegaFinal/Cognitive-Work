//
//  DevicePairView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

/// Pairs the phone with the device using the IP shown on its screen.
struct DevicePairView: View {
    @Bindable var hardwareViewModel: HardwareViewModel
    @State private var disconectThisPhone = false
    
    /// Closes the whole sheet, not just this step.
    var onClose: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Parear dispositivo")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 50)
                    
                    Text("Para que seja possível conectar o seu celular com o hardware, retorne ao seu WiFi e clique para confirmar.")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                OnboardingProgressButton(
                    text: "Parear",
                    isLoading: hardwareViewModel.isPairing,
                    isDisabled: hardwareViewModel.hostName.isEmpty
                ) {
                    await hardwareViewModel.pair()
                }
                
                Button("Desconectar este celular") {
                    hardwareViewModel.disconnectThisPhone()
                    disconectThisPhone = true
                }
                .padding(.bottom, 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden()
        .task {
            await hardwareViewModel.fetchHostName()
        }
        .alert(
            hardwareViewModel.conectionResult?.title ?? "",
            isPresented: Binding(
                get: { hardwareViewModel.conectionResult != nil },
                set: { if !$0 { hardwareViewModel.conectionResult = nil } }
            ),
            presenting: hardwareViewModel.conectionResult
        ) { result in
            Button("Voltar", role: .cancel) {
                if result == .success { onClose() }
            }
        } message: { result in
            Text(result.message)
        }
        .dismissKeyboardOnTap()
        
        .alert("Celular desconectado.", isPresented: $disconectThisPhone) {
            Button("OK") { onClose() }
        } message: {
            Text("Seu celular foi desconectado com sucesso!")
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
