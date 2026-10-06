//
//  RoomsManagementView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 06/10/26.
//

import SwiftUI

/// Lists the house's rooms and lets the user create, edit and delete them.
///
/// Reached from ``HouseSettingsView``. Tapping a row (or swiping it) edits the room, the "+"
/// toolbar button creates a new one and the trailing swipe deletes it — together with its chores,
/// after a confirmation.
struct RoomsManagementView: View {
    @State private var viewModel: RoomsManagementViewModel
    
    /// Room being edited, or `nil` when the edit sheet is closed.
    @State private var roomBeingEdited: RoomModel?
    @State private var isCreatingRoom = false
    @State private var roomPendingDeletion: RoomModel?
    
    init(house: HouseModel?) {
        _viewModel = State(initialValue: RoomsManagementViewModel(house: house))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.rooms.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.rooms.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum cômodo", systemImage: "square.split.bottomrightquarter")
                } description: {
                    Text("Adicione os cômodos da sua casa para organizar as tarefas.")
                } actions: {
                    Button("Adicionar cômodo") {
                        isCreatingRoom = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                roomsList
            }
        }
        .navigationTitle("Cômodos")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreatingRoom = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Adicionar cômodo")
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $isCreatingRoom) {
            RoomFormSheet(room: nil) { name, color in
                let didSave = await viewModel.createRoom(name: name, color: color)
                // The sheet shows its own error, the list's alert can't appear over it.
                if !didSave { viewModel.errorMessage = nil }
                return didSave
            }
        }
        .sheet(item: $roomBeingEdited) { room in
            RoomFormSheet(room: room) { name, color in
                let didSave = await viewModel.updateRoom(room, name: name, color: color)
                if !didSave { viewModel.errorMessage = nil }
                return didSave
            }
        }
        .alert(
            deletionTitle,
            isPresented: Binding(
                get: { roomPendingDeletion != nil },
                set: { if !$0 { roomPendingDeletion = nil } }
            ),
            presenting: roomPendingDeletion
        ) { room in
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                Task { await viewModel.deleteRoom(room) }
            }
        } message: { room in
            Text(deletionMessage(for: room))
        }
        .alert(
            "Algo deu errado",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .blockingOperation(isPresented: $viewModel.isDeleting, message: "Excluindo cômodo...")
    }
    
    // MARK: - List
    
    private var roomsList: some View {
        List {
            Section {
                ForEach(viewModel.rooms) { room in
                    Button {
                        roomBeingEdited = room
                    } label: {
                        RoomRow(room: room, choreCount: viewModel.choreCount(for: room))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            roomPendingDeletion = room
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                        
                        Button {
                            roomBeingEdited = room
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            roomBeingEdited = room
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            roomPendingDeletion = room
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("Toque em um cômodo para editá-lo ou deslize para excluí-lo.")
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }
    
    // MARK: - Deletion copy
    
    private var deletionTitle: String {
        guard let roomPendingDeletion else { return "" }
        return L10n.tr("Excluir \"%@\"?", roomPendingDeletion.name)
    }
    
    private func deletionMessage(for room: RoomModel) -> String {
        let count = viewModel.choreCount(for: room)
        switch count {
        case 0:
            return L10n.tr("Esta ação não pode ser desfeita.")
        case 1:
            return L10n.tr("A tarefa deste cômodo também será excluída. Esta ação não pode ser desfeita.")
        default:
            return L10n.tr("As %lld tarefas deste cômodo também serão excluídas. Esta ação não pode ser desfeita.", count)
        }
    }
}

// MARK: - Row

/// A room in the list: its colored, textured icon, its name and how many chores it has.
private struct RoomRow: View {
    let room: RoomModel
    let choreCount: Int
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: room.symbol)
                .font(.title3)
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background(RoomTextureBackground(room: room, zoom: 1.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(choreCountText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
    
    private var choreCountText: String {
        switch choreCount {
        case 0: L10n.tr("Nenhuma tarefa")
        case 1: L10n.tr("1 tarefa")
        default: L10n.tr("%lld tarefas", choreCount)
        }
    }
}

// MARK: - Form sheet

/// Sheet used both to create a room (`room == nil`) and to edit an existing one.
///
/// Default room types (Quarto, Cozinha…) have a fixed color and icon, so only their name can be
/// changed; custom rooms can also pick a color.
struct RoomFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let room: RoomModel?
    /// Persists the form. Returns `true` when the sheet can close.
    let onSave: (_ name: String, _ color: RoomColor) async -> Bool
    
    @State private var name: String
    @State private var selectedColor: RoomColor
    @State private var isSaving = false
    @State private var didFailToSave = false
    @FocusState private var isNameFocused: Bool
    
    init(room: RoomModel?, onSave: @escaping (_ name: String, _ color: RoomColor) async -> Bool) {
        self.room = room
        self.onSave = onSave
        _name = State(initialValue: room?.name ?? "")
        _selectedColor = State(initialValue: room?.color ?? .yellow)
    }
    
    private var isEditing: Bool { room != nil }
    
    private var isColorLocked: Bool {
        guard let room else { return false }
        return RoomsManagementViewModel.isDefaultType(room)
    }
    
    private var symbol: String {
        room?.symbol ?? RoomsManagementViewModel.customRoomSymbol
    }
    
    private var pattern: RoomTexturePattern {
        room?.texturePattern ?? .fallback
    }
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
    
    private var isReservedName: Bool {
        RoomsManagementViewModel.isReservedName(trimmedName)
    }
    
    private var canSave: Bool {
        !trimmedName.isEmpty && !isReservedName && !isSaving
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // MARK: Preview card
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundStyle(.black)
                        .frame(width: 160, height: 160)
                        .background(RoomTextureBackground(color: selectedColor, pattern: pattern))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // MARK: Name
                    VStack(spacing: 6) {
                        TextField("Nome do Cômodo", text: $name)
                            .characterLimit(TextLimits.roomName, text: $name)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .font(.system(size: 34))
                            .bold()
                            .multilineTextAlignment(.center)
                        
                        Rectangle()
                            .frame(height: 1)
                        
                        if isReservedName {
                            Text("Este nome é reservado para tarefas da casa toda.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else if didFailToSave {
                            Text("Não foi possível salvar o cômodo. Verifique sua conexão e tente novamente.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // MARK: Color
                    if isColorLocked {
                        Text("A cor e o ícone dos cômodos padrão não podem ser alterados.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    } else {
                        HStack(spacing: 25) {
                            ForEach(RoomColor.allCases) { color in
                                ColorSwatch(color: color, isSelected: selectedColor == color) {
                                    withAnimation(.spring) {
                                        selectedColor = color
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 30)
            }
            .navigationTitle(isEditing ? "Editar Cômodo" : "Novo Cômodo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                isSaving = true
                                didFailToSave = false
                                let didSave = await onSave(trimmedName, selectedColor)
                                isSaving = false
                                didFailToSave = !didSave
                                if didSave { dismiss() }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .dismissKeyboardOnTap()
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                if !isEditing { isNameFocused = true }
            }
        }
    }
}

/// A single color swatch used to pick a room's color.
private struct ColorSwatch: View {
    let color: RoomColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(color.uiColor)
            .frame(width: 34, height: 34)
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(.blue, lineWidth: 2.5)
                        .padding(-3)
                }
            }
            .onTapGesture(perform: action)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Lista") {
    NavigationStack {
        RoomsManagementView(house: HouseModel(name: "Casa", description: "Casa para o preview"))
    }
}

#Preview("Formulário") {
    RoomFormSheet(room: nil) { _, _ in true }
}
