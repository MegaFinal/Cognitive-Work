//
//  DevicePairView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI
import CloudKit

/// A view that handles hardware device pairing via IP address and transmits rendered chart data to an ESP32 device.
struct DevicePairView: View {
    
    /// The view model managing hardware connectivity and state.
    @Bindable var hardwareViewModel: HardwareViewModel
    
    /// The view model responsible for fetching and calculating fortnightly chore data.
    @State var fortnightlyViewModel = FortnightlyViewModel()
    
    @State private var users: [UserModel] = []
    @State private var chores: [ChoreModel] = []
    @State private var usageEntries: [DailyUsageEntry] = []
    @State private var startDate: Date = Date()
    @State private var isChartLoading = true
    @State private var pairingErrorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Pareie seu celular!")
                .font(.system(size: 20))
                .bold()
                .padding(.bottom, 20)
            TextField("IP do device", text: $hardwareViewModel.deviceIP)
                .frame(width: 300, height: 44)
                .textFieldStyle(.roundedBorder)
                .padding()
            Button {
                if hardwareViewModel.deviceIP != "" {
                    Task {
                        do {
                            let connected = try await hardwareViewModel.askForParingCode()
                            
                            if connected {
                                let saved = await hardwareViewModel.createIp()
                                if !saved {
                                    pairingErrorMessage = hardwareViewModel.errorMessage ?? "Erro ao salvar o IP."
                                }
                            } else {
                                pairingErrorMessage = "Não foi possível parear com o dispositivo."
                            }
                        } catch {
                            pairingErrorMessage = error.localizedDescription
                        }
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: 100, height: 44)
                        .foregroundStyle(.indigo)
                    Text("Parear")
                        .frame(width: 150, height: 44)
                        .foregroundStyle(.white)
                        .font(.system(size: 22))
                }
            }.padding(.bottom, 20)
             
            VStack {
                Divider()
                if isChartLoading {
                    ProgressView("Carregando gráfico...")
                } else {
                    VStack(spacing: 16) {
                        FortnightlyBarChart(
                            users: users,
                            entries: usageEntries,
                            startDate: startDate,
                            onSelect: { _ in },
                            scrollEnabled: false,
                            daysToShow: 7
                        )
                         
                        legend
                            .padding(.bottom)
                    }
                }
                 
                Button {
                    Task {
                        do {
                            try await hardwareViewModel.sendChartToESP32()
                        } catch {
                            pairingErrorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width: 150, height: 44)
                            .foregroundStyle(.orange)
                        Text("Enviar gráfico")
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
            }
        }
        .padding()
        .task {
            await fortnightlyViewModel.setupWithFetch()
             
            users = fortnightlyViewModel.users
            chores = fortnightlyViewModel.chores
            usageEntries = fortnightlyViewModel.usageEntries
            startDate = fortnightlyViewModel.startDate
            isChartLoading = false
        }
        .alert("Ops", isPresented: .constant(pairingErrorMessage != nil)) {
            Button("OK") { pairingErrorMessage = nil }
        } message: {
            Text(pairingErrorMessage ?? "Ocorreu um erro.")
        }
    }
    
    /// A helper subview that displays a color-coded legend for the active users.
    private var legend: some View {
        HStack {
            ForEach(Array(users.enumerated()), id: \.offset) { index, user in
                HStack {
                    Circle()
                        .frame(width: 14)
                        .foregroundStyle(UserColorPalette.color(for: index))

                    Text(user.name)
                        .font(.system(size: 15))
                        .fontWeight(.light)
                }
            }
        }
    }
}

#Preview {
    DevicePairView(hardwareViewModel: HardwareViewModel())
}
