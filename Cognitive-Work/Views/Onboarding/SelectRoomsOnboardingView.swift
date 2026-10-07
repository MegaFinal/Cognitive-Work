//
//  FourthOnboardingView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 19/08/26.
//

import SwiftUI

/// The step where the user selects which rooms exist in their house
///
/// `FourthOnboardingView` renders the list of available rooms (from
/// ``OnboardingViewModel/availableRooms``) as a two-column grid of
/// ``OnboardingRoomCard`` items
///
/// Tapping a card toggles its selection state, tapping the dedicated "add" card
/// presents ``NewRoomSheet`` so the user can define a custom room
///
///  Confirming the selection persists the chosen rooms via
/// ``OnboardingViewModel/saveSelectedRooms()``.
struct SelectRoomsOnboardingView: View {

    // MARK: - Properties

    /// The shared onboarding view model, read from the environment
    @Binding var viewModel: OnboardingViewModel
    
    /// Whether the sheet for creating a custom room is currently presented
    @State private var isShowingCustomRoomSheet = false
    
    /// The room type whose quantity and names are being edited (after a long press), or `nil`.
    @State private var editingRoomID: UUID?
    
    /// The card being pressed right now, so it can shrink under the finger while the long
    /// press builds up.
    @State private var pressingRoomID: UUID?
    
    /// The editor's current height, measured so it can be flipped above its card when it
    /// wouldn't fit below.
    @State private var editorHeight: CGFloat = 0
    
    /// The two-column grid layout used to display room cards
    let columns = [GridItem(), GridItem()]

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                OnboardingHeader(
                    title: "Defina os cômodos",
                    description: "Escolha os ambientes presentes na sua residência, aperte e segure para editar seus nomes e quantidades."
                )
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.availableRooms) { roomDraft in
                        OnboardingRoomCard(
                            text: roomDraft.name,
                            symbol: roomDraft.symbol,
                            color: roomDraft.color,
                            pattern: roomDraft.texturePattern,
                            isSelected: roomDraft.isSelected,
                            quantity: roomDraft.quantity
                        )
                        .onTapGesture {
                            if !viewModel.isLoading {
                                if roomDraft.isAddButton {
                                    isShowingCustomRoomSheet = true
                                } else {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.toggleRoomSelection(id: roomDraft.id)
                                    }
                                }
                            }
                        }
                        // Long press opens the quantity/name editor for this room type. The card
                        // sinks while the finger is down, so the user sees something is happening.
                        .onLongPressGesture(minimumDuration: 0.25) {
                            guard !viewModel.isLoading, !roomDraft.isAddButton else { return }
                            startEditing(roomDraft)
                        } onPressingChanged: { isPressing in
                            guard !roomDraft.isAddButton || !isPressing else { return }
                            withAnimation(isPressing ? .easeOut(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.6)) {
                                pressingRoomID = isPressing ? roomDraft.id : nil
                            }
                        }
                        .scaleEffect(pressingRoomID == roomDraft.id ? 0.9 : 1)
                        .opacity(editingRoomID != nil && editingRoomID != roomDraft.id ? 0.55 : 1)
                        .anchorPreference(key: RoomCardBoundsKey.self, value: .bounds) {
                            [roomDraft.id: $0]
                        }
                    }
                }
                .padding(.horizontal)
                
                OnboardingProgressButton(text: "Continuar", isLoading: viewModel.isLoading, isDisabled: !viewModel.hasSelectedRooms) {
                    Task {
                        await viewModel.saveSelectedRooms()
                        // `isLoading` is always false here, even on failure; check the error instead.
                        if viewModel.errorMessage == nil {
                            viewModel.goToNextView()
                        }
                  }
                }
            }
            Spacer()
        }
        .overlayPreferenceValue(RoomCardBoundsKey.self) { cardBounds in
            if let editingRoomID,
               let index = viewModel.availableRooms.firstIndex(where: { $0.id == editingRoomID }) {
                GeometryReader { proxy in
                    let placement = editorPlacement(
                        cardFrame: cardBounds[editingRoomID].map { proxy[$0] },
                        in: proxy.size
                    )
                    
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture { stopEditing() }
                        
                        // The card being edited is redrawn above the dim, lifted, so it stays
                        // bright and it is clear which room the editor belongs to.
                        if let cardFrame = cardBounds[editingRoomID].map({ proxy[$0] }) {
                            let room = viewModel.availableRooms[index]
                            OnboardingRoomCard(
                                text: room.name,
                                symbol: room.symbol,
                                color: room.color,
                                pattern: room.texturePattern,
                                isSelected: true,
                                quantity: room.quantity
                            )
                            .scaleEffect(1.06)
                            .shadow(color: room.color.uiColor.opacity(0.55), radius: 14, x: 0, y: 6)
                            .position(x: cardFrame.midX, y: cardFrame.midY)
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                        
                        RoomQuantityEditor(room: $viewModel.availableRooms[index])
                            .frame(width: placement.width)
                            .onGeometryChange(for: CGFloat.self) { geometry in
                                geometry.size.height
                            } action: { height in
                                editorHeight = height
                            }
                            .offset(x: placement.origin.x, y: placement.origin.y)
                            .transition(.scale(scale: 0.9, anchor: placement.anchor).combined(with: .opacity))
                    }
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingCustomRoomSheet) {
            NewRoomSheet()
                .environment(viewModel)
                .presentationDetents([.large])
        }
        .onboardingBackButton(viewModel: viewModel)
        .navigationBarBackButtonHidden()
        .alert("Não foi possível salvar os cômodos", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Editing
    
    /// Opens the editor for a room type, selecting it too: setting how many rooms of a type
    /// the house has
    private func startEditing(_ room: RoomDTO) {
        HapticsManager.impact(.medium)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if !room.isSelected {
                viewModel.toggleRoomSelection(id: room.id)
            }
            editingRoomID = room.id
        }
    }
    
    private func editorPlacement(cardFrame: CGRect?, in size: CGSize) -> EditorPlacement {
        let margin: CGFloat = 16
        let gap: CGFloat = 8
        let width = min(size.width - margin * 2, 320)
        
        guard let cardFrame else {
            return EditorPlacement(
                origin: CGPoint(x: (size.width - width) / 2, y: max(margin, (size.height - editorHeight) / 2)),
                width: width,
                anchor: .center
            )
        }
        
        let isRightColumn = cardFrame.midX > size.width / 2
        let x = isRightColumn ? size.width - margin - width : margin
        
        var y = cardFrame.maxY + gap
        var opensBelow = true
        
        if y + editorHeight > size.height - margin {
            let above = cardFrame.minY - gap - editorHeight
            if above >= margin {
                y = above
                opensBelow = false
            } else {
                y = max(margin, size.height - margin - editorHeight)
            }
        }
        
        // Grows out of the corner closest to the card.
        let anchor: UnitPoint
        switch (isRightColumn, opensBelow) {
        case (true, true): anchor = .topTrailing
        case (false, true): anchor = .topLeading
        case (true, false): anchor = .bottomTrailing
        case (false, false): anchor = .bottomLeading
        }
        
        return EditorPlacement(origin: CGPoint(x: x, y: y), width: width, anchor: anchor)
    }
    
    private func stopEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        withAnimation(.easeOut(duration: 0.2)) {
            editingRoomID = nil
        }
    }
}

// MARK: - Editor placement

/// Where ``RoomQuantityEditor`` is drawn, relative to the screen's top-leading corner.
private struct EditorPlacement {
    var origin: CGPoint
    var width: CGFloat
    /// The corner it scales in from.
    var anchor: UnitPoint
}

/// Each room card's bounds, keyed by ``RoomDTO/id``, so the editor can open right under the
/// card being edited.
private struct RoomCardBoundsKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

// MARK: - Private subviews

/// A selectable card representing a single room.
///
/// The card displays an SF Symbol icon and a label. Its appearance flips between
/// an unselected (white background, black content) and selected (blue
/// background, white content) state depending on ``isSelected``.
///
/// Selection handling is applied by the parent view via a tap gesture.
private struct OnboardingRoomCard: View {
    
    var text: String
    var symbol: String
    var color: RoomColor
    var pattern: RoomTexturePattern
    var isSelected: Bool = false
    
    /// How many rooms of this type were set with a long press; shown as a badge above one.
    var quantity: Int = 1
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            
            if quantity > 1 {
                Text("×\(quantity)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? color.uiColor : .black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    .offset(x: -8, y: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: quantity)
    }
    
    private var content: some View {
        ZStack {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.2, height: height * 0.1)
                .padding(.bottom, 20)
                .foregroundColor(isSelected ? .white : .black)
            
            Text(L10n.tr(text))
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 20)
                .foregroundColor(isSelected ? .white : .black)
        }
        .frame(width: width * 0.42, height: height * 0.2)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .foregroundColor(isSelected ? color.uiColor : .white)
                .shadow(color: .black.opacity(0.25), radius: 6.85, x: 0, y: 4)
                .overlay {
                    if isSelected {
                        RoomTextureBackground(color: color, pattern: pattern)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
        )
    }
}

/// The card shown on a long press over a room type: how many rooms of that type the house
/// has, and each one's name.
private struct RoomQuantityEditor: View {
    
    @Binding var room: RoomDTO
    
    @FocusState private var focusedInstance: UUID?
    
    private let maxQuantity = 10
    private let maxNameLength = TextLimits.roomName
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Quantidade")
                    .font(.system(size: 22, weight: .bold))
                
                Spacer()
                
                quantityStepper
            }
            
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(room.instances.enumerated()), id: \.element.id) { index, instance in
                    nameRow(index: index, instance: instance)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 25))
        .onChange(of: focusedInstance) { _, _ in
            restoreDefaultForEmptyNames()
        }
    }
    
    // MARK: - Subviews
    
    private var quantityStepper: some View {
        HStack(spacing: 5) {
            Button {
                withAnimation(.snappy) { room.setQuantity(room.quantity - 1) }
            } label: {
                Image(systemName: "minus")
            }
            .foregroundStyle(room.quantity > 1 ? Color.black : Color.gray.opacity(0.5))
            .disabled(room.quantity <= 1)
            
            Text("\(room.quantity)")
                .font(.system(size: 22, weight: .semibold))
                .frame(minWidth: 24)
            
            Button {
                withAnimation(.snappy) { room.setQuantity(room.quantity + 1) }
            } label: {
                Image(systemName: "plus")
            }
            .foregroundStyle(room.quantity < maxQuantity ? Color.black : Color.gray.opacity(0.5))
            .disabled(room.quantity >= maxQuantity)
        }
        .font(.system(size: 22, weight: .medium))
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.06), in: Capsule())
    }
    
    private func nameRow(index: Int, instance: RoomInstanceDTO) -> some View {
        let name = nameBinding(at: index)
        
        return HStack {
            TextField(room.instanceName(at: index), text: name)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .focused($focusedInstance, equals: instance.id)
                .submitLabel(.done)
                .characterLimit(maxNameLength, text: name)
            
            Button {
                focusedInstance = instance.id
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Names
    
    /// Reads the room's current name (custom or default); writing stores it as a custom name.
    private func nameBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { room.instanceName(at: index) },
            set: { newName in
                guard room.instances.indices.contains(index) else { return }
                room.instances[index].customName = newName
            }
        )
    }
    
    /// A name left empty goes back to the default one once the field loses focus.
    private func restoreDefaultForEmptyNames() {
        for index in room.instances.indices {
            let customName = room.instances[index].customName ?? ""
            if room.instances[index].customName != nil,
               customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                room.instances[index].customName = nil
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = OnboardingViewModel()
    return SelectRoomsOnboardingView(viewModel: $viewModel)
}
