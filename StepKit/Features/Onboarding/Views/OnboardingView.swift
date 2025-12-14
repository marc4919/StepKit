//
//  OnboardingView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 6/12/25.
//

import SwiftUI

enum SlideAnimation {
    case bounce
    case breathe
    case none
}

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void


    private let slides: [(icon: String, title: String, subtitle: String, animation: SlideAnimation)] = [
        (
            icon: "figure.walk",
            title: "El primer paso importa",
            subtitle: "Dinos tu objetivo. Te mostramos cómo empezar sin bloquearte.",
            animation: .bounce
        ),
        (
            icon: "list.bullet.clipboard",
            title: "Un plan para ti",
            subtitle: "Transformamos tu meta en pasos sencillos que puedes seguir a tu ritmo.",
            animation: .none
        ),
        (
            icon: "heart.fill",
            title: "Construimos StepKit juntos",
            subtitle: "Esta es la primera versión. Disfruta el camino.",
            animation: .breathe
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // TabView con slides
            TabView(selection: $currentPage) {
                ForEach(slides.enumerated(), id: \.offset) { index, slide in
                    OnboardingSlide(
                        icon: slide.icon,
                        title: slide.title,
                        subtitle: slide.subtitle,
                        animation: slide.animation,
                        isVisible: currentPage == index
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Spacer()

            // Botón de acción
            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var actionButton: some View {
        Button {
            if currentPage < slides.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage += 1
                }
            } else {
                onComplete()
            }
        } label: {
            HStack(spacing: 8) {
                Text(currentPage == slides.count - 1 ? "Empezar" : "Siguiente")
                    .font(.headline)

                if currentPage < slides.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(LinearGradient.accentGradient)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .glowShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Onboarding Slide
struct OnboardingSlide: View {
    let icon: String
    let title: String
    let subtitle: String
    let animation: SlideAnimation
    let isVisible: Bool

    @State private var animationTrigger = false

    var body: some View {
        VStack(spacing: 32) {
            // Icono con glow
            iconView

            // Textos
            VStack(spacing: 16) {
                Text(title)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.horizontal, 24)
    }

    private var iconView: some View {
        ZStack {
            // Glow exterior
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentHighlight.opacity(0.3), Color.accentColor.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 140, height: 140)

            // Círculo de fondo
            Circle()
                .fill(LinearGradient.accentWithOpacity( 0.2))
                .frame(width: 100, height: 100)

            // Icono con animación
            iconImage
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                animationTrigger.toggle()
            }
        }
        .onAppear {
            if isVisible {
                animationTrigger = true
            }
        }
    }

    @ViewBuilder
    private var iconImage: some View {
        let baseIcon = Image(systemName: icon)
            .font(.system(size: 44, weight: .medium))
            .foregroundStyle(LinearGradient.accentGradient)

        switch animation {
        case .bounce:
            baseIcon
                .symbolEffect(.bounce, value: animationTrigger)
        case .breathe:
            baseIcon
                .symbolEffect(.breathe, options: .repeating, isActive: isVisible)
        case .none:
            baseIcon
        }
    }
}

// MARK: - Previews
#Preview("Slide 1") {
    OnboardingView(onComplete: {})
}

#Preview("Dark Mode") {
    OnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}
