//
//  RetroPercentageOfDoneView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct RetroPercentageOfDoneView: View {
    @Binding var page: Int
    @Binding var isRetroDone: Bool
    var completedChores: Int = 0
    var totalChores: Int = 20
    @State var percentage: Double = 0.0

    private var targetPercentage: Double {
        guard totalChores > 0 else { return 0 }
        return min(max(Double(completedChores) / Double(totalChores) * 100, 0), 100)
    }

    var body: some View {
        ZStack {
            Color(.chorePurple)
                .overlay{
                    PieSlice(progress: percentage / 100)
                        .padding(.bottom, height * 0.127)
                        .frame(width: height * 2, height: height * 2)
                        .ignoresSafeArea()
                        .foregroundStyle(.white)
                }
                .ignoresSafeArea()

            VStack{
                Keyhole()
                    .aspectRatio(width * 0.8 / height * 1.5, contentMode: .fit)
                    .padding(.top, height * 0.24)
                    .foregroundStyle(.white)
                
            }
                

            VStack {
                Spacer ()
                
                AnimatedPercentageText(value: percentage)
                    .bold()
                    .font(.system(size: 64))
                    .padding(.bottom, height * 0.03)
                
                Text("Você realizou \(completedChores) de \(totalChores) \n tarefas da sua escala")
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
                
                Button {
                    withAnimation {
                        isRetroDone = true
                    }
                } label: {
                    Text("ver depois")
                        .fontWeight(.semibold)
                        .font(.subheadline)
                        .foregroundStyle(.subTitleGray) //Arrumar depois a cor
                }
                .padding(.bottom, height * 0.014)
                
                Button {
                    withAnimation {
                        page += 1
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            percentage = 0
            withAnimation(.easeInOut(duration: 2).delay(0.3)) {
                percentage = targetPercentage
            }
        }
    }
}


#Preview("0%") {
    @Previewable @State var page = 0
    @Previewable @State var isRetroDone = false
    RetroPercentageOfDoneView(page: $page, isRetroDone: $isRetroDone)
}

#Preview("25%") {
    @Previewable @State var page = 0
    @Previewable @State var isRetroDone = false
    RetroPercentageOfDoneView(page: $page, isRetroDone: $isRetroDone, completedChores: 25, totalChores: 100)
}

#Preview("50%") {
    @Previewable @State var page = 0
    @Previewable @State var isRetroDone = false
    RetroPercentageOfDoneView(page: $page, isRetroDone: $isRetroDone, completedChores: 50, totalChores: 100)
}

#Preview("75%") {
    @Previewable @State var page = 0
    @Previewable @State var isRetroDone = false
    RetroPercentageOfDoneView(page: $page, isRetroDone: $isRetroDone, completedChores: 75, totalChores: 100)
}

#Preview("100%") {
    @Previewable @State var page = 0
    @Previewable @State var isRetroDone = false
    RetroPercentageOfDoneView(page: $page, isRetroDone: $isRetroDone, completedChores: 100, totalChores: 100)
}
