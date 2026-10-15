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
    
    private var title: some View {
        Text("Divisão atual")
            .font(.system(size: 15))
            .fontWeight(.semibold)
    }
    
    private var periodText: some View {
        Text(period)
            .font(.system(size: 15))
    }
    
    var body: some View {
        // Title and period side by side when they fit; otherwise stacked on two lines. The
        // background wraps the text (pill on one line, rounded card on two) instead of a fixed
        // capsule the text used to spill out of.
        ViewThatFits(in: .horizontal) {
            HStack {
                title
                periodText
            }
            .fixedSize()
            
            VStack(spacing: 2) {
                title
                periodText
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minWidth: width * 0.58, minHeight: height * 0.04)
        .frame(maxWidth: width * 0.9)
        .background(
            Color.gray.opacity(0.2),
            in: RoundedRectangle(cornerRadius: height * 0.02, style: .continuous)
        )
        // One element with the full dates ("Divisão atual, de 28 de setembro a 11 de outubro").
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.tr("Divisão atual, de %@ a %@",
                    ChartA11y.dayMonth(viewModel.periodStart),
                    ChartA11y.dayMonth(viewModel.periodFinish))
        )
    }
}

#Preview {
    DateDivisionComponent(viewModel: .constant(DashboardViewModel()))
}
