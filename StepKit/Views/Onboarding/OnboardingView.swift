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

    // Colores del tema (consistentes con SignInView)
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)

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
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    OnboardingSlide(
                        icon: slide.icon,
                        title: slide.title,
                        subtitle: slide.subtitle,
                        animation: slide.animation,
                        isVisible: currentPage == index,
                        accentBlue: accentBlue,
                        accentHighlight: accentHighlight
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
                    accentBlue.opacity(0.05)
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentHighlight, accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: glowColor.opacity(0.4), radius: 12, x: 0, y: 6)
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
    let accentBlue: Color
    let accentHighlight: Color

    @State private var animationTrigger = false

    var body: some View {
        VStack(spacing: 32) {
            // Icono con glow
            iconView

            // Textos
            VStack(spacing: 16) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                        colors: [accentHighlight.opacity(0.3), accentBlue.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 140, height: 140)

            // Círculo de fondo
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accentHighlight.opacity(0.2), accentBlue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
            .foregroundStyle(
                LinearGradient(
                    colors: [accentHighlight, accentBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

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
