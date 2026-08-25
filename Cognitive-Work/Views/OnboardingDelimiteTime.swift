//
//  OnboardingDelimiteTime.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 20/08/26.
//

import SwiftUI

@Observable
class DayOfWeekDTO {
    let name: String
    let nameAbbreviation: String
    var freeTime: FreeTimeEnum = .none
    
    init(name: String, nameAbbreviation: String) {
        self.name = name
        self.nameAbbreviation = nameAbbreviation
    }
}

enum FreeTimeEnum: String{
    case none = ""
    case thirtyMinutes = "Até 30 minutos"
    case oneHour = "Até 1 hora"
    case twoHours = "Até 2 horas"
    case threeHours = "Até 3 horas"
    case fourHours = "Até 4 horas"
    case fiveHours = "5 horas ou mais"
    
    var timeInHours: Double {
        switch self {
        case .none:
            return 0.0
        case .thirtyMinutes:
            return 0.5
        case .oneHour:
            return 1.0
        case .twoHours:
            return 2.0
        case .threeHours:
            return 3.0
        case .fourHours:
            return 4.0
        case .fiveHours:
            return 5.0
        }
    }
    
    init(_ num: Int) {
        switch num {
        case 0 :
            self = .none
        case 1 :
            self = .thirtyMinutes
        case 2 :
            self = .oneHour
        case 3 :
            self = .twoHours
        case 4 :
            self = .threeHours
        case 5 :
            self = .fourHours
        case 6 :
            self = .fiveHours
        default:
            self = .none
        }
    }
}

struct OnboardingDelimiteTime: View {
    @State var weekOrder = [
        DayOfWeekDTO(name: "Segunda - Feira", nameAbbreviation: "Seg"),
        DayOfWeekDTO(name: "Terça - Feira", nameAbbreviation:"Ter"),
        DayOfWeekDTO(name: "Quarta - Feira", nameAbbreviation: "Qua"),
        DayOfWeekDTO(name: "Quinta - Feira", nameAbbreviation: "Qui"),
        DayOfWeekDTO(name: "Sexta - Feira", nameAbbreviation:"Sex"),
        DayOfWeekDTO(name: "Sabado -", nameAbbreviation: "Sab"),
        DayOfWeekDTO(name: "Domingo -",nameAbbreviation: "Dom")
    ]
    
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
                    .padding(.bottom, 10)
                
                Text("Defina seu tempo disponível para realizar tarefas domésticas durante a semana")
                    .bold()
                    .font(.system(size: 16))
                    .foregroundStyle(.subTitleGray)
                
                HStack(spacing: width * 0.073) {
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
                
                ForEach($weekOrder, id: \.name) { $day in
                    OnboardingCustomSliderComponent(dayOfWeek: $day, width: width)
                }
                HStack {
                    Spacer()
                    Button {
                        // TODO ação: avançar e salvar
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.accentColor, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }

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
    @Binding var dayOfWeek: DayOfWeekDTO
    @State var rating: Int = 0
    
    let width: CGFloat
    var body: some View {
            HStack(spacing: width * 0.03) {
                Text(dayOfWeek.nameAbbreviation)
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .frame(width: width * 0.091, alignment: .leading)

                VStack {
                   FreeTimeSlider(rating: $rating)
                    HStack {
                        Text(dayOfWeek.name)
                            .font(.system(size: 14))
                            .fontWeight(.medium)
                        Text(dayOfWeek.freeTime.rawValue)
                            .font(.system(size: 14))
                            .fontWeight(.light)
                        Spacer()
                    }
                    .foregroundStyle(.delimiteTimeTextComponent)
                }
            }
            .onChange(of: rating) {
                dayOfWeek.freeTime = FreeTimeEnum(rating)
            }
        }
    }


struct FreeTimeSlider: View {
    @Binding var rating: Int
    var maxRating: Int = 6
    var squareSize: CGFloat = 38
    var activeColor: Color = .delimiteTimeSelectedSquareComponent
    var inactiveColor: Color = .delimiteTimeSquareComponent
    var spacing: CGFloat = 12
    
    var body: some View {
        GeometryReader { geometry in
            
            ZStack(alignment: .leading) {
                RectangleView(color: inactiveColor)
                
                RectangleView(color: activeColor)
                    .mask(
                        Rectangle()
                            .size(
                                width: rating < 6 ?
                                    geometry.size.width * CGFloat(Double(rating) / Double(maxRating)) :
                                    geometry.size.width + 4.0,
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
        .frame(maxWidth: CGFloat(maxRating) * squareSize + spacing * CGFloat(maxRating - 1),maxHeight: squareSize)
    }
    
    private func RectangleView(color: Color) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<maxRating, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .frame(width: squareSize, height: squareSize)
                    .foregroundColor(color)
            }
        }
    }
    
    private func updateRating(with xPosition: CGFloat, in totalWidth: CGFloat) {
        let percentage = xPosition / totalWidth
        let rawRating = percentage * Double(maxRating)
        
        let calculatedRating = Int(ceil(rawRating))
        
        rating = max(0, min(maxRating, calculatedRating))
        print(rating)
    }
}
