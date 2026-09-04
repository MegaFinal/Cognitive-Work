//
//  ExistingIPView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 02/09/26.
//

import SwiftUI

struct ExistingIPView: View {
    @Binding var viewModelHardware: HardwareViewModel
    
    var profileImage: UIImage?
    
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            
            Button {
                print("Botão Parear clicado! IP atual: \(viewModelHardware.deviceIP)")
                
                if !viewModelHardware.deviceIP.isEmpty {
                    Task {
                        do {
                            let connected = try await viewModelHardware.askForParingCode()
                            print("Resultado do pareamento: \(connected)")
                            if !connected {
                                errorMessage = "Não foi possível parear com o dispositivo."
                            }
                        } catch {
                            print("Erro no pareamento: \(error.localizedDescription)")
                            errorMessage = error.localizedDescription
                        }
                    }
                } else {
                    errorMessage = "IP do dispositivo não encontrado."
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: 100, height: 44)
                        .foregroundStyle(.indigo)
                    Text("Parear")
                        .foregroundStyle(.white)
                        .font(.title2)
                }
            }
            .padding(.bottom, 20)
            
            
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
            
            Button {
                Task {
                    await viewModelHardware.deleteIp()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: 150, height: 44)
                        .foregroundStyle(.orange)
                    Text("Delete Ip")
                        .foregroundStyle(.white)
                        .padding()
                }
            }
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
