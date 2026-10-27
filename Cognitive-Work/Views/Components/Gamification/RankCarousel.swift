//
//  RankCarousel.swift
//  Cognitive-Work
//
//  Created by Jonas Melo on 19/10/26.
//

import SwiftUI
import CloudKit

/// The rewards tab's ranks: one fixed card with the progress arc in the middle, showing one cycle
/// at a time.
///
/// It opens on the current cycle. Dragging to the right goes back to older cycles, dragging to the
/// left comes back; the chevrons do the same. The card itself never moves: the arc fills or empties
/// to the selected cycle and the texts and the rank icon change with an animation. The arc shows
/// how far that cycle got into its division (full at Mestre, the top of the ladder).
struct RankCarousel: View {

    /// The signed-in user's points in the current cycle.
    let points: Int

    /// Past cycles, oldest first.
    let history: [RankHistoryModel]

    /// Height of the card.
    static let cardHeight: CGFloat = 236

    /// Index in ``items`` chosen by the user; `nil` follows the current cycle (the last one).
    @State private var chosenIndex: Int?

    /// Side the new content comes in from, so it follows the drag.
    @State private var incomingEdge: Edge = .trailing

    /// Swaps the slide animations for fades when the user asked for less motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Past cycles, then the current one.
    private var items: [RankItem] {
        history.map { RankItem(progress: Tier.progress(forPoints: $0.points), kind: .past($0)) }
            + [RankItem(progress: Tier.progress(forPoints: points), kind: .current)]
    }

    /// The cycle shown right now.
    private var index: Int {
        min(chosenIndex ?? items.count - 1, items.count - 1)
    }

    /// Whether there is an older cycle to go back to.
    private var canGoBack: Bool { index > 0 }
    /// Whether there is a newer cycle to go to.
    private var canGoForward: Bool { index < items.count - 1 }

    var body: some View {
        let item = items[index]

        VStack(spacing: 8) {
            // MARK: - Cycle title
            // Each changing part sits in a ZStack, so the outgoing and incoming versions overlap
            // during the animation instead of stacking up.
            ZStack {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.subTitleGray)
                    .id("title-\(index)")
                    .transition(textTransition)
            }

            // MARK: - Chevrons, arc and rank icon
            HStack(spacing: 0) {
                chevron("chevron.left", enabled: canGoBack) { go(by: -1) }

                ZStack(alignment: .bottom) {
                    // Fixed: only its fill and color change.
                    RankArc(progress: item.fraction, tint: item.tint)
                        .frame(width: 190, height: 102)

                    Image(item.progress.tier.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .id("icon-\(index)")
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity)

                chevron("chevron.right", enabled: canGoForward) { go(by: 1) }
            }

            // MARK: - Rank name and detail
            ZStack {
                VStack(spacing: 4) {
                    Text(item.progress.tier.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.titleGray)

                    Text(item.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(.subTitleGray)
                        .multilineTextAlignment(.center)
                }
                .id("info-\(index)")
                .transition(textTransition)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: Self.cardHeight)
        // Keeps the sliding texts inside the card.
        .clipped()
        // MARK: - Card background and swipe to change cycle
        .background(
            Color(.systemGray6).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let horizontal = value.translation.width
                    guard abs(horizontal) > 50, abs(horizontal) > abs(value.translation.height) else { return }
                    // Right → older cycles, left → newer.
                    go(by: horizontal > 0 ? -1 : 1)
                }
        )
        .padding(.horizontal, 30)
        // MARK: - VoiceOver
        // One element: "Ciclo atual, Prata 1" + "Faltam 15 pontos para Prata 2"; swipe up/down
        // with VoiceOver to change the cycle.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.title), \(item.progress.tier.displayName)"))
        .accessibilityValue(Text(item.detail))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: go(by: 1)
            case .decrement: go(by: -1)
            @unknown default: break
            }
        }
    }

    // MARK: - Navigation

    /// Moves `step` cycles (−1 older, +1 newer), with an animation.
    private func go(by step: Int) {
        let target = index + step
        guard items.indices.contains(target) else { return }
        incomingEdge = step < 0 ? .leading : .trailing
        let change = {
            // Back on the last card means "follow the current cycle" again.
            chosenIndex = target == items.count - 1 ? nil : target
        }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2), change)
        } else {
            withAnimation(.snappy(duration: 0.35), change)
        }
    }

    /// How the texts change: sliding in from the drag's side, or fading with reduced motion.
    private var textTransition: AnyTransition {
        reduceMotion ? .opacity : .push(from: incomingEdge)
    }

    /// A chevron button; hidden when there's nowhere to go.
    private func chevron(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.subTitleGray)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
    }
}

// MARK: - Item

/// What the card shows for one cycle.
private struct RankItem {

    /// Whether the item is the current cycle or a past one.
    enum Kind {
        /// The cycle running now.
        case current
        /// A finished cycle, from the rank history.
        case past(RankHistoryModel)
    }

    /// The rank and how far into it the cycle got.
    let progress: Tier.Progress
    /// Current or past.
    let kind: Kind

    /// Whether this is the current cycle.
    var isCurrent: Bool {
        if case .current = kind { return true }
        return false
    }

    /// How full the arc is: the share of the division already done, or full at Mestre.
    var fraction: Double {
        guard progress.nextTier != nil else { return 1 }
        return Double(progress.pointsIntoDivision) / Double(Tier.pointsPerDivision)
    }

    /// Color of the arc, for the current cycle and the past ones alike: how close the cycle is (or
    /// got) to the next division, red (far), orange, yellow, green (almost there), and Mestre's
    /// pink once it reached the top.
    var tint: Color {
        if progress.tier == .master { return .rankMasterPink }
        switch fraction {
        case ..<0.25: return .tagRed
        case ..<0.5: return .choreOrange
        case ..<0.75: return .choreYellow
        default: return .choreGreen
        }
    }

    /// "Ciclo atual", or the past cycle's dates.
    var title: String {
        switch kind {
        case .current:
            return L10n.tr("Ciclo atual")
        case .past(let entry):
            let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)
            return "\(entry.cycleStart.formatted(style)) – \(entry.cycleEnd.formatted(style))"
        }
    }

    /// For the current cycle, the points missing for the next rank; for a past one, its points.
    var detail: String {
        switch kind {
        case .current:
            if let next = progress.nextTier, let missing = progress.pointsToNext {
                return L10n.tr("Faltam \(missing) pontos para \(next.displayName)")
            }
            return L10n.tr("Você chegou ao rank máximo")
        case .past(let entry):
            return L10n.tr("\(entry.points) pts")
        }
    }
}

// MARK: - Arc

/// A half circle (the top half) with a gray track and the filled part, from left to right.
struct RankArc: View {

    /// From 0 (empty) to 1 (full).
    let progress: Double
    /// The color of the filled part.
    var tint: Color = .choreYellow
    /// The arc's thickness.
    var lineWidth: CGFloat = 14

    /// Fills at once when the user asked for less motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How much is drawn right now (animates toward ``progress``).
    @State private var shown: Double = 0

    /// ``progress`` kept between 0 and 1.
    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            // MARK: - Gray track and filled part
            HalfCircle()
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            HalfCircle()
                .trim(from: 0, to: shown)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        // Keeps the rounded ends of the stroke inside the frame.
        .padding(lineWidth / 2)
        .onAppear { fill() }
        .onChange(of: progress) { fill() }
        .accessibilityHidden(true)
    }

    /// Fills up to ``progress``, animated unless Reduce Motion is on.
    private func fill() {
        if reduceMotion {
            shown = clamped
        } else {
            withAnimation(.easeOut(duration: 0.8)) { shown = clamped }
        }
    }
}

/// The top half of a circle whose center is the middle of the bottom edge.
private struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        var path = Path()
        // Left → top → right on screen (SwiftUI's y axis points down).
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        return path
    }
}

#Preview {
    let user = CKRecord.Reference(recordID: CKRecord.ID(recordName: "preview"), action: .none)
    let day: (Int, Int) -> Date = { month, day in
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day))!
    }
    RankCarousel(
        points: 195,
        history: [
            RankHistoryModel(user: user, cycleKey: "2026-09-19", cycleStart: day(9, 19), cycleEnd: day(10, 2), tier: Tier(points: 40), points: 40),
            RankHistoryModel(user: user, cycleKey: "2026-10-03", cycleStart: day(10, 3), cycleEnd: day(10, 16), tier: Tier(points: 160), points: 160)
        ]
    )
}
