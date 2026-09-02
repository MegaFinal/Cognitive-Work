//
//  FitfhOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI
import CloudKit

struct InviteUsersOnboardingView: View {
    @Binding var viewModel: OnboardingViewModel
    
    @State private var houseShare: CKShare? = nil
    @State private var showSheet = false
    @State private var resolvendoShare = false
    @State private var shareURL: URL? = nil
    @State private var isLoading = true
    
    var width: CGFloat = UIScreen.main.bounds.width * 0.5
    var height: CGFloat = UIScreen.main.bounds.height * 0.06
    
    var body: some View {
        VStack{
            OnboardingHeader(title: "Adicione seus roomies!", description: "Envie o convite para os outros moradores da sua casa se juntarem com você no app!")
            
            Text("Assim que todos os moradores estiverem no app, clique em continuar. ")
                .frame(width: width * 1.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
            
            
            HStack {
                if resolvendoShare {
                    ProgressView("Preparando chaves de acesso...")
                        .frame(width: width, height: height)
                } else {
                    if shareURL != nil {
                        ShareLink(item: shareURL!){
                            Text("Compartilhar Convite")
                                .font(.system(size: 17))
                                .frame(width: width, height: height, alignment: .center)
                                .foregroundColor(.white)
                                .background {
                                    Capsule()
                                        .foregroundColor(.blue)
                                        .glassEffect()
                                }
                        }
                        
                    }
                    else {
                        Button {
                        } label: {
                            ProgressView().tint(.white)
                        }
                        .frame(width: width, height: height, alignment: .center)
                        .foregroundColor(.white)
                        .background(Capsule().foregroundStyle(.gray))
                    }
                }
                
                OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true) {
                    viewModel.goToNextView()
                }
                .multilineTextAlignment(.trailing)
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .centerLastTextBaseline)
            .padding(.bottom)
            
            OnboardingSkipButton() {
                viewModel.finishOnboarding()
            }
            
        }
        .navigationBarBackButtonHidden()
        .task {
            print("currentHouse:", viewModel.currentHouse as Any)
            print("recordID:", viewModel.currentHouse?.recordID as Any)
            
            guard let house = viewModel.currentHouse else { return }
            
            houseShare = await CloudKitManager.shared.resolveShare(for: house)
            print("share:", houseShare as Any)
            
            do {
                if let share = houseShare {
                    let url = try await CloudKitManager.shared.generateShareLink(share: share)
                    self.shareURL = url
                }
            } catch {
                print("Erro ao gerar link: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    InviteUsersOnboardingView(viewModel: $viewModel)
        .environment(OnboardingViewModel())
}
