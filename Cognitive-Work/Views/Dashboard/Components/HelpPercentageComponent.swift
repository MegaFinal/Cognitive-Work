//
//  HelperPercentageComponent.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 01/10/26.
//

import SwiftUI

struct HelpPercentageComponent: View {
    var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: - Base text
            Text("Divisão da casa")
                .font(.title2.bold())
                
            Text("O trabalho de notar, lembrar, decidir e acompanhar é tão importante quanto realizar uma tarefa")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            
            // MARK: Percentage
            HStack(spacing: 8) {
                Text(viewModel.myCognitiveShareText)
                    .font(.system(size: self.height * 0.1, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("do esforço mental da casa esta semana foi seu")
                    .font(.body)
            }
            
            // MARK: - Your contribuition bar
            ZStack(alignment: .leading) {
                
                // base bar
                Capsule()
                    .frame(width: self.width * 0.87, height: self.height * 0.03)
                    .foregroundStyle(Color.gray.opacity(0.2))
                
                // your contribuition bar
                Capsule()
                    .frame(width: self.width * 0.87 * CGFloat(viewModel.myCognitiveShare), height: self.height * 0.03)
                    .foregroundStyle(Color.blue)
                
                // MARK: - Expected contribution average
                VStack(alignment: .center, spacing: 8) {
                    Capsule()
                        .frame(width: 3, height: self.height * 0.045)
                    
                    Text("ideal \(viewModel.idealCognitiveShareText)")
                        .font(.caption2)
                        .offset(y: -6)
                }
                
                .foregroundStyle(.black)
                .offset(x: self.width * 0.87 * CGFloat(viewModel.idealCognitiveShare) - 1, y: 0)
            }
            .frame(height: self.height * 0.05)
            
            // MARK: - Card caption
            HStack(spacing: 16) {
                Label("você", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Label("resto da casa", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    HelpPercentageComponent(viewModel: DashboardViewModel())
}
