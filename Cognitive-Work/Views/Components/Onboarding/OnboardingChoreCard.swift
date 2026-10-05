//
//  OnboardingChoreCard.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 02/10/26.
//

import SwiftUI
import Foundation

struct OnboardingChoreCard: View {
    let chore: ChoreDTO
    
    private var room: RoomDTO { chore.roomDTO }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(chore.name)
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 14)
                .padding(.horizontal, 3)
            
            Spacer(minLength: 8)
            
            Image(systemName: room.symbol)
                .resizable()
                .scaledToFit()
                .fontWeight(.light)
                .frame(width: 72, height: 72)
            
            Spacer(minLength: 12)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoomTextureBackground(color: room.color, pattern: room.texturePattern)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Mock Data

extension ChoreDTO {
    /// Sample chore for the onboarding's animated background.
    static func mock(_ name: String, _ room: DefaultRoomsOnboarding) -> ChoreDTO {
        ChoreDTO(name: name,
                 description: "",
                 frequency: .weekly,
                 duration: 10,
                 priorityTag: .low,
                 room: room.roomDTO)
    }
    
    /// 4 columns with the same chores in different orders, so neighboring columns don't look alike.
    static let colunasMock: [[ChoreDTO]] = {
        let tarefas: [ChoreDTO] = [
            mock("Aspirar a sala", .livingRoom),
            mock("Regar as plantas", .garden),
            mock("Arrumar a cama", .bedroom),
            mock("Lavar o box", .bathroom),
            mock("Tirar o lixo", .kitchen),
            mock("Lavar a roupa", .laundryRoom)
        ]
        return (0..<4).map { coluna in
            tarefas.indices.map { tarefas[($0 + coluna * 2) % tarefas.count] }
        }
    }()
}

#Preview {
    let chore = ChoreDTO()
    OnboardingChoreCard(chore: chore)
}
