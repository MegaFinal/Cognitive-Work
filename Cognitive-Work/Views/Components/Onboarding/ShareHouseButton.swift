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
    }
}


#Preview("Convite pronto") {
    @Previewable @State var share: CKShare? = CKShare(
        rootRecord: CKRecord(recordType: HouseModel.recordType)
    )
    @Previewable @State var shareURL: URL? = nil
    @Previewable @State var showSheet = false

    ShareHouseButton(
        viewModel: OnboardingViewModel(),
        share: $share,
        shareURL: $shareURL,
        showSheet: $showSheet
    )
}

#Preview("Sem convite") {
    @Previewable @State var share: CKShare? = nil
    @Previewable @State var shareURL: URL? = nil
    @Previewable @State var showSheet = false

    ShareHouseButton(
        viewModel: OnboardingViewModel(),
        share: $share,
        shareURL: $shareURL,
        showSheet: $showSheet
    )
}

