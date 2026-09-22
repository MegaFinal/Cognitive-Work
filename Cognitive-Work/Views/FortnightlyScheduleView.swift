//
//  FortnightlySchedule.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 28/08/26.
//

import SwiftUI

// Main schedule view: display `WaitingAlgorithmView` while loading, and `FortnightlyView` when running.
struct FortnightlyScheduleView: View {
    @State private var scheduleViewModel = ScheduleViewModel()
    
    let shouldGenerate: Bool
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
            await scheduleViewModel.loadSchedule(shouldGenerate: shouldGenerate)
        }
    }
}

#Preview {
    FortnightlyScheduleView(shouldGenerate: true) {
        print("Action")
    }
}
