//
//  SeventhOnboardingView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//

import SwiftUI
import CloudKit

/// Seventh onboarding step, where the user picks the chores that are split
/// equally between every resident of the house.
///
/// Rooms are listed as collapsible sections. Tapping the chevron of a room
/// toggles ``RoomDTO/isExpanded`` for that room alone, revealing the chores
/// that can be marked through a `Toggle`. The trailing button advances to the
/// next step.
///
/// Spacing is derived from the container size reported by `GeometryReader`, so
/// the layout keeps its proportions across device sizes.
///
/// > Warning: Every room currently expands the same ``mockedChores`` array.
/// > Since ``ChoreDTO`` is a reference type, selecting a chore in one room also
/// > selects it in the others. Give each room its own list before replacing the
/// > mock with real data.
struct SelectChoresOnboardingView: View {
    
    // MARK: - Properties
    
    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel
    
    /// Rooms listed on the screen, each holding its own expansion state.
    @State private var rooms: [RoomModel] = []
    
    /// Placeholder chores rendered inside every expanded room.
    ///
    /// > Note: Temporary stand-in for the chores fetched from CloudKit through
    /// > ``RoomModel/fetchRelatedChores()``.
    @State private var choresDTO: [ChoreDTO] = []
    
    /// Chores the user marked to be split between the residents.
    private var selectedChores: [ChoreDTO] {
        choresDTO.filter { $0.isSelected }
    }
        
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            VStack(alignment: .leading) {
                
                VStack(alignment: .leading) {
                    Text("Selecione as tarefas")
                        .bold()
                        .font(.system(size: 32))
                        .foregroundStyle(.titleGray)
                        .padding(.top, height * 0.034)
                        .padding(.bottom, 10)
                    
                    Text("Escolha **apenas** as tarefas que serão divididas de maneira igual entre todos os moradores")
                        .font(.system(size: 16))
                        .foregroundStyle(.subTitleGray)
                        .padding(.bottom, height * 0.025)
                }
                
                if rooms.isEmpty {
                    ProgressView("Carregando Comodos e Tarefas...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
                else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading) {
                            ForEach($rooms) { $room in
                                HStack {
                                    SelectChoreListItem(viewModel: $viewModel, room: $room, height: height, width: width)
                                }
                                .padding(.bottom, height * 0.07)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, width * 0.086)
            .navigationBarBackButtonHidden()
        }
        .overlay {
            OnboardingProgressButton(width: 50.0, height: 50.0, text: "chevron.forward", isSystemImage: true, isLoading: viewModel.isLoading ,isDisabled: viewModel.selectedChores.isEmpty) {
                viewModel.isLoading = true
                await viewModel.createDefaultChores()
                
                if !viewModel.isLoading {
                    viewModel.goToNextView()
                }
                viewModel.isLoading = false
            }
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity,maxHeight: .infinity,alignment: .bottomTrailing)
            .padding(.trailing, 20)
        }
        .task(id: viewModel.currentHouse?.recordID) {
            rooms = await viewModel.fetchRooms()
        }
    }
}

// MARK: - Private subviews

/// A collapsible room section listing the default chores the user can pick.
private struct SelectChoreListItem: View {
    @Binding var viewModel: OnboardingViewModel
    
    @Binding var room: RoomModel
    
    @State var isExpanded: Bool = false
    @State var defaultChores: [ChoreDTO] = []
    
    let height: CGFloat
    let width: CGFloat
    
    var body: some View {
        VStack(alignment: .leading) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Text(room.name)
                        .font(.system(size: 24))
                        .bold()
                        .padding(.bottom, height * 0.018)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .fontWeight(.semibold)
            .foregroundStyle(.black)
            
            Divider()
                .frame(height: height * 0.001)
                .overlay(Color.black)
            
            if isExpanded {
                ForEach($defaultChores) { $chore in
                    Button {
                        if !viewModel.isLoading {
                            chore.isSelected.toggle()
                            if chore.isSelected {
                                if let roomRecordID = room.recordID {
                                    chore.roomReference = CKRecord.Reference(recordID: roomRecordID, action: .none)
                                }
                                viewModel.selectedChores.append(chore)
                            }
                            else {
                                viewModel.selectedChores.removeAll { $0.name == chore.name }
                            }
                        }
                    } label: {
                        HStack {
                            Circle()
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
            if let defaultRoom = DefaultRoomsOnboarding(rawValue: room.name) {
                defaultChores = defaultRoom.defaultChores
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    SelectChoresOnboardingView(viewModel: $viewModel)
}
