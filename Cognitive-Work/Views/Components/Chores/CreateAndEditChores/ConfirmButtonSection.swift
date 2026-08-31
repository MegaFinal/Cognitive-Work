//
//  ConfirmButtonSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

/// A reusable bottom-anchored button for confirming actions, featuring an embedded loading state.
struct ConfirmButtonSection: View {
    
    /// Toggles the replacement of the label text with an indeterminate progress view.
    let isSaving: Bool
    
    /// Disables user interaction and optionally dims the visual state.
    let isDisabled: Bool
    
    var width: CGFloat
    var height: CGFloat
    
    /// The closure to execute upon receiving a tap.
    let action: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            Button {
                action()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Confirmar")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                }
                .frame(width: width * 0.8, height: height * 0.06)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .disabled(isDisabled)
            
            Spacer()
        }
    }
}
