//
//  ExistingIPView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 02/09/26.
//

import SwiftUI

struct ExistingIPView: View {
    @Binding var viewModelHardware: HardwareViewModel
    
    var image: UIImage?
    
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
            }.padding(.bottom, 20)
             
            profileImage
             
            Button {
                Task {
                    do {
                        guard let image = image else {
                            errorMessage = "Nenhuma imagem selecionada para enviar."
                            return
                        }
                        try await viewModelHardware.prepareImageForESP32(imageUI: image)
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
     
    private var profileImage: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .background(Color(.systemBackground))
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 65))
                            .foregroundStyle(.gray)
                    }
            }
        }
        .clipShape(Circle())
        .shadow(radius: 5)
    }
}
