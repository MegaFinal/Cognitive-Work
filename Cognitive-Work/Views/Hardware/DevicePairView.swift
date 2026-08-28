//
//  DevicePairView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

struct DevicePairView: View {
    @Bindable var viewModel: WifiConnectionViewModel
    let image1 = UIImage(named: "fish")
    let image2 = UIImage(named: "emoji")
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        VStack(spacing: 0) {
            Text("Pareie seu celular!")
                .font(.title3)
                .bold()
                .padding(.bottom, 20)
            TextField("IP do device", text: $viewModel.deviceIP)
                .frame(width: 300, height: 44)
                .textFieldStyle(.roundedBorder)
                .padding()
            Button {
                if viewModel.deviceIP != "" {
                    Task {
                        try await viewModel.askForParingCode()
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: 100, height: 44)
                        .foregroundStyle(.indigo)
                    Text("Parear")
                        .frame(width: 150, height: 44)
                        .foregroundStyle(.white)
                        .font(.title2)
                }
            }.padding(.bottom, 20)
            
            VStack{
                Divider()
                BarChartView(
                    values: [0.4, 0.9, 0.6, 0.3, 0.7],
                    labels: ["Seg", "Ter", "Qua", "Qui", "Sex"],
                    title: "Tarefa da semana"
                )
                
                Button {
                    Task {
                        try await viewModel.sendChartToESP32(
                            values: [0.4, 0.9, 0.6, 0.3, 0.7],
                            labels: ["Seg", "Ter", "Qua", "Qui", "Sex"],
                            title: "Tarefas da semana"
                        )
                    }
                } label: {
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width: 150, height: 44)
                            .foregroundStyle(.orange)
                        Text("Enviar gráfico")
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    DevicePairView(viewModel: WifiConnectionViewModel())
}
