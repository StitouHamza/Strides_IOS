//
//  RunActivityWidget.swift
//  Strides
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RunActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            // Lock Screen / StandBy Banner HUD
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CRUISE PACE")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                    Text(context.state.currentPace)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(StridesPalette.voltageOrange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("DISTANCE")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.2f", context.state.distanceKm))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("KM")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(StridesPalette.electricCyan)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(StridesPalette.surface)
            .activityBackgroundTint(StridesPalette.canvas)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Island
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PACE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.gray)
                        Text(context.state.currentPace)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(StridesPalette.voltageOrange)
                    }
                    .padding(.leading, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("DISTANCE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f KM", context.state.distanceKm))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        let isAhead = context.state.ghostDeltaSeconds <= 0
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isAhead ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            Text("\(isAhead ? "-" : "+")\(abs(context.state.ghostDeltaSeconds))s VS PB")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("STRIDES HUD")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .foregroundColor(StridesPalette.voltageOrange)
                    Text(context.state.currentPace)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                Text(String(format: "%.1fK", context.state.distanceKm))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(StridesPalette.electricCyan)
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundColor(StridesPalette.voltageOrange)
            }
        }
    }
}
