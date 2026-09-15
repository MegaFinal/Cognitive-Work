//
//  WaitHouseCreatorShedule.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 09/09/26.
//

import SwiftUI

/// Guest screen shown while the admin generates the chore division.
///
/// ## Sync fix
/// The screen used to re-check the server only twice: once in `.task` and whenever
/// `.cloudKitDidChange` arrived. That notification depends on silent pushes, which iOS
/// throttles, coalesces and drops (and never delivered before the `remote-notification`
/// background mode was declared), and `.task` never runs again while the view stays on screen.
/// If the admin finished while the guest's app was in the background, nothing ever triggered a
/// new check, so the guest waited forever. Two completion paths were added, both calling the
/// same, now re-entrancy-safe, `checkAndAdvanceIfScheduleReady()`:
/// - a re-check whenever the app becomes active again;
/// - a low-frequency polling fallback, tied to the view's lifetime (cancelled on disappear).
struct WaitHouseCreatorSheduleView: View {
    /// State shared by every step of the flow.
    @Binding var viewModel: OnboardingViewModel
    
    /// Sync fix: interval of the polling fallback used when no push arrives.
    private let pollingInterval: Duration = .seconds(15)
    
    let description1: String = "Estamos apenas esperando que o criador da casa gere a divisão das tarefas."
    let description2: String = "Isso acontecerá de forma automática assim que todos os membros entrarem na casa e definirem seus horários de tempo livre."
    let description3: String = "Enviaremos uma notificação quando a divisão estiver pronta."
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 40) {
                Image(systemName: "circle.hexagonpath")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.4)
                    .padding(.bottom)
                
                Text("Aguardando divisão de tarefas...")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text(description1)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    Text(description2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)
                    
                    Text(description3)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 30)
        }
        .navigationBarBackButtonHidden()
        .task {
            await viewModel.checkAndAdvanceIfScheduleReady()
            
            // Sync fix: polling fallback. `.task` is cancelled automatically when the view
            // disappears, which ends the loop.
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)
                guard !Task.isCancelled else { break }
                await viewModel.checkAndAdvanceIfScheduleReady()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
            Task(priority: .userInitiated) {
                await viewModel.checkAndAdvanceIfScheduleReady()
                print("Recebi mudança")
            }
        }
        // Sync fix: pushes that arrived (or were dropped) while the app was in the background
        // never reach this view, so re-check as soon as the app is active again.
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
