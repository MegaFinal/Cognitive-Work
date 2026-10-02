//
//  WalcomeAnimatedOnboardingView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 02/10/26.
//

import SwiftUI
import Foundation

/// The animated background of the welcome screen.
///
/// Shows columns of chore cards scrolling in alternating directions:
/// even columns move up and odd columns move down, each one slightly
/// out of phase so neighboring columns never line up.
struct WelcomeAnimatedOnboardingView: View{
    @Binding var viewModel: OnboardingViewModel
    
    @State var showSheet: Bool = false
    
    /// Mock columns, built only once since ``ChoreDTO`` is a class.
    private let columns = ChoreDTO.colunasMock
    
    var body: some View {
        ZStack {
            Color(.onboardingBackground)
            
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns.indices, id: \.self) { index in
                    InfinityRow(cards: columns[index],
                                movesUp: index.isMultiple(of: 2),
                                phase: Double(index) * 60)
                    .frame(width: 110)
                }
            }
            .frame(width: width, height: height, alignment: .top)
            .clipped()
            
            if showSheet {
                
                VStack(alignment: .leading){
                    Text("Dividir a casa vai além da faxina")
                        .bold()
                        .font(.largeTitle)
                        .padding(.bottom, height * 0.028)
                        .padding(.top, height * 0.052)
                    Text("Cuidar da casa também é lembrar e perceber o que falta. O Pipa organiza as tarefas e reconhece o trabalho de todos.")
                        .font(.body)
                        .padding(.bottom, height * 0.028)
                    
                    Text("Pipa. Para aqueles que notam.")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding(.horizontal, height * 0.028)
                .frame(width: width, height: height * 0.6)
                .background(Color.white)
                .clipShape (
                    UnevenRoundedRectangle(topLeadingRadius: 32,topTrailingRadius: 32,style: .continuous)
                )
                .overlay(alignment: .bottomTrailing) {
                    
                    Button("Continuar", systemImage: "chevron.right") {
                        viewModel.goToNextView()
                    }
                    .bold()
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .padding(.bottom, height * 0.073)
                    .padding(.trailing, width * 0.061)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1)) {
                showSheet = true
            }
        }
        .transition(.move(edge: .bottom))
        .ignoresSafeArea()
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    WelcomeAnimatedOnboardingView(viewModel: $viewModel)
}
