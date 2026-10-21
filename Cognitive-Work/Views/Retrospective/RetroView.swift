//
//  RetroView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 29/09/26.
//

import SwiftUI

/// Container of the retrospective. It owns no flow state: `RetroViewModel.phase` and `pageIndex`
/// decide what shows, and every page reads only its own content from the same view model.
struct RetroView: View {
    @State private var viewModel: RetroViewModel
    
    /// Coins to redeem on the points page. The presenting screen may pass one it already loaded.
    @State private var coinsViewModel: RetroCoinsViewModel
    
    /// Presentation-only: the card expands first (with the alert still on it), then the pages fade in.
    @State private var pagesVisible = false
    
    /// Called when the flow ends (schedule confirmed, or "Dividir mais tarde").
    var onFinish: () -> Void
    
    /// - Parameters:
    ///   - viewModel: Inject one for previews/tests. `nil` builds the production one.
    ///   - coinsViewModel: Coins already loaded by the presenting screen. `nil` builds (and loads) a new one.
    init(
        viewModel: RetroViewModel? = nil,
        coinsViewModel: RetroCoinsViewModel? = nil,
        onFinish: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel ?? RetroViewModel(
            repository: CloudKitRetroRepository(),
            configuration: RetroConfiguration(maxFloatingCoins: RetroCoinsScatter.maxCount)
        ))
        _coinsViewModel = State(initialValue: coinsViewModel ?? RetroCoinsViewModel())
        self.onFinish = onFinish
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        // Group (not the ZStack) carries the tasks: they must outlive `.dismissed`
        // so the final event still reaches `onFinish`.
        Group {
            if viewModel.phase != .dismissed {
                ZStack {
                    // The card is sized from the real container (not the global `width`/`height`,
                    // which come from the screen and can differ from the container, e.g. in previews),
                    // so its bottom edge, and the page indicator, never fall off the screen.
                    GeometryReader { proxy in
                        ZStack {
                            Color.black.opacity(0.45)
                                .contentShape(Rectangle())
                                .onTapGesture { }
                                .accessibilityDecorative()
                            
                            RoundedRectangle(cornerRadius: 32)
                                // Real sizes (not .infinity), so SwiftUI can interpolate the size in both directions.
                                .frame(width: viewModel.isCardExpanded ? proxy.size.width : proxy.size.width * 0.87,
                                       height: viewModel.isCardExpanded ? proxy.size.height : proxy.size.height * 0.59)
                                .foregroundStyle(.white)
                                .overlay {
                            // Same branch for "alert" and "pages not visible yet": the alert must keep its
                            // identity while the card expands, otherwise it is recreated and the animation is lost.
                            if showsAlert {
                                RetroAlert(viewModel: viewModel)
                                    .transition(.opacity)
                            } else if viewModel.phase == .pages {
                                VStack(spacing: 12) {
                                    TabView(selection: $viewModel.pageIndex) {
                                        RetroPercentageOfDoneView(viewModel: viewModel)
                                            .tag(RetroPage.percentage.rawValue)
                                        // Developed later; still bound to the same page/flow.
//                                        RetroStreakView(page: $viewModel.pageIndex, isRetroDone: isRetroDoneBinding)
//                                            .tag(RetroPage.streak.rawValue)
                                        RetroPointsView(viewModel: viewModel, coinsViewModel: coinsViewModel)
                                            .tag(RetroPage.points.rawValue)
                                        RetroRoomsView(viewModel: viewModel)
                                            .tag(RetroPage.rooms.rawValue)
                                    }
                                    .tabViewStyle(.page(indexDisplayMode: .never))
                                    PageIndicator(count: 3, current: $viewModel.pageIndex)
                                        // Clears the home indicator, now that the card reaches the screen edge.
                                        .padding(.bottom, 16)

                                }
                                .transition(.opacity)
                            } else if viewModel.phase == .divisionPrompt {
                                RetroNewChoresDivision(
                                    onAutomaticDivision: { withAnimation { viewModel.requestAutomaticDivision() } },
                                    onLater: { withAnimation { viewModel.deferDivision() } }
                                )
                            }
                        }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .ignoresSafeArea()
                    
                    if viewModel.phase == .schedule {
                        NavigationStack {
                            FortnightlyScheduleView(shouldGenerate: true) {
                                viewModel.confirmSchedule()
                            }
                        }
                        .background(Color(.systemBackground).ignoresSafeArea())
                        .transition(.opacity)
                    }
                }
            }
        }
        // Voice Control has no escape gesture: an invisible, touch-transparent "Fechar"
        // element in the top corner lets the user say "Toque em Fechar".
        .overlay(alignment: .topTrailing) {
            if viewModel.phase != .dismissed && viewModel.phase != .schedule {
                DashboardVoiceControlButton(
                    labels: [L10n.tr("Fechar"), L10n.tr("Sair")],
                    action: close
                )
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
        .task { await viewModel.load() }
        // Idempotent: reuses the load the presenting screen may have started.
        .task { await coinsViewModel.load() }
        .task {
            for await event in viewModel.makeEventStream() {
                switch event {
                case .finished: onFinish()
                default: break
                }
            }
        }
        // Each step swaps the whole content: let VoiceOver re-read it from the top.
        .onChange(of: viewModel.currentPage) { VoiceOver.screenChanged() }
        .onChange(of: viewModel.phase) { _, phase in
            VoiceOver.screenChanged()
            guard phase == .pages, !pagesVisible else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.easeInOut(duration: 0.3)) { pagesVisible = true }
            }
        }
    }
    
    /// Escape gesture / "Fechar": leaves the current step the same way its "later" button does.
    private func close() {
        withAnimation {
            switch viewModel.phase {
            case .alert, .pages: viewModel.skipRetrospective()
            case .divisionPrompt: viewModel.deferDivision()
            case .schedule, .dismissed: break
            }
        }
    }
    
    private var showsAlert: Bool {
        viewModel.phase == .alert || (viewModel.phase == .pages && !pagesVisible)
    }
    
    /// Lets `RetroStreakView` (not migrated yet) keep its `isRetroDone` contract:
    /// setting it to `true` means "ver depois".
    private var isRetroDoneBinding: Binding<Bool> {
        Binding(
            get: { viewModel.phase != .pages },
            set: { if $0 { viewModel.skipRetrospective() } }
        )
    }
}

#if DEBUG
// MARK: - Preview support

/// Repository that returns fixed data, for previews.
struct PreviewRetroRepository: RetroRepository {
    var completed = 3
    var total = 4
    var points = 60
    
    func fetchSnapshot(for period: RetroPeriod) async throws -> RetroSnapshot {
        let day = Date().addingTimeInterval(-3600)
        let rooms = [
            RetroRoom(id: "kitchen", name: "Cozinha", color: .blue),
            RetroRoom(id: "living", name: "Sala", color: .green),
            RetroRoom(id: "bath", name: "Banheiro", color: .orange)
        ]
        let items = (0..<total).map { index in
            RetroWorkItem(id: "\(index)", day: day, isCompleted: index < completed,
                          roomID: rooms[index % rooms.count].id)
        }
        return RetroSnapshot(items: items, rooms: rooms, totalPoints: points)
    }
}

/// Loads a preview view model, optionally jumps to the pages, then shows `content`.
struct RetroPreviewHost<Content: View>: View {
    @State private var viewModel: RetroViewModel
    private let startOnPages: Bool
    private let page: RetroPage
    private let content: (RetroViewModel) -> Content
    
    init(
        completed: Int = 3, total: Int = 4, points: Int = 60,
        startOnPages: Bool = true,
        page: RetroPage = .percentage,
        @ViewBuilder content: @escaping (RetroViewModel) -> Content
    ) {
        _viewModel = State(initialValue: RetroViewModel(
            repository: PreviewRetroRepository(completed: completed, total: total, points: points),
            baselineStore: PreviewBaselineStore(),
            configuration: RetroConfiguration(maxFloatingCoins: RetroCoinsScatter.maxCount)
        ))
        self.startOnPages = startOnPages
        self.page = page
        self.content = content
    }
    
    var body: some View {
        content(viewModel)
            .task {
                await viewModel.load()
                if startOnPages {
                    viewModel.startRetrospective()
                    viewModel.goToPage(page)
                }
            }
    }
}

@MainActor
private final class PreviewBaselineStore: RetroBaselineStore {
    var pointsAtLastRetro: Int?
}

#Preview {
    RetroView(viewModel: RetroViewModel(
        repository: PreviewRetroRepository(),
        baselineStore: PreviewBaselineStore()
    ))
}
#endif
