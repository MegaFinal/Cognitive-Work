//
//  WalcomeAnimatedOnboardingView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 02/10/26.
//

import SwiftUI
import Foundation

/// The animated background of the welcome screen.
struct WelcomeAnimatedOnboardingView: View{
    @Binding var viewModel: OnboardingViewModel
    
    @State var showSheet: Bool = false
    
    /// Mock columns, built only once since ``ChoreDTO`` is a class.
    private let columns = ChoreDTO.columnsMock
    
    /// Speed of each column, in points per second.
    private static let speeds: [Double] = [17, 19, 17, 19]
    
    /// Starting offset of each column, in points. A card plus its spacing is 186pt.
    private static let phases: [Double] = [93, 40, 0, 40]
    
    var body: some View {
        ZStack {
            Color(.onboardingBackground)
            
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns.indices, id: \.self) { index in
                    InfinityRow(cards: columns[index],
                                movesUp: index.isMultiple(of: 2),
                                speed: Self.speeds[index % Self.speeds.count],
                                phase: Self.phases[index % Self.phases.count])
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
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, height * 0.028)
                        .padding(.top, height * 0.052)
                    Text("Cuidar da casa também é lembrar e perceber o que falta. O Pipa organiza as tarefas e reconhece o trabalho de todos.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, height * 0.028)
                    
                    Text("Pipa. Para aqueles que notam.")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(.horizontal, height * 0.028)
                .padding(.bottom, height * 0.15)
                .frame(width: width)
                .frame(minHeight: height * 0.6, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
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
