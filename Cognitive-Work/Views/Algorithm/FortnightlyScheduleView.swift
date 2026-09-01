//
//  FortnightlySchedule.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 28/08/26.
//

import SwiftUI

// View principal da escala, quando estiver carregando, aparecer WaitingAlgorithmView e quando rodar, aparever a FortinightlyView

struct FortnightlyScheduleView: View {
    @State private var scheduleViewModel = FortnightlyScheduleViewModel()
    
    let action: () -> Void
    var body: some View {
        Group {
            if scheduleViewModel.isLoading {
                WaitingAlgorithmView()
            } else {
                FortnightlyView(users: scheduleViewModel.users, chores: scheduleViewModel.chores)
                    .overlay(alignment: .topTrailing) {
                        OnboardingProgressButton(width: 50.0, height: 50.0, text: "xmark", isSystemImage: true) {
                            action()
                        }
                        .padding(10)
                    }
            }
        }
        .task {
            print("Chegou na view")
            await scheduleViewModel.generateSchedule()
        }
    }
}

#Preview {
    FortnightlyScheduleView() {
        print("Action")
    }
}


