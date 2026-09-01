//
//  LayoutToggleButton.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 18/08/26.
//

/// A button that toggles between the grid and list card layouts.
///
/// The button observes the current layout mode from the provided
/// ``ContentViewModel`` and displays an icon representing the
/// layout that can be selected next.
///
/// Tapping the button triggers the same animated layout transition
/// used by the swipe gesture.

import SwiftUI

struct LayoutToggleButton: View {
    @Bindable var viewModel: CarouselViewModel
    
    var body: some View {
        HStack (spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.55,dampingFraction: 0.78)) {
                    viewModel.toggleLayout()
                }
            } label: {
                Image(systemName: viewModel.layoutMode == .grid ? "inset.filled.leftthird.middlethird.rightthird.rectangle" : "inset.filled.topthird.middlethird.bottomthird.rectangle")
                    .font(.title2)
                    .foregroundColor(.black)
                    .padding(8)
            }
            
            if viewModel.layoutMode == .list {
                Button {
                    viewModel.isSelectingFilter = true
                    
                    //                Menu {
                    //                    Button {
                    //
                    //                    } label: {
                    //                        Text("Filtrar")
                    //                    }
                    //
                    //                    Menu {
                    //                        Button("Usuário") {
                    //
                    //                        }
                    //                        Button("Data") { }
                    //                        Menu("Prioridade") {
                    //                            ForEach(PriorityTag.allCases, id: \.self) { tag in
                    //                                Button {
                    //                                    Task {
                    //                                        await viewModel.addOrRemoveFilter(tag: tag)
                    //                                    }
                    //                                } label: {
                    //                                    Label(tag.rawValue.capitalized, systemImage: viewModel.filterChoices.tags.contains(tag) ? "checkmark.circle.fill" : "circle")
                    //                                }
                    //                            }
                    //                        }
                    //                    } label: {
                    //                        Label("Usuário", systemImage: "line.3.horizontal.decrease")
                    //                    }
                    
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.title2)
                        .foregroundColor(.black)
                        .padding(8)
                }
                .popover(isPresented: $viewModel.isSelectingFilter) {
                    FilterOptionsMenu(viewModel: viewModel)
                        .frame(width: 250)
                        .presentationCompactAdaptation(.popover)
                }
                
            }
        }
        
        .glassEffect(
            .regular.interactive(),
            in: .capsule
        )
    }
}

#Preview {
    LayoutToggleButton(viewModel: CarouselViewModel())
}
