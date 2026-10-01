//
//  ScheduleInfoPopUp.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/09/26.
//

import SwiftUI

struct ScheduleInfoPopUp: View {
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("EXPLICAÇÃO")
                    .font(.system(size: 13))
                    .bold()
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                        .fontWeight(.medium)
                        .padding(12)
                        .buttonStyle(.plain)
                        .glassEffect(
                            .regular.interactive(),
                            in: .capsule
                        )
                }
            }
            .padding(.top, 5)
            
            Text("Sua escala está \npronta!")
                .font(.system(size: 28))
                .bold()
            
            Text("Dividimos as tarefas de acordo com o tempo livre de cada morador.")
                .font(.system(size: 16))
                .foregroundColor(.black.opacity(0.55))
            
            
            VStack(alignment: .leading, spacing: 25) {
                HStack(spacing: 18) {
                    Image(systemName: "15.calendar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width * 0.1)
                        .foregroundColor(.choreOrange)
                    
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Vale por 15 dias")
                            .font(.system(size: 18))
                            .bold()
                        
                        Text("Depois desse período, tudo é redistribuído entre vocês.")
                            .font(.system(size: 15))
                    }
                }
                
                HStack(spacing: 22) {
                    Image(systemName: "hand.tap")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width * 0.08)
                        .foregroundColor(.choreYellow)
                    
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Tarefas à pegar")
                            .font(.system(size: 18))
                            .bold()
                        
                        Text("As tarefas que sobraram da divisão ficam na tela inicial, no botão. Pegue as que couberem no seu tempo.")
                            .font(.system(size: 15))
                    }
                    .frame(width: width * 0.6)
                }
                
                HStack(spacing: 11) {
                    Image(systemName: "chart.bar.xaxis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width * 0.11)
                        .foregroundColor(.chorePurple)
                    
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Retrospectiva quinzenal")
                            .font(.system(size: 18))
                            .bold()
                        
                        Text("No fim dos 15 dias você terá uma analise completa de como foram suas atividades.")
                            .font(.system(size: 15))
                    }
                    .frame(width: width * 0.6)
                }
            }
            .padding(.top, 15)
            
            Button {
                onDismiss()
            } label: {
                Text("Ver minha escala")
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .buttonStyle(.plain)
                    .glassEffect(
                        .regular.interactive().tint(.blue),
                        in: .capsule
                    )
            }
            .padding(.top, 15)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(width: width * 0.87)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 3.2, x: 0, y: 4)
        )
    }
}

#Preview {
    ScheduleInfoPopUp(onDismiss: {})
}
