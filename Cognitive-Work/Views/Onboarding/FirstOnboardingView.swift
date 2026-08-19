//
//  FirstOnboardingView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

struct FirstOnboardingView: View {
    @State private var isExpanded = false
    @State private var isSwipeVisible = false
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Image("houseHouse")
                    .resizable()
                    .frame(width: width * 0.7, height: height * 0.32)
                
                ZStack(alignment: .top) {
                    if !isExpanded {
                        Text("Seu facilitador de organização doméstica!")
                            .foregroundColor(.gray)
                            .font(.title2)
                            .frame(width: width * 0.7)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                        
                    } else {
                        OnboardingAppDescription()
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: isExpanded ? .top : .center)
            .ignoresSafeArea(edges: isExpanded ? .top : [])
            .padding(.top, 5)
            
            if isSwipeVisible {
                OnboardingSwipeIndicator()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -50 && !isExpanded {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            isExpanded = true
                            isSwipeVisible = false
                        }
                    }
                }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if !isExpanded {
                    withAnimation(.easeIn(duration: 0.8)) {
                        isSwipeVisible = true
                    }
                }
            }
        }
    }
}

#Preview {
    FirstOnboardingView()
}
