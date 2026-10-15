//
//  WaitHouseCreatorShedule.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 09/09/26.
//

import SwiftUI

/// Guest screen shown while the admin generates the chore division.
/// If the admin finished while the guest's app was in the background, nothing ever triggered a
/// new check, so the guest waited forever. Two completion paths were added, both calling the
/// same, now re-entrancy-safe, `checkAndAdvanceIfScheduleReady()`:
/// - a re-check whenever the app becomes active again;
/// - a low-frequency polling fallback, tied to the view's lifetime (cancelled on disappear).
struct WaitHouseCreatorSheduleView: View {
    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel

    private let pollingInterval: Duration = .seconds(5)
    
    // `LocalizedStringKey` (not `String`) so `Text` translates them.
    let description1: LocalizedStringKey = "O criador da casa vai gerar a divisão assim que todos definirem seu tempo livre"
    let description2: LocalizedStringKey = "Enviaremos uma notificação quando a divisão estiver pronta"
    
    /// Scrolling chore cards behind the card, same as ``WaitingAlgorithmView``.
    private let columns = ChoreDTO.columnsMock
    @State private var isRotating = 0.0
    
    var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns.indices, id: \.self) { index in
                    InfinityRow(
                        cards: columns[index],
                        movesUp: index.isMultiple(of: 1),
                        speed: 0,
                        phase: Double(index) * 130
                    )
                    .frame(width: 110)
                }
            }
            .frame(width: width, height: height, alignment: .top)
            .clipped()
            .opacity(0.6)
            .accessibilityDecorative()
            
            VStack(spacing: 30) {
                Image("loadingIcon")
                    .rotationEffect(.degrees(isRotating))
                    .accessibilityDecorative()
                    .onAppear {
                        withAnimation(.linear(duration: 1)
                            .speed(0.1).repeatForever(autoreverses: false)) {
                                isRotating = 360.0
                            }
                    }
                
                Text("Aguardando divisão de tarefas...")
                    .font(.system(size: 30))
                    .bold()
                    .accessibilityAddTraits(.isHeader)
                
                VStack(spacing: 15) {
                    Text(description1)
                    Text(description2)
                }
                .accessibilityElement(children: .combine)
                .padding(.horizontal)
                
                // MARK: - Skip
                // Lets the guest go straight into the app instead of watching the automatic
                // division; it still arrives later through CloudKit.
                OnboardingSkipButton {
                    viewModel.finishOnboarding()
                }
            }
            .multilineTextAlignment(.center)
            .frame(width: width * 0.8)
            .padding(.horizontal, 16)
            .padding(.top, 36)
            .padding(.bottom, 24)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 3.2, x: 0, y: 4)
            )
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden()
        .task {
            await viewModel.checkAndAdvanceIfScheduleReady()
            
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)
                guard !Task.isCancelled else { break }
                await viewModel.checkAndAdvanceIfScheduleReady()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task(priority: .userInitiated) {
                await viewModel.checkAndAdvanceIfScheduleReady()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task(priority: .userInitiated) {
                await viewModel.checkAndAdvanceIfScheduleReady()
            }
        }
    }
}

#Preview {
    @Previewable @State var mockViewModel = OnboardingViewModel()
    WaitHouseCreatorSheduleView(viewModel: $mockViewModel)
}
