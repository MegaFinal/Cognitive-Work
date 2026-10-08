//
//  RetroViewModel.swift
//  Cognitive-Work
//
//  Single source of truth for the retrospective area (RetroView and its pages).
//  RetroStreakView is intentionally NOT handled here: its page slot exists in the
//  flow (so the TabView tags stay 0...3) but it has no data and no logic.
//
//  Data flow:
//
//    RetroRepository ──snapshot──▶ RetroViewModel ──▶ per-page content structs
//         (CloudKit)                    │  ▲
//                                       │  └── intents (public methods) called by the Views
//                                       └────▶ RetroEvent stream (AsyncStream) for outside listeners
//

import Foundation

// MARK: - Errors

/// Everything that can go wrong while loading the retrospective.
enum RetroError: Error, Equatable, LocalizedError {
    /// The signed-in user has no profile inside the current house.
    case userNotFound
    /// The device is offline or CloudKit could not be reached.
    case networkUnavailable
    /// Any other failure; carries the localized description of the original error.
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "Não foi possível encontrar o seu perfil na casa."
        case .networkUnavailable:
            return "Sem conexão com a internet."
        case .underlying(let message):
            return message
        }
    }
}

// MARK: - Domain input (plain value types, no CloudKit)

/// One thing the user was supposed to do in the period (a daily assignment or a one-off chore).
struct RetroWorkItem: Equatable, Sendable {
    let id: String
    let day: Date
    let isCompleted: Bool
    let roomID: String?
}

struct RetroRoom: Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let color: RoomColor
}

/// Raw data the repository hands to the view model.
struct RetroSnapshot: Equatable, Sendable {
    var items: [RetroWorkItem]
    var rooms: [RetroRoom]
    /// The user's lifetime points right now (`UserModel.points`).
    var totalPoints: Int
    /// Only the house owner may start a new division of chores.
    var isHouseOwner = true
}

/// Closed interval of days the retrospective covers.
struct RetroPeriod: Equatable, Sendable {
    let start: Date
    let end: Date

    func contains(_ date: Date) -> Bool { date >= start && date <= end }

    /// The last `days` days, ending at `now` (the start is the beginning of that first day).
    static func last(days: Int, endingAt now: Date, calendar: Calendar) -> RetroPeriod {
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? startOfToday
        return RetroPeriod(start: start, end: now)
    }
}

// MARK: - Dependencies

/// Where the retrospective data comes from. `CloudKitRetroRepository` is the production one.
@MainActor
protocol RetroRepository {
    /// Throws `RetroError` (anything else is wrapped as `.underlying`).
    func fetchSnapshot(for period: RetroPeriod) async throws -> RetroSnapshot
}

/// Remembers the user's points when the last retrospective was concluded,
/// so "points earned" only counts what happened since then.
@MainActor
protocol RetroBaselineStore: AnyObject {
    var pointsAtLastRetro: Int? { get set }
}

/// Production store, backed by `UserDefaults`.
@MainActor
final class UserDefaultsRetroBaselineStore: RetroBaselineStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "retro.pointsAtLastRetro") {
        self.defaults = defaults
        self.key = key
    }

    var pointsAtLastRetro: Int? {
        get { defaults.object(forKey: key) as? Int }
        set {
            if let newValue { defaults.set(newValue, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
    }
}

/// Tunable rules. Defaults match the current RetroPointsView.
struct RetroConfiguration: Equatable, Sendable {
    var periodDays = 15
    /// From this many points on, the pig gets a coin.
    var coinPigThreshold = 50
    /// From this many points on, coins also float around the pig.
    var floatingCoinsThreshold = 100
    /// Floating coins shown right at the threshold.
    var baseFloatingCoins = 2
    /// Every extra block of points after the threshold reveals one more coin.
    var pointsPerExtraCoin = 50
    /// Pass `RetroCoinsScatter.maxCount` from the composition root.
    var maxFloatingCoins = 5

    static let `default` = RetroConfiguration()
}

// MARK: - Flow

/// Where the user is in the whole retrospective experience.
enum RetroPhase: Equatable {
    /// "Sua retrospectiva chegou!" (small card)
    case alert
    /// The pager with the retro pages (full-screen card)
    case pages
    /// "Comece a nova divisão de tarefas" (small card)
    case divisionPrompt
    /// The generated schedule (full screen)
    case schedule
    /// Nothing left to show; the host can remove RetroView.
    case dismissed
}

/// Pager pages. Raw values are the TabView tags.
enum RetroPage: Int, CaseIterable, Equatable, Sendable {
    case percentage = 0
    /// Placeholder: RetroStreakView is developed later. It only occupies its slot in the pager.
//    case streak = 1
    case points = 1
    case rooms = 2
}

enum RetroLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(RetroError)
}

/// Things other parts of the app can react to without knowing any View.
enum RetroEvent: Equatable {
    case loaded
    case loadFailed(RetroError)
    case pageChanged(RetroPage)
    case retrospectiveSkipped
    case retrospectiveCompleted
    case divisionRequested
    case divisionDeferred
    case divisionConfirmed
    /// The experience is over and the host should remove it (always the last event of a flow).
    case finished
}

// MARK: - Per-page content

/// What `RetroPercentageOfDoneView` needs.
struct RetroPercentageContent: Equatable {
    let completedChores: Int
    let totalChores: Int
    /// 0...100
    let percentage: Double
    let summary: String
    let subtitle: String
    let closing: String

    static let empty = RetroPercentageContent(
        completedChores: 0, totalChores: 0, percentage: 0,
        summary: "", subtitle: "", closing: ""
    )
}

/// What `RetroPointsView` needs.
struct RetroPointsContent: Equatable {
    let points: Int
    let pointsLabel: String
    let hasCoinPig: Bool
    let floatingCoinsCount: Int
    let message: String

    var hasFloatingCoins: Bool { floatingCoinsCount > 0 }

    static let empty = RetroPointsContent(
        points: 0, pointsLabel: "", hasCoinPig: false, floatingCoinsCount: 0, message: ""
    )
}

/// What `RetroRoomsView` needs.
struct RetroRoomsContent: Equatable {
    struct Bar: Equatable, Identifiable {
        let id: String
        let roomName: String
        let color: RoomColor
        let choreCount: Int
    }

    let title: String
    let subtitle: String
    /// Sorted by chore count, highest first.
    let bars: [Bar]
    var maxChoreCount: Int { bars.map(\.choreCount).max() ?? 0 }

    static let empty = RetroRoomsContent(title: "", subtitle: "", bars: [])
}

// MARK: - Calculator (pure business rules)

/// All transformations from raw data to screen content. Pure and stateless, so it is trivial to test.
enum RetroCalculator {

    static func percentage(items: [RetroWorkItem], period: RetroPeriod) -> RetroPercentageContent {
        let inPeriod = items.filter { period.contains($0.day) }
        let total = inPeriod.count
        let completed = inPeriod.filter(\.isCompleted).count
        let percentage = total > 0
            ? min(max(Double(completed) / Double(total) * 100, 0), 100)
            : 0

        let subtitle: String
        let closing: String
        switch percentage {
        case _ where total == 0:
            subtitle = "Você não teve tarefas na escala nesse período"
            closing = "bora na próxima!"
        case 100:
            subtitle = "Você fez tudo o que era seu"
            closing = "parabéns!"
        case 50...:
            subtitle = "Foi por pouco, na próxima você chega lá"
            closing = "quase lá!"
        default:
            subtitle = "Vamos tentar de novo na próxima"
            closing = "você consegue!"
        }

        return RetroPercentageContent(
            completedChores: completed,
            totalChores: total,
            percentage: percentage,
            summary: "Você realizou \(completed) de \(total) \n tarefas da sua escala",
            subtitle: subtitle,
            closing: closing
        )
    }

    static func points(earned: Int, configuration c: RetroConfiguration) -> RetroPointsContent {
        let points = max(earned, 0)
        let hasCoinPig = points >= c.coinPigThreshold
        let hasFloating = points >= c.floatingCoinsThreshold

        var coins = 0
        if hasFloating {
            let extra = c.pointsPerExtraCoin > 0
                ? (points - c.floatingCoinsThreshold) / c.pointsPerExtraCoin
                : 0
            coins = min(c.baseFloatingCoins + extra, c.maxFloatingCoins)
        }

        let message: String
        if hasFloating {
            message = "Boa parte do que a casa fez começou com você percebendo, parabéns!"
        } else if hasCoinPig {
            message = "Reparar que algo precisa ser feito também é trabalho, parabéns!"
        } else {
            message = "Cada coisa que você reparou conta!"
        }

        return RetroPointsContent(
            points: points,
            pointsLabel: "\(points) \(points == 1 ? "ponto" : "pontos")",
            hasCoinPig: hasCoinPig,
            floatingCoinsCount: coins,
            message: message
        )
    }

    /// Counts the chores the user actually completed per room.
    static func rooms(items: [RetroWorkItem], rooms: [RetroRoom], period: RetroPeriod) -> RetroRoomsContent {
        var counts: [String: Int] = [:]
        for item in items where item.isCompleted && period.contains(item.day) {
            if let roomID = item.roomID { counts[roomID, default: 0] += 1 }
        }

        let bars = rooms
            .compactMap { room -> RetroRoomsContent.Bar? in
                guard let count = counts[room.id], count > 0 else { return nil }
                return .init(id: room.id, roomName: room.name, color: room.color, choreCount: count)
            }
            .sorted { $0.choreCount != $1.choreCount ? $0.choreCount > $1.choreCount : $0.roomName < $1.roomName }

        guard let top = bars.first else {
            return RetroRoomsContent(title: "0 cômodos", subtitle: "Nenhuma tarefa concluída nesse período.", bars: [])
        }
        return RetroRoomsContent(
            title: "\(bars.count) \(bars.count == 1 ? "cômodo" : "cômodos")",
            subtitle: "Seu cômodo mais trabalhado: \(top.roomName).",
            bars: bars
        )
    }
}

// MARK: - Event bus

/// Fan-out of `RetroEvent`s to any number of `AsyncStream` subscribers.
/// Each subscription is removed automatically when its consuming task ends or is cancelled.
@MainActor
final class RetroEventBus {
    private var continuations: [UUID: AsyncStream<RetroEvent>.Continuation] = [:]

    func makeStream() -> AsyncStream<RetroEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: RetroEvent.self, bufferingPolicy: .bufferingNewest(32)
        )
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    func send(_ event: RetroEvent) {
        for continuation in continuations.values { continuation.yield(event) }
    }

    func finish() {
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
    }
}

// MARK: - ViewModel

/// Orchestrates the whole retrospective: loading, flow between phases/pages, and the content of each page.
///
/// Views never compute anything: they read the `*Content` properties and call the intent methods.
@MainActor
@Observable
final class RetroViewModel {

    // MARK: Overall state

    /// Loading status of the retrospective data. `RetroAlert`/pages can show a spinner or an error from it.
    private(set) var loadState: RetroLoadState = .idle

    /// Which screen of the experience is showing. Single source of truth for RetroView's old
    /// `showPages`, `isRetroDone` and `showSchedule` flags.
    private(set) var phase: RetroPhase = .alert

    /// Whether the signed-in user owns the house. Only the owner gets the new-division prompt;
    /// everyone else goes straight from the retrospective to the end.
    private(set) var isHouseOwner = false

    /// Current page of the pager.
    private(set) var currentPage: RetroPage = .percentage

    /// Period covered (set on every load).
    private(set) var period: RetroPeriod

    // MARK: Per-screen content (each View reads only its own)

    /// For `RetroPercentageOfDoneView`.
    private(set) var percentageContent: RetroPercentageContent = .empty
    /// For `RetroPointsView`.
    private(set) var pointsContent: RetroPointsContent = .empty
    /// For `RetroRoomsView`.
    private(set) var roomsContent: RetroRoomsContent = .empty

    // MARK: Derived state

    /// Whether the white card fills the screen (replaces `isExpanded`).
    var isCardExpanded: Bool { phase == .pages || phase == .schedule }

    /// True while the rooms page is the visible one, so its bars grow each time it appears
    /// (replaces `isActive: page == 3`).
    var isRoomsPageActive: Bool { phase == .pages && currentPage == .rooms }

    var isLastPage: Bool { currentPage == RetroPage.allCases.last }

    /// Two-way bridge for `TabView(selection:)`. Use with `@Bindable`: `$viewModel.pageIndex`.
    var pageIndex: Int {
        get { currentPage.rawValue }
        set { if let page = RetroPage(rawValue: newValue) { goToPage(page) } }
    }

    // MARK: Dependencies

    private let repository: RetroRepository
    private let baselineStore: RetroBaselineStore
    private let configuration: RetroConfiguration
    private let clock: () -> Date
    private let calendar: Calendar
    private let eventBus: RetroEventBus

    private var snapshot: RetroSnapshot?
    private var loadTask: Task<Void, Never>?
    /// Incremented on every load; a finished load only applies its result if it is still the latest.
    private var loadGeneration = 0

    init(
        repository: RetroRepository,
        baselineStore: RetroBaselineStore? = nil,
        configuration: RetroConfiguration = .default,
        calendar: Calendar = .current,
        clock: @escaping () -> Date = { Date() },
        eventBus: RetroEventBus? = nil
    ) {
        self.repository = repository
        self.baselineStore = baselineStore ?? UserDefaultsRetroBaselineStore()
        self.configuration = configuration
        self.calendar = calendar
        self.clock = clock
        self.eventBus = eventBus ?? RetroEventBus()
        self.period = .last(days: configuration.periodDays, endingAt: clock(), calendar: calendar)
    }

    // MARK: - Events (View ↔ View, ViewModel ↔ app, without direct coupling)

    /// A new stream of events. Each caller gets its own; it ends when the consuming task is cancelled.
    ///
    ///     .task { for await event in viewModel.makeEventStream() { ... } }
    func makeEventStream() -> AsyncStream<RetroEvent> { eventBus.makeStream() }

    // MARK: - Loading

    /// Loads and publishes all page content. Safe to call repeatedly: only the latest call wins.
    /// Use from `.task { await viewModel.load() }` so SwiftUI cancels it with the view.
    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        let hadData = snapshot != nil
        loadState = .loading
        period = .last(days: configuration.periodDays, endingAt: clock(), calendar: calendar)
        let requestedPeriod = period

        do {
            let result = try await repository.fetchSnapshot(for: requestedPeriod)
            guard generation == loadGeneration, !Task.isCancelled else {
                if generation == loadGeneration { loadState = hadData ? .loaded : .idle }
                return
            }
            snapshot = result
            isHouseOwner = result.isHouseOwner
            publishContent(from: result, period: requestedPeriod)
            loadState = .loaded
            eventBus.send(.loaded)
        } catch is CancellationError {
            if generation == loadGeneration { loadState = hadData ? .loaded : .idle }
        } catch {
            guard generation == loadGeneration else { return }
            let retroError = (error as? RetroError) ?? .underlying(error.localizedDescription)
            loadState = .failed(retroError)
            eventBus.send(.loadFailed(retroError))
        }
    }

    /// Fire-and-forget version of `load()` for buttons ("tentar de novo"). Cancels a load in flight.
    func reload() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in await self?.load() }
    }

    /// Cancels any load in flight. Call from `onDisappear` if the VM outlives the view.
    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func publishContent(from snapshot: RetroSnapshot, period: RetroPeriod) {
        percentageContent = RetroCalculator.percentage(items: snapshot.items, period: period)
        pointsContent = RetroCalculator.points(earned: pointsEarned(in: snapshot), configuration: configuration)
        roomsContent = RetroCalculator.rooms(items: snapshot.items, rooms: snapshot.rooms, period: period)
    }

    private func pointsEarned(in snapshot: RetroSnapshot) -> Int {
        guard let baseline = baselineStore.pointsAtLastRetro else { return snapshot.totalPoints }
        return max(snapshot.totalPoints - baseline, 0)
    }

    // MARK: - Intents: alert → pages

    /// "Ver minha retrospectiva". Only valid on the alert. The View keeps its own fade timing.
    func startRetrospective() {
        guard phase == .alert else { return }
        currentPage = .percentage
        phase = .pages
    }

    // MARK: - Intents: pager

    /// "Continuar". On the last page it does nothing (the last page uses `finishRetrospective()`).
    func continueToNextPage() {
        guard phase == .pages,
              let next = RetroPage(rawValue: currentPage.rawValue + 1) else { return }
        goToPage(next)
    }

    /// Also called by swipes through `pageIndex`.
    func goToPage(_ page: RetroPage) {
        guard phase == .pages, page != currentPage else { return }
        currentPage = page
        eventBus.send(.pageChanged(page))
    }

    // MARK: - Intents: leaving the pages

    /// "ver depois" (pages) or "Pular para a nova divisão" (alert): jumps straight to the
    /// new-division prompt. Does not reset the points baseline.
    func skipRetrospective() {
        guard phase == .alert || phase == .pages else { return }
        eventBus.send(.retrospectiveSkipped)
        leaveRetrospective()
    }

    /// "Concluir" on the last page. Goes to the division prompt and starts a new points cycle.
    func finishRetrospective() {
        guard phase == .pages else { return }
        if let snapshot { baselineStore.pointsAtLastRetro = snapshot.totalPoints }
        eventBus.send(.retrospectiveCompleted)
        leaveRetrospective()
    }

    // MARK: - Intents: new division

    /// "Divisão automática de tarefas".
    func requestAutomaticDivision() {
        guard phase == .divisionPrompt, isHouseOwner else { return }
        phase = .schedule
        eventBus.send(.divisionRequested)
    }

    /// "Dividir mais tarde".
    func deferDivision() {
        guard phase == .divisionPrompt else { return }
        eventBus.send(.divisionDeferred)
        dismiss()
    }

    /// The user confirmed the generated schedule (replaces RetroView's `onFinish`).
    func confirmSchedule() {
        guard phase == .schedule else { return }
        eventBus.send(.divisionConfirmed)
        dismiss()
    }

    // MARK: - Flow helpers

    /// After the retrospective: the owner is offered the new division; everyone else is done.
    private func leaveRetrospective() {
        if isHouseOwner {
            phase = .divisionPrompt
        } else {
            dismiss()
        }
    }

    private func dismiss() {
        phase = .dismissed
        eventBus.send(.finished)
    }
}
