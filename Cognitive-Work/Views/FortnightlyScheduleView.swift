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
    @State private var showInfoPopUp = false
    
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
                    .disabled(showInfoPopUp)
                    .onAppear {
                        showInfoPopUp = true
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { infoPopUpOverlay }
        .task {
            await scheduleViewModel.loadSchedule(shouldGenerate: shouldGenerate)
        }
    }

    @ViewBuilder
    private var infoPopUpOverlay: some View {
        if showInfoPopUp {
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                
                ScheduleInfoPopUp {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showInfoPopUp = false
                    }
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    FortnightlyScheduleView(shouldGenerate: true) {
        print("Action")
    }
}
