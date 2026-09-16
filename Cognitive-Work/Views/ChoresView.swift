//
//  ChoresView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 25/08/26.
//

import SwiftUI
import CloudKit

/// The primary view for displaying and managing the user's chores.
///
/// `ChoresView` coordinates the display of chores in either a carousel (grid) or a vertical list format.
/// It integrates a progress section, layout toggles, and floating action buttons for creating new chores.
struct ChoresView: View {
    
    /// The view model controlling the state and data of the chores carousel.
    @State var carouselVM = CarouselViewModel()
    
    /// The dominant color derived from the currently focused chore's room.
    @State private var activeRoomColor: Color = .gray

    /// Today's chore statistics
    @State private var dashboard: DashboardModel?

    /// Namespace used for matched geometry effect transitions between the list and carousel layouts.
    @Namespace private var cardAnimation
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    /// Creates the view, optionally injecting a pre-populated view model (used by previews and tests).
    init(carouselVM: CarouselViewModel = CarouselViewModel()) {
        self._carouselVM = State(initialValue: carouselVM)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Header, progress cards and action buttons
                VStack(spacing: 3) {
                    VStack(spacing: 15) {
                        header
                        progressSection
                    }
                    
                    Spacer()
                        .matchedGeometryEffect(id: "Spawnpoint", in: cardAnimation)
                    
                    if carouselVM.layoutMode != .grid {
                        choreList
                            .zIndex(1000)
                    }
                }
                
                VStack {
                    Spacer()
                    ChoresViewButtonsSection(carouselViewModel: carouselVM)
                }
                
                // MARK: - Darkening the view if there's a focused card
                if carouselVM.hasFocusedCard {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .zIndex(1)
                        .transition(.opacity)
                        .onTapGesture {
                            dismissFocusedCard()
                        }
                }
                
                // MARK: - Chore Card layout conditionals
                if carouselVM.layoutMode == .grid {
                    VStack {
                        Spacer()
                        Carousel(
                            viewModel: carouselVM,
                            isBackgroundClear: true,
                            onSwipeDown: carouselVM.toggleLayout, namespace: cardAnimation
                        )
                        .padding(.top, 70)
                        Spacer()
                    }
                    .zIndex(2)
                } else if let focusedChore = carouselVM.focusedChoreForDetails {
                    VStack {
                        Spacer()
                        CarouselCardFrame(
                            chore: focusedChore,
                            carouselViewModel: carouselVM,
                            namespace: cardAnimation,
                            isFocused: true,
                            rotation: 180,
                            isShowingBack: true
                        )
                        Spacer()
                    }
                    .zIndex(2)
                    .transition(.scale)
                }
            }
            .background(
                Color(.white)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissFocusedCard()
                    }
            )
        }
        .task {
            await carouselVM.fetchAllData()
            updateActiveRoomColor()
        }
        .task {
            await loadDashboard()
        }
        .task(id: carouselVM.activeIndex) {
            updateActiveRoomColor()
        }
        .task(id: carouselVM.cardModels.count) {
            updateActiveRoomColor()
        }
    }
    
    // MARK: - Subviews
    
    /// Page title alongside the layout toggle control.
    private var header: some View {
        HStack {
            Text("Suas Tarefas")
                .font(.system(size: 34))
                .fontWeight(.bold)
                .padding(.horizontal, 30)
                .padding(.top, 20)
            
            Spacer()
            
            HStack (spacing: 4) {
                Button {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        carouselVM.toggleLayout()
                    }
                } label: {
                    Image(systemName: carouselVM.layoutMode == .grid ? "inset.filled.leftthird.middlethird.rightthird.rectangle" : "inset.filled.topthird.middlethird.bottomthird.rectangle")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                        .padding(8)
                }
                
                if carouselVM.layoutMode == .list {
                    Button {
                        carouselVM.isSelectingFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 22))
                            .foregroundColor(.black)
                            .padding(8)
                    }
                    .popover(isPresented: $carouselVM.isSelectingFilter) {
                        FilterOptionsMenu(viewModel: carouselVM)
                            .frame(width: 250)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .glassEffect(
                .regular.interactive(),
                in: .capsule
            )
            .padding(.top, 20)
            .padding(.trailing, 30)
        }
    }
    
    /// Informational segment displaying metric-based progress cards.
    ///
    /// Each card is bound to a different statistic from ``dashboard``
    private var progressSection: some View {
        let cardColor = carouselVM.layoutMode == .grid ? activeRoomColor : .black

        return HStack(spacing: 10) {
            ProgressIndicatorCard(
                title: "Tempo médio",
                data: dashboard?.totalTimeFormatted ?? "0h00",
                color: cardColor
            )
            ProgressIndicatorCard(
                title: "A fazer",
                data: "\(dashboard?.toDo ?? 0) tarefas",
                color: cardColor
            )
            ProgressIndicatorCard(
                title: "Concluído",
                data: dashboard?.completionPercentageString ?? "0%",
                color: cardColor
            )
        }
        .padding(.horizontal, 30)
        .animation(.easeInOut, value: activeRoomColor)
    }
    
    /// Vertical scroll view rendering the chores in a list format.
    private var choreList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ForEach(Array(carouselVM.visibleChores.enumerated()), id: \.element.id) { index, chore in
                    ChoreCardListStyle(chore: chore, namespace: cardAnimation, carouselViewModel: carouselVM) {
                        carouselVM.focusDetailsImmediately(index)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .onPullDownAtTop(action: carouselVM.toggleLayout)
        .matchedGeometryEffect(id: "Spawnpoint", in: cardAnimation)
    }
    
    // MARK: - Actions
    
    /// Dismisses the currently focused card based on the active layout mode.
    private func dismissFocusedCard() {
        if carouselVM.layoutMode == .grid {
            carouselVM.clearFocus()
        } else {
            carouselVM.clearFocusedDetails()
        }
    }

    /// Updates the background color of the progress section locally to match the focused chore's room color.
    private func updateActiveRoomColor() {
        guard !carouselVM.visibleChores.isEmpty,
              carouselVM.visibleChores.indices.contains(carouselVM.activeIndex) else {
            activeRoomColor = .gray
            return
        }

        let centeredChore = carouselVM.visibleChores[carouselVM.activeIndex]

        if let room = carouselVM.getRoom(for: centeredChore) {
            activeRoomColor = room.color.uiColor
        } else {
            activeRoomColor = .gray
        }
    }

    /// Loads the signed-in user's profile and uses it to build and populate
    private func loadDashboard() async {
        guard let user = await CloudKitManager.shared.fetchMyUser() else { return }

        let model = DashboardModel(user: user)
        await model.setup()
        self.dashboard = model
    }
}

// MARK: - Private subviews

/// Renders statistics paired with a title tag.
private struct ProgressIndicatorCard: View {
    
    /// Short label indicating the metric meaning.
    var title: String
    
    /// Formatted data result (e.g., "1h 30m").
    var data: String
    
    /// Visual thematic backdrop color applying depth over UI layouts.
    var color: Color = .gray
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 12))
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 10)
            
            Spacer()
            
            Text(data)
                .font(.system(size: 15))
                .fontWeight(.bold)
                .padding(.bottom, 25)
                .foregroundColor(.white)
        }
        .frame(width: width * 0.28, height: height * 0.088)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 21))
        .shadow(color: .black.opacity(0.25), radius: 4.07717, x: 0, y: 1.23551)
    }
}

#Preview("Lista de tarefas") {
    let vm: CarouselViewModel = {
        var cozinha = RoomModel(name: "Cozinha", color: .orange)
        cozinha.recordID = CKRecord.ID(recordName: "preview-cozinha")

        var banheiro = RoomModel(name: "Banheiro", color: .blue)
        banheiro.recordID = CKRecord.ID(recordName: "preview-banheiro")

        func makeChore(_ name: String, symbol: String, room: RoomModel, frequency: Recurrence, duration: Double, priority: PriorityTag) -> ChoreModel {
            let chore = ChoreModel(
                name: name,
                description: "Descrição da tarefa \(name.lowercased()).",
                frequency: frequency,
                duration: duration,
                isPublic: true,
                priorityTag: priority,
                roomReference: room.recordID.map { CKRecord.Reference(recordID: $0, action: .none) }
            )
            chore.symbolName = symbol
            chore.recordID = CKRecord.ID(recordName: "preview-\(UUID().uuidString)")
            return chore
        }

        let vm = CarouselViewModel()
        vm.roomModels = [cozinha, banheiro]
        vm.cardModels = [
            makeChore("Lavar a louça", symbol: "dishwasher", room: cozinha,
                      frequency: .daily, duration: 20, priority: .medium),
            makeChore("Limpar o box", symbol: "shower", room: banheiro,
                      frequency: .weekly, duration: 45, priority: .high),
            makeChore("Organizar a despensa", symbol: "cabinet", room: cozinha,
                      frequency: .monthly, duration: 90, priority: .low)
        ]
        return vm
    }()

    ChoresView(carouselVM: vm)
}
