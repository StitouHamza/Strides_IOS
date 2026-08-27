//
//  StridesWidgetLiveActivity.swift
//  StridesWidget
//
//  Lock Screen banner + Dynamic Island for a live run, in the Strides
//  dark-cockpit style. Driven by `RunActivityAttributes` (shared with the app).
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StridesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            // MARK: Lock Screen / banner
            LockScreenRunView(context: context)
                .activityBackgroundTint(Color(hex: "09090B"))
                .activitySystemActionForegroundColor(Color(hex: "FF5500"))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandMetric(value: context.state.currentPace,
                                 label: "PACE /KM",
                                 tint: Color(hex: "FF5500"))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandMetric(value: String(format: "%.2f", context.state.distanceKm),
                                 label: "KM",
                                 tint: .white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ghostBar(delta: context.state.ghostDeltaSeconds)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundColor(Color(hex: "FF5500"))
            } compactTrailing: {
                Text(context.state.currentPace)
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundColor(Color(hex: "FF5500"))
            } minimal: {
                Text(ghostShort(context.state.ghostDeltaSeconds))
                    .font(.system(.caption2, design: .monospaced, weight: .heavy))
                    .foregroundColor(ghostColor(context.state.ghostDeltaSeconds))
            }
            .keylineTint(Color(hex: "FF5500"))
        }
    }

    // MARK: - Dynamic Island helpers

    private func islandMetric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)
        }
    }

    private func ghostBar(delta: Int) -> some View {
        let ahead = delta <= 0
        return HStack(spacing: 6) {
            Image(systemName: ahead ? "arrow.up.forward" : "arrow.down.forward")
                .font(.system(size: 11, weight: .black))
            Text(String(format: "%@%ds", ahead ? "-" : "+", abs(delta)))
                .font(.system(.callout, design: .monospaced, weight: .heavy))
            Text(ahead ? "AHEAD OF PB" : "BEHIND PB")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
        }
        .foregroundColor(ghostColor(delta))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
    }

    private func ghostShort(_ delta: Int) -> String {
        String(format: "%@%d", delta <= 0 ? "-" : "+", abs(delta))
    }

    private func ghostColor(_ delta: Int) -> Color {
        delta <= 0 ? Color(hex: "10B981") : Color(hex: "EF4444")
    }
}

// MARK: - Lock Screen view

private struct LockScreenRunView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.currentPace)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "FF5500"))
                Text("PACE /KM · \(context.attributes.routeName.uppercased())")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f KM", context.state.distanceKm))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                let ahead = context.state.ghostDeltaSeconds <= 0
                HStack(spacing: 3) {
                    Text(String(format: "%@%ds", ahead ? "-" : "+", abs(context.state.ghostDeltaSeconds)))
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(ahead ? Color(hex: "10B981") : Color(hex: "EF4444"))
                    Text("vs GHOST")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
    }
}

// MARK: - Hex color (widget-local copy; the app has its own in Shared/)

fileprivate extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

extension RunActivityAttributes {
    fileprivate static var preview: RunActivityAttributes {
        RunActivityAttributes(routeName: "Riverside Loop")
    }
}

extension RunActivityAttributes.ContentState {
    fileprivate static var ahead: RunActivityAttributes.ContentState {
        .init(currentPace: "5'02\"", distanceKm: 4.21, ghostDeltaSeconds: -7)
    }
    fileprivate static var behind: RunActivityAttributes.ContentState {
        .init(currentPace: "5'48\"", distanceKm: 4.21, ghostDeltaSeconds: 12)
    }
}

#Preview("Lock Screen", as: .content, using: RunActivityAttributes.preview) {
    StridesWidgetLiveActivity()
} contentStates: {
    RunActivityAttributes.ContentState.ahead
    RunActivityAttributes.ContentState.behind
}
