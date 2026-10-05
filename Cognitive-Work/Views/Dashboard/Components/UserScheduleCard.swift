//
//  UserScheduleCard.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 02/10/26.
//

import Foundation
import SwiftUI
import CloudKit

// MARK: - Card

/// A card that shows the current user's chores as stacked bars, one column per day.
///
/// Each bar is one chore. Its **height** comes from the chore's duration tier
/// (``DailyUsageEntry/tier``) and its **color** from the room the chore belongs to.
/// Tapping a bar opens a popover with the chore's details.
///
/// The view is "dumb": it receives plain data and lookup closures, so it can be previewed
/// without CloudKit.
///
/// ```swift
/// UserScheduleCard(
///     user: viewModel.currentUser,
///     entries: viewModel.myEntries,
///     startDate: viewModel.startDate,
///     legendRooms: viewModel.roomsInUse,
///     chore: viewModel.chore(for:),
///     room: viewModel.room(for:)
/// )
/// ```
///
/// > Note: With the default of 7 days the chart fits a 361 pt wide card. A larger
/// > `daysToShow` scrolls horizontally.
struct UserScheduleCard: View {
    
    /// The resident the card belongs to. Used for the avatar and the popover.
    let user: UserModel?
    
    /// The user's entries; entries from other residents should be filtered out beforehand.
    let entries: [DailyUsageEntry]
    
    /// First day shown in the chart.
    let startDate: Date
    
    /// Rooms listed in the legend.
    let legendRooms: [RoomModel]
    
    /// Resolves the chore an entry refers to.
    let chore: (DailyUsageEntry) -> ChoreModel?
    
    /// Resolves the room a chore belongs to.
    let room: (ChoreModel) -> RoomModel?
    
    /// Number of day columns to display.
    var daysToShow: Int = 14
    
    /// The entry whose popover is currently open, if any.
    @State private var selectedEntry: DailyUsageEntry?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            
            chart
            
            MyScheduleCaption(rooms: legendRooms)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
        .background(Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255),
                    in: RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: Subviews
    
    private var header: some View {
        HStack(alignment: .top) {
            Text("Sua divisão atual")
                .font(.system(size: 28, weight: .bold))
            
            Spacer()
            
//            MyScheduleAvatar(name: user?.name ?? "")
        }
    }
    
    private var chart: some View {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: startDate)
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<daysToShow, id: \.self) { offset in
                    if let day = calendar.date(byAdding: .day, value: offset, to: firstDay) {
                        MyScheduleDayColumn(
                            day: day,
                            entries: entries.filter { calendar.isDate($0.day, inSameDayAs: day) },
                            selectedEntry: $selectedEntry,
                            user: user,
                            chore: chore,
                            room: room
                        )
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Day column

/// One day of the chart: the weekday label with the day's chore bars stacked below it.
private struct MyScheduleDayColumn: View {
    
    /// The day this column represents.
    let day: Date
    
    /// Entries scheduled on ``day``.
    let entries: [DailyUsageEntry]
    
    /// Shared selection; the popover opens on the bar whose entry equals this value.
    @Binding var selectedEntry: DailyUsageEntry?
    
    let user: UserModel?
    let chore: (DailyUsageEntry) -> ChoreModel?
    let room: (ChoreModel) -> RoomModel?
    
    /// Height, in points, of a bar whose duration tier ratio is `1`.
    private let maxBarHeight: CGFloat = 160
    
    /// Total height of every column, so the labels float at different heights like the design.
    private let columnHeight: CGFloat = 330
    
    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            
            Text(weekdayText)
                .font(.system(size: 16.35, weight: .medium))
            
            VStack(spacing: 4) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    bar(for: entry)
                }
            }
        }
        .frame(width: 46, height: columnHeight)
    }
    
    /// Short, capitalized weekday in the app's language (e.g. "Seg").
    private var weekdayText: String {
        day.formatted(.dateTime.weekday(.abbreviated).locale(L10n.locale))
            .replacingOccurrences(of: ".", with: "")
            .capitalized(with: L10n.locale)
    }
    
    /// A single tappable bar that presents the chore popover.
    @ViewBuilder
    private func bar(for entry: DailyUsageEntry) -> some View {
        let resolvedChore = chore(entry)
        let resolvedRoom = resolvedChore.flatMap(room)
        
        RoomTexturedShape(shape: RoundedRectangle(cornerRadius: 15), room: resolvedRoom)
            .frame(width: 45, height: maxBarHeight * entry.tier.heightRatio)
            .contentShape(RoundedRectangle(cornerRadius: 15))
            .onTapGesture {
                selectedEntry = (selectedEntry == entry) ? nil : entry
            }
            .popover(
                isPresented: isPresented(entry),
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .bottom
            ) {
                if let resolvedChore {
                    ChoreCard(chore: resolvedChore, user: user, room: resolvedRoom)
                        .padding()
                        // Keeps a real popover on iPhone instead of a sheet.
                        .presentationCompactAdaptation(.popover)
                }
            }
    }
    
    /// A binding that is `true` only while `entry` is the selected one.
    private func isPresented(_ entry: DailyUsageEntry) -> Binding<Bool> {
        Binding(
            get: { selectedEntry == entry },
            set: { isShown in
                if !isShown, selectedEntry == entry { selectedEntry = nil }
            }
        )
    }
}

// MARK: - Room swatch

/// A shape that shows a room's ``RoomTextureBackground``, clipped to an outline.
///
/// Delegating to ``RoomTextureBackground`` keeps bars and legend dots identical to the
/// room cards (same color, pattern and texture opacity). A `nil` room is drawn as plain
/// gray, matching how unknown rooms are shown elsewhere.
private struct RoomTexturedShape<S: Shape>: View {
    
    /// The outline to clip to (a rounded rectangle for bars, a circle for legend dots).
    let shape: S
    
    /// The room that provides the color and texture.
    let room: RoomModel?
    
    /// Enlargement of the texture, forwarded to ``RoomTextureBackground``.
    /// Higher values draw bigger, fewer shapes.
    var zoom: CGFloat = RoomTextureBackground.textureZoom
    
    var body: some View {
        if let room {
            RoomTextureBackground(room: room, zoom: zoom)
                .clipShape(shape)
        } else {
            shape.fill(.gray)
        }
    }
}

// MARK: - Caption

/// A wrapping legend that lists each room with its color.
private struct MyScheduleCaption: View {
    
    /// Rooms to list.
    let rooms: [RoomModel]
    
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(rooms, id: \.recordID) { room in
                HStack(spacing: 6) {
                    RoomTexturedShape(shape: Circle(), room: room, zoom: 1)
                        .frame(width: 14, height: 14)
                    
                    Text(room.name)
                        .font(.system(size: 15, weight: .light))
                }
            }
        }
    }
}

// MARK: - User Avatar

/// A circular avatar showing the user's initial.
///
/// > Note: This is a placeholder. Replace the body with your `UserProfileCache`
/// > image loading to show the real profile picture.
//private struct MyScheduleAvatar: View {
//    
//    /// The user's display name.
//    let name: String
//    
//    var body: some View {
//        Text(name.prefix(1).uppercased())
//            .font(.headline)
//            .frame(width: 44, height: 44)
//            .background(.white, in: Circle())
//            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
//    }
//}
