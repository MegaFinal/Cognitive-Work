//
//  RetroView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

struct RetroView: View {
    @State var isExpanded: Bool = false
    @State var isRetroDone: Bool = false
    @State var page = 0
    
    /// Called when the user confirms the new chore division (check button of the schedule screen).
    var onFinish: () -> Void = {}
    
    // "Divisão automática de tarefas": the white card expands to fill the screen
    // (same animation as the RetroAlert), then the schedule screen fades in.
    @State private var showSchedule = false
    
    // "Ver minha retrospectiva": same idea. The card expands with the alert still on it,
    // then the retro pages fade in.
    @State private var showPages = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }
            
            RoundedRectangle(cornerRadius: 32)
                // Real sizes (not .infinity), so SwiftUI can interpolate the size in both directions.
                .frame(width: isExpanded ? width : width * 0.87, height: isExpanded ? height : height * 0.59)
                .foregroundStyle(.white)
                .ignoresSafeArea()
                .overlay {
                    if !showPages && !isRetroDone {
                        RetroAlert(isExpanded: $isExpanded)
                            .transition(.opacity)
                    }
                    else if showPages && !isRetroDone {
                        VStack(spacing: 12){
                            TabView(selection: $page) {
                                RetroPercentageOfDoneView(page: $page, isRetroDone: $isRetroDone)
                                    .tag(0)
                                RetroStreakView(page: $page, isRetroDone: $isRetroDone)
                                    .tag(1)
                                RetroPointsView(page: $page, isRetroDone: $isRetroDone)
                                    .tag(2)
                                RetroRoomsView(isExpanded: $isExpanded, isRetroDone: $isRetroDone, isActive: page == 3)
                                    .tag(3)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            
                            PageIndicator(count: 4, current: $page)
                        }
                        .transition(.opacity)
                    }
                    else if isRetroDone {
                        RetroNewChoresDivision {
                            startAutomaticDivision()
                        }
                    }
                }
            
            if showSchedule {
                NavigationStack {
                    FortnightlyScheduleView(shouldGenerate: true) {
                        onFinish()
                    }
                }
                .background(Color(.systemBackground).ignoresSafeArea())
                .transition(.opacity)
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            guard expanded, !isRetroDone, !showPages else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.easeInOut(duration: 0.3)) {
                    showPages = true
                }
            }
        }
    }
    
    private func startAutomaticDivision() {
        guard !isExpanded else { return }
        withAnimation {
            isExpanded = true
        }
        Task {
            try? await Task.sleep(for: .seconds(0.01))
            withAnimation(.easeInOut(duration: 0.01)) {
                showSchedule = true
            }
        }
    }
}


#Preview {
    RetroView()
}
