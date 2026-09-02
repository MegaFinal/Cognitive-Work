//
//  DevicePairView.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 25/08/26.
//

import SwiftUI

struct DevicePairView: View {
    @Bindable var hardwareViewModel: HardwareViewModel
    @State var fortnightlyViewModel = FortnightlyViewModel()
    let image1 = UIImage(named: "fish")
    let image2 = UIImage(named: "emoji")
    
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
                            onSelect: { _ in }
                        )
                        FortnightlyLegend(users: users)
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
}

#Preview {
    DevicePairView(hardwareViewModel: HardwareViewModel())
}
