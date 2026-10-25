//
//  ShopListItemCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI
import CloudKit

/// One item of the shopping list: the category tile, name and amount, the avatars of who it's
/// for, and a check button to mark it as bought. Tapping the card opens the edit form.
struct ShopListItemCard: View {
    
    /// The item shown.
    var item: ShopListItem
    
    /// Resolved by the parent from ``ShopListViewModel/houseUsers`` instead of each card
    /// firing its own CloudKit request.
    var relatedUsers: [UserModel]
    
    /// Checks or unchecks the item (marks it as bought or not).
    var onToggle: () async -> Void
    /// Opens the item's edit form.
    var onTap: () -> Void
    
    /// Blocks double taps while the change is being saved.
    @State private var isToggling = false
    
    /// The item's category.
    private var category: ShopItemCategory { item.category }
    
    /// "2 unidades", with the unit in the right plural.
    private var quantityText: String {
        "\(item.quantity) \(item.unitMeasurement.getDisplayName(for: Double(item.quantity)))"
    }
    
    /// The total price as money, or `nil` without a price.
    private var priceText: String? {
        guard let value = item.totalValue else { return nil }
        return value.formatted(.currency(code: "BRL").locale(L10n.locale))
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // MARK: - Category tile
            categoryTile
            
            // MARK: - Name, amount and avatars
            VStack(alignment: .leading) {
                details
                avatars
            }
            
            Spacer()
            
            // MARK: - Check button
            VStack(alignment: .trailing, spacing: 25) {
                
                checkButton
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(item.isBought ? 0.6 : 1)
        .animation(.snappy, value: item.isBought)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture(perform: onTap)
        // One VoiceOver element for the whole card; activating it checks the item off (the
        // parent adds "Editar" and "Excluir" as named actions).
        .accessibilityElement(children: .ignore)
        .voiceOverLabel(ShopListViewModel.accessibilityLabel(for: item, relatedUsers: relatedUsers))
        .voiceOverHint(ShopListViewModel.accessibilityToggleName(for: item))
        .accessibilityAddTraits(.isButton)
        // Voice Control: "Toque em Arroz" / "Toque em Comprar Arroz"; "Editar" and "Excluir"
        // via "Mostrar ações para Arroz".
        .voiceControlNames(ShopListViewModel.voiceControlInputLabels(for: item))
        .accessibilityAction {
            toggle()
        }
    }
    
    // MARK: - Pieces
    
    /// The category's icon on a textured tile. Every tile has the same fixed size.
    private var categoryTile: some View {
        ShopCategoryTile(category: category)
    }
    
    /// Name (struck through when bought) and amount.
    private var details: some View {
        VStack(alignment: .leading) {
            Text(item.name)
                .font(.system(size: 18))
                .fontWeight(.bold)
                .strikethrough(item.isBought)
                .lineLimit(2)
            
            Text(quantityText)
        }
    }
    
    /// The avatars of who the item is for.
    private var avatars: some View {
        HStack(spacing: -8) {
            ForEach(relatedUsers, id: \.recordID) { user in
                UserProfilePictureTag(user: user, widthMultiplier: 0.065)
                    .shadow(color: .black.opacity(0.24), radius: 1.83087, x: 1.71644, y: 1.14429)
            }
        }
    }

    /// The round check button (spinner while saving).
    private var checkButton: some View {
        Button {
            toggle()
        } label: {
            ZStack {
                Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.black)
                    .font(.system(size: 22))
                    .opacity(isToggling ? 0.4 : 1)
                
                if isToggling {
                    ProgressView().controlSize(.small)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
        .voiceOverLabel(item.isBought ? L10n.tr("Marcar como não comprado") : L10n.tr("Marcar como comprado"))
    }

    /// Checks the item off (or puts it back), from the button or from VoiceOver.
    private func toggle() {
        guard !isToggling else { return }
        HapticsManager.notify(item.isBought ? .warning : .success)
        isToggling = true
        Task {
            await onToggle()
            isToggling = false
        }
    }
}

// MARK: - Category tile

/// The square behind a category's icon: the category's soft color with its texture on top.
struct ShopCategoryTile: View {
    
    /// The category shown.
    let category: ShopItemCategory
        
    /// The icon's size.
    private let iconSide: CGFloat = 42
    
    var body: some View {
        // MARK: - Category color, texture and icon
        RoundedRectangle(cornerRadius: 22)
            .foregroundColor(category.color)
            .overlay {
                Image(category.texturePattern.assetName(for: category.roomColor))
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * 0.15, height: height * 0.18)
                    .scaleEffect(5)
                    .opacity(0.3)
                    .allowsHitTesting(false)
            }
            .overlay {
                SymbolImage(name: category.symbol)
                    .frame(width: iconSide, height: iconSide)
                    .foregroundColor(.white)
            }
            .frame(width: width * 0.15, height: height * 0.09)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 14) {
        ShopListItemCard(
            item: ShopListPreviewData.pendingItem,
            relatedUsers: [ShopListPreviewData.jones, ShopListPreviewData.isabela, ShopListPreviewData.carol],
            onToggle: {},
            onTap: {}
        )
        
        ShopListItemCard(
            item: ShopListPreviewData.boughtItem,
            relatedUsers: [ShopListPreviewData.jones, ShopListPreviewData.isabela],
            onToggle: {},
            onTap: {}
        )
        
        ShopListItemCard(
            item: ShopListPreviewData.longNameItem,
            relatedUsers: [],
            onToggle: {},
            onTap: {}
        )
    }
    .padding(.horizontal, 20)
}
