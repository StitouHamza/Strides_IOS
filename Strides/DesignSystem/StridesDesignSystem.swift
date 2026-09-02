//
//  StridesDesignSystem.swift
//  Strides
//

import SwiftUI

// MARK: - Tokens & Metrics

enum StridesTheme {
    static let cornerRadiusLarge: CGFloat = 26
    static let cornerRadiusMedium: CGFloat = 18
    static let cornerRadiusSmall: CGFloat = 12

    static let hairlineBorder: Color = Color.white.opacity(0.08)
    static let glowOrange: Color = StridesPalette.voltageOrange.opacity(0.35)
    static let glowCyan: Color = StridesPalette.electricCyan.opacity(0.35)

    static let springSnappy: Animation = .interpolatingSpring(stiffness: 300, damping: 24)
    static let springSmooth: Animation = .interpolatingSpring(stiffness: 180, damping: 20)
}

// MARK: - Button Styles & Micro-interactions

struct CockpitButtonStyle: ButtonStyle {
    let baseColor: Color
    let foregroundColor: Color
    var isHero: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(baseColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: isHero ? baseColor.opacity(0.4) : Color.black.opacity(0.3), radius: configuration.isPressed ? 6 : 14, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(StridesTheme.springSnappy, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: configuration.isPressed)
    }
}

// MARK: - Cockpit Gauge Component

struct CockpitGaugeView: View {
    let speedMPS: Double
    let paceFormatted: String
    let isRunning: Bool

    // Gauge range: 0.0 to 6.0 m/s (sprint)
    private var normalizedProgress: Double {
        min(max(speedMPS / 5.5, 0.0), 1.0)
    }

    private var activeColor: Color {
        StridesPalette.speedColor(forMPS: speedMPS)
    }

    var body: some View {
        ZStack {
            // Track & Active Arc
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 14
                let startAngle = Angle.degrees(140)
                let endAngle = Angle.degrees(400)
                let totalSpan = endAngle.degrees - startAngle.degrees

                // Background track
                var bgPath = Path()
                bgPath.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.stroke(bgPath, with: .color(StridesPalette.elevated), style: StrokeStyle(lineWidth: 10, lineCap: .round))

                // Active telemetry sweep
                let currentProgressAngle = Angle.degrees(startAngle.degrees + (totalSpan * normalizedProgress))
                var activePath = Path()
                activePath.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: currentProgressAngle, clockwise: false)
                context.stroke(
                    activePath,
                    with: .color(activeColor),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
            }
            .frame(width: 210, height: 210)
            .animation(StridesTheme.springSmooth, value: normalizedProgress)

            // Dynamic glow node
            Circle()
                .fill(activeColor)
                .frame(width: 8, height: 8)
                .blur(radius: 2)
                .offset(y: -91)
                .rotationEffect(.degrees(140 + (260 * normalizedProgress) - 180))
                .animation(StridesTheme.springSmooth, value: normalizedProgress)
                .opacity(isRunning && normalizedProgress > 0.02 ? 1 : 0)

            // Center Metric Stack
            VStack(spacing: 2) {
                Text(StridesPalette.speedLabel(forMPS: speedMPS))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundColor(activeColor)
                    .animation(StridesTheme.springSnappy, value: activeColor)

                Text(paceFormatted)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .shadow(color: activeColor.opacity(0.4), radius: 10)

                Text("MIN / KM")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 200)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusLarge)
                .fill(StridesPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusLarge)
                        .stroke(StridesTheme.hairlineBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Reusable Metric Telemetry Card

struct HUDMetricCard: View {
    let title: String
    let value: String
    let unit: String
    var accentColor: Color = StridesPalette.electricCyan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.gray)
                .tracking(1.8)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text(unit)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusMedium)
                .fill(StridesPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusMedium)
                        .stroke(StridesTheme.hairlineBorder, lineWidth: 1)
                )
        )
    }
}
