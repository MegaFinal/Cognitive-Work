//
//  DateDivisionComponent.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 01/10/26.
//

import SwiftUI

struct DateDivisionComponent: View {
    @Binding var viewModel: DashboardViewModel
    
    /// Current division range.
    /// Ex.: "28 set — 11 out"
    private var period: String {
        "\(viewModel.periodStart.shortDayMonth) — \(viewModel.periodFinish.shortDayMonth)"
    }
    
    var body: some View {
        ZStack {
            Capsule()
                .frame(width: width * 0.58, height: height * 0.04)
                .foregroundStyle(Color.gray.opacity(0.2))
            
            HStack {
                Text("Divisão atual")
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                Text(period)
                    .font(.system(size: 15))
            }
        }
    }
}

#Preview {
    DateDivisionComponent(viewModel: .constant(DashboardViewModel()))
}
