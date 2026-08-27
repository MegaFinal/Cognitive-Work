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
    
    @State private var viewModel = FortnightlyViewModel()
    
    init(house: HouseModel?, viewModel: FortnightlyViewModel = FortnightlyViewModel()) {
            self.house = house
            _viewModel = State(wrappedValue: viewModel)
        }
    
    var body: some View {
        VStack{
            OnboardingHeader(
                title: "Escala quinzenal",
                description: description
            )
            .padding(.bottom)
//            ScrollView{
                FortnightlyChart(viewModel: viewModel, house: house)
//            }
            Spacer()
        }
    }
}

#Preview {
    let previewVM = FortnightlyViewModel()
    previewVM.loadMockData()
    
    return FortnightlyView(house: nil, viewModel: previewVM)
}
