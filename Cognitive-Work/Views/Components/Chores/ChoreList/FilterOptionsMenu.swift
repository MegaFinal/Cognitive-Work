//
//  FilterOptionsMenu.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 31/08/26.
//

import SwiftUI

/// Content of the chores list's native filter `Menu`, split into two submenus:
/// "Ordenação" and "Filtros".
struct FilterOptionsMenu: View {
    @Bindable var viewModel: CarouselViewModel

    private var filterableRooms: [RoomModel] {
        viewModel.roomModels.filter { $0.name != "Casa" }
    }

    /// How many filter categories currently narrow the list, shown under "Filtros".
    private var activeFilterCount: Int {
        let choices = viewModel.filterChoices
        return [
            !choices.tags.isEmpty,
            !choices.users.isEmpty,
            !choices.frequencies.isEmpty,
            !choices.rooms.isEmpty,
            choices.state != nil
        ].filter { $0 }.count
    }

    var body: some View {
        // MARK: - Ordering section
        Menu {
            Toggle(isOn: $viewModel.isSortedByUrgency) {
                Label("Urgência", systemImage: "exclamationmark.triangle")
            }
        } label: {
            FilterMenuRow(
                systemImage: "arrow.up.arrow.down",
                title: "Ordenação",
                subtitle: viewModel.isSortedByUrgency ? L10n.tr("Dia e urgência") : L10n.tr("Dia")
            )
        }

        // MARK: - Filters section
        Menu {
            Menu {
                ForEach(PriorityTag.allCases.filter { $0 != .undefined }, id: \.self) { tag in
                    Toggle(isOn: tagBinding(tag)) {
                        Text(verbatim: tag.displayName.capitalized(with: L10n.locale))
                    }
                }
            } label: {
                FilterMenuRow(
                    systemImage: "flag",
                    title: "Prioridade",
                    subtitle: summary(viewModel.filterChoices.tags.map { $0.displayName.capitalized(with: L10n.locale) })
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
                    subtitle: summary(viewModel.filterChoices.users.map { $0.name.localizedDefault.capitalized(with: L10n.locale) })
                )
            }

            Menu {
                ForEach(Recurrence.allCases.filter { $0 != .undefined }, id: \.self) { frequency in
                    Toggle(isOn: frequencyBinding(frequency)) {
                        Text(verbatim: frequency.displayName.capitalized(with: L10n.locale))
                    }
                }
            } label: {
                FilterMenuRow(
                    systemImage: "repeat",
                    title: "Frequência",
                    subtitle: summary(viewModel.filterChoices.frequencies.map { $0.displayName.capitalized(with: L10n.locale) })
                )
            }

            Menu {
                ForEach(filterableRooms, id: \.self) { room in
                    Toggle(isOn: roomBinding(room)) {
                        Text(room.name.localizedDefault.capitalized(with: L10n.locale))
                    }
                }
            } label: {
                FilterMenuRow(
                    systemImage: "house",
                    title: "Cômodo",
                    subtitle: summary(viewModel.filterChoices.rooms.map { $0.name.localizedDefault.capitalized(with: L10n.locale) })
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
                    subtitle: viewModel.filterChoices.state.map { $0 ? L10n.tr("Concluído") : L10n.tr("Pendente") } ?? L10n.tr("Nenhum")
                )
            }

            Divider()

            Button {
                viewModel.resetFilter()
            } label: {
                Label("Limpar filtro", systemImage: "eraser")
            }
            .disabled(activeFilterCount == 0)
        } label: {
            FilterMenuRow(
                systemImage: "line.3.horizontal.decrease",
                title: "Filtros",
                subtitle: activeFilterCount == 0 ? L10n.tr("Nenhum") : L10n.tr("%lld ativos", activeFilterCount)
            )
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
        case 0: return L10n.tr("Nenhum")
        case 1: return selected[0]
        default: return L10n.tr("%lld selecionados", selected.count)
        }
    }
}

/// A single row inside the filter menu: icon, title, and the current selection as a subtitle
private struct FilterMenuRow: View {
    let systemImage: String
    let title: LocalizedStringKey
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
