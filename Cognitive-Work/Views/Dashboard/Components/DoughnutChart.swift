//
//  DoughnutChart.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 01/10/26.
//

import SwiftUI
import Charts

struct Slice: Identifiable {
    let id = UUID()
    let size: Int
    let color: Color
}

struct DoughnutChart: View {
    @Binding var viewModel: DashboardViewModel
    
    private var completedAndAllChores: String {
        "\(viewModel.completedToday) de \(viewModel.totalToday)"
    }
    
    var slices: [Slice] {
        let done = Slice(size: viewModel.completedToday, color: .choreBlue)
        let all = Slice(size: viewModel.totalToday - viewModel.completedToday, color: Color.gray.opacity(0.15))
        
        return [done, all]
    }
    
    var body: some View {
        // MARK: - Loading
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(Color(.systemGray6).opacity(0.5))
                .frame(width: width * 0.437, height: height * 0.21)
            
            if viewModel.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 8) {
                    // Leading-aligned across the card's width (minus its margins) instead of a big
                    // trailing padding, which left ~55pt and cut "Today" short; wraps if needed.
                    Text("Hoje")
                        .font(.system(size: 17))
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: width * 0.437 - 40, alignment: .leading)
                    
                    ZStack {
                        Text(viewModel.completionText)
                            .font(.system(size: 20))
                            .fontWeight(.black)
                        
                        Chart(slices) { slice in
                            SectorMark(
                                angle: .value("Chores", slice.size),
                                innerRadius: .ratio(0.64)
                            )
                            .foregroundStyle(slice.color)
                        }
                        .frame(width: width * 0.27, height: height * 0.126)
                    }
                    
                    Text(completedAndAllChores)
                        .font(.system(size: 15))
                    
                }
            }
        }
    }
}

#Preview {
    let vm: DashboardViewModel = {
        let vm = DashboardViewModel()
        vm.completedToday = 3
        vm.totalToday = 4
        vm.completionProgress = 0.75
        vm.completionText = "75%"
        return vm
    }()
    
    DoughnutChart(viewModel: .constant(vm))
}
