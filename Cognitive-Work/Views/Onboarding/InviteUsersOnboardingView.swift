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
    
    var width: CGFloat = UIScreen.main.bounds.width
    var height: CGFloat = UIScreen.main.bounds.height
    var isFromSettings: Bool

    // MARK: - Body

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Adicione seus \nroomies!")
                    .bold()
                    .font(.title)
                    .foregroundColor(.black)
                
                VStack(alignment: .leading) {
                    Text("Envie o convite para os outros moradores da sua casa se juntarem com você no app!")
                    
                    Text("Aceite o pedido dos moradores que estão em vermelho!")
                }
            }
            .frame(width: width * 0.84)
            .foregroundColor(.secondary)
            .padding(.top, 30)
            
            Spacer()
            
            if !houseUsers.isEmpty {
                joinedUsers
            }
            
            Spacer()
            
            Text("Assim que todos os moradores estiverem no app, clique em continuar. ")
                .frame(width: width * 0.8)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
            
            HStack {
                if resolvendoShare {
                    ProgressView("Preparando chaves de acesso...")
                        .frame(width: width * 0.55)
                } else {
                    if shareURL != nil {
                        ShareLink(item: shareURL!){
                            Text("Compartilhar Convite")
                                .font(.system(size: 17))
                                .frame(width: width * 0.5, height: height * 0.065, alignment: .center)
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
                
                if !isFromSettings {
                    OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true) {
                        viewModel.goToNextView()
                    }
                    .multilineTextAlignment(.trailing)
                }
            }
            .padding(.top)
            
            if !isFromSettings {
                OnboardingSkipButton() {
                    viewModel.finishOnboarding()
                }
            }
        }
        .frame(width: width * 0.84)
        .navigationBarBackButtonHidden(!isFromSettings)
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
                ZStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: width * 0.17)
                    UserProfilePictureTag(imageData: user.profilePicture?.fileURL?.dataRepresentation, widthMultiplier: 0.15)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()
    
    InviteUsersOnboardingView(viewModel: $mockViewModel, isFromSettings: false)
}
