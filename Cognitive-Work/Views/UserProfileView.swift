//
//  ProfileView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI
import PhotosUI
import CloudKit

/// A screen that displays and manages the current user's profile.
///
/// `UserProfileView` is responsible for loading the current user's information from CloudKit
/// through ``UserProfileViewModel`` and presenting it in a form-based interface.
///
/// The screen supports:
/// - Viewing and editing the user's display name.
/// - Viewing and changing the profile picture.
/// - Displaying information about the user's house.
/// - Navigating to the hardware Wi-Fi connection flow.
/// - Deleting the current user's account.
///
struct UserProfileView: View {
    @State private var viewModelUser: UserProfileViewModel
    @State private var viewModelHouse = HouseEditViewModel()
    @State private var viewModelHardware = HardwareViewModel()
    @State private var viewModelOnboarding = OnboardingViewModel()
    
    init(viewModelUser: UserProfileViewModel = UserProfileViewModel()) {
        self._viewModelUser = State(initialValue: viewModelUser)
    }
    
    // MARK: - View
    var body: some View {
        NavigationStack {
            VStack(spacing: 50) {
                userInfo
                
                SettingsButtonsSection(
                    viewModelUser: viewModelUser,
                    viewModelHouse: viewModelHouse,
                    viewModelHardware: $viewModelHardware,
                    viewModelOnboarding: $viewModelOnboarding
                )
                
                Spacer()
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink {
                        EditProfileView(viewModel: viewModelUser)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel(Text("Editar Perfil"))
                    .disabled(viewModelUser.user == nil)
                }
            }
            .tabBarVisibilityRoot()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // MARK: Task
        .task {
            async let loadUserTask: () = viewModelUser.loadUser()
            async let loadIpTask: () = viewModelHardware.fetchHostName()
            
            _ = await (loadUserTask, loadIpTask)
        }
        // MARK: Alert if didn't save
        .alert(
            "Não foi possível salvar",
            isPresented: Binding(
                get: { viewModelUser.errorMessage != nil },
                set: { if !$0 { viewModelUser.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
        message: {
            Text(viewModelUser.errorMessage ?? "")
        }
        .overlay {
            if viewModelUser.isSaving {
                ProgressView()
            }
        }
    }
    
    private var userInfo: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .foregroundColor(.orange)
                .frame(height: height * 0.26)
                .shadow(color: .black.opacity(0.14), radius: 16.46937, x: 0, y: 4.68879)
            
            VStack(alignment: .center, spacing: 10) {
                if let data = viewModelUser.displayedImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width * 0.5, height: width * 0.5)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.gray)
                        .frame(width: width * 0.5, height: width * 0.5)
                        .background(.white)
                        .clipShape(Circle())
                }
                
                if viewModelUser.isLoading && viewModelUser.user == nil {
                    ProgressView()
                        .frame(height: 50)
                } else {
                    Text(viewModelUser.user?.name ?? "")
                        .font(.system(size: 22))
                        .bold()
                }
            }
            .padding(.top, (height * 0.25) - (width * 0.25))
        }
    }
}

private struct SettingsButtonsSection: View {
    var viewModelUser: UserProfileViewModel
    var viewModelHouse: HouseEditViewModel
    @Binding var viewModelHardware: HardwareViewModel
    @Binding var viewModelOnboarding: OnboardingViewModel
    
    @State private var hardwareSheet: HardwareSheet?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            NavigationLink {
                GeneralProfileSettingsView(viewModel: viewModelUser, houseViewModel: viewModelHouse)
            } label: {
                HStack {
                    Text("Configurações Gerais")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            NavigationLink {
                HouseSettingsView(viewModel: viewModelHouse)
            } label: {
                HStack {
                    Text("Ajustes da Casa")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            NavigationLink {
                SelectFreeTimeOnboardingView(viewModel: $viewModelOnboarding, isFromSettings: true)
            } label: {
                HStack {
                    Text("Alterar Tempo Livre")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            Button {
                if viewModelHardware.isPaired {
                    hardwareSheet = .existing
                } else if !viewModelHardware.hostName.isEmpty {
                    hardwareSheet = .pair
                } else {
                    hardwareSheet = .wifi
                }
            } label: {
                Text("Conectar com meu Hardware")
            }
            .padding(.horizontal)
        }
        .sheet(item: $hardwareSheet) { sheet in
            Group {
                switch sheet {
                case .existing:
                    ExistingIPView(
                        viewModelHardware: $viewModelHardware,
                        profileImage: viewModelUser.displayedImageData.flatMap { UIImage(data: $0) }
                    )
                case .pair:
                    NavigationStack {
                        DevicePairView(
                            hardwareViewModel: viewModelHardware,
                            onClose: { hardwareSheet = nil }
                        )
                    }
                case .wifi:
                    WifiCredentialsView(viewModel: viewModelHardware)
                }
            }
            .presentationDetents([.medium ])
            .presentationDragIndicator(.visible)
        }
    }
}

/// Which hardware screen the sheet shows, decided when the button is tapped.
private enum HardwareSheet: Identifiable {
    case existing, pair, wifi
    var id: Self { self }
}

// MARK: - Preview

#Preview {
    let mockViewModel = UserProfileViewModel()
    
    return UserProfileView(viewModelUser: mockViewModel)
}
