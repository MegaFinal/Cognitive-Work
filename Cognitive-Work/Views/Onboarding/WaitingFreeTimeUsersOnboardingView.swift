//
//  DoneSelectingFreeTimeView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 10/09/26.
//

import CloudKit
import SwiftUI

/// Onboarding step where the house owner waits for every member to finish
/// filling their free time availability.
/// - `updateUsers()` can now run several times concurrently (push + foreground + poll). Each
///   run performs slow network reads, so an older run could finish *after* a newer one and
///   overwrite fresh data with a stale roster. Only the latest run may publish its result.
struct InviteAndWaitUsersFreeTimeOnboardingView: View {
    
    // MARK: - Properties
    
    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel
    
    @State private var houseUsers: [UserModel] = []
    @State private var completedUsers: [UserModel] = []
    @State private var pendingUsers: [UserModel] = []
    
    @State private var refreshGeneration: Int = 0
    @State private var resolveShare = true
    @State private var shareURL: URL? = nil
    @State private var didFailToPrepareInvite = false
    @State private var houseShare: CKShare? = nil
    
    
    /// `false` until the first fetch returns;
    @State private var hasLoadedUsers = false
    
    private let pollingInterval: Duration = .seconds(5)
    
    
    var isFromSettings: Bool
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adicione seus roomies!")
                .bold()
                .font(.system(size: 28))
                .foregroundColor(.black)
            
            Text("Envie o convite para quem mora com você")
                .foregroundColor(.secondary)
                .padding(.bottom, height * 0.028)
            
            
            Text("Na casa \(Text("\(houseUsers.count)").fontWeight(.black))")
                .font(.body)
                .frame(width: width * 0.84, alignment: .leading)
                .padding(.top, 30)
                .padding(.bottom, width * 0.02)
            
            
            if !hasLoadedUsers {
                ProgressView()
                    .controlSize(.large)
            }
                    
            if !pendingUsers.isEmpty {
                Text("Em configuração")
                .font(.subheadline)
                .fontWeight(.thin)
                pendingUsersView
            }
            
            if !completedUsers.isEmpty {
                Text("Usuarios prontos")
                .font(.subheadline)
                .fontWeight(.thin)
                completedUsersView
            }
                        
            
            Spacer()

            
        }
        .overlay(alignment: .bottomTrailing) {
            VStack {
                Text("Certifique-se de que todos os moradores estão dentro do app antes de continuar")
                    .frame(width: width * 0.8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
            
                HStack {
                    inviteButton
                        .frame(alignment: .center)
                    
                    Button("Continuar", systemImage: "chevron.right") {
                        Task { viewModel.goToNextView() }
                    }
                    .bold()
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .disabled(!pendingUsers.isEmpty)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, height * 0.073)
                .padding(.trailing, width * 0.021)
            }
        }
        .frame(width: width * 0.84)
        .navigationBarBackButtonHidden(!isFromSettings)
        .task(id: viewModel.currentHouse?.recordID) {
            await prepareInvite()
        }
        .task {
            await updateUsers()
            
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)
                guard !Task.isCancelled else { break }
                await updateUsers()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task {
                await updateUsers()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await updateUsers()
            }
        }
    }
    
    
    // MARK: - Subviews
    
    /// Members who already completed their free time.
    private var completedUsersView: some View {
        HStack(spacing: 20) {
            ForEach(completedUsers) { user in
                ZStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: width * 0.17)
                    
                    UserProfilePictureTag(user: user, widthMultiplier: 0.15)
                }
            }
        }
    }
    
    /// Members who still need to complete their free time.
    private var pendingUsersView: some View {
        HStack(spacing: 20) {
            ForEach(pendingUsers) { user in
                ZStack {
                    Circle()
                        .foregroundColor(.red)
                        .frame(width: width * 0.17)
                    
                    UserProfilePictureTag(user: user, widthMultiplier: 0.15)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var inviteButton: some View {
        if let shareURL, !resolveShare {
            ShareLink(item: shareURL) {
                inviteCapsule(color: .black) {
                    Text("Compartilhar Convite")
                }
            }
        } else if didFailToPrepareInvite && !resolveShare {
            Button {
                Task { await prepareInvite() }
            } label: {
                inviteCapsule(color: .black) {
                    Label("Tentar novamente", systemImage: "arrow.clockwise")
                }
            }
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
            .frame(width: width * 0.539, height: height * 0.058, alignment: .center)
            .foregroundColor(.white)
            .background {
                Capsule()
                    .foregroundColor(color)
                    .glassEffect()
            }
    }
    
    // MARK: - Actions
    
    /// Resolves the house's CKShare and its link.
    private func prepareInvite() async {
        resolveShare = true
        didFailToPrepareInvite = false
        defer { resolveShare = false }
        
        var house = viewModel.currentHouse
        if house == nil {
            house = await CloudKitManager.shared.currentHouse()
        }
        guard let house else {
            didFailToPrepareInvite = true
            return
        }
        
        if let share = await CloudKitManager.shared.resolveShare(for: house) {
            houseShare = share
            do {
                shareURL = try await CloudKitManager.shared.generateShareLink(share: share)
            } catch {
                print("Erro ao gerar link: \(error.localizedDescription)")
            }
        }
        
        didFailToPrepareInvite = shareURL == nil
    }
    
    private func updateUsers() async {
        // Sync fix: tag this run so a slower, older run can't overwrite a newer result.
        refreshGeneration += 1
        let generation = refreshGeneration
        
        let fetchedUsers = await viewModel.fetchHouseUsers()
        
        var completed: [UserModel] = []
        var pending: [UserModel] = []
        
        for user in fetchedUsers {
            let availableTimes = await user.availableTime
            
            if availableTimes.isEmpty {
                pending.append(user)
            } else {
                completed.append(user)
            }
        }
        
        // Sync fix: publish only if no newer refresh started meanwhile.
        guard generation == refreshGeneration else { return }
        houseUsers = fetchedUsers
        completedUsers = completed
        pendingUsers = pending
        hasLoadedUsers = true
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()
    
    InviteAndWaitUsersFreeTimeOnboardingView(
        viewModel: $mockViewModel,
        isFromSettings: false
    )
}
