//
//  ConfirmButtonSection.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 30/08/26.
//

import SwiftUI

struct ConfirmButtonSection: View {
    let isSaving: Bool
    let isDisabled: Bool
    let width: CGFloat
    let height: CGFloat
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
