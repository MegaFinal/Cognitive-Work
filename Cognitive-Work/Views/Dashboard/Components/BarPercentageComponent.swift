//
//  BarPercentageComponent.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 01/10/26.
//

import SwiftUI

/// A dashboard card with a horizontal bar. It shows one of two things:
/// - The user's share of the house's mental effort, with the ideal share marked on the bar.
/// - How many public chores have no owner yet.
struct BarPercentageComponent: View {
    /// Provides the shares, the counts and their texts.
    @State var viewModel: DashboardViewModel
    
    /// `true` shows the "chores without owner" card; `false` shows the mental effort card.
    ///
    /// The "without owner" layout is temporary and will change when the pending chores section is done.
    let isUnassignedChores: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isUnassignedChores {
                unasingededChoresContent
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
    
    /// The mental effort card: title, the big percentage, the bar and its legend.
    private var cognitiveLoadContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text("Divisão da casa")
                .font(.system(size: 22).bold())
                .accessibilityAddTraits(.isHeader)
            
            Text("O trabalho de notar, lembrar, decidir e acompanhar é tão importante quanto realizar uma tarefa")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            do {
                myContribuitionPercentage
                
                ZStack(alignment: .leading) {
                    baseBarChart
                    myContributionChart
                    
                    // if the "ideal division is 0 or 100%, don't show the line
                    if viewModel.idealCognitiveShare > 0 && viewModel.idealCognitiveShare < 1{
                        averageLine
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height * 0.05)
                // The percentage above already reads the whole bar (value, ideal and status).
                .accessibilityHidden(true)
            }
            
            HStack(spacing: 16) {
                caption("Você", myContributionColor)
                caption("Resto da casa", .gray.opacity(0.4))
            }
            .padding(.top, 4)
            // Color legend only; the bar's VoiceOver value already says whose share it is.
            .accessibilityHidden(true)
        }
    }
    
    // MARK: - Unassigned Chores
    // TODO: Temporary visualization. Replace this layout when the pending chores section is finalized.
    
    /// The "chores without owner" card: the count, the bar and its legend.
    private var unasingededChoresContent: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            HStack(alignment: .top, spacing: 12) {
                Text("\(viewModel.unownedPublicCount)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    // Read by the title below ("3 tarefas sem dono").
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tarefas sem dono")
                        .font(.title2.bold())
                        .voiceOverLabel(L10n.tr("%lld tarefas sem dono", viewModel.unownedPublicCount))
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("O trabalho de notar, lembrar e distribuir tarefas também faz parte da organização da casa")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            do {
                ZStack(alignment: .leading) {
                    baseBarChart
                    unassignedChoresChart
                }
                .frame(maxWidth: .infinity)
                .frame(height: height * 0.05)
                .accessibilityElement(children: .ignore)
                .voiceOverLabel(L10n.tr("Gráfico de tarefas sem dono"))
                .voiceOverValue(viewModel.unownedAccessibilityValue)
            }
            
            HStack(spacing: 16) {
                caption("tarefas sem dono", .orange)
                caption("tarefas de moradores", .gray.opacity(0.2))
            }
            .padding(.top, 4)
            .accessibilityHidden(true)
        }
    }
    
    
    // MARK: - Charts
    
    /// The full gray bar behind the colored one.
    private var baseBarChart: some View {
        Capsule()
            .frame(maxWidth: .infinity)
            .frame(height: height * 0.03)
            .foregroundStyle(Color(.systemGray5).opacity(0.8))
    }
    
    /// The orange part of the bar: the share of public chores without owner (temporary).
    private var unassignedChoresChart: some View {
        
        filledBar(progress: viewModel.unownedPublicProgress, color: .orange)
    }
    
    // MARK: - Charts Cognive workload
    
    /// The color of the user's part, based on how far it is from the ideal share:
    /// orange (much lower), yellow (lower), green (about right), blue (higher), purple (much higher).
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
    
    /// The user's part of the bar.
    private var myContributionChart: some View {
        filledBar(progress: viewModel.myCognitiveShare, color: myContributionColor)
    }
    
    /// A bar that fills `progress` (clamped to 0...1) of the width the card gives it, so it
    /// never goes past the gray bar, even at 100% or more.
    private func filledBar(progress: Double, color: Color) -> some View {
        GeometryReader { proxy in
            Capsule()
                .foregroundStyle(color)
                .frame(width: proxy.size.width * CGFloat(min(max(progress, 0), 1)))
        }
        .frame(height: height * 0.03)
    }
    
    /// The big percentage and its sentence (also read by VoiceOver for the whole bar).
    private var myContribuitionPercentage: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(viewModel.myCognitiveShareText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                // Keeps "100%" on one line: the number shrinks instead of dropping the "%" down.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text("do esforço mental da casa esta semana foi seu")
                .font(.footnote)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // One element for the number and the bar below it:
        // "Sua parte do esforço mental da casa esta semana: 40%, ideal 50%, abaixo do ideal".
        .accessibilityElement(children: .ignore)
        .voiceOverLabel(L10n.tr("Sua parte do esforço mental da casa esta semana"))
        .voiceOverValue(viewModel.cognitiveShareAccessibilityValue)
    }
    
    // MARK: - Ideal share marker
    /// A thin line on the bar at the ideal share, with an "ideal X%" label.
    private var averageLine: some View {
        GeometryReader { proxy in
            let idealX = proxy.size.width * CGFloat(min(max(viewModel.idealCognitiveShare, 0), 1))
            
            Capsule()
                .frame(width: 3, height: height * 0.045)
                .foregroundStyle(Color.black.opacity(0.8))
                .position(x: idealX, y: proxy.size.height / 2)
            
            Text("ideal \(viewModel.idealCognitiveShareText)")
                .font(.caption2)
                .foregroundStyle(.black.opacity(0.8))
                .position(x: idealX, y: (height * 0.01) + (height * 0.018))
        }
    }
    
    
    // MARK: - Chart Caption
    
    /// One legend item: a colored dot and its text.
    private func caption(_ text: LocalizedStringKey, _ color: Color) -> some View {
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
    viewModel.myCognitiveShare = 0.4
    viewModel.idealCognitiveShare = 0.5
    viewModel.myCognitiveShareText = "100%"
    viewModel.idealCognitiveShareText = "50%"
    
    return BarPercentageComponent(viewModel: viewModel, isUnassignedChores: false)
}


#Preview("Divisão da casa – 100%") {
    let viewModel = DashboardViewModel()
    viewModel.myCognitiveShare = 1.0
    viewModel.idealCognitiveShare = 1.0
    viewModel.myCognitiveShareText = "100%"
    viewModel.idealCognitiveShareText = "100%"
    
    return BarPercentageComponent(viewModel: viewModel, isUnassignedChores: false)
}
