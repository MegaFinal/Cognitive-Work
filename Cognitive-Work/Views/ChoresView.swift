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
    
    /// Days whose section in the list layout the user has collapsed, keyed by
    /// ``DayGroup/id``.
    @State private var collapsedDays: Set<Date> = []
    
    /// Namespace used for matched geometry effect transitions between the list and carousel layouts.
    @Namespace private var cardAnimation
    
    // MARK: - List layout spacing
    
    private let listCardSpacing: CGFloat = 8
    
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
                } else if let occurrence = carouselVM.focusedOccurrence {
                    let _ = print("occurrence:", occurrence.assignment?.recordID?.recordName ?? "NIL",
                                  "chore:", occurrence.chore.name)
                    VStack {
                        Spacer()
                        CarouselCardFrame(
                            chore: occurrence.chore,
                            recurrentAssignment: occurrence.assignment,
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
                
                // MARK: - Unassigned chores popup, always on top of everything else
                if carouselVM.isShowingUnassignedList {
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .zIndex(2000)
                        .onTapGesture {
                            carouselVM.dismissUnassignedList()
                        }
                    
                    UnassignmentList(
                        items: carouselVM.unassignedItems,
                        onPick: { item in
                            Task { await carouselVM.pickForMyself(item) }
                        }, carouselViewModel: carouselVM
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 105)
                    .padding(.bottom, 20)
                    .zIndex(2100)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
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
        .task(id: carouselVM.activeIndex) {
            updateActiveRoomColor()
        }
        .task(id: carouselVM.dataVersion) {
            updateActiveRoomColor()
        }
        .task {
            // Keep chores in sync across devices without requiring a relaunch.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await carouselVM.fetchAllData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            carouselVM.requestRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            carouselVM.requestRefresh()
        }
        .alert(
            "Não foi possível excluir",
            isPresented: Binding(
                get: { carouselVM.errorMessage != nil },
                set: { if !$0 { carouselVM.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(carouselVM.errorMessage ?? "")
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
                    Menu {
                        FilterOptionsMenu(viewModel: carouselVM)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 22))
                            .foregroundColor(.black)
                            .padding(8)
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
    
    /// Vertical list rendering the chores
    private var choreList: some View {
        List {
            // One collapsible section per day, nearest day first — see `dayGroups`.
            ForEach(dayGroups) { group in
                VStack {
                    dayHeader(for: group)
                    
                    if !collapsedDays.contains(group.id) {
                        ForEach(group.occurrences) { item in
                            ChoreCardListStyle(
                                chore: item.occurrence.chore,
                                recurrentAssignment: item.occurrence.assignment,
                                namespace: cardAnimation,
                                carouselViewModel: carouselVM
                            ) {
                                carouselVM.focusDetailsImmediately(item.index)
                            }
                            .padding(.bottom, 10)
                        }
                        .onDelete { offsets in
                            deleteOccurrences(offsets.map { group.occurrences[$0].occurrence })
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPullDownAtTop(action: carouselVM.toggleLayout)
        .matchedGeometryEffect(id: "Spawnpoint", in: cardAnimation)
        .overlay {
            if !carouselVM.isLoading && carouselVM.visibleOccurrences.isEmpty {
                emptyChoreListState
            }
        }
    }
    
    /// Shown in place of ``choreList`` when the list layout has no chores to display —
    /// either because the house has none, or the active filter matches none.
    private var emptyChoreListState: some View {
        ContentUnavailableView(
            carouselVM.isFilterOn ? "Nenhuma tarefa encontrada" : "Nenhuma tarefa ainda",
            systemImage: "checklist",
            description: Text(
                carouselVM.isFilterOn
                ? "Nenhuma tarefa corresponde ao filtro selecionado."
                : "Toque em \"+\" para criar a primeira tarefa da casa."
            )
        )
    }
    
    // MARK: - Day grouping
    
    /// ``CarouselViewModel/visibleOccurrences`` split into one group per calendar day.
    ///
    /// The view model always sorts by day first, so each day's occurrences are already
    /// contiguous — this only has to cut the list wherever the day changes.
    private var dayGroups: [DayGroup] {
        let calendar = Calendar.current
        var groups: [DayGroup] = []
        
        for (index, occurrence) in carouselVM.visibleOccurrences.enumerated() {
            let day = occurrence.day.map { calendar.startOfDay(for: $0) }
            let item = IndexedOccurrence(index: index, occurrence: occurrence)
            
            if let last = groups.last, last.day == day {
                groups[groups.count - 1].occurrences.append(item)
            } else {
                groups.append(DayGroup(day: day, occurrences: [item]))
            }
        }
        
        return groups
    }
    
    /// A day's title row ("Hoje 23/09 ⌄"). Tapping it collapses or expands that day.
    private func dayHeader(for group: DayGroup) -> some View {
        let isCollapsed = collapsedDays.contains(group.id)
        
        return Button {
            if isCollapsed {
                collapsedDays.remove(group.id)
            } else {
                collapsedDays.insert(group.id)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(group.title)
                    .font(.system(size: 22, weight: .bold))
                
                if let dateText = group.dateText {
                    Text(dateText)
                        .font(.system(size: 17))
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                
                Spacer()
            }
            .foregroundStyle(.black)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    // MARK: - Actions
    
    /// Deletes the swiped occurrence(s)
    @MainActor
    private func deleteOccurrences(_ occurrencesToDelete: [ChoreOccurrence]) {
        for occurrence in occurrencesToDelete {
            let targetOccurrences = occurrence.assignment.map { [$0] } ?? []
            let snapshot = carouselVM.removeOccurrenceLocally(chore: occurrence.chore, targetOccurrences: targetOccurrences)
            
            Task {
                await carouselVM.persistDelete(chore: occurrence.chore, targetOccurrences: targetOccurrences, restoring: snapshot)
            }
        }
    }
    
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
    
    /// Today's chore statistics.
    private var dashboard: DashboardModel? {
        carouselVM.dashboard
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

/// A single scheduled occurrence of a chore: the chore itself plus the
/// assignment that places it on a given day.
///
/// One-off chores have no assignment; their date comes from `chore.dueDate`.
/// One day's section in the list layout.
private struct DayGroup: Identifiable {
    private static let locale = Locale(identifier: "pt_BR")
    
    /// The day, at its start; `nil` for occurrences with no date.
    let day: Date?
    var occurrences: [IndexedOccurrence]
    
    var id: Date { day ?? .distantFuture }
    
    /// "Hoje", "Amanhã", or the weekday's name ("Sexta-feira"). Past days never get a
    /// group — `CarouselViewModel` leaves them out of the list.
    var title: String {
        guard let day else { return "Sem data" }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Hoje" }
        if calendar.isDateInTomorrow(day) { return "Amanhã" }
        
        let weekday = day.formatted(.dateTime.weekday(.wide).locale(Self.locale))
        return weekday.prefix(1).uppercased() + weekday.dropFirst()
    }
    
    /// "25/09", or `nil` for the undated group.
    var dateText: String? {
        day?.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(Self.locale))
    }
}

/// An occurrence plus its position in ``CarouselViewModel/visibleOccurrences``, which the
/// details card's focus (`focusDetailsImmediately`) is indexed by.
private struct IndexedOccurrence: Identifiable {
    let index: Int
    let occurrence: ChoreOccurrence
    
    var id: String { occurrence.id }
}

struct ChoreOccurrence: Identifiable {
    let chore: ChoreModel
    let assignment: RecurrentAssignmentModel?
    
    var id: String {
        if let assignmentId = assignment?.recordID {
            return assignmentId.recordName
        }
        return chore.id.uuidString
    }
    
    var day: Date? {
        return assignment?.day ?? chore.dueDate
    }
}

#Preview("Lista de tarefas") {
    let vm: CarouselViewModel = {
        var cozinha = RoomModel(name: "Cozinha", symbol: "cooktop", color: .orange)
        cozinha.recordID = CKRecord.ID(recordName: "preview-cozinha")

        var banheiro = RoomModel(name: "Banheiro", symbol: "toilet", color: .blue)
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
