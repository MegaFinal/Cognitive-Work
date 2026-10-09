//
//  ShopListView.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/09/26.
//

import SwiftUI
import CloudKit

/// Shows the house's shopping list.
struct ShopListView: View {

    @State private var viewModel: ShopListViewModel

    @State private var isPresentingAddItem = false
    @State private var editingItem: ShopListItem?

    /// Which card is swiped open; shared so only one can be open at a time.
    @State private var revealedItemID: String?

    /// The delete button matches the card: same height, same 22-point corners.
    private let swipeStyle = SwipeToDeleteStyle(cornerRadius: 22, topInset: 0)

    init(viewModel: ShopListViewModel? = nil) {
        self._viewModel = State(initialValue: viewModel ?? ShopListViewModel())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if viewModel.hasLoaded && viewModel.items.isEmpty {
                ShopListEmptyState()
                    .frame(maxHeight: .infinity)
            } else {
                itemList
            }
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .background(Color(.white).ignoresSafeArea())
        .task {
            guard !viewModel.hasLoaded else { return }
            await viewModel.setup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            viewModel.requestRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.requestRefresh()
        }
        .sheet(isPresented: $isPresentingAddItem) {
            ShopListItemFormView(
                mode: .create,
                availableUsers: viewModel.houseUsers,
                currentUser: viewModel.currentUser,
                viewModel: viewModel
            )
        }
        .sheet(item: $editingItem) { item in
            ShopListItemFormView(
                mode: .edit(item),
                availableUsers: viewModel.houseUsers,
                currentUser: viewModel.currentUser,
                viewModel: viewModel
            )
        }
        .alert(
            "Não foi possível concluir",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && !isPresentingAddItem && editingItem == nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    /// Page title alongside the sort control
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compras")
                    .font(.system(size: 34))
                    .fontWeight(.bold)

                if !viewModel.pendingItems.isEmpty {
                    Text(viewModel.pendingSummary)
                        .font(.system(size: 18))
                        .foregroundStyle(.subTitleGray)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)

            Spacer()

            Menu {
                Picker("Ordenar por", selection: $viewModel.sortOption) {
                    ForEach(ShopListSortOption.allCases) { option in
                        Label(option.label, systemImage: option.symbol).tag(option)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                    .padding(12)
            }
            .glassEffect(
                .regular.interactive(),
                in: .capsule
            )
            .padding(.top, 20)
            .padding(.trailing, 30)
        }
    }

    // MARK: - List

    private var itemList: some View {
        let pendingSections = viewModel.pendingSections
        let boughtSection = viewModel.boughtSection

        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(pendingSections) { section in
                    sectionView(section, isFirst: section.id == pendingSections.first?.id)
                }

                if let boughtSection {
                    if !pendingSections.isEmpty {
                        boughtDivider
                            .padding(.top, sectionSpacing)
                    }

                    sectionView(boughtSection, isFirst: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private let sectionSpacing: CGFloat = 40

    private var boughtDivider: some View {
        Capsule()
            .fill(Color.black)
            .frame(height: 1.5)
            .frame(maxWidth: .infinity)
    }

    private var itemDivider: some View {
        Capsule()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .accessibilityHidden(true)
    }

    /// A collapsible section: the title, then its cards separated by thin lines.
    ///
    /// - Parameter isFirst: The first section sits right under the header
    @ViewBuilder
    private func sectionView(_ section: ShopListSection, isFirst: Bool) -> some View {
        sectionTitle(section)
            .padding(.top, isFirst ? 10 : sectionSpacing)
            .padding(.bottom, 20)

        if !viewModel.isCollapsed(section) {
            VStack(spacing: 0) {
                ForEach(section.items) { item in
                    row(for: item)

                    if item.id != section.items.last?.id {
                        itemDivider
                    }
                }
            }
        }
    }

    private func sectionTitle(_ section: ShopListSection) -> some View {
        let isCollapsed = viewModel.isCollapsed(section)

        return Button {
            withAnimation(.snappy) {
                viewModel.toggleCollapsed(section)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(section.title)
                    .font(.system(size: 22, weight: .bold))

                Text("\(section.items.count)")
                    .font(.system(size: 17))

                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .foregroundStyle(.black)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(for item: ShopListItem) -> some View {
        SwipeToDeleteRow(
            id: item.id,
            revealedID: $revealedItemID,
            style: swipeStyle,
            onDelete: {
                Task { await viewModel.deleteItem(item) }
            }
        ) {
            ShopListItemCard(
                item: item,
                relatedUsers: viewModel.relatedUsers(for: item),
                onToggle: { await viewModel.toggleBought(item) },
                onTap: {
                    if revealedItemID != nil {
                        withAnimation(.snappy) { revealedItemID = nil }
                    } else {
                        editingItem = item
                    }
                }
            )
        }
    }

    private var addButton: some View {
        Button {
            HapticsManager.selection()
            isPresentingAddItem = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28))
                .foregroundColor(.white)
                .padding(20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.interactive().tint(.black),
            in: .circle
        )
        .disabled(!viewModel.canAddItems)
        .padding(.horizontal, 30)
        .padding(.bottom)
    }
}

// MARK: - Empty state

private struct ShopListEmptyState: View {

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(RoomColor.yellow.lowOpacityColor.opacity(0.3))

                Image("loadingIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112)
            }
            .frame(width: 176, height: 176)
            .clipShape(Circle())
            .overlay(alignment: .topTrailing) {
                sparkle(size: 24).offset(x: 4, y: 6)
            }
            .overlay(alignment: .bottomLeading) {
                sparkle(size: 16).offset(x: 2, y: -10)
            }
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Lista de compras vazia")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.titleGray)
                    .multilineTextAlignment(.center)

                Text("Toque em \"+\" para adicionar o primeiro item.")
                    .font(.system(size: 16))
                    .foregroundStyle(.subTitleGray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .onAppear { isAnimating = true }
    }

    private func sparkle(size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(.choreYellow)
            .scaleEffect(isAnimating ? 1.15 : 0.85)
            .animation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                value: isAnimating
            )
    }
}

#Preview("Lista") {
    ShopListView(viewModel: ShopListPreviewData.populatedViewModel)
}
