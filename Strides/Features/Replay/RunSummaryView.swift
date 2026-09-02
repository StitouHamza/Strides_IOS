//
//  RunSummaryView.swift
//  Strides
//

import SwiftUI
import MapKit

struct RunSummaryView: View {
    let run: CompletedRun
    @Environment(\.dismiss) private var dismiss
    @State private var showFlyover = false
    @State private var showShareCard = false

    var body: some View {
        NavigationStack {
            ZStack {
                StridesPalette.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // PB Banner Indicator
                        if run.isPersonalBest {
                            HStack(spacing: 8) {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(StridesPalette.voltageOrange)
                                Text("NEW PERSONAL BENCHMARK")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .tracking(2)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(StridesPalette.voltageOrange.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(StridesPalette.voltageOrange.opacity(0.3), lineWidth: 1))
                            .padding(.top, 8)
                        }

                        // Route Map with Flyover Launcher
                        ZStack(alignment: .bottomTrailing) {
                            Map {
                                ForEach(0..<max(0, run.trajectory.count - 1), id: \.self) { idx in
                                    let p1 = run.trajectory[idx]
                                    let p2 = run.trajectory[idx + 1]
                                    MapPolyline(coordinates: [p1.coordinate, p2.coordinate])
                                        .stroke(StridesPalette.speedColor(forMPS: p2.speedMPS), lineWidth: 4)
                                }
                            }
                            .mapStyle(.standard(elevation: .realistic))
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusLarge))
                            .overlay(
                                RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusLarge)
                                    .stroke(StridesTheme.hairlineBorder, lineWidth: 1)
                            )

                            Button {
                                showFlyover = true
                            } label: {
                                Label("3D FLYOVER", systemImage: "play.fill")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(StridesPalette.voltageOrange)
                                    .clipShape(Capsule())
                            }
                            .padding(12)
                        }

                        // Telemetry Grid
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                HUDMetricCard(title: "TOTAL DISTANCE", value: String(format: "%.2f", run.totalDistanceMeters / 1000.0), unit: "KM")
                                HUDMetricCard(title: "AVG PACE", value: run.avgPaceFormatted, unit: "/KM", accentColor: StridesPalette.voltageOrange)
                            }
                            HStack(spacing: 10) {
                                HUDMetricCard(title: "DURATION", value: formatDuration(run.durationSeconds), unit: "ELAPSED")
                                HUDMetricCard(title: "AVG CADENCE", value: "\(run.avgCadenceSPM)", unit: "SPM")
                            }
                        }

                        // Kilometer Splits Breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INTERVAL SPLITS")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(.gray)
                                .tracking(2)

                            ForEach(run.splits) { split in
                                SplitBarRow(split: split, fastestSeconds: run.splits.map(\.durationSeconds).min() ?? 1)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusMedium)
                                .fill(StridesPalette.surface)
                                .overlay(RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusMedium).stroke(StridesTheme.hairlineBorder, lineWidth: 1))
                        )

                        // Action Deck
                        Button("GENERATE RECAP CARD") {
                            showShareCard = true
                        }
                        .buttonStyle(CockpitButtonStyle(baseColor: StridesPalette.voltageOrange, foregroundColor: .black, isHero: true))
                        .padding(.top, 6)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("DEBRIEF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(StridesPalette.voltageOrange)
                }
            }
            .fullScreenCover(isPresented: $showFlyover) {
                Replay3DFlyoverView(run: run)
            }
            .sheet(isPresented: $showShareCard) {
                ShareableRecapView(run: run)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let min = Int(duration) / 60
        let sec = Int(duration) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

struct SplitBarRow: View {
    let split: RunSplit
    let fastestSeconds: Double

    private var relativeRatio: CGFloat {
        CGFloat(fastestSeconds / max(split.durationSeconds, 1.0))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("KM \(split.kilometer)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 44, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(StridesPalette.elevated)
                        .frame(height: 6)

                    Capsule()
                        .fill(StridesPalette.voltageOrange)
                        .frame(width: proxy.size.width * relativeRatio, height: 6)
                }
            }
            .frame(height: 6)

            Text(split.paceFormatted)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
