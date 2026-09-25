//
//  ChoreListLayout.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI
import UIKit

/// The list layout of the chores screen: occurrences grouped under one collapsible title per
/// day ("Hoje 23/09 ⌄"), nearest day first, each card with a custom swipe-to-delete.
struct ChoreListLayout: View {
    
    /// The carousel view model controlling the global collection of chores.
    @Bindable var viewModel: CarouselViewModel
    
    /// Closure triggered to dismiss or toggle the layout context.
    let onSwipeDown: () -> Void
    
    /// Namespace required for geometric transitions into the grid view.
    let namespace: Namespace.ID
    
    /// Days the user has collapsed, keyed by ``DayGroup/id``.
    @State private var collapsedDays: Set<Date> = []
    
    /// The occurrence whose delete button is currently revealed. Only one at a time: revealing
    /// another closes it, and tapping any card closes it instead of opening the details.
    @State private var revealedOccurrenceID: String?
    
    /// Whether the list is currently pulled down past its top edge by more than
    /// ``pullDownThreshold``. Only flips when crossing the threshold, so scrolling doesn't
    /// re-render the list every frame.
    @State private var isPulledPastThreshold = false
    
    /// How far past the top (in points) the list must be pulled, on release, to switch back
    /// to the carousel.
    private let pullDownThreshold: CGFloat = 70
    
    // MARK: - Spacing
    
    /// Gap between two cards of the same day.
    private let cardSpacing: CGFloat = 18
    
    /// Gap between a day's title and its first card.
    private let titleToCardSpacing: CGFloat = 20
    
    /// Gap above each day's title, separating it from the previous day.
    private let daySpacing: CGFloat = 20
    
    /// Look and feel of the swipe-to-delete — see ``SwipeToDeleteStyle``.
    private let swipeStyle = SwipeToDeleteStyle()
    
    init(viewModel: CarouselViewModel, onSwipeDown: @escaping () -> Void, namespace: Namespace.ID) {
        self.viewModel = viewModel
        self.onSwipeDown = onSwipeDown
        self.namespace = namespace
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(dayGroups) { group in
                    dayTitle(for: group)
                        .padding(.top, daySpacing)
                        .padding(.bottom, titleToCardSpacing)
                    
                    if !collapsedDays.contains(group.id) {
                        VStack(spacing: cardSpacing) {
                            ForEach(group.occurrences) { item in
                                card(for: item)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            -(geometry.contentOffset.y + geometry.contentInsets.top) > pullDownThreshold
        } action: { _, isPastThreshold in
            isPulledPastThreshold = isPastThreshold
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            if oldPhase == .interacting, newPhase != .interacting, isPulledPastThreshold {
                onSwipeDown()
            }
        }
        .matchedGeometryEffect(id: "Spawnpoint", in: namespace)
        .overlay {
            if !viewModel.isLoading && viewModel.visibleOccurrences.isEmpty {
                emptyState
            }
        }
    }
    
    // MARK: - Subviews
    
    /// One card, wrapped in the swipe-to-delete.
    private func card(for item: IndexedOccurrence) -> some View {
        SwipeToDeleteRow(
            id: item.id,
            revealedID: $revealedOccurrenceID,
            style: swipeStyle,
            onDelete: { delete(item.occurrence) }
        ) {
            ChoreCardListStyle(
                chore: item.occurrence.chore,
                recurrentAssignment: item.occurrence.assignment,
                namespace: namespace,
                carouselViewModel: viewModel
            ) {
                if revealedOccurrenceID != nil {
                    withAnimation(.snappy) { revealedOccurrenceID = nil }
                } else {
                    viewModel.focusDetailsImmediately(item.index)
                }
            }
        }
    }
    
    /// A day's title ("Hoje 23/09 ⌄"). Tapping it collapses or expands that day.
    private func dayTitle(for group: DayGroup) -> some View {
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
            }
            .foregroundStyle(.black)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: width * 0.92, alignment: .leading)
    }
    
    /// Shown when there's nothing to list — either the house has no chores, or the active
    /// filter matches none.
    private var emptyState: some View {
        ContentUnavailableView(
            viewModel.isFilterOn ? "Nenhuma tarefa encontrada" : "Nenhuma tarefa ainda",
            systemImage: "checklist",
            description: Text(
                viewModel.isFilterOn
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
        
        for (index, occurrence) in viewModel.visibleOccurrences.enumerated() {
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
    
    // MARK: - Actions
    
    /// Deletes an occurrence: only that day for a recurring chore (the chore and its other
    /// occurrences are left alone), or the whole chore for a one-off one.
    @MainActor
    private func delete(_ occurrence: ChoreOccurrence) {
        let targetOccurrences = occurrence.assignment.map { [$0] } ?? []
        
        let snapshot: CarouselViewModel.RemovedOccurrenceSnapshot = withAnimation(.snappy) {
            revealedOccurrenceID = nil
            return viewModel.removeOccurrenceLocally(chore: occurrence.chore, targetOccurrences: targetOccurrences)
        }
        
        Task {
            await viewModel.persistDelete(chore: occurrence.chore, targetOccurrences: targetOccurrences, restoring: snapshot)
        }
    }
}

// MARK: - Swipe to delete

/// How the list's swipe-to-delete looks and behaves. Change the defaults here to adjust it.
struct SwipeToDeleteStyle {
    
    /// Width of the revealed delete button.
    var buttonWidth: CGFloat = 76
    
    /// Gap between the card and the button once it's revealed.
    var gap: CGFloat = 10
    
    /// Corner radius of the button. The card's own is 25.
    var cornerRadius: CGFloat = 25
    
    var topInset: CGFloat = 38
    
    var backgroundColor: Color = .red
    var foregroundColor: Color = .white
    var systemImage: String = "trash.fill"
    
    /// Label under the icon; `nil` shows the icon alone.
    var title: String? = "Excluir"
    
    /// Dragging the card past this fraction of the row's width and letting go deletes right
    /// away, without tapping the button (like iOS's own "full swipe").
    var fullSwipeFraction: CGFloat = 0.55
    
    /// Animation used to open, close and dismiss the card.
    var animation: Animation = .snappy
}

/// Wraps a card with a left swipe that slides it aside to reveal a delete button.
private struct SwipeToDeleteRow<Content: View>: View {
    
    let id: String
    
    /// Which row is revealed; shared by every row so only one can be open at a time.
    @Binding var revealedID: String?
    
    let style: SwipeToDeleteStyle
    let onDelete: () -> Void
    let content: Content
    
    /// Live horizontal translation of the drag in progress (0 when idle).
    @State private var dragTranslation: CGFloat = 0
    
    /// Whether the current drag is past the full-swipe threshold, so the haptic only fires
    /// when crossing it.
    @State private var isPastFullSwipe = false
    
    /// Set once deleting starts, sliding the card off screen.
    @State private var isDeleting = false
    
    @State private var rowWidth: CGFloat = 0
    
    init(
        id: String,
        revealedID: Binding<String?>,
        style: SwipeToDeleteStyle,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self._revealedID = revealedID
        self.style = style
        self.onDelete = onDelete
        self.content = content()
    }
    
    private var isRevealed: Bool { revealedID == id }
    
    /// How far the card slides to reveal the button.
    private var revealDistance: CGFloat { style.buttonWidth + style.gap }
    
    private var fullSwipeDistance: CGFloat { rowWidth * style.fullSwipeFraction }
    
    /// The card's current horizontal offset (always ≤ 0: it only ever slides left).
    private var offset: CGFloat {
        if isDeleting { return -(rowWidth + revealDistance) }
        let resting: CGFloat = isRevealed ? -revealDistance : 0
        return min(0, resting + dragTranslation)
    }
    
    /// 0 with the card at rest, 1 once it has slid far enough to fully show the button.
    private var revealProgress: CGFloat {
        guard revealDistance > 0 else { return 0 }
        return min(1, -offset / revealDistance)
    }
    
    var body: some View {
        content
            .background(alignment: .trailing) {
                deleteButton
                    .offset(x: -offset)
            }
            .offset(x: offset)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { rowWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, newWidth in rowWidth = newWidth }
                }
            }
            .gesture(swipeGesture)
    }
    
    private var deleteButton: some View {
        Button(action: dismissAndDelete) {
            VStack(spacing: 4) {
                Image(systemName: style.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                
                if let title = style.title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(style.foregroundColor)
            .frame(width: style.buttonWidth)
            .frame(maxHeight: .infinity)
            .background(style.backgroundColor, in: RoundedRectangle(cornerRadius: style.cornerRadius))
        }
        .buttonStyle(.plain)
        .padding(.top, style.topInset)
        .opacity(revealProgress)
        .scaleEffect(0.8 + 0.2 * revealProgress)
        .allowsHitTesting(isRevealed && !isDeleting)
    }

    private var swipeGesture: HorizontalPanGesture {
        HorizontalPanGesture(
            onBegan: {
                guard !isDeleting else { return }
                if let revealedID, revealedID != id {
                    withAnimation(style.animation) { self.revealedID = nil }
                }
            },
            onChanged: { translation in
                guard !isDeleting else { return }
                dragTranslation = translation
                
                let pastFullSwipe = -offset > fullSwipeDistance
                if pastFullSwipe != isPastFullSwipe {
                    isPastFullSwipe = pastFullSwipe
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            },
            onEnded: { translation, velocity, wasCancelled in
                defer { isPastFullSwipe = false }
                guard !isDeleting else { return }
                
                if !wasCancelled, -offset > fullSwipeDistance {
                    dismissAndDelete()
                    return
                }
                
                let resting: CGFloat = isRevealed ? -revealDistance : 0
                let projected = resting + translation + (wasCancelled ? 0 : velocity * 0.25)
                
                withAnimation(style.animation) {
                    dragTranslation = 0
                    revealedID = -projected > revealDistance / 2 ? id : (isRevealed ? nil : revealedID)
                }
            }
        )
    }
    
    /// Slides the card off screen, then deletes it.
    private func dismissAndDelete() {
        guard !isDeleting else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        
        withAnimation(style.animation) {
            isDeleting = true
            dragTranslation = 0
        } completion: {
            onDelete()
        }
    }
}

// MARK: - Horizontal pan

/// A pan that only ever *begins* for a mostly-horizontal drag.
///
/// A vertical drag makes this recognizer fail right away (`gestureRecognizerShouldBegin`),
/// so the enclosing `ScrollView` always gets vertical scrolling
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    
    /// Called once, when a horizontal drag is recognized.
    var onBegan: () -> Void
    
    /// Called with the horizontal translation (points) as the drag moves.
    var onChanged: (CGFloat) -> Void
    
    /// Called when the drag finishes, with the final horizontal translation
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat, _ wasCancelled: Bool) -> Void
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        
        switch recognizer.state {
        case .began:
            onBegan()
            onChanged(translation)
        case .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation, recognizer.velocity(in: recognizer.view).x, false)
        case .cancelled, .failed:
            onEnded(translation, 0, true)
        default:
            break
        }
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Only start for drags that move more sideways than up/down.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

// MARK: - Grouping models

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
