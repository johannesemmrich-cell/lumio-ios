import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = OnboardingViewModel()
    @Namespace private var animation

    var body: some View {
        ZStack {
            OnboardingBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingProgressBar(currentStep: viewModel.currentStep, totalSteps: OnboardingStep.allCases.count)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                TabView(selection: $viewModel.currentStep) {
                    ForEach(OnboardingStep.allCases, id: \.self) { step in
                        OnboardingStepView(step: step, viewModel: viewModel)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: viewModel.currentStep)
            }
        }
    }
}

struct OnboardingBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            Color.black
                .overlay(
                    RadialGradient(
                        colors: [Color.sunwakeAccent.opacity(0.15), Color.clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
        } else {
            Color(UIColor.systemBackground)
                .overlay(
                    RadialGradient(
                        colors: [Color.sunwakeAccent.opacity(0.08), Color.clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
        }
    }
}

struct OnboardingProgressBar: View {
    let currentStep: OnboardingStep
    let totalSteps: Int

    private var progress: Double {
        Double(currentStep.rawValue + 1) / Double(totalSteps)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 3)
                Capsule()
                    .fill(Color.sunwakeAccent)
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.spring(duration: 0.4), value: progress)
            }
        }
        .frame(height: 3)
    }
}
