//
//  NotificationsView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 30/09/26.
//

import SwiftUI

struct NotificationsView: View {
    var body: some View {
        NavigationStack {
            // MARK: - Header, progress cards and action buttons
            VStack(spacing: 3) {
                VStack(spacing: 15) {
                    header
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Page title.
    private var header: some View {
        HStack {
            Text("Notificações")
                .font(.system(size: 34))
                .fontWeight(.bold)
                .padding(.horizontal, 30)
                .padding(.top, 20)
            
            Spacer()
        }
    }
}

#Preview {
    NotificationsView()
}
