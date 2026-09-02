import SwiftUI

/// Step shown after the user chooses to join an existing house.
///
/// The app cannot advance on its own here: the user has to open the invite link
/// they received, which triggers the system share-acceptance flow. ``Onboarding``
/// listens for `.didAcceptShare` and moves the flow forward once that happens.
struct WaitAcceptLinkOnboardingView: View {
    @Binding var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeader(
                title: "Aguardando o convite",
                description: "Abra o link que enviaram para você e toque em entrar. Assim que aceitar, voltamos automaticamente por aqui."
            )

            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 8)

            Text("Esperando você aceitar o convite...")
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            Spacer()

            OnboardingProgressButton(text: "Voltar") {
                viewModel.goToPreviousView()
            }
        }
        .padding(.horizontal, 30)
        .navigationBarBackButtonHidden()
    }
}