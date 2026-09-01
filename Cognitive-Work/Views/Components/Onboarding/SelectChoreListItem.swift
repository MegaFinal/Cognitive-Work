//
//  SelectChoreListItem.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 28/08/26.
//

import SwiftUI

struct SelectChoreListItem: View {
    @Binding var viewModel: OnboardingViewModel
    
    @Binding var room: RoomModel

    @State var isExpanded: Bool = false
    @State var defaultChores: [ChoreDTO] = []
    
    let height: CGFloat
    let width: CGFloat
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                
                Text(room.name)
                    .font(.system(size: 24))
                    .bold()
                    .padding(.bottom, height * 0.018)
                
                Spacer()
                
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .fontWeight(.semibold)
                .foregroundStyle(.black)
            }
            
            Divider()
            .frame(height: height * 0.001)
            .overlay(Color.black)
            
            if isExpanded {
                ForEach($defaultChores) { $chore in
                    Button {
                        chore.isSelected.toggle()
                        if chore.isSelected {
                            viewModel.selectedChores.append(chore)
                        }
                        else {
                            viewModel.selectedChores.removeAll { $0.name == chore.name }
                        }
                    } label: {
                        HStack {
                            Circle()
                                .border(.black)
                                .background(.clear)
                                .frame(width: 15, height: 15)
                                .padding(.trailing, 8)
                            Text(chore.name)
                            
                            Spacer()
                        }
                        .foregroundStyle(chore.isSelected ? .blue : .black)
                    }
                }
            }
        }
        .task {
            if let defoultRoom = DefaultRoomsOnboarding(rawValue: room.name) {
                defaultChores = defoultRoom.defaultChores
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    @Previewable @State var room = RoomModel(name: "Quarto", color: .blue)
    SelectChoreListItem(viewModel: $viewModel,room: $room, height: 852, width: 393)
}
