//
//  DoneSelectingFreeTimeView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 10/09/26.
//

import SwiftUI

struct WaitingFreeTimeUsersOnboardingView: View {

    @Binding var viewModel: OnboardingViewModel

    var completedUsers: [UserModel] {
        viewModel.users.filter { $0.hasCompletedFreeTime }
    }

    var pendingUsers: [UserModel] {
        viewModel.users.filter { !$0.hasCompletedFreeTime }
    }

    var body: some View {
        VStack(spacing: 24) {

            VStack(spacing: 8) {
                Text("Aguardando os horários dos membros")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("A divisão das tarefas será liberada quando todos preencherem seus horários livres.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {

                Text("Membros que já finalizaram")
                    .font(.headline)

                ForEach(completedUsers) { user in
                    HStack {
                        ProfileImageView(imageData: user.profileImageData, size: 42)

                        Text(user.name)

                        Spacer()

//                        icon name=check-circle-filled color="#34C759"
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {

                Text("Ainda preenchendo")
                    .font(.headline)

                ForEach(pendingUsers) { user in
                    HStack {
                        ProfileImageView(imageData: user.profileImageData, size: 42)

                        Text(user.name)

                        Spacer()

                        ProgressView()
                    }
                }
            }

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden()
        .task {
            await viewModel.fetchHouseUsers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task {
                await viewModel.fetchHouseUsers()
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()

    WaitingFreeTimeUsersOnboardingView(viewModel: $viewModel)
}
