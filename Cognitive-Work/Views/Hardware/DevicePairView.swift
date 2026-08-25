//
//  DevicePairView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

struct DevicePairView: View {
    @Environment(WifiConnectionViewModel.self) var viewModel
    
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
            }
        }
        .padding()
    }
}

#Preview {
    DevicePairView()
}
