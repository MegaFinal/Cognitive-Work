//
//  ShopListItemCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import SwiftUI
import CloudKit

/// One shopping list entry
struct ShopListItemCard: View {
    
    var item: ShopListItem
    
    /// Resolved by the parent from ``ShopListViewModel/houseUsers`` instead of each card
    /// firing its own CloudKit request.
    var relatedUsers: [UserModel]
    
    var onToggle: () async -> Void
    var onTap: () -> Void
    
    /// Blocks double taps while the change is being saved.
    @State private var isToggling = false
    
    private var category: ShopItemCategory { item.category }
    
    /// "2 unidades", with the unit in the right plural.
    private var quantityText: String {
        "\(item.quantity) \(item.unitMeasurement.getDisplayName(for: Double(item.quantity)))"
    }
    
    private var priceText: String? {
        guard let value = item.value, value > 0 else { return nil }
        return value.formatted(.currency(code: "BRL").locale(L10n.locale))
    }
    
    var body: some View {
        HStack(spacing: 15) {
            categoryTile
            
            VStack(alignment: .leading) {
                details
                avatars
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 25) {
                
                checkButton
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(item.isBought ? 0.6 : 1)
        .animation(.snappy, value: item.isBought)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture(perform: onTap)
    }
    
    // MARK: - Pieces
    
    /// The category's icon on a textured tile. Every tile has the same fixed size.
    private var categoryTile: some View {
        ShopCategoryTile(category: category)
    }
    
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
    
    private var avatars: some View {
        HStack(spacing: -8) {
            ForEach(relatedUsers, id: \.recordID) { user in
                UserProfilePictureTag(user: user, widthMultiplier: 0.065)
                    .shadow(color: .black.opacity(0.24), radius: 1.83087, x: 1.71644, y: 1.14429)
            }
        }
    }

    private var checkButton: some View {
        Button {
            HapticsManager.notify(item.isBought ? .warning : .success)
            isToggling = true
            Task {
                await onToggle()
                isToggling = false
            }
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
        .accessibilityLabel(item.isBought ? "Marcar como não comprado" : "Marcar como comprado")
    }
}

// MARK: - Category tile

/// The square behind a category's icon: the category's soft color with its texture on top.
struct ShopCategoryTile: View {
    
    let category: ShopItemCategory
        
    private let iconSide: CGFloat = 32
    
    var body: some View {
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
                Image(systemName: category.symbol)
                    .resizable()
                    .scaledToFit()
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
