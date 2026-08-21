//
//  OnboardingDelimiteTime.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 20/08/26.
//

import SwiftUI

struct OnboardingDelimiteTime: View {
    let daysOfWeek: [String : Int] = ["Seg" : 0, "Ter" : 0, "Qua" : 0, "Qui" : 0, "Sex" : 0, "Sab" : 0, "Dom" : 0]
    @State var weekOrder = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sab", "Dom"]
    
    private var sortedDays: [String] {
        let orderIndex = Dictionary(uniqueKeysWithValues: weekOrder.enumerated().map { ($1, $0) })
        return daysOfWeek.keys.sorted {
            orderIndex[$0, default: .max] < orderIndex[$1, default: .max]
        }
    }
    
    @State var currentRating = 0
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            VStack(alignment: .leading) {
                Text("Delimite seu tempo")
                    .bold()
                    .font(.system(size: 32))
                    .foregroundStyle(.titleGray)
                    .padding(.top, height * 0.034)
                
                Text("Defina seu tempo disponível para realizar tarefas domésticas durante a semana")
                    .bold()
                    .font(.system(size: 16))
                    .foregroundStyle(.subTitleGray)
                    .padding(.top, 0.001)
                
                HStack(spacing: 29) {
                    Spacer()
                    Text("30’")
                    Text("1h")
                    Text("2h’")
                    Text("3h’")
                    Text("4h")
                    Text("5h")
                }
                .font(.system(size: 16))
                .fontWeight(.medium)
                .padding(.trailing, 10)
                .padding(.top, height * 0.023)
                
                ForEach(sortedDays, id: \.self) { day in
                    OnboardingCustomSliderComponent(dayOfWeek: day, dayOfWeekAbbreviation: day, width: width, height: height)
                }
            }
            .padding(.horizontal, width * 0.0865)
        }
    }
}

#Preview {
    OnboardingDelimiteTime()
}

struct OnboardingCustomSliderComponent: View {
    @State var rating = 0
    
    let dayOfWeek: String
    let dayOfWeekAbbreviation: String
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        HStack(spacing: width * 0.03) {
            Text(dayOfWeekAbbreviation)
                .font(.system(size: 16))
                .fontWeight(.medium)
            
            VStack {
               CustomSliderComponent(rating: $rating)
                .foregroundStyle(.delimiteTimeSquareComponent)
                HStack {
                    Text("Segunda - Feira")
                        .font(.system(size: 14))
                        .fontWeight(.medium)
                    Spacer()
                }
                .foregroundStyle(.delimiteTimeTextComponent)
            }
        }
    }
}

struct CustomSliderComponent: View {
    @Binding var rating: Int
    var maxRating: Int = 6
    var starSize: CGFloat = 38
    var activeColor: Color = .delimiteTimeSelectedSquareComponent
    var inactiveColor: Color = .delimiteTimeSquareComponent
    var spacing: CGFloat = 12
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                starsView(color: inactiveColor)
                
                starsView(color: activeColor)
                    .mask(
                        Rectangle()
                            .size(
                                width: geometry.size.width * CGFloat(Double(rating) / Double(maxRating)),
                                height: geometry.size.height
                            )
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateRating(with: value.location.x, in: geometry.size.width)
                    }
            )
        }
//        .frame(width: CGFloat(maxRating) * (starSize + spacing), height: starSize)
    }
    
    private func starsView(color: Color) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<maxRating, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .frame(width: starSize, height: starSize)
                    .foregroundColor(color)
            }
        }
    }
    
    private func updateRating(with xPosition: CGFloat, in totalWidth: CGFloat) {
        let percentage = xPosition / totalWidth
        let rawRating = percentage * Double(maxRating)
        
        let calculatedRating = Int(ceil(rawRating))
        
        rating = max(0, min(maxRating, calculatedRating))
    }
}
