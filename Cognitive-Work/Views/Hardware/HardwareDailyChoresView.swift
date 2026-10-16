//
//  HardwareDailyChoresView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 17/09/26.
//

import Foundation
import SwiftUI
import WeatherKit
import CloudKit

/// Wall-dashboard view showing every house member's chores for the target day, one column per
/// user, shaded by the room each chore belongs to.
///
/// The image goes to a 4-level grayscale e-paper (see `UIImage.levelBitmap4Gray()`), so the
/// rooms use the shades of ``EInkRoomStyle`` instead of their app colors, which all collapsed
/// into similar grays there.
///
/// Which day that is comes from ``HardwareDailyChoresViewModel/dayOffsetFromToday`` — currently
/// tomorrow, on purpose, while the e-paper flow is being tested.
///
/// > Note: this view is render-only. ``HardwareViewModel/sendChartToESP32()`` awaits
/// > `viewModel.setup()` and then hands the populated view model to `ImageRenderer`, which does
/// > not run `.task`. The modifier below is a fallback for presenting the dashboard on screen;
/// > it is not what fills the image sent to the device.
struct HardwareDailyChoresView: View {
    var viewModel = HardwareDailyChoresViewModel()
    var weatherViewModel = WeatherViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            userColumns
            legend
        }
        .padding(.vertical)
        .foregroundStyle(EInkShade.black)
        .environment(\.colorScheme, .light)
        .accessibilityHidden(true)
        .task {
            guard viewModel.userGroups.isEmpty else { return }
            await viewModel.setup()
        }
    }

    // MARK: - Subviews

    /// Title, Date and Weather Forecast
    private var header: some View {
        HStack {
            HStack(alignment: .firstTextBaseline) {
                Text("Tarefas do Dia,")
                    .font(.largeTitle)
                    .bold()

                Text(viewModel.targetDateFormatted)
                    .font(.title)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Image(systemName: weatherViewModel.weatherIcon)
                
                Text(weatherViewModel.averageTemperature)
            }
            .font(.title2)
            .padding(.bottom)
        }
        .padding(.horizontal)
    }

    /// One column per house member, each showing their chores for today.
    private var userColumns: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 12) {
                ForEach(viewModel.userGroups) { group in
                    UserDailyChoresColumn(group: group, roomProvider: viewModel.room(for:))
                        .frame(height: geometry.size.height)
                }
            }
        }
        .padding(.horizontal)
    }

    /// Room legend, with the same fill and border as the cards.
    private var legend: some View {
        HStack(spacing: 20) {
            ForEach(viewModel.roomsInUse) { room in
                HStack(spacing: 6) {
                    EInkRoomSwatch(style: EInkRoomStyle(room: room))
                    Text(room.name.localizedDefault)
                        .font(.title2)
                        .foregroundStyle(.black)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}

// MARK: - Private subviews

/// One user's chores cards for today with header
private struct UserDailyChoresColumn: View {
    var group: UserDailyChoresGroup
    var roomProvider: (ChoreModel) -> RoomModel?

    /// Caps how many chore cards a column renders, so a user with a long list doesn't demand
    /// more height than the screen has to offer. Chores past the cap collapse into one thin
    /// "+N tarefas" strip instead of a full card.
    static let maxVisibleChores = 3

    private var visibleChores: [ChoreModel] {
        Array(group.chores.prefix(Self.maxVisibleChores))
    }

    private var overflowCount: Int {
        max(0, group.chores.count - Self.maxVisibleChores)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(group.user.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(group.shareOfDayFormatted)
                    .font(.title3)
                    .foregroundStyle(.black)
            }
            .padding(.trailing, 5)

            if group.chores.isEmpty {
                emptyState
            } else {
                VStack(spacing: 7) {
                    ForEach(visibleChores) { chore in
                        DailyChoreCard(chore: chore, room: roomProvider(chore))
                            .frame(maxHeight: .infinity)
                    }
                    if overflowCount > 0 {
                        OverflowStrip(count: overflowCount)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Shown instead of the chore stack when the user has nothing due today.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sem tarefas por hoje")
                .font(.title2)
                .fontWeight(.bold)
                // No line limit: wraps onto as many lines as it needs instead of "…".
                .fixedSize(horizontal: false, vertical: true)

            // Makes card expand when there's only one chore
            Spacer(minLength: 0)
        }
        // Plain white with dark gray text: no fill or border, so it never reads as a room.
        .foregroundColor(EInkShade.darkGray)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(EInkShade.white)
    }
}

/// A single chore, styled with the e-ink style of the room it belongs to
private struct DailyChoreCard: View {
    var chore: ChoreModel
    var room: RoomModel?

    private var style: EInkRoomStyle { EInkRoomStyle(room: room) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(room?.name.localizedDefault ?? L10n.tr("Sem cômodo"))
                .font(.title3)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)

            Text(chore.localizedName)
                .font(.title)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)

            // Makes card expand when there's only one chore
            Spacer(minLength: 0)
        }
        .foregroundColor(style.text)
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 55, alignment: .topLeading)
        .background(style.fill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Card with the number of chores that were not rendered on the list
private struct OverflowStrip: View {
    var count: Int

    var body: some View {
        Text(verbatim: "+" + L10n.tr("%lld tarefas", count))
            .font(.title)
            .fontWeight(.semibold)
            .foregroundColor(EInkShade.darkGray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(EInkShade.white)
    }
}

// MARK: - E-ink palette

/// The four levels the e-paper can show. Each value sits in the middle of the brightness band
/// `levelBitmap4Gray()` maps it to (0–63, 64–127, 128–191, 192–255), so antialiasing or a slight
/// rendering difference never pushes a card into the neighbouring level.
private enum EInkShade {
    static let black = Color(white: 0)
    static let darkGray = Color(white: 96 / 255)
    static let lightGray = Color(white: 160 / 255)
    static let white = Color(white: 1)
}

/// How a room's cards look on the e-paper.
///
/// The display has four levels and the background takes white, so only black, dark gray and
/// light gray stand out as card fills. With five room colors, two shades are shared; the room
/// name on each card (and the legend) still tells them apart. Text is always the opposite end
/// of the scale from the fill, for maximum contrast.
private struct EInkRoomStyle {
    let fill: Color
    let text: Color

    init(room: RoomModel?) {
        guard let color = room?.color else {
            self.init(fill: EInkShade.lightGray, text: EInkShade.black)
            return
        }
        // Darker app colors get darker shades, so the dashboard keeps a similar feel.
        switch color {
        case .purple: self.init(fill: EInkShade.black, text: EInkShade.white)
        case .blue, .orange: self.init(fill: EInkShade.darkGray, text: EInkShade.white)
        case .green, .yellow: self.init(fill: EInkShade.lightGray, text: EInkShade.black)
        }
    }

    private init(fill: Color, text: Color) {
        self.fill = fill
        self.text = text
    }
}

/// Legend dot with a room's shade.
private struct EInkRoomSwatch: View {
    let style: EInkRoomStyle

    var body: some View {
        Circle()
            .fill(style.fill)
            .frame(width: 22, height: 22)
    }
}

@MainActor
private enum HardwareDailyChoresPreviewData {

    static func makeViewModel() -> HardwareDailyChoresViewModel {
        // MARK: rooms
        func makeRoom(_ name: String, color: RoomColor, id: String) -> RoomModel {
            var room = RoomModel(name: name, symbol: "fish", color: color)
            room.recordID = CKRecord.ID(recordName: "preview-\(id)")
            return room
        }

        let banheiro      = makeRoom("Banheiro",        color: .purple, id: "banheiro")
        let cozinha       = makeRoom("Cozinha",         color: .blue,   id: "cozinha")
        let salaDeEstar   = makeRoom("Sala de estar",   color: .green,  id: "sala")
        let areaDeServico = makeRoom("Área de serviço", color: .yellow, id: "area")
        let quarto        = makeRoom("Quarto",          color: .orange, id: "quarto")

        // MARK: users
        func makeUser(_ name: String) -> UserModel {
            let user = UserModel(name: name, tier: .tier1, ownerRecordName: "preview-\(name)")
            user.recordID = CKRecord.ID(recordName: "preview-user-\(name)")
            return user
        }

        let jones   = makeUser("Jones")
        let isabela = makeUser("Isabela")
        let carol   = makeUser("Carol")
        let anshu   = makeUser("Anshu")
        let dayo    = makeUser("Dayô") // sem tarefas: mostra o "Sem tarefas por hoje"

        // MARK: chores
        func makeChore(_ name: String, room: RoomModel, responsible: UserModel, duration: Double) -> ChoreModel {
            let chore = ChoreModel(
                name: name,
                description: "",
                dueDate: Date(),
                frequency: .daily,
                duration: duration,
                isPublic: true,
                priorityTag: .medium,
                currentResponsible: responsible.recordID.map { CKRecord.Reference(recordID: $0, action: .none) },
                roomReference: room.recordID.map { CKRecord.Reference(recordID: $0, action: .none) }
            )
            chore.recordID = CKRecord.ID(recordName: "preview-chore-\(UUID().uuidString)")
            return chore
        }

        let chores: [ChoreModel] = [
            // Jones
            makeChore("Lavar Box",               room: banheiro,      responsible: jones,   duration: 15),
            makeChore("Lavar louça do domingo",  room: cozinha,       responsible: jones,   duration: 20),
            makeChore("Regar as plantas",        room: quarto,        responsible: jones,   duration: 10),

            // Isabela
            makeChore("Lavar roupas brancas",    room: areaDeServico, responsible: isabela, duration: 40),
            makeChore("Lavar chão",              room: banheiro,      responsible: isabela, duration: 15),
            makeChore("Tirar o lixo",            room: banheiro,      responsible: isabela, duration: 5),

            // Carol
            makeChore("Lavar louça do jantar",   room: cozinha,       responsible: carol,   duration: 20),
            makeChore("Passar pano",             room: salaDeEstar,   responsible: carol,   duration: 15),
            makeChore("Dobrar as roupas",        room: areaDeServico, responsible: carol,   duration: 25),

            // Anshu (5 tarefas: testa o limite de 3 cards + faixa "+2 tarefas")
            makeChore("Jogar água nas plantas",  room: quarto,        responsible: anshu,   duration: 5),
            makeChore("Tirar o lixo",            room: cozinha,       responsible: anshu,   duration: 5),
            makeChore("Cozinhar almoço",         room: cozinha,       responsible: anshu,   duration: 45),
            makeChore("Lavar panelas",           room: cozinha,       responsible: anshu,   duration: 20),
            makeChore("Organizar geladeira",     room: cozinha,       responsible: anshu,   duration: 15),
        ]

        return HardwareDailyChoresViewModel(
            chores: chores,
            users: [jones, isabela, carol, anshu, dayo],
            rooms: [banheiro, cozinha, salaDeEstar, areaDeServico, quarto]
        )
    }
}

// MARK: - Preview

#Preview("Painel (paisagem)", traits: .fixedLayout(width: 800, height: 480)) {
    HardwareDailyChoresView(viewModel: HardwareDailyChoresPreviewData.makeViewModel())
        .background(Color.white)
}
