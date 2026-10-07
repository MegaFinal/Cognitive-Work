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
    
    /// The house's rooms, in the order they are offered.
    @State private var rooms: [RoomModel] = []
    
    @State private var isLoadingRooms: Bool = true
    
    /// The room whose chores are listed.
    @State private var selectedRoomID: RoomModel.ID?
    
    /// Default chores of each room, built once per room so the marks aren't lost on a redraw.
    @State private var choresByRoom: [RoomModel.ID: [ChoreDTO]] = [:]
    
    /// Rooms handed in by the caller (previews), shown instead of fetching them from CloudKit.
    private let injectedRooms: [RoomModel]
    
    /// - Parameters:
    ///   - viewModel: State shared by every step of the flow.
    ///   - rooms: Rooms to show without fetching them. Leave empty to load the house's rooms.
    init(viewModel: Binding<OnboardingViewModel>, rooms: [RoomModel] = []) {
        self._viewModel = viewModel
        self.injectedRooms = rooms
        self._rooms = State(initialValue: rooms)
        self._isLoadingRooms = State(initialValue: rooms.isEmpty)
        self._selectedRoomID = State(initialValue: rooms.first?.id)
    }
    
    private var selectedRoom: RoomModel? {
        rooms.first { $0.id == selectedRoomID }
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let horizontalMargin = width * 0.06
            
            VStack(alignment: .leading, spacing: 20) {
                header
                
                VStack {
                    if isLoadingRooms {
                        ProgressView("Carregando Comodos e Tarefas...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                            .padding(.top, height * 0.1)
                    } else if rooms.isEmpty {
                        Text("Nenhum cômodo padrão foi selecionado para a casa.")
                            .font(.system(size: 16))
                            .foregroundStyle(.subTitleGray)
                            .padding(.horizontal, horizontalMargin)
                    } else {
                        roomSelector(horizontalMargin: horizontalMargin)
                            .padding(.bottom, height * 0.025)
                        
                        choreList(horizontalMargin: horizontalMargin)
                    }
                }
            }
            .navigationBarBackButtonHidden()
        }
        .overlay {
            OnboardingProgressButton(width: width * 0.12, height: width * 0.12, text: "chevron.forward", isSystemImage: true, isLoading: viewModel.isLoading ,isDisabled: viewModel.selectedChores.isEmpty) {
                viewModel.isLoading = true
                await viewModel.createDefaultChores()
                
                if viewModel.errorMessage == nil {
                    viewModel.goToNextView()
                }
                viewModel.isLoading = false
            }
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity,maxHeight: .infinity,alignment: .bottomTrailing)
            .padding(.trailing, 20)
        }
        .task(id: viewModel.currentHouse?.recordID) {
            guard injectedRooms.isEmpty else { return }
            isLoadingRooms = true
            guard viewModel.currentHouse != nil else { return }
            rooms = await viewModel.fetchRooms().filter {
                DefaultRoomsOnboarding(rawValue: $0.kind ?? $0.name) != nil
            }
            if selectedRoom == nil {
                selectedRoomID = rooms.first?.id
            }
            isLoadingRooms = false
        }
        .task(id: selectedRoomID) {
            loadChoresIfNeeded(for: selectedRoom)
        }
        .onboardingBackButton(viewModel: viewModel)
        .alert("Não deu para salvar as tarefas", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        OnboardingHeader(
            title: "O que a casa divide?",
            description: "Marque **apenas** as tarefas que vão para a escala de todos."
        )
    }
    
    /// Horizontal row of room capsules.
    private func roomSelector(horizontalMargin: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(rooms) { room in
                    RoomCapsule(
                        room: room,
                        selectedCount: selectedCount(in: room),
                        isSelected: room.id == selectedRoomID
                    ) {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedRoomID = room.id
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, horizontalMargin, for: .scrollContent)
    }
    
    /// The selected room's chores, one rounded row each, centered on the screen.
    private func choreList(horizontalMargin: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if let room = selectedRoom {
                    ForEach(choresByRoom[room.id] ?? []) { chore in
                        ChoreSelectionRow(
                            chore: chore,
                            color: room.color,
                            isSelected: chore.isSelected
                        ) {
                            toggle(chore, in: room)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalMargin)
            .padding(.bottom, 90)
        }
        .id(selectedRoomID)
        .transition(.opacity)
    }
    
    // MARK: - Selection
    
    /// Builds the room's default chores the first time it is shown.
    private func loadChoresIfNeeded(for room: RoomModel?) {
        guard let room, choresByRoom[room.id] == nil,
              let defaultRoom = DefaultRoomsOnboarding(rawValue: room.kind ?? room.name)
        else { return }
        
        choresByRoom[room.id] = defaultRoom.defaultChores
    }
    
    /// How many of `room`'s chores are marked.
    private func selectedCount(in room: RoomModel) -> Int {
        guard let recordID = room.recordID else { return 0 }
        return viewModel.selectedChores.filter { $0.roomReference?.recordID == recordID }.count
    }
    
    private func toggle(_ chore: ChoreDTO, in room: RoomModel) {
        guard !viewModel.isLoading else { return }
        
        chore.isSelected.toggle()
        
        if chore.isSelected {
            if let roomRecordID = room.recordID {
                chore.roomReference = CKRecord.Reference(recordID: roomRecordID, action: .none)
            }
            viewModel.selectedChores.append(chore)
        } else {
            // By identity, not name: two rooms of the same type ("Quarto 1", "Quarto 2") list
            // chores with the same names.
            viewModel.selectedChores.removeAll { $0.id == chore.id }
        }
    }
}

// MARK: - Private subviews

/// A room capsule. Selected, it is filled with the room's color; the count of marked chores
/// shows inside it.
private struct RoomCapsule: View {
    let room: RoomModel
    let selectedCount: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(room.name.localizedDefault)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                
                if selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isSelected ? room.color.uiColor : .white)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(isSelected ? Color.white : room.color.uiColor, in: Circle())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(isSelected ? .white : .black.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isSelected ? room.color.uiColor : Color(.systemGray5), in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.25), value: selectedCount)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One selectable chore: a rounded row with a check circle, tinted with the room's color once
/// marked.
private struct ChoreSelectionRow: View {
    let chore: ChoreDTO
    let color: RoomColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? color.uiColor : .black)
                
                Text(chore.name.localizedDefault)
                    .font(.system(size: 19))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(
                        isSelected ? color.lowOpacityColor.opacity(0.25) : Color(.systemGray6)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    
    /// Rooms as they come back from CloudKit after the "select rooms" step: two bedrooms share
    /// the "Quarto" kind and so the same default chores.
    let house = CKRecord.Reference(recordID: CKRecord.ID(recordName: "preview-house"), action: .none)
    let roomTypes: [(name: String, type: DefaultRoomsOnboarding)] = [
        ("Sala de Estar", .livingRoom),
        ("Banheiro", .bathroom),
        ("Quarto 1", .bedroom),
        ("Quarto 2", .bedroom),
        ("Cozinha", .kitchen),
        ("Área de Serviço", .laundryRoom)
    ]
    let previewRooms: [RoomModel] = roomTypes.map { name, type in
        var room = RoomModel(
            name: name,
            symbol: type.symbol,
            house: house,
            color: type.color,
            kind: type.rawValue
        )
        room.recordID = CKRecord.ID(recordName: "preview-room-\(name)")
        return room
    }
    
    SelectChoresOnboardingView(viewModel: $viewModel, rooms: previewRooms)
}
