//
//  HelperPercentageComponent.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 01/10/26.
//

import SwiftUI

struct HelpPercentageComponent: View {
    @State var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: - Base text
            Text("Divisão da casa")
                .font(.title2.bold())
            
            Text("O trabalho de notar, lembrar, decidir e acompanhar é tão importante quanto realizar uma tarefa")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // MARK: Percentage
            myContribuitionPercentage
            
            // MARK: - Your contribuition bar
            ZStack(alignment: .leading) {
                
                let barWidth = width * 0.87
                let idealX = barWidth * CGFloat(viewModel.idealCognitiveShare)
                
                // base bar chart
                baseBarChart
                
                // your contribuition bar
                myContributionChart
                
                // MARK: - Expected contribution average as separate positioned views
                Capsule()
                    .frame(width: 3, height: height * 0.045)
                    .foregroundStyle(Color.black.opacity(0.8))
                    .position(x: idealX, y: (height * 0.03)/2)
                
                Text("ideal \(viewModel.idealCognitiveShareText)")
                    .font(.caption2)
                    .foregroundStyle(.black.opacity(0.8))
                    .position(x: idealX, y: (height * 0.03) + (height * 0.018))
            }
            .frame(height: height * 0.05)
            
            // MARK: - Card caption
            HStack(spacing: 16) {
                caption("Você")
                caption("Resto da casa")
            }
            .padding(.top, 4)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        
    }
    
    private var baseBarChart: some View {
        Capsule()
            .frame(width: width * 0.87, height: height * 0.03)
            .foregroundStyle(Color.gray.opacity(0.2))
    }
    
    private var myContributionColor: Color {
        let share = viewModel.myCognitiveShare
        let ideal = viewModel.idealCognitiveShare
        let lowerBound = ideal * 0.9
        let upperBound = ideal * 1.1
        
        if share < ideal * 0.5 {
            return .orange
        } else if share < ideal {
            return .yellow
        } else if share >= lowerBound && share <= upperBound {
            return .green
        } else if share > upperBound && share <= ideal * 1.5 {
            return .blue
        } else {
            return .purple
        }
    }
    
    private var myContributionChart: some View {
        Capsule()
            .frame(width: width * 0.87 * CGFloat(viewModel.myCognitiveShare), height: height * 0.03)
            .foregroundStyle(myContributionColor)
    }
    
    private var myContribuitionPercentage: some View {
        HStack(spacing: 8) {
            Text(viewModel.myCognitiveShareText)
                .font(.system(size: height * 0.08, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("do esforço mental da casa esta semana foi seu")
                .font(.body)
        }
        .frame(width: width * 0.95)
    }
    
    private func caption(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .frame(width: width * 0.03)
                .foregroundStyle(Color.choreOrange)

            Text(text)
                .font(.caption)
        }
    }
    
}

#Preview {
    let viewModel = DashboardViewModel()
    viewModel.myCognitiveShare = 0.15
    viewModel.idealCognitiveShare = 0.5
    viewModel.myCognitiveShareText = "15%"
    viewModel.idealCognitiveShareText = "40%"
    return HelpPercentageComponent(viewModel: viewModel)
}

