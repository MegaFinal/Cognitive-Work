//
//  RoomsManagementView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 06/10/26.
//

import SwiftUI

/// Shows the house's rooms as textured cards (same look as the onboarding room selection) and
/// lets the user create, edit and delete them.
///
/// - Tapping a card opens ``RoomFormSheet``, zooming out of the card.
/// - The trailing "+" card (or the toolbar "+") creates a room.
/// - "Editar" in the toolbar makes the cards wiggle and shows a delete badge on each one;
///   a long press offers the same actions in a context menu.
struct RoomsManagementView: View {
    @State private var viewModel: RoomsManagementViewModel
    
    /// Room being edited, or `nil` when the edit sheet is closed.
    @State private var roomBeingEdited: RoomModel?
    @State private var isCreatingRoom = false
    @State private var roomPendingDeletion: RoomModel?
    
    /// Delete mode: cards wiggle and show a delete badge.
    @State private var isEditing = false
    
    /// Drives the staggered entrance of the cards after the first load.
    @State private var hasAppeared = false
    
    private let columns = [GridItem(spacing: 16), GridItem(spacing: 16)]
    
    init(house: HouseModel?) {
        _viewModel = State(initialValue: RoomsManagementViewModel(house: house))
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                
                if viewModel.isLoading && viewModel.rooms.isEmpty {
                    loadingGrid
                } else {
                    roomsGrid
                }
            }
            .padding(.bottom, 30)
        }
        .refreshable {
            await viewModel.load()
        }
        .navigationTitle("Seus cômodos")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        .toolbar {
            if !viewModel.rooms.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "OK" : "Editar") {
                        HapticsManager.impact(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isEditing.toggle()
                        }
                    }
                    .fontWeight(isEditing ? .semibold : .regular)
                }
            }
        }
        .task {
            await viewModel.load()
            hasAppeared = true
        }
        .onChange(of: viewModel.rooms.isEmpty) { _, isEmpty in
            if isEmpty { isEditing = false }
        }
        .sheet(isPresented: $isCreatingRoom) {
            RoomFormSheet(room: nil) { name, color, symbol in
                let didSave = await viewModel.createRoom(name: name, color: color, symbol: symbol)
                // The sheet shows its own error, the screen's alert can't appear over it.
                if !didSave { viewModel.errorMessage = nil }
                return didSave
            }
        }
        .sheet(item: $roomBeingEdited) { room in
            RoomFormSheet(room: room) { name, color, symbol in
                let didSave = await viewModel.updateRoom(room, name: name, color: color, symbol: symbol)
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
                Task {
                    if await viewModel.deleteRoom(room) {
                        HapticsManager.notify(.success)
                    } else {
                        HapticsManager.notify(.error)
                    }
                }
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
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEditing
                 ? LocalizedStringKey("Toque no ícone vermelho para excluir um cômodo.")
                 : LocalizedStringKey("Toque em um cômodo para editá-lo ou no + para criar um novo."))
                .foregroundColor(.subTitleGray)
                .contentTransition(.opacity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Grid
    
    private var roomsGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(viewModel.rooms.enumerated()), id: \.element.id) { index, room in
                RoomCard(
                    room: room,
                    choreCount: viewModel.choreCount(for: room),
                    isEditing: isEditing,
                    wiggleDirection: index.isMultiple(of: 2) ? 1 : -1,
                    onDelete: { askToDelete(room) }
                )
                .onTapGesture {
                    HapticsManager.selection()
                    roomBeingEdited = room
                }
                .contextMenu {
                    Button {
                        roomBeingEdited = room
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        askToDelete(room)
                    } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                }
                .staggeredEntrance(index: index, isVisible: hasAppeared)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            
            AddRoomCard()
                .onTapGesture {
                    HapticsManager.selection()
                    isEditing = false
                    isCreatingRoom = true
                }
                .opacity(isEditing ? 0.4 : 1)
                .allowsHitTesting(!isEditing)
                .staggeredEntrance(index: viewModel.rooms.count, isVisible: hasAppeared)
        }
        .padding(.horizontal)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: viewModel.rooms.map(\.recordID))
    }
    
    /// Pulsing placeholders shown while the rooms load for the first time.
    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<4, id: \.self) { index in
                PulsingPlaceholder(delay: Double(index) * 0.1)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Deletion
    
    private func askToDelete(_ room: RoomModel) {
        HapticsManager.notify(.warning)
        roomPendingDeletion = room
    }
    
    private var deletionTitle: String {
        guard let roomPendingDeletion else { return "" }
        return L10n.tr("Excluir \"%@\"?", roomPendingDeletion.name.localizedDefault)
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

// MARK: - Room card

/// A room as a textured card in its color, with its icon, name and chore count — the same
/// visual language as the onboarding room cards.
private struct RoomCard: View {
    let room: RoomModel
    let choreCount: Int
    let isEditing: Bool
    /// 1 or -1, so neighbouring cards wiggle in opposite directions.
    let wiggleDirection: Double
    let onDelete: () -> Void
    
    @State private var isWiggling = false
    
    /// How far the card tilts while wiggling (0 when not in delete mode).
    private var wiggleAmplitude: Double {
        isEditing ? 1.6 * wiggleDirection : 0
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            card
                .rotationEffect(.degrees(isWiggling ? wiggleAmplitude : -wiggleAmplitude))
                .animation(
                    isEditing
                    ? .easeInOut(duration: 0.13).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.15),
                    value: isWiggling
                )
                .onAppear { isWiggling = isEditing }
                .onChange(of: isEditing) { _, editing in
                    isWiggling = editing
                }
            
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.red, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                }
                .buttonStyle(.plain)
                .offset(x: -8, y: -8)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Excluir \(room.name.localizedDefault)")
            }
        }
    }
    
    private var card: some View {
        ZStack {
            VStack(spacing: 14) {
                Image(systemName: room.symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .fontWeight(.light)
                
                Text(room.name.localizedDefault)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            
            Text(choreCountText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.white.opacity(0.85), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
                .contentTransition(.numericText())
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(RoomTextureBackground(room: room))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 6.85, x: 0, y: 4)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
    
    private var choreCountText: String {
        switch choreCount {
        case 0: L10n.tr("Nenhuma tarefa")
        case 1: L10n.tr("1 tarefa")
        default: L10n.tr("%lld tarefas", choreCount)
        }
    }
}

/// The trailing card that creates a new room.
private struct AddRoomCard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "plus")
                .font(.system(size: 40, weight: .light))
            Text("Novo cômodo")
                .fontWeight(.medium)
        }
        .foregroundStyle(.black.opacity(0.6))
        // Fill the whole square proposed by the grid — same size as ``RoomCard`` — instead of
        // shrinking to the icon and text, so the backgrounds below cover the full card.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 6.85, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.black.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .padding(8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Entrance animation

private extension View {
    /// Rises and fades the view in, one grid cell after the other.
    func staggeredEntrance(index: Int, isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 24)
            .scaleEffect(isVisible ? 1 : 0.92)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8).delay(Double(min(index, 10)) * 0.05),
                value: isVisible
            )
    }
}

// MARK: - Form sheet

/// Sheet used both to create a room (`room == nil`) and to edit an existing one.
///
/// The top of the sheet is the room's own texture, so the user sees the card change as they
/// pick a color or icon. Default room types (Quarto, Cozinha…) have a fixed color and icon, so
/// only their name can be changed; custom rooms can also pick a color and an icon.
struct RoomFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let room: RoomModel?
    /// Persists the form. Returns `true` when the sheet can close.
    let onSave: @MainActor (_ name: String, _ color: RoomColor, _ symbol: String) async -> Bool
    
    @State private var name: String
    @State private var selectedColor: RoomColor
    @State private var selectedSymbol: String
    @State private var isSaving = false
    @State private var didFailToSave = false
    /// Bumped on every save failure to shake the name field.
    @State private var failureCount = 0
    @FocusState private var isNameFocused: Bool
    
    private let symbolColumns = Array(repeating: GridItem(spacing: 12), count: 6)
    
    init(room: RoomModel?, onSave: @escaping @MainActor (_ name: String, _ color: RoomColor, _ symbol: String) async -> Bool) {
        self.room = room
        self.onSave = onSave
        _name = State(initialValue: room?.name ?? "")
        _selectedColor = State(initialValue: room?.color ?? .purple)
        _selectedSymbol = State(initialValue: room?.symbol ?? RoomsManagementViewModel.customRoomSymbol)
    }
    
    private var isEditingRoom: Bool { room != nil }
    
    private var isLookLocked: Bool {
        guard let room else { return false }
        return RoomsManagementViewModel.isDefaultType(room)
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
                VStack(spacing: 28) {
                    hero
                    nameField
                    
                    if isLookLocked {
                        Label("A cor e o ícone dos cômodos padrão não podem ser alterados.", systemImage: "lock.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        colorPicker
                        symbolPicker
                    }
                }
                .padding(.bottom, 30)
            }
            .ignoresSafeArea(edges: .top)
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(isEditingRoom ? "Editar Cômodo" : "Novo Cômodo")
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
                            save()
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
                if !isEditingRoom { isNameFocused = true }
            }
        }
    }
    
    // MARK: - Hero
    
    /// The room's texture across the top of the sheet, with its icon on a floating card.
    private var hero: some View {
        ZStack {
            RoomTextureBackground(color: selectedColor, pattern: pattern, zoom: 3)
                .id(selectedColor)
                .transition(.opacity)
            
            Image(systemName: selectedSymbol)
                .resizable()
                .scaledToFit()
                .fontWeight(.light)
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: selectedColor)
                .frame(width: 140, height: 140)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedColor.uiColor)
                        .shadow(color: .black.opacity(0.25), radius: 6.85, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                )
                .padding(.top, 50)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: selectedColor)
    }
    
    // MARK: - Name
    
    private var nameField: some View {
        VStack(spacing: 6) {
            TextField("Nome do Cômodo", text: $name)
                .characterLimit(TextLimits.roomName, text: $name)
                .focused($isNameFocused)
                .submitLabel(.done)
                .font(.system(size: 34))
                .bold()
                .multilineTextAlignment(.center)
            
            Capsule()
                .fill(isNameFocused ? selectedColor.uiColor : Color.primary.opacity(0.8))
                .frame(height: isNameFocused ? 3 : 1)
                .animation(.easeInOut(duration: 0.2), value: isNameFocused)
            
            Group {
                if isReservedName {
                    Text("Este nome é reservado para tarefas da casa toda.")
                } else if didFailToSave {
                    Text("Não foi possível salvar o cômodo. Verifique sua conexão e tente novamente.")
                }
            }
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .padding(.horizontal, 40)
        .modifier(ShakeEffect(shakes: CGFloat(failureCount)))
        .animation(.linear(duration: 0.4), value: failureCount)
        .animation(.easeInOut(duration: 0.2), value: isReservedName)
        .animation(.easeInOut(duration: 0.2), value: didFailToSave)
    }
    
    // MARK: - Color
    
    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Cor")
            
            HStack(spacing: 0) {
                ForEach(RoomColor.allCases) { color in
                    ColorSwatch(color: color, pattern: pattern, isSelected: selectedColor == color) {
                        HapticsManager.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            selectedColor = color
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Symbol
    
    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Ícone")
            
            LazyVGrid(columns: symbolColumns, spacing: 12) {
                ForEach(RoomsManagementViewModel.customRoomSymbols, id: \.self) { symbol in
                    let isSelected = selectedSymbol == symbol
                    
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        // Wide glyphs (car, gamecontroller…) shrink to fit instead of overflowing.
                        .frame(width: 24, height: 24)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        // Fill the whole grid cell as a square so the circle behind is full size.
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(
                            Circle()
                                .fill(isSelected ? selectedColor.uiColor : Color.gray.opacity(0.12))
                        )
                        .scaleEffect(isSelected ? 1.08 : 1)
                        .contentShape(Circle())
                        .onTapGesture {
                            HapticsManager.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                selectedSymbol = symbol
                            }
                        }
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
    }
    
    // MARK: - Save
    
    private func save() {
        guard !isSaving else { return }
        isNameFocused = false
        Task { @MainActor in
            isSaving = true
            didFailToSave = false
            let didSave = await onSave(trimmedName, selectedColor, selectedSymbol)
            isSaving = false
            
            if didSave {
                HapticsManager.notify(.success)
                dismiss()
            } else {
                HapticsManager.notify(.error)
                didFailToSave = true
                failureCount += 1
            }
        }
    }
}

/// Horizontal shake used when saving fails. Animating `shakes` by 1 plays one shake.
nonisolated private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = 10 * sin(shakes * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

/// Gray card that pulses while the rooms load.
private struct PulsingPlaceholder: View {
    let delay: Double
    @State private var isDimmed = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.gray.opacity(0.15))
            .aspectRatio(1, contentMode: .fit)
            .opacity(isDimmed ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(delay), value: isDimmed)
            .onAppear { isDimmed = true }
    }
}

private extension RoomTextureBackground {
    /// Same background with a different texture opacity.
    func withTextureOpacity(_ opacity: Double) -> Self {
        var copy = self
        copy.textureOpacity = opacity
        return copy
    }
}

/// A color option shown as a small textured circle of that color.
private struct ColorSwatch: View {
    let color: RoomColor
    let pattern: RoomTexturePattern
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        RoomTextureBackground(color: color, pattern: pattern, zoom: 1.5)
            .withTextureOpacity(0.35)
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(color.uiColor, lineWidth: 3)
                    .padding(-5)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.7)
            }
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isSelected ? 1.1 : 1)
            .shadow(color: .black.opacity(isSelected ? 0.2 : 0.08), radius: 4, y: 2)
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Cômodos") {
    NavigationStack {
        RoomsManagementView(house: HouseModel(name: "Casa", description: "Casa para o preview"))
    }
}

#Preview("Novo cômodo") {
    RoomFormSheet(room: nil) { _, _, _ in true }
}

#Preview("Editar cômodo padrão") {
    RoomFormSheet(room: RoomModel(name: "Cozinha", symbol: "cooktop", color: .yellow, kind: "Cozinha")) { _, _, _ in true }
}
