//
//  GamificationView.swift
//  Cognitive-Work
//
//  Created by Jonas Melo on 15/10/26.
//

import SwiftUI
import CloudKit

/// The rewards tab: the user's coins and the coupons each room offers.
struct GamificationView: View {

    @State private var viewModel: GamificationViewModel

    /// Key (``couponKey(_:)``) of the coupon brought to the center of the screen, if any.
    @State private var focusedCouponKey: String?

    /// Lets a ticket fly from the list to the center and back.
    @Namespace private var ticketNamespace

    init(viewModel: GamificationViewModel? = nil) {
        self._viewModel = State(initialValue: viewModel ?? GamificationViewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                // The focused coupon takes the whole screen.
                .toolbar(focusedCouponKey == nil ? .automatic : .hidden, for: .tabBar)
                .overlay { focusedCouponOverlay }
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                
                // Current rank last; swipe right for the past cycles.
                RankCarousel(points: viewModel.points, history: viewModel.rankHistory)
                
                CoinsBalanceCard(coins: viewModel.coins)
                    .padding(.horizontal, 30)
                
                if viewModel.rooms.isEmpty {
                    if viewModel.hasLoaded {
                        emptyState(
                            title: "Nenhum cômodo ainda",
                            message: "Quando a casa tiver cômodos, os cupons de cada um aparecem aqui."
                        )
                    } else {
                        Spacer()
                    }
                } else {
                    roomPicker
                        .padding(.horizontal, 30)
                    
                    couponList
                }
            }
            .background(Color(.white).ignoresSafeArea())
            .task {
                guard !viewModel.hasLoaded else { return }
                await viewModel.setup()
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
                viewModel.requestRefresh(catchUp: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.requestRefresh()
            }
            .alert(
                "Não foi possível comprar",
                isPresented: Binding(
                    get: { viewModel.alertMessage != nil },
                    set: { if !$0 { viewModel.alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }

    // MARK: - Header

    /// Page title laid out like the header of ``ShopListView``.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Recompensas")
                .font(.system(size: 34))
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("Troque suas moedas por cupons")
                .font(.system(size: 18))
                .foregroundStyle(.subTitleGray)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
    }

    // MARK: - Room picker

    /// Same control as the chore form's "Cômodo" row: a menu showing the room as a colored tag.
    private var roomPicker: some View {
        HStack {
            Text("Cômodo")
                .bold()
                .accessibilityHidden(true) // the menu says "Cômodo"

            Spacer()

            Menu {
                Picker("Cômodo", selection: $viewModel.selectedRoomKey) {
                    ForEach(viewModel.rooms, id: \.id) { room in
                        Label {
                            Text(roomName(room))
                        } icon: {
                            Image(uiImage: .coloredCircle(color: room.color.uiColor))
                                .renderingMode(.original)
                        }
                        .tag(Optional(GamificationViewModel.key(for: room)))
                    }
                }
            } label: {
                HStack {
                    CapsuleTag(
                        tagName: viewModel.selectedRoom.map(roomName) ?? L10n.tr("Sem Cômodo"),
                        tagColor: viewModel.selectedRoom?.color.uiColor ?? .gray,
                        horizontalPadding: 10.0,
                        verticalPadding: 1.5
                    )

                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.black)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
                .fixedSize()
            }
            .voiceOverLabel(L10n.tr("Cômodo"))
            .voiceOverValue(viewModel.selectedRoom.map(roomName) ?? L10n.tr("Sem Cômodo"))
            .voiceControlNames([L10n.tr("Cômodo"), L10n.tr("Trocar cômodo")])
        }
    }

    private func roomName(_ room: RoomModel) -> String {
        room.name.localizedDefault.capitalized(with: L10n.locale)
    }

    // MARK: - Coupons

    @ViewBuilder
    private var couponList: some View {
        let coupons = viewModel.selectedCoupons
        let color = viewModel.selectedRoom?.color ?? .yellow
        let symbol = viewModel.selectedRoom?.symbol ?? "house"

        if coupons.isEmpty {
            emptyState(
                title: "Sem cupons por aqui",
                message: "Esse cômodo ainda não tem cupons disponíveis."
            )
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 18) {
                    ForEach(coupons, id: \.recordID) { coupon in
                        let key = Self.couponKey(coupon)
                        if focusedCouponKey == key {
                            // Keeps its place while the ticket is at the center.
                            Color.clear
                                .frame(height: CouponTicket.height)
                                .accessibilityHidden(true)
                        } else {
                            CouponCard(
                                coupon: coupon,
                                roomColor: color,
                                roomSymbol: symbol,
                                isAffordable: viewModel.canAfford(coupon),
                                state: viewModel.state(of: coupon),
                                isBuying: viewModel.buyingCouponName == key,
                                onSelect: { focusCoupon(key) }
                            )
                            .matchedGeometryEffect(id: key, in: ticketNamespace)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Focused coupon

    /// Identifies a coupon on screen; the same value ``GamificationViewModel/buyingCouponName`` uses.
    static func couponKey(_ coupon: CouponModel) -> String {
        coupon.recordID?.recordName ?? coupon.name
    }

    private func focusCoupon(_ key: String) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            focusedCouponKey = key
        }
    }

    private func closeFocusedCoupon() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            focusedCouponKey = nil
        }
    }

    /// The chosen coupon at the center, over a white background. Tapping outside it closes it.
    @ViewBuilder
    private var focusedCouponOverlay: some View {
        if let key = focusedCouponKey,
           let coupon = viewModel.selectedCoupons.first(where: { Self.couponKey($0) == key }) {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeFocusedCoupon() }
                    .accessibilityHidden(true)
                    .transition(.opacity)

                FocusedCouponView(
                    coupon: coupon,
                    roomColor: viewModel.selectedRoom?.color ?? .yellow,
                    roomSymbol: viewModel.selectedRoom?.symbol ?? "house",
                    isAffordable: viewModel.canAfford(coupon),
                    state: viewModel.state(of: coupon),
                    isBuying: viewModel.buyingCouponName == key,
                    namespace: ticketNamespace,
                    matchID: key,
                    onBuy: { await viewModel.buy(coupon) },
                    onClose: { closeFocusedCoupon() }
                )
            }
        }
    }

    /// The mascot over the soft yellow disc, like ``ChoresEmptyState``.
    private func emptyState(title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(RoomColor.yellow.lowOpacityColor.opacity(0.3))

                Image("loadingIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96)
            }
            .frame(width: 150, height: 150)
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.titleGray)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(.subTitleGray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    GamificationView(viewModel: GamificationViewModel(
        previewCoins: 45,
        previewPoints: 85,
        previewHistory: [
            RankHistoryModel(
                user: CKRecord.Reference(recordID: CKRecord.ID(recordName: "preview"), action: .none),
                cycleKey: "2026-10-03",
                cycleStart: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 3))!,
                cycleEnd: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 16))!,
                tier: Tier(points: 160),
                points: 10
            ),
            RankHistoryModel(
                user: CKRecord.Reference(recordID: CKRecord.ID(recordName: "preview"), action: .none),
                cycleKey: "2026-10-03",
                cycleStart: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 3))!,
                cycleEnd: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 16))!,
                tier: Tier(points: 160),
                points: 100
            ),
            RankHistoryModel(
                user: CKRecord.Reference(recordID: CKRecord.ID(recordName: "preview"), action: .none),
                cycleKey: "2026-10-03",
                cycleStart: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 3))!,
                cycleEnd: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 16))!,
                tier: Tier(points: 160),
                points: 200
            ),
            RankHistoryModel(
                user: CKRecord.Reference(recordID: CKRecord.ID(recordName: "preview"), action: .none),
                cycleKey: "2026-10-03",
                cycleStart: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 3))!,
                cycleEnd: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 16))!,
                tier: Tier(points: 160),
                points: 300
            ),
            RankHistoryModel(
                user: CKRecord.Reference(recordID: CKRecord.ID(recordName: "preview"), action: .none),
                cycleKey: "2026-10-03",
                cycleStart: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 3))!,
                cycleEnd: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 16))!,
                tier: Tier(points: 160),
                points: 400
            )
        ],
        rooms: [
            RoomModel(name: "Cozinha", symbol: "fork.knife", color: .orange),
            RoomModel(name: "Sala", symbol: "sofa", color: .purple),
            RoomModel(name: "Banheiro", symbol: "shower", color: .blue)
        ],
        couponsByRoomName: [
            "Cozinha": [
                CouponModel(name: "Folga da louça por um dia", isOnSale: true, price: 30, tier: .tier1),
                CouponModel(name: "Escolher o jantar", isOnSale: true, price: 80, tier: .tier3)
            ],
            "Sala": [
                CouponModel(name: "Escolher o filme da noite", isOnSale: true, price: 20, tier: .tier1)
            ]
        ]
    ))
}
