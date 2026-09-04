//
//  ShareHouseButton.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI
import CloudKit

struct ShareHouseButton: View {
    let viewModel: OnboardingViewModel

    var width: CGFloat = UIScreen.main.bounds.width * 0.5
    var height: CGFloat = UIScreen.main.bounds.height * 0.06
    
    @Binding var share: CKShare?
    @Binding var shareURL: URL?
    @Binding var showSheet: Bool

    @State private var isLoading = false
    
    
    var body: some View {
        
        Button {
            Task {
                guard let share = share else { return }
                isLoading = true

                do {
                    let url = try await CloudKitManager.shared.generateShareLink(share: share)
                    self.shareURL = url
                    self.showSheet = true
                } catch {
                    print("Erro ao gerar link: \(error.localizedDescription)")
                }
                
                isLoading = false
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Compartilhar Convite")
                        .font(.system(size: 17))
                }
            }
            .frame(width: width, height: height)
            .foregroundColor(.white)
            .background(Capsule().foregroundColor(share == nil || isLoading ? .gray : .blue))
        }
        .disabled(share == nil || isLoading)
        
        //        if let url = shareURL {
        //            ShareLink(item: url) {
        //                ZStack {
        //                    Text("Compartilhar convite")
        //                        .font(.system(size: 17, weight: .medium))
        //                }
        //                .frame(width: width, height: height)
        //                .foregroundColor(.white)
        //                .background(Capsule().glassEffect().foregroundColor(.blue))
        //            }
        //        } else {
        //            ZStack {
        //                Text("Compartilhar convite")
        //                    .font(.system(size: 17, weight: .medium))
        //            }
        //            .frame(width: width, height: height)
        //            .foregroundColor(.white)
        //            .background(Capsule().glassEffect())
        //        }
    }
}


#Preview {
//    ShareHouseButton()
}

