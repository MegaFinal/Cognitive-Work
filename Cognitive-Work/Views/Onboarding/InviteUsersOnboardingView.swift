//
//  FitfhOnboardingView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 25/08/26.
//

import SwiftUI
import CloudKit

/// Onboarding step where the house owner shares the invite link.
///
/// Resolves the CloudKit share on appear and keeps the list of members who
/// already joined up to date through `.cloudKitDidChange`.
struct InviteUsersOnboardingView: View {

    // MARK: - Properties

    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel
    
    @State private var houseShare: CKShare? = nil
    @State private var showSheet = false
    @State private var resolvendoShare = false
    @State private var shareURL: URL? = nil
    @State private var isLoading = true
    @State private var houseUsers: [UserModel] = []
    
    var width: CGFloat = UIScreen.main.bounds.width * 0.5
    var height: CGFloat = UIScreen.main.bounds.height * 0.06
    var editHouse: Bool

    // MARK: - Body

    var body: some View {
        VStack {
            OnboardingHeader(title: "Adicione seus roomies!", description: "Envie o convite para os outros moradores da sua casa se juntarem com você no app!")
            
            Spacer()
            
            if !houseUsers.isEmpty {
                joinedUsers
            }
            
            Spacer()
            
            Text("Assim que todos os moradores estiverem no app, clique em continuar. ")
                .frame(width: width * 1.65)
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
                
                if !editHouse {
                    OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true) {
                        viewModel.goToNextView()
                    }
                    .multilineTextAlignment(.trailing)
                }
            }
            .padding(.top)
            
            if !editHouse {
                OnboardingSkipButton() {
                    viewModel.finishOnboarding()
                }
            }
        }
        .navigationBarBackButtonHidden(!editHouse)
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task {
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
                houseUsers = await viewModel.fetchHouseUsers()
            }
        }
        .task {
            guard let house = viewModel.currentHouse else { return }
            
            resolvendoShare = true
            houseShare = await CloudKitManager.shared.resolveShare(for: house)
            
            do {
                if let share = houseShare {
                    let url = try await CloudKitManager.shared.generateShareLink(share: share)
                    self.shareURL = url
                }
            } catch {
                print("Erro ao gerar link: \(error.localizedDescription)")
            }
            
            houseUsers = await viewModel.fetchHouseUsers()
            resolvendoShare = false
        }
    }
    
    // MARK: - Subviews
    private var joinedUsers: some View {
        HStack(spacing: 20) {
            ForEach(houseUsers) { user in
                UserProfilePictureTag(imageData: user.profilePicture?.fileURL?.dataRepresentation, widthMultiplier: 0.15)
            }
        }
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()
    
    InviteUsersOnboardingView(viewModel: $mockViewModel, editHouse: true)
}
