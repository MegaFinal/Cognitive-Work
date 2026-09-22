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

    var width: CGFloat?
    var height: CGFloat?

    @Binding var share: CKShare?
    @Binding var shareURL: URL?
    @Binding var showSheet: Bool

    @State private var isLoading = false

    // `width`/`height` shadow the View extension's properties of the same
    // name, so casting to `any View` is needed to reach the extension's
    // default (screen-based) value when no override was passed in.
    private var resolvedWidth: CGFloat { width ?? (self as any View).width * 0.5 }
    private var resolvedHeight: CGFloat { height ?? (self as any View).height * 0.06 }

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
            .frame(width: resolvedWidth, height: resolvedHeight)
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
