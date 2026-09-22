//
//  FilterOptionsMenu.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 31/08/26.
//

import SwiftUI

/// Content of the chores list's filter menu.
struct FilterOptionsMenu: View {
    @Bindable var viewModel: CarouselViewModel

    private var filterableRooms: [RoomModel] {
        viewModel.roomModels.filter { $0.name != "Casa" }
    }

    var body: some View {
        Menu {
            ForEach(PriorityTag.allCases, id: \.self) { tag in
                Toggle(isOn: tagBinding(tag)) {
                    Text(tag.rawValue.capitalized)
                }
            }
        } label: {
            FilterMenuRow(
                systemImage: "flag",
                title: "Prioridade",
                subtitle: summary(viewModel.filterChoices.tags.map { $0.rawValue.capitalized })
            )
        }

        Menu {
            ForEach(viewModel.userModels, id: \.self) { user in
                Toggle(isOn: userBinding(user)) {
                    Text(user.name.capitalized)
                }
            }
        } label: {
            FilterMenuRow(
                systemImage: "person.2",
                title: "Usuários",
                subtitle: summary(viewModel.filterChoices.users.map { $0.name.capitalized })
            )
        }

        Menu {
            ForEach(Recurrence.allCases, id: \.self) { frequency in
                Toggle(isOn: frequencyBinding(frequency)) {
                    Text(frequency.rawValue.capitalized)
                }
            }
        } label: {
            FilterMenuRow(
                systemImage: "repeat",
                title: "Frequência",
                subtitle: summary(viewModel.filterChoices.frequencies.map { $0.rawValue.capitalized })
            )
        }

        Menu {
            ForEach(filterableRooms, id: \.self) { room in
                Toggle(isOn: roomBinding(room)) {
                    Text(room.name.capitalized)
                }
            }
        } label: {
            FilterMenuRow(
                systemImage: "house",
                title: "Cômodo",
                subtitle: summary(viewModel.filterChoices.rooms.map { $0.name.capitalized })
            )
        }

        Menu {
            Toggle(isOn: stateBinding(true)) {
                Text("Concluído")
            }
            Toggle(isOn: stateBinding(false)) {
                Text("Pendente")
            }
        } label: {
            FilterMenuRow(
                systemImage: "checkmark.circle",
                title: "Status",
                subtitle: viewModel.filterChoices.state.map { $0 ? "Concluído" : "Pendente" } ?? "Nenhum"
            )
        }

        Divider()

        Button {
            viewModel.resetFilter()
        } label: {
            Label("Limpar filtro", systemImage: "eraser")
        }
    }

    // MARK: - Toggle bindings

    private func tagBinding(_ tag: PriorityTag) -> Binding<Bool> {
        Binding(
            get: { viewModel.filterChoices.tags.contains(tag) },
            set: { _ in viewModel.addOrRemoveFilter(tag: tag) }
        )
    }

    private func userBinding(_ user: UserModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.filterChoices.users.contains(user) },
            set: { _ in viewModel.addOrRemoveFilter(user: user) }
        )
    }

    private func frequencyBinding(_ frequency: Recurrence) -> Binding<Bool> {
        Binding(
            get: { viewModel.filterChoices.frequencies.contains(frequency) },
            set: { _ in viewModel.addOrRemoveFilter(frequency: frequency) }
        )
    }

    private func roomBinding(_ room: RoomModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.filterChoices.rooms.contains(room) },
            set: { _ in viewModel.addOrRemoveFilter(room: room) }
        )
    }

    private func stateBinding(_ state: Bool) -> Binding<Bool> {
        Binding(
            get: { viewModel.filterChoices.state == state },
            set: { _ in viewModel.addOrRemoveFilter(state: state) }
        )
    }

    /// "Nenhum" when empty, the single value's name, or a count once more than one is picked
    private func summary(_ selected: [String]) -> String {
        switch selected.count {
        case 0: return "Nenhum"
        case 1: return selected[0]
        default: return "\(selected.count) selecionados"
        }
    }
}

/// A single row inside the filter menu: icon, title, and the current selection as a subtitle 
private struct FilterMenuRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

#Preview {
    Menu {
        FilterOptionsMenu(viewModel: CarouselViewModel())
    } label: {
        Label("Filtrar", systemImage: "line.3.horizontal.decrease")
    }
    .padding()
}
