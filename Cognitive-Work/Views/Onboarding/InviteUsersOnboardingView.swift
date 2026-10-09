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
    @State private var resolvendoShare = true
    @State private var didFailToPrepareInvite = false
    @State private var shareURL: URL? = nil
    @State private var houseUsers: [UserModel] = []
    
    var isFromSettings: Bool
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            Spacer()
            
            if !houseUsers.isEmpty {
                joinedUsers
            }
            
            Spacer()
            
            Text("Assim que todos os moradores estiverem no app, clique em continuar.")
                .frame(width: width * 0.8)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
            
            HStack {
                inviteButton
                
                if !isFromSettings {
                    OnboardingProgressButton(width: width * 0.12, height: width * 0.12, text: "chevron.forward", isSystemImage: true) {
                        viewModel.goToNextView()
                    }
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        .frame(width: width * 0.84)
        .navigationBarBackButtonHidden(!isFromSettings)
        .onboardingBackButton(viewModel: viewModel, isHidden: isFromSettings)
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task {
                houseUsers = await viewModel.fetchHouseUsers()
            }
        }
        .task(id: viewModel.currentHouse?.recordID) {
            await prepareInvite()
        }
        .onChange(of: houseUsers.count) { oldCount, newCount in
            // Someone accepted the invite while the user waits on this screen.
            if newCount > oldCount && oldCount > 0 {
                VoiceOver.announce(L10n.tr("%lld moradores na casa", newCount))
            }
        }
        .onChange(of: didFailToPrepareInvite) { _, didFail in
            if didFail { VoiceOver.announce(L10n.tr("Não foi possível preparar o convite")) }
        }
    }
    
    // MARK: - Actions
    
    /// Resolves the house's CKShare and its link.
    private func prepareInvite() async {
        resolvendoShare = true
        didFailToPrepareInvite = false
        shareURL = nil
        houseShare = nil
        defer { resolvendoShare = false }
        
        var house = viewModel.currentHouse
        if house == nil {
            house = try? await CloudKitManager.shared.currentHouse()
        }
        guard let house else {
            didFailToPrepareInvite = true
            return
        }
        
        async let resolvedShare = CloudKitManager.shared.resolveShare(for: house)
        async let users = viewModel.fetchHouseUsers()
        
        if let share = await resolvedShare {
            houseShare = share
            do {
                shareURL = try await CloudKitManager.shared.generateShareLink(share: share)
            } catch {
                print("Erro ao gerar link: \(error.localizedDescription)")
            }
        }
        
        houseUsers = await users
        didFailToPrepareInvite = shareURL == nil
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var inviteButton: some View {
        if let shareURL, !resolvendoShare {
            ShareLink(item: shareURL) {
                inviteCapsule(color: .blue) {
                    Text("Compartilhar Convite")
                }
            }
            .voiceControlNames([L10n.tr("Compartilhar Convite"), L10n.tr("Compartilhar"), L10n.tr("Convidar")])
        } else if didFailToPrepareInvite && !resolvendoShare {
            Button {
                Task { await prepareInvite() }
            } label: {
                inviteCapsule(color: .blue) {
                    Label("Tentar novamente", systemImage: "arrow.clockwise")
                }
            }
            .voiceControlNames([L10n.tr("Tentar novamente"), L10n.tr("Recarregar")])
        } else {
            inviteCapsule(color: .gray) {
                ProgressView()
                    .tint(.white)
            }
            .accessibilityLabel(Text("Preparando convite"))
        }
    }
    
    private func inviteCapsule<Content: View>(color: Color, @ViewBuilder label: () -> Content) -> some View {
        label()
            .font(.system(size: 17))
            .frame(width: width * 0.5, height: height * 0.057, alignment: .center)
            .foregroundColor(.white)
            .background {
                Capsule()
                    .foregroundColor(color)
                    .glassEffect()
            }
    }
    private var joinedUsers: some View {
        HStack(spacing: 20) {
            ForEach(houseUsers) { user in
                ZStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: width * 0.17)
                    UserProfilePictureTag(user: user, widthMultiplier: 0.15)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(user.name))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.tr("Moradores que já entraram")))
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()
    
    InviteUsersOnboardingView(viewModel: $mockViewModel, isFromSettings: false)
}
