//
//  OnboardingNewChoreSheet.swift
//  Cognitive-Work
//

import SwiftUI
import CloudKit

/// Sheet for creating a chore that isn't in the default list, during onboarding.
///
/// Presented from ``SelectChoresOnboardingView``. Nothing is saved here: the new chore comes
/// back through `onCreate` already marked, and is persisted with the selected default chores
/// by ``OnboardingViewModel/createDefaultChores()`` when the step is confirmed.
struct OnboardingNewChoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    /// Rooms the chore can belong to.
    let rooms: [RoomModel]
    
    /// Called with the new chore (already linked to its room) when the user confirms.
    let onCreate: (ChoreDTO, RoomModel) -> Void
    
    @State private var draft = ChoreDTO()
    @State private var selectedRoomID: RoomModel.ID?
    @FocusState private var isNameFocused: Bool
    
    /// - Parameters:
    ///   - rooms: Rooms the chore can belong to.
    ///   - initialRoom: Room picked when the sheet opens (the one being browsed).
    ///   - onCreate: Receives the new chore and its room.
    init(rooms: [RoomModel], initialRoom: RoomModel?, onCreate: @escaping (ChoreDTO, RoomModel) -> Void) {
        self.rooms = rooms
        self.onCreate = onCreate
        _selectedRoomID = State(initialValue: initialRoom?.id ?? rooms.first?.id)
    }
    
    private var selectedRoom: RoomModel? {
        rooms.first { $0.id == selectedRoomID }
    }
    
    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canCreate: Bool {
        !trimmedName.isEmpty && selectedRoom != nil
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    header
                    
                    VStack(spacing: 10) {
                        HStack {
                            Text("Prioridade")
                            Spacer()
                            ChoreTagPicker(chore: $draft, type: .priority)
                        }
                        
                        HStack {
                            Text("Duração")
                            Spacer()
                            ChoreTagPicker(chore: $draft, type: .duration)
                        }
                        
                        HStack {
                            Text("Frequência")
                            Spacer()
                            ChoreTagPicker(chore: $draft, type: .frequency)
                        }
                    }
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Descrição")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                        
                        TextField("Descrição da Tarefa", text: $draft.description, axis: .vertical)
                            .font(.system(size: 17))
                            .foregroundColor(.gray)
                            .characterLimit(TextLimits.choreDescription, text: $draft.description)
                    }
                }
                .padding(.vertical)
                .frame(width: width * 0.9)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Nova Tarefa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        create()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!canCreate)
                }
            }
            .dismissKeyboardOnTap()
            .onAppear { isNameFocused = true }
        }
    }
    
    // MARK: - Subviews
    
    /// Room icon, chore name and room picker.
    private var header: some View {
        HStack {
            Image(systemName: selectedRoom?.symbol ?? "house")
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.15)
                .fontWeight(.thin)
                .contentTransition(.symbolEffect(.replace))
                .padding(.leading, 8)
            
            Spacer()
            
            VStack(spacing: 25) {
                VStack(spacing: 2) {
                    TextField(
                        "",
                        text: $draft.name,
                        prompt: Text("Nome da Tarefa")
                            .foregroundStyle(.black)
                    )
                    .font(.system(size: 28))
                    .bold()
                    .focused($isNameFocused)
                    .characterLimit(TextLimits.choreName, text: $draft.name)
                    .submitLabel(.done)
                    
                    Capsule()
                        .frame(height: height * 0.0015)
                }
                
                HStack {
                    Text("Cômodo")
                        .bold()
                    
                    Spacer()
                    
                    Menu {
                        Picker("Cômodo", selection: $selectedRoomID) {
                            ForEach(rooms) { room in
                                Text(room.name.localizedDefault)
                                    .tag(RoomModel.ID?(room.id))
                            }
                        }
                    } label: {
                        HStack {
                            CapsuleTag(
                                tagName: selectedRoom?.name.localizedDefault ?? L10n.tr("Sem Cômodo"),
                                tagColor: selectedRoom?.color.uiColor ?? .gray,
                                horizontalPadding: 10.0,
                                verticalPadding: 1.5
                            )
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.black)
                                .imageScale(.small)
                        }
                        .fixedSize()
                    }
                    .id(selectedRoomID)
                }
            }
            .frame(width: width * 0.65)
        }
    }
    
    // MARK: - Actions
    
    private func create() {
        guard canCreate, let room = selectedRoom else { return }
        
        draft.name = trimmedName
        draft.description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        // `room` also sets `roomReference`, which `createDefaultChores()` uses to place it.
        draft.room = room
        draft.roomDTO = RoomDTO(name: room.kind ?? room.name, symbol: room.symbol, color: room.color)
        draft.symbolName = room.symbol
        draft.isSelected = true
        
        HapticsManager.notify(.success)
        onCreate(draft, room)
        dismiss()
    }
}
