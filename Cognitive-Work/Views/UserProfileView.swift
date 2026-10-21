//
//  ProfileView.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 31/08/26.
//

import SwiftUI
import PhotosUI
import CloudKit

/// The profile tab: the user's banner, photo and name, and links to the settings screens.
///
/// It loads the user through ``UserProfileViewModel`` and offers:
/// - The pencil button, which opens ``EditProfileView`` (name, photo and banner).
/// - "Configurações Gerais" (language, haptics, calendar, delete profile).
/// - "Ajustes da Casa" (members, rooms, reset division, delete or leave the house).
/// - "Chave Pix" and "Alterar Tempo Livre".
struct UserProfileView: View {
    /// The signed-in user's profile.
    @State private var viewModelUser: UserProfileViewModel
    /// The house settings and the admin status.
    @State private var viewModelHouse = HouseEditViewModel()
    /// The hardware (Harvii) connection. Its button is hidden for now.
    @State private var viewModelHardware = HardwareViewModel()
    /// Used by the "Alterar Tempo Livre" screen.
    @State private var viewModelOnboarding = OnboardingViewModel()
    
    /// Creates the screen. Pass a ready view model for previews.
    init(viewModelUser: UserProfileViewModel = UserProfileViewModel()) {
        self._viewModelUser = State(initialValue: viewModelUser)
    }
    
    // MARK: - Banner, photo and name; settings links
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
            // MARK: - Edit profile button
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink {
                        EditProfileView(viewModel: viewModelUser)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel(Text("Editar Perfil"))
                    .voiceControlNames([L10n.tr("Editar"), L10n.tr("Editar Perfil")])
                    .disabled(viewModelUser.user == nil)
                }
            }
            .tabBarVisibilityRoot()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // MARK: - Loads the user, the hardware and the admin status
        .task {
            async let loadUserTask: () = viewModelUser.loadUser()
            async let loadIpTask: () = viewModelHardware.fetchHostName()
            async let loadAdminTask: Bool = viewModelHouse.checkAdminStatus()
            
            _ = await (loadUserTask, loadIpTask, loadAdminTask)
        }
        // MARK: - Save error alert and saving spinner
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
                    .voiceOverLabel(L10n.tr("Salvando"))
            }
        }
    }
    
    /// The banner with the photo (or a placeholder) and the name on top.
    private var userInfo: some View {
        ZStack(alignment: .top) {
            RoomTextureBackground(color: viewModelUser.displayedBanner.color,
                                  pattern: viewModelUser.displayedBanner.pattern)
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
                
                Text(viewModelUser.user?.name ?? "")
                    .font(.system(size: 22))
                    .bold()
            }
            .padding(.top, (height * 0.25) - (width * 0.25))
        }
        // Read the header as one sentence: name, level, points and coins.
        .accessibilityElement(children: .ignore)
        .voiceOverLabel(viewModelUser.accessibilityProfileSummary)
        .voiceControlNames(viewModelUser.accessibilityProfileInputLabels)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The list of settings links, plus the hardware sheet.
private struct SettingsButtonsSection: View {
    /// The user's profile.
    var viewModelUser: UserProfileViewModel
    /// The house settings.
    var viewModelHouse: HouseEditViewModel
    /// The hardware connection.
    @Binding var viewModelHardware: HardwareViewModel
    /// Used by the free time screen.
    @Binding var viewModelOnboarding: OnboardingViewModel
    
    /// The hardware screen shown in the sheet, or `nil`.
    @State private var hardwareSheet: HardwareSheet?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // MARK: - General settings
            NavigationLink {
                GeneralProfileSettingsView(viewModel: viewModelUser, houseViewModel: viewModelHouse)
            } label: {
                HStack {
                    Text("Configurações Gerais")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
            }
            .voiceControlNames([L10n.tr("Configurações Gerais"), L10n.tr("Configurações"), L10n.tr("Ajustes")])
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            // MARK: - House settings
            NavigationLink {
                HouseSettingsView(viewModel: viewModelHouse)
            } label: {
                HStack {
                    Text("Ajustes da Casa")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
            }
            .voiceControlNames([L10n.tr("Ajustes da Casa"), L10n.tr("Casa")])
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            // MARK: - Pix key
            NavigationLink {
                PixKeySettingsView(viewModel: viewModelUser)
            } label: {
                HStack {
                    Text("Chave Pix")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            // MARK: - Free time
            NavigationLink {
                SelectFreeTimeOnboardingView(viewModel: $viewModelOnboarding, isFromSettings: true)
            } label: {
                HStack {
                    Text("Alterar Tempo Livre")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
            }
            .voiceControlNames([L10n.tr("Alterar Tempo Livre"), L10n.tr("Tempo livre")])
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            
            // MARK: - Hardware connection (hidden for now)
//            Button {
//                if viewModelHardware.isPaired {
//                    hardwareSheet = .existing
//                } else if !viewModelHardware.hostName.isEmpty {
//                    hardwareSheet = .pair
//                } else {
//                    hardwareSheet = .wifi
//                }
//            } label: {
//                Text("Conectar com meu Hardware")
//            }
//            .padding(.horizontal)caso tenha
        }
        // MARK: - Hardware sheet
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
    /// Already paired; connected Wi-Fi; needs Wi-Fi.
    case existing, pair, wifi
    /// The case itself, for `sheet(item:)`.
    var id: Self { self }
}

// MARK: - Preview

#Preview {
    let mockViewModel = UserProfileViewModel()
    
    return UserProfileView(viewModelUser: mockViewModel)
}
