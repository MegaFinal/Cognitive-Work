//
//  FortnightlySchedule.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 28/08/26.
//

import SwiftUI

// View principal da escala, quando estiver carregando, aparecer WaitingAlgorithmView e quando rodar, aparever a FortinightlyView

struct FortnightlyScheduleView: View {
    @Environment(OnboardingViewModel.self) var viewModel

    @State private var scheduleViewModel = FortnightlyScheduleViewModel()

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        Group {
            if scheduleViewModel.isLoading {
                WaitingAlgorithmView()
            } else {
                FortnightlyView(users: scheduleViewModel.users, chores: scheduleViewModel.chores)
            }
        }
        
        .task {
            await scheduleViewModel.generateSchedule()
        }
        .onAppear{
        }
    }
}

#Preview {
    FortnightlyScheduleView()
}


