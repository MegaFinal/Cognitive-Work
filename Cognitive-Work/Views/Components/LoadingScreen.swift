//
//  LoadingScreen.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI

/// Full-screen loading state
struct LoadingScreen: View {
    var title: LocalizedStringKey = "Carregando sua casa..."
    
    @State private var rotation = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            Image("loadingIcon")
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1).speed(0.3).repeatForever(autoreverses: false)) {
                        rotation = 360.0
                    }
                }
            
            Text(title)
                .font(.system(size: 28))
                .bold()
            
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("yellow.sparkles")
                .resizable()
                .opacity(0.2)
                .frame(width: width * 1.6)
                .ignoresSafeArea()
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LoadingScreen()
}
