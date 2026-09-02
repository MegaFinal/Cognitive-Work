//
//  DevicePairView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

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
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Pareie seu celular!")
                .font(.title3)
                .bold()
                .padding(.bottom, 20)
            TextField("IP do device", text: $hardwareViewModel.deviceIP)
                .frame(width: 300, height: 44)
                .textFieldStyle(.roundedBorder)
                .padding()
            Button {
                if hardwareViewModel.deviceIP != "" {
                    Task {
                        try await hardwareViewModel.askForParingCode()
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
                        .font(.title2)
                }
            }.padding(.bottom, 20)
             
            VStack{
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
                        try await hardwareViewModel.sendChartToESP32(
                            users: users, chores: chores, usageEntries: usageEntries, startDate: startDate
                        )
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
            print("setup")
            await fortnightlyViewModel.setupWithFetch()
             
            users = fortnightlyViewModel.users
            chores = fortnightlyViewModel.chores
            usageEntries = await fortnightlyViewModel.usageEntries
            startDate = fortnightlyViewModel.startDate
            isChartLoading = false
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
