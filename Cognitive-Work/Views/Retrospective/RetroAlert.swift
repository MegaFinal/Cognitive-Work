//
//  RetroAlert.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct Retro: View {
    @State var isExpanded: Bool = false
    @State var percentage: Double = 0.0
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }
            
            RoundedRectangle(cornerRadius: 32)
                .frame(width: isExpanded ? .infinity : width * 0.87, height: isExpanded ? .infinity : height * 0.59)
                .foregroundStyle(.white)
                .ignoresSafeArea()
                .overlay {
                    if !isExpanded {
                        RetroAlert(isExpanded: $isExpanded)
                    } else {
                        ZStack {
                            
                            VStack {
                                Spacer ()
                                
                                Text("\(String(format: "%.0f", percentage))%")
                                    .bold()
                                    .font(.system(size: 64))
                                    .padding(.bottom, height * 0.03)
                                
                                Text("Você realizou 0 de 20 \n tarefas da sua escala")
                                    .font(.title)
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom, height * 0.008)
                                
                                Text("Vamos tentar de novo na próxima")
                                    .font(.callout)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.subTitleGray) //Arrumar depois a cor
                                
                                Spacer()
                                
                                Text("você consegue!")
                                    .bold()
                                    .font(.system(size: 40))
                                    .padding(.bottom, height * 0.018)
                                
                                Text("ver depois")
                                    .fontWeight(.semibold)
                                    .font(.subheadline)
                                    .foregroundStyle(.subTitleGray) //Arrumar depois a cor
                                    .padding(.bottom, height * 0.014)
                                
                                Button {
                                    withAnimation {
                                        isExpanded.toggle()
                                    }
                                } label: {
                                    Text("Continuar")
                                        .frame(width: width * 0.69, height: height * 0.037)
                                        .fontWeight(.medium)
                                        .font(.system(size: 17))
                                }
                                .buttonStyle(.glassProminent)
                                .glassEffectTransition(.identity)
                            }
                        }
                    }
                    
                }
        }
    }
}

private struct RetroAlert: View {
    @Binding var isExpanded: Bool
    var body: some View {
        VStack {
            Image(systemName: "chart.bar.xaxis")
                .resizable()
                .frame(width: width * 0.27, height: height * 0.089)
                .foregroundStyle(.choreYellow)
                .padding(.bottom, height * 0.05)
            
            Text("Sua retrospectiva chegou!")
                .bold()
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding(.bottom, height * 0.018)
            
            Text("Veja como você se saiu durante os últimos 15 dias")
                .font(.title2)
                .multilineTextAlignment(.center)
                .fontWeight(.regular)
                .padding(.bottom, height * 0.037)
            
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Text("Ver minha retrospectiva")
                        .frame(width: width * 0.69, height: height * 0.037)
                        .fontWeight(.medium)
                        .font(.system(size: 17))
                }
                .buttonStyle(.glassProminent)
                .glassEffectTransition(.identity)

                Button {

                } label: {
                    Text("Pular para a nova divisão")
                        .frame(width: width * 0.69, height: height * 0.037)
                        .fontWeight(.medium)
                        .font(.system(size: 17))
                }
                .buttonStyle(.glass)
        
        }
    }
}

#Preview {
    Retro()
}
