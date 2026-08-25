//
//  FitfhOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI
import CloudKit

struct FifthOnboardingView: View {
    
    let viewModel = ContentViewModel() 
    let houseRecord: CKRecord 
    
    @State private var houseShare: CKShare? = nil
    @State private var shareURL: URL? = nil
    @State private var showSheet = false
    @State private var resolvendoShare = false
    
    var body: some View {
        
        VStack{
            OnboardingHeader(title: "Adicione seus roomies!", description: "Envie o convite para os outros moradores da sua casa se juntarem com você no app!")
            
            Text("Assim que todos os moradores estiverem no app, clique em continuar. ")
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
            
            
            HStack(alignment: .center) {
                if resolvendoShare {
                    ProgressView("Preparando chaves de acesso...")
                } else {
                    ShareHouseButton(
                        share: houseShare,
                        viewModel: viewModel,
                        shareURL: $shareURL,
                        showSheet:$showSheet
                    )
                }
                OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true, action: {})
                    .multilineTextAlignment(.trailing)
            }
            
            OnboardingSkipButton(action: {})
            
        }
        .onAppear {
            Task {
                resolvendoShare = true
                self.houseShare = await CloudKitManager.shared.resolveShare(for: houseRecord)
                resolvendoShare = false
            }
        }
        .sheet(isPresented: $showSheet) {
            if let url = shareURL {
                ShareSheet(url: url)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}
#Preview {
    let mockRecord = CKRecord(recordType: "House")
    FifthOnboardingView(houseRecord: mockRecord)
}
