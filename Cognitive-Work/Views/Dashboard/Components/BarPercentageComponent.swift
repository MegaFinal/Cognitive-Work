//
//  BarPercentageComponent.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 01/10/26.
//

import SwiftUI

struct BarPercentageComponent: View {
    @State var viewModel: DashboardViewModel
    
    // Temporary visualization for unowned chores.
    // This will be replaced when the pending chores section is finalized.
    let isUnassignedChores: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isUnassignedChores {
                unownedChoresContent
            } else {
                cognitiveLoadContent
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .frame(width: width - 32, alignment: .leading)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }
    
    // MARK: - Cognitive Load
    
    private var cognitiveLoadContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text("Divisão da casa")
                .font(.title2.bold())
            
            Text("O trabalho de notar, lembrar, decidir e acompanhar é tão importante quanto realizar uma tarefa")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            myContribuitionPercentage
            
            ZStack(alignment: .leading) {
                
                baseBarChart
                
                myContributionChart
                
                // if the "ideal division is 0", don't show the line
                if viewModel.idealCognitiveShare > 0 {
                    averageLine
                }
            }
            .frame(height: height * 0.05)
            
            HStack(spacing: 16) {
                caption("Você", myContributionColor)
                caption("Resto da casa", .gray.opacity(0.4))
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Unowned Chores
    // TODO: Temporary visualization. Replace this layout when the pending chores section is finalized.
    
    private var unownedChoresContent: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            HStack(alignment: .top, spacing: 12) {
                Text("\(viewModel.unownedPublicCount)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tarefas sem dono")
                        .font(.title2.bold())
                    
                    Text("O trabalho de notar, lembrar e distribuir tarefas também faz parte da organização da casa")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            ZStack(alignment: .leading) {
                baseBarChart
                unassignedChoresChart
            }
            .frame(height: height * 0.05)
            
            HStack(spacing: 16) {
                caption("tarefas sem dono", .orange)
                caption("tarefas de moradores", .gray.opacity(0.2))
            }
            .padding(.top, 4)
        }
    }
    
    
    // MARK: - Charts
    
    private var baseBarChart: some View {
        Capsule()
            .frame(width: width * 0.85, height: height * 0.03)
            .foregroundStyle(Color(.systemGray5).opacity(0.8))
    }
    
    // Temporary chart for unowned chores.
    private var unassignedChoresChart: some View {
        
        Capsule()
            .frame(
                width: width * 0.87
                * CGFloat(viewModel.unownedPublicProgress),
                height: height * 0.03
            )
            .foregroundStyle(.orange)
    }
    
    // MARK: - Charts Cognive workload
    
    private var myContributionColor: Color {
        let share = viewModel.myCognitiveShare
        let ideal = viewModel.idealCognitiveShare
        let lowerBound = ideal * 1.0
        let upperBound = ideal * 1.2
        
        if share < ideal * 0.5 {
            return .choreOrange
        } else if share < ideal {
            return .choreYellow
        } else if share >= lowerBound && share <= upperBound {
            return .choreGreen
        } else if share > upperBound && share <= ideal * 1.5 {
            return .choreBlue
        } else if share > ideal * 0.5 {
            return .chorePurple
        }
        else {
            return .gray
        }
    }
    
    private var myContributionChart: some View {
        Capsule()
            .frame(width: width * 0.87 * CGFloat(viewModel.myCognitiveShare), height: height * 0.03)
            .foregroundStyle(myContributionColor)
    }
    
    private var myContribuitionPercentage: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(viewModel.myCognitiveShareText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("do esforço mental da casa esta semana foi seu")
                .font(.body)
        }
        .frame(width: width * 0.87)
    }
    
    // MARK: - Expected contribution average as separate positioned views
    private var averageLine: some View {
        VStack {
            let barWidth = width * 0.87
            let idealX = barWidth * CGFloat(viewModel.idealCognitiveShare)
            
            Capsule()
                .frame(width: 3, height: height * 0.045)
                .foregroundStyle(Color.black.opacity(0.8))
                .position(x: idealX, y: (height * 0.05)/2)
            
            Text("ideal \(viewModel.idealCognitiveShareText)")
                .font(.caption2)
                .foregroundStyle(.black.opacity(0.8))
                .position(x: idealX, y: (height * 0.01) + (height * 0.018))
        }
    }
    
    // MARK: - Chart Caption
    
    private func caption(_ text: String,_ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .frame(width: width * 0.03)
                .foregroundStyle(color)
            
            Text(text)
                .font(.caption)
        }
    }
    
}

#Preview {
    let viewModel = DashboardViewModel()
    viewModel.myCognitiveShare = 0.5
    viewModel.idealCognitiveShare = 0.4
    viewModel.myCognitiveShareText = "15%"
    viewModel.idealCognitiveShareText = "50%"
    
    return BarPercentageComponent(viewModel: viewModel, isUnassignedChores: false)
}

