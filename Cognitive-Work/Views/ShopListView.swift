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
    @State private var isShowingPendingPayments = false

    /// Whether the "add several items with AI" sheet is open.
    @State private var isPresentingAIBatch = false
    /// Whether the AI button shows: the on-device model can run on this device and language.
    @State private var canUseAI = false

    /// "Pode estar faltando": usual items and products that go with the list.
    @State private var suggestionsModel: ShopListSuggestionViewModel

    /// Which card is swiped open; shared so only one can be open at a time.
    @State private var revealedItemID: String?

    /// The delete button matches the card: same height, same 22-point corners.
    private let swipeStyle = SwipeToDeleteStyle(cornerRadius: 22, topInset: 0)

    init(viewModel: ShopListViewModel? = nil) {
        let shopList = viewModel ?? ShopListViewModel()
        self._viewModel = State(initialValue: shopList)
        self._suggestionsModel = State(initialValue: ShopListSuggestionViewModel(shopList: shopList))
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $isShowingPendingPayments) {
                    PendingPaymentsView(shopList: viewModel)
                }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            // One-tap chips for what might be missing; hidden when there's nothing to suggest.
            ShopSuggestionsRow(model: suggestionsModel)
                .animation(.snappy, value: suggestionsModel.suggestions.map(\.id))

            if viewModel.hasLoaded && viewModel.items.isEmpty {
                ShopListEmptyState()
                    .frame(maxHeight: .infinity)
            } else {
                itemList
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // The AI button sits right above "+", centred on it.
            VStack(spacing: 12) {
                if canUseAI {
                    aiBatchButton
                }
                addButton
            }
        }
        .background(Color(.white).ignoresSafeArea())
        .overlay { purchasePriceOverlay }
        .animation(.easeInOut(duration: 0.25), value: viewModel.purchasePrompt?.id)
        .task {
            canUseAI = viewModel.canSuggestItemDetails
            guard !viewModel.hasLoaded else { return }
            await viewModel.setup()
        }
        // Suggestions follow the list: an item added, bought or removed changes them.
        .onChange(of: suggestionsKey, initial: true) { _, _ in
            suggestionsModel.refresh()
        }
        #if DEBUG
        // DEBUG test mode: a "day" is a minute, so time alone can make an item due; check again
        // every 30 seconds instead of waiting for the list to change.
        .task {
            guard ShopListSuggestionViewModel.usesMinutesAsDays else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                suggestionsModel.refresh()
            }
        }
        #endif
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
        // Several items at once with the on-device model, reviewed before saving.
        .sheet(isPresented: $isPresentingAIBatch) {
            AddMoreItensInteligence(viewModel: viewModel)
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
                // The AI sheet shows its own errors.
                get: { viewModel.errorMessage != nil && !isPresentingAddItem && editingItem == nil && !isPresentingAIBatch },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    /// Changes whenever an item is added, removed, bought or renamed.
    private var suggestionsKey: String {
        viewModel.items
            .map { "\($0.id)\($0.isBought)\($0.name)" }
            .joined(separator: "|")
    }

    // MARK: - Price pop-up

    /// "How much was it?", over a dimmed backdrop, when an item without a price is checked off.
    @ViewBuilder
    private var purchasePriceOverlay: some View {
        if let prompt = viewModel.purchasePrompt {
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.dismissPurchasePrompt() }
                    .accessibilityHidden(true)

                PurchasePricePopUp(
                    itemName: prompt.item.name,
                    quantity: prompt.item.quantity,
                    onConfirm: { text in
                        Task { await viewModel.confirmPurchaseAnnouncing(of: prompt.item, valueText: text) }
                    },
                    onSkip: {
                        Task { await viewModel.confirmPurchaseAnnouncing(of: prompt.item, valueText: nil) }
                    },
                    onCancel: { viewModel.dismissPurchasePrompt() }
                )
                .id(prompt.id)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            .transition(.opacity)
        }
    }

    // MARK: - Header

    /// Page title alongside the controls, laid out like the header of ``ChoresView``.
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compras")
                    .font(.system(size: 34))
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

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

            HStack(spacing: 4) {
                Button {
                    HapticsManager.selection()
                    isShowingPendingPayments = true
                } label: {
                    Image(systemName: "banknote")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                        .padding(8)
                }
                .accessibilityLabel("Pendências")
                .voiceControlNames([L10n.tr("Pendências"), L10n.tr("Dinheiro"), L10n.tr("Pagamentos")])

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
                .accessibilityLabel("Ordenar por")
                .voiceOverValue(viewModel.sortOption.label)
                .voiceControlNames([L10n.tr("Ordenar"), L10n.tr("Filtro"), L10n.tr("Ordenar por")])
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
        .voiceOverLabel(viewModel.accessibilityLabel(for: section))
        .voiceOverValue(viewModel.accessibilityValue(for: section))
        .voiceControlNames([section.title])
        .accessibilityAddTraits(.isHeader)
    }

    private func row(for item: ShopListItem) -> some View {
        SwipeToDeleteRow(
            id: item.id,
            revealedID: $revealedItemID,
            style: swipeStyle,
            onDelete: {
                Task { await viewModel.deleteItemAnnouncing(item) }
            }
        ) {
            ShopListItemCard(
                item: item,
                relatedUsers: viewModel.relatedUsers(for: item),
                onToggle: { await viewModel.toggleBoughtAnnouncing(item) },
                onTap: {
                    if revealedItemID != nil {
                        withAnimation(.snappy) { revealedItemID = nil }
                    } else {
                        editingItem = item
                    }
                }
            )
        }
        .accessibilityAction(named: Text(verbatim: L10n.tr("Editar"))) {
            editingItem = item
        }
        // "Excluir" comes from SwipeToDeleteRow itself (it calls onDelete above).
    }

    /// Opens ``ShopListAIBatchSheet`` to add several items from one text.
    private var aiBatchButton: some View {
        Button {
            HapticsManager.selection()
            isPresentingAIBatch = true
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .padding(14)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!viewModel.canAddItems)
        .voiceOverLabel(L10n.tr("Adicionar com IA"))
        .voiceControlNames([L10n.tr("Adicionar com IA"), L10n.tr("IA")])
        .transition(.scale.combined(with: .opacity))
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
        .voiceOverLabel(L10n.tr("Adicionar item"))
        .voiceControlNames([L10n.tr("Adicionar"), L10n.tr("Mais"), L10n.tr("Adicionar item")])
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
        .accessibilityElement(children: .combine)
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
