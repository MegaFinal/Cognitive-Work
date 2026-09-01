//
//  FilterOptionsMenu.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 31/08/26.
//

import SwiftUI

// user: UserModel? = nil, tag: PriorityTag? = nil, frequency: Recurrence? = nil, state: Bool? = nil

struct FilterOptionsMenu: View {
    @Bindable var viewModel: CarouselViewModel
    @State private var isOptionExpanded = [false, false, false, false]
    @State private var optionsName = ["Prioridade", "Usuários", "Frequência", "Status"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            FilterHeaderButton(isExpanded: $isOptionExpanded[0], headerText: optionsName[0])
            if isOptionExpanded[0] {
                FilterOptionRow(
                    items: PriorityTag.allCases,
                    isSelected: { viewModel.filterChoices.tags.contains($0) },
                    label: { $0.rawValue.capitalized },
                    onSelect: { tag in
                        await viewModel.addOrRemoveFilter(tag: tag)
                    }
                )
            }
            
            FilterHeaderButton(isExpanded: $isOptionExpanded[1], headerText: optionsName[1])
            if isOptionExpanded[1] {
                FilterOptionRow(
                    items: viewModel.userModels,
                    isSelected: { viewModel.filterChoices.users.contains($0) },
                    label: {$0.name.capitalized},
                    onSelect: { user in
                    await viewModel.addOrRemoveFilter(user: user)
                })
            }
            
            FilterHeaderButton(isExpanded: $isOptionExpanded[2], headerText: optionsName[2])
            if isOptionExpanded[2] {
                FilterOptionRow(
                    items: Recurrence.allCases,
                    isSelected: { viewModel.filterChoices.frequencies.contains($0) },
                    label: {$0.rawValue.capitalized},
                    onSelect: { freq in
                    await viewModel.addOrRemoveFilter(frequency: freq)
                    })
            }
            
            FilterHeaderButton(isExpanded: $isOptionExpanded[3], headerText: optionsName[3])
            if isOptionExpanded[3] {
                FilterOptionRow(
                    items: [true, false],
                    isSelected: { viewModel.filterChoices.state == $0 },
                    label: {$0 ? "Concluido" : "Pendente"},
                    onSelect: { state in
                        await viewModel.addOrRemoveFilter(state: state)
                    })
            }
            
            Button {
                viewModel.resetFilter()
            } label: {
                HStack {
                    Text("Limpar filtro")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "eraser")
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }

        }
        .frame(width: 250)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

#Preview {
    FilterOptionsMenu(viewModel: CarouselViewModel())
        .padding()
        .background(.blue)
}
