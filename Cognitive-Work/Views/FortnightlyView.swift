//
//  FortnightlyView.swift
//  Cognitive-Work
//
//  Created by anshu Li on 26/08/26.
//

import SwiftUI

struct FortnightlyView: View {
    let description: String = """
        Dividimos as tarefas escolhidas pelos moradores pensando nas cargas horárias que cada um tem disponível.
        Clique nas tarefas para saber mais.
        """

    var body: some View {
        VStack{
            OnboardingHeader(
                title: "Escala quinzenal",
                description: description
            )
            .padding(.bottom)
//            ScrollView{
                FortnightlyChart()
//            }
            Spacer()
        }
    }
}

#Preview {
    return FortnightlyView()
}
