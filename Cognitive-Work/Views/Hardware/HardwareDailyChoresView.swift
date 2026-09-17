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

/// Wall-dashboard view showing every house member's chores for
/// today, one column per user, colored by the room each chore
/// belongs to.
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
                    .font(.title)
                    .bold()
                Text(viewModel.todayDateFormatted)
                    .font(.title2)
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

    /// Color legend
    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.roomsInUse) { room in
                HStack(spacing: 6) {
                    Circle()
                        .fill(room.color.uiColor)
                        .frame(width: 10, height: 10)
                    Text(room.name)
                        .font(.footnote)
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
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(group.shareOfDayFormatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(2)

            // Makes card expand when there's only one chore
            Spacer(minLength: 0)
        }
        .foregroundColor(.gray.opacity(0.7))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// A single chore, styled with the background color of the room it belongs to
private struct DailyChoreCard: View {
    var chore: ChoreModel
    var room: RoomModel?

    private var backgroundColor: Color {
        room?.color.uiColor ?? Color(.systemGray4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(room?.name ?? "Sem cômodo")
                .font(.caption)
                .fontWeight(.medium)

            Text(chore.name)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(2)

            // Makes card expand when there's only one chore
            Spacer(minLength: 0)
        }
        .foregroundColor(.white)
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 55, alignment: .topLeading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Card with the number of chores that were not rendered on the list
private struct OverflowStrip: View {
    var count: Int

    var body: some View {
        Text("+\(count) \(count == 1 ? "tarefa" : "tarefas")")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    // MARK: - rooms
    var banheiro = RoomModel(name: "Banheiro", color: .purple)
    banheiro.recordID = CKRecord.ID(recordName: "preview-banheiro")

    var cozinha = RoomModel(name: "Cozinha", color: .blue)
    cozinha.recordID = CKRecord.ID(recordName: "preview-cozinha")

    var salaDeEstar = RoomModel(name: "Sala de estar", color: .green)
    salaDeEstar.recordID = CKRecord.ID(recordName: "preview-sala")

    var areaDeServico = RoomModel(name: "Área de serviço", color: .yellow)
    areaDeServico.recordID = CKRecord.ID(recordName: "preview-area")

    var varanda = RoomModel(name: "Quarto", color: .orange)
    varanda.recordID = CKRecord.ID(recordName: "preview-varanda")

    // MARK: - users
    func makeUser(_ name: String) -> UserModel {
        let user = UserModel(name: name, tier: .tier1, ownerRecordName: "preview-\(name)")
        user.recordID = CKRecord.ID(recordName: "preview-user-\(name)")
        return user
    }

    let jones = makeUser("Jones")
    let isabela = makeUser("Isabela")
    let carol = makeUser("Carol")
    let anshu = makeUser("Anshu")
    let dayo = makeUser("Dayô")

    // MARK: - chores
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

    let chores = [
        // Jones
        makeChore("Lavar Box", room: banheiro, responsible: jones, duration: 15),
        makeChore("Lavar louça do domingo", room: cozinha, responsible: jones, duration: 20),
        makeChore("Regar as plantas", room: varanda, responsible: jones, duration: 10),

        // Isabela
        makeChore("Lavar roupas brancas", room: areaDeServico, responsible: isabela, duration: 40),
        makeChore("Lavar chão", room: banheiro, responsible: isabela, duration: 15),
        makeChore("Tirar o lixo", room: banheiro, responsible: isabela, duration: 5),

        // Carol
        makeChore("Lavar louça do jantar", room: cozinha, responsible: carol, duration: 20),
        makeChore("Passar pano", room: salaDeEstar, responsible: carol, duration: 15),
        makeChore("Dobrar as roupas", room: areaDeServico, responsible: carol, duration: 25),

        // Anshu
        makeChore("Jogar água nas plantas", room: varanda, responsible: anshu, duration: 5),
        makeChore("Tirar o lixo", room: cozinha, responsible: anshu, duration: 5),
        makeChore("Cozinhar almoço", room: cozinha, responsible: anshu, duration: 45),
        makeChore("Cozinhar almoço", room: cozinha, responsible: anshu, duration: 45),
        makeChore("Cozinhar almoço", room: cozinha, responsible: anshu, duration: 45),

        // Dayô
//        makeChore("Passar pano", room: cozinha, responsible: dayo, duration: 15)
    ]

    let viewModel = HardwareDailyChoresViewModel(
        chores: chores,
        users: [jones, isabela, carol, anshu, dayo],
        rooms: [banheiro, cozinha, salaDeEstar, areaDeServico, varanda]
    )

    return HardwareDailyChoresView(viewModel: viewModel)
}
